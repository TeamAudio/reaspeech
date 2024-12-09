--[[

  TranscriptExporter.lua - Transcript export UI

]] --
TranscriptExporter = Polo {
    TITLE = 'Export',
    WIDTH = 650,
    HEIGHT = 200,
    BUTTON_WIDTH = 120,
    INPUT_WIDTH = 120,
    FILE_WIDTH = 500
}

function TranscriptExporter:init()
    assert(self.transcript, 'missing transcript')

    Logging.init(self, 'TranscriptExporter')

    ToolWindow.init(self, {
        title = self.TITLE,
        width = self.WIDTH,
        height = self.HEIGHT,
        window_flags = 0 | ImGui.WindowFlags_AlwaysAutoResize() | ImGui.WindowFlags_NoCollapse() |
            ImGui.WindowFlags_NoDocking()
    })

    self.export_formats = TranscriptExporterFormats.new {TranscriptExportFormat.exporter_json(),
                                                         TranscriptExportFormat.exporter_srt(),
                                                         TranscriptExportFormat.exporter_csv(),
                                                         TranscriptExportFormat.exporter_vtt()}

    self.export_options = {}

    self.file_selector = ReaSpeechFileSelector.new({
        label = 'File',
        save = true,
        button_width = self.BUTTON_WIDTH,
        input_width = self.FILE_WIDTH
    })

    self.alert_popup = AlertPopup.new {}

end

function TranscriptExporter:show_success()
    self.alert_popup.onclose = function()
        self.alert_popup.onclose = nil
        self:close()
    end
    self.alert_popup:show('Export Successful',
        'Exported ' .. self.export_formats:selected_key() .. ' to: ' .. self.file_selector:value())
end

function TranscriptExporter:show_error(msg)
    self.alert_popup:show('Export Failed', msg)
end

function TranscriptExporter:render_content()
    self.alert_popup:render()

    self.export_formats:render_combo()

    ImGui.Spacing(ctx)

    self.export_formats:render_format_options(self.export_options)

    ImGui.Spacing(ctx)

    self:render_file_selector()

    self:render_separator()

    self:render_buttons()
end

function TranscriptExporter:render_file_selector()
    self.file_selector:render()
end

function TranscriptExporter:render_buttons()
    ReaUtil.disabler(ctx)(self.file_selector:value() == '', function()
        if ImGui.Button(ctx, 'Export', self.BUTTON_WIDTH, 0) then
            if self:handle_export() then
                self:show_success()
            end
        end
    end)

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'Cancel', self.BUTTON_WIDTH, 0) then
        self:close()
    end
end

function TranscriptExporter:handle_export()
    if self.file_selector:value() == '' then
        self:show_error('Please specify a file name.')
        return false
    end
    local file = io.open(self.file_selector:value(), 'w')
    if not file then
        self:show_error('Could not open file: ' .. self.file_selector:value())
        return false
    end
    self.export_formats:write(self.transcript, file, self.export_options)
    file:close()
    return true
end

TranscriptExporterFormats = Polo {
    new = function(formatters)
        local format_map = {}

        for i, formatter in ipairs(formatters) do
            format_map[formatter.key] = i
        end

        return {
            formatters = formatters,
            format_map = format_map
        }
    end
}

function TranscriptExporterFormats:init()
    if not self.format_widget then
        local storage = Storage.ExtState.make {
            section = 'ReaSpeech.Export.Format',
            persist = true
        }

        local format_items = {}
        for _, format in ipairs(self.formatters) do
            table.insert(format_items, format.key)
        end

        self.format_widget = ReaSpeechCombo.new {
            state = storage:string('format', self.formatters[1].key),
            label = 'Format',
            items = format_items
        }
    end
end

function TranscriptExporterFormats:render_combo()
    self:init()
    self.format_widget:render()
end

function TranscriptExporterFormats:selected_key()
    return self.format_widget:value()
end

function TranscriptExporterFormats:file_selector_spec()
    return self:selected_format():file_selector_spec()
end

function TranscriptExporterFormats:write(transcript, output_file, options)
    return self:selected_format().writer(transcript, output_file, options)
end

function TranscriptExporterFormats:selected_format()
    local index = self.format_map[self:selected_key()]
    return self.formatters[index]
end

function TranscriptExporterFormats:render_format_options(options)
    Trap(function()
        local format = self:selected_format()

        if format then
            format.option_renderer(options)
        end
    end)
end

TranscriptExportFormat = Polo {
    OPTIONS_NOOP = function(_options)
    end,

    new = function(key, extension, option_renderer, writer_f)
        return {
            key = key,
            extension = extension,
            option_renderer = option_renderer,
            writer = writer_f
        }
    end
}

function TranscriptExportFormat:file_selector_spec()
    local selector_spec = '%s files (*.%s)\0*.%s\0All files (*.*)\0*.*\0\0'
    return selector_spec:format(self.key, self.extension, self.extension)
end

function TranscriptExportFormat.exporter_json()
    return TranscriptExportFormat.new('JSON', 'json', TranscriptExportFormat.options_json,
        TranscriptExportFormat.writer_json)
end

function TranscriptExportFormat.options_json(options)
    if not options.json_widgets then
        local storage = Storage.ExtState.make {
            section = 'ReaSpeech.Export.JSON',
            persist = true
        }

        options.json_widgets = {
            object_per_segment = ReaSpeechCheckbox.new {
                state = storage:boolean('object_per_segment', false),
                label_long = 'One Object per Transcript Segment', -- Changed from label to label_long
                help_text = [[Each transcript segment is exported a separate JSON object.]]
            }
        }
    end

    Trap(function()
        options.json_widgets.object_per_segment:render()
        options.object_per_segment = options.json_widgets.object_per_segment:value()
    end)
end

function TranscriptExportFormat.writer_json(transcript, output_file, options)
    if options.object_per_segment then
        for _, segment in pairs(transcript:get_segments()) do
            output_file:write(segment:to_json())
            output_file:write('\n')
        end
    else
        output_file:write(transcript:to_json())
    end
end

function TranscriptExportFormat.exporter_srt()
    return TranscriptExportFormat.new('SRT', 'srt', TranscriptExportFormat.options_srt,
        TranscriptExportFormat.writer_srt)
end

function TranscriptExportFormat.strip_non_numeric(value)
    return value:gsub("[^0-9]", ""):gsub("^0+", "")
end

function TranscriptExportFormat.strip_non_numeric_percent(value)
    -- Remove any % sign from the end
    value = value:gsub("%%$", "")
    -- Keep only numbers, decimal points
    value = value:gsub("[^0-9%.]", "")
    -- Remove leading zeros (but keep single zero)
    value = value:gsub("^0+(%d)", "%1")
    return value
end

function TranscriptExportFormat.options_srt(options)
    if not options.srt_widgets then
        local storage = Storage.ExtState.make {
            section = 'ReaSpeech.Export.SRT',
            persist = true
        }

        options.srt_widgets = {
            coords_x1 = ReaSpeechTextInput.new {
                state = storage:string('coords_x1', ''),
                label = 'X1',
                help_text = [[Left coordinate of the subtitle box.]],
                flags = ImGui.InputTextFlags_CharsDecimal()
            },
            coords_y1 = ReaSpeechTextInput.new {
                state = storage:string('coords_y1', ''),
                label = 'Y1',
                help_text = [[Top coordinate of the subtitle box.]],
                flags = ImGui.InputTextFlags_CharsDecimal()
            },
            coords_x2 = ReaSpeechTextInput.new {
                state = storage:string('coords_x2', ''),
                label = 'X2',
                help_text = [[Right coordinate of the subtitle box.]],
                flags = ImGui.InputTextFlags_CharsDecimal()
            },
            coords_y2 = ReaSpeechTextInput.new {
                state = storage:string('coords_y2', ''),
                label = 'Y2',
                help_text = [[Bottom coordinate of the subtitle box.]],
                flags = ImGui.InputTextFlags_CharsDecimal()
            }
        }
    end

    Trap(function()
        ImGui.Text(ctx, "Subtitle Coordinates")

        options.srt_widgets.coords_x1:render()
        ImGui.SameLine(ctx)
        options.srt_widgets.coords_y1:render()

        options.srt_widgets.coords_x2:render()
        ImGui.SameLine(ctx)
        options.srt_widgets.coords_y2:render()

        -- Update options with widget values
        options.coords_x1 = TranscriptExportFormat.strip_non_numeric(options.srt_widgets.coords_x1:value())
        options.coords_y1 = TranscriptExportFormat.strip_non_numeric(options.srt_widgets.coords_y1:value())
        options.coords_x2 = TranscriptExportFormat.strip_non_numeric(options.srt_widgets.coords_x2:value())
        options.coords_y2 = TranscriptExportFormat.strip_non_numeric(options.srt_widgets.coords_y2:value())
    end)
end

function TranscriptExportFormat.writer_srt(transcript, output_file, options)
    local writer = SRTWriter.new {
        file = output_file,
        options = options
    }
    writer:write(transcript)
end

function TranscriptExportFormat.exporter_csv()
    return TranscriptExportFormat.new('CSV', 'csv', TranscriptExportFormat.options_csv,
        TranscriptExportFormat.writer_csv)
end

function TranscriptExportFormat.options_csv(options)
    if not options.csv_widgets then
        local storage = Storage.ExtState.make {
            section = 'ReaSpeech.Export.CSV',
            persist = true
        }

        local delimiter_items = {}
        for _, delimiter in ipairs(CSVWriter.DELIMITERS) do
            table.insert(delimiter_items, delimiter.name)
        end

        options.csv_widgets = {
            delimiter = ReaSpeechCombo.new {
                state = storage:string('delimiter', CSVWriter.DELIMITERS[1].name),
                label = 'Delimiter',
                help_text = [[Choose the character that separates fields:
Comma - Standard CSV format
Tab - Tab-separated values (TSV)
Semicolon (;) - Alternative for locales using comma as decimal]],
                items = delimiter_items
            },

            include_header = ReaSpeechCheckbox.new {
                state = storage:boolean('include_header', true),
                label_long = 'Include Header Row',
                help_text = [[Adds a header row with column names.
Useful for importing into spreadsheets.]]
            }
        }
    end

    Trap(function()
        options.csv_widgets.delimiter:render()
        ImGui.Spacing(ctx)
        options.csv_widgets.include_header:render()

        -- Update options with widget values
        local selected_delimiter = CSVWriter.DELIMITERS[1]
        for _, delimiter in ipairs(CSVWriter.DELIMITERS) do
            if delimiter.name == options.csv_widgets.delimiter:value() then
                selected_delimiter = delimiter
                break
            end
        end
        options.delimiter = selected_delimiter.char
        options.include_header_row = options.csv_widgets.include_header:value()
    end)
end

function TranscriptExportFormat.writer_csv(transcript, output_file, options)
    local writer = CSVWriter.new {
        file = output_file,
        delimiter = options.delimiter,
        include_header_row = options.include_header_row
    }
    writer:write(transcript)
end

function TranscriptExportFormat.exporter_vtt()
    return TranscriptExportFormat.new('VTT', 'vtt', TranscriptExportFormat.options_vtt,
        TranscriptExportFormat.writer_vtt)
end

function TranscriptExportFormat.options_vtt(options)
    if not options.vtt_widgets then
        local storage = Storage.ExtState.make {
            section = 'ReaSpeech.Export.VTT',
            persist = true
        }

        options.vtt_widgets = {
            text_direction = ReaSpeechCombo.new {
                state = storage:string('text_direction', 'Horizontal'),
                label = 'Text Direction',
                help_text = [[Horizontal: default text
for languages like Japanese that can be written vertically:
    Right to Left - Vertical text written right-to-left
    Left to Right - Vertical text written left-to-right]],
                items = {'Horizontal', 'Right to Left', 'Left to Right'}
            },

            line = ReaSpeechTextInput.new {
                state = storage:string('line', ''),
                label = 'Line Position',
                help_text = [[line position of captions:
    Numbers: Place on specific line
      - Positive (1,2,3...) counts from top
      - Negative (-1,-2,-3...) counts from bottom
    Percentages: Position relative to video height
      - 0% = top
      - 100% = bottom]]
            },

            position = ReaSpeechTextInput.new {
                state = storage:string('position', ''),
                label = 'Horizontal Position %',
                help_text = [[Sets horizontal position: 0% = left edge, 50% = center, 100% = right edge]]
            },

            size = ReaSpeechTextInput.new {
                state = storage:string('size', ''),
                label = 'Caption Box Size %',
                help_text = [[Sets caption box width (0-100% of video width), Default auto-sizes to fit text]]
            },

            align = ReaSpeechCombo.new {
                state = storage:string('align', 'Default'),
                label = 'Text Alignment',
                items = {'Start', 'Center', 'End', 'Left', 'Right'}
            }
        }
    end

    Trap(function()
        options.vtt_widgets.text_direction:render()
        ImGui.Spacing(ctx)

        options.vtt_widgets.line:render()
        ImGui.Spacing(ctx)

        options.vtt_widgets.position:render()
        ImGui.Spacing(ctx)

        options.vtt_widgets.size:render()
        ImGui.Spacing(ctx)

        options.vtt_widgets.align:render()
        ImGui.Spacing(ctx)

        local direction = options.vtt_widgets.text_direction:value()
        options.vertical = direction == 'Right to Left' and 'rl' or direction == 'Left to Right' and 'lr' or nil -- Horizontal case

        options.line = options.vtt_widgets.line:value()
        options.position = TranscriptExportFormat.strip_non_numeric_percent(options.vtt_widgets.position:value())
        options.size = TranscriptExportFormat.strip_non_numeric_percent(options.vtt_widgets.size:value())
        options.align = options.vtt_widgets.align:value() ~= 'Default' and
                            string.lower(options.vtt_widgets.align:value()) or nil
    end)
end

function TranscriptExportFormat.writer_vtt(transcript, output_file, options)
    local writer = VTTWriter.new {
        file = output_file,
        options = options
    }
    writer:write(transcript)
end
