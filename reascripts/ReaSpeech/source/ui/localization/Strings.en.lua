--[[

    Strings.en.lua - English localization strings

]] --

Strings = Strings or {}

Strings.en = {
  _name = "English",
  _fallback = nil,

  -- AU = {
  --   _name = "Australian English",
  --   _fallback = "en",
  -- },

  -- CA = {
  --   _name = "Canadian English",
  --   _fallback = "en",
  -- },

  -- GB = {
  --   _name = "British English",
  --   _fallback = "en",
  --   _strings = {
  --     color_or_colour = "colour",
  --   },
  -- },

  -- IE = {
  --   _name = "Irish English",
  --   _fallback = "en",
  -- },

  -- IN = {
  --   _name = "Indian English",
  --   _fallback = "en",
  -- },

  -- NZ = {
  --   _name = "New Zealand English",
  --   _fallback = "en",
  -- },

  -- SG = {
  --   _name = "Singaporean English",
  --   _fallback = "en",
  -- },

  -- US = {
  --   _name = "American English",
  --   _fallback = "en",
  -- },

  -- ZA = {
  --   _name = "South African English",
  --   _fallback = "en",
  -- },

  _strings = {
    color_or_colour = "color",
    libs = {
      ctx = { -- Ctx
        label = "Application",
      },
      curl_request = { -- CurlRequest
        assert_url = "missing url",
        debug_sentinel = "Sentinel found, parsing response",
        debug_opening_output = "Couldn't open output file:",
        debug_trying_again_later = "trying again later",
        error_msg_server_responded_with = "Server responded with status",
        error_msg_empty_response = "Empty response",
        error_msg_json_parsing = "JSON parse error",
        error_msg_progress_file = "Unable to open progress file",
        error_msg_no_curl = "Unable to run curl",
        debug_curl_timeout = "Curl timeout reached",
        error_msg_curl_failed = "Curl failed with status",
        error_msg_request_failed = "Request failed with status",
        debug_checking_sentinel = "Checking sentinel",
        error_status_not_found = "Status not found in headers",
      },
      exec_process = { -- ExecProcess
        error_no_tempfile = "Unable to open tempfile",
      },
      logging = { -- Logging
        basic_tag = "LOG",
        debug_tag = "DEBUG",
      },
      storage = { -- Storage
        assert_section = "missing section",
        assert_project = "missing project",
        assert_extname = "missing extname",
      },
      tool_window = { -- ToolWindow
        default_title = "Tool Window",
      },
    },
    main = { -- main/*.lua, ReaSpeechMain
      imgui_required =
      "This script requires the ReaImGui API, which can be installed from:\n\nExtensions > ReaPack > Browse packages...",
      imgui_required_title = "ReaImGui required",
      csv_writer = { -- CSVWriter
        delimiter_comma = "Comma",
        delimiter_semicolon = "Semicolon",
        delimiter_tab = "Tab",
        assert_file = "missing file",
        header_sequence_number = "Sequence Number",
        header_start_time = "Start Time",
        header_end_time = "End Time",
        header_text = "Text",
        header_file = "File",
        time_format = "%02d:%02d:%02d,%03d",
      },
      srt_writer = { -- SRTWriter
        assert_file = "missing file",
        time_format = "%02d:%02d:%02d,%03d",
      },
      transcript_segment = { -- TranscriptSegment
        assert_data = "missing data",
        assert_item = "missing item",
        assert_take = "missing take",
      },
      transcript_word = { -- TranscriptWord
        assert_word = "missing word",
        assert_start = "missing start",
        assert_end = "missing end_",
        assert_probability = "missing probability",
      },
      worker = { -- ReaSpeechWorker
        assert_requests = "missing requests",
        assert_responses = "missing responses",
        log_processing_finished = "Processing finished",
        sending_media = "Sending Media",
        log_processing = "Processing speech...",
        debug_active_job = "Active job",
        debug_status = "Status",

      },
    },
    ui = {
      transcription_failed = "Transcription failed",            -- ReaSpeechUI
      assert_endpoint = "Endpoint required for API call",       -- ReaSpeechUI
      alert = { -- AlertPopup
        default_title = "Alert",
        ok_button = "OK",
      },
      actions = { -- ReaSpeechActionsUI
        cancel_button = "Cancel",
      },
      annotations = { -- TranscriptAnnotations
        assert_transcript = "transcript is required",
        notes_track_default_name = "Speech",

        ui = { -- TranscriptAnnotationsUI
          title = "Transcript Annotations",
          assert_transcript = "transcript is required",
          create_button = "Create",
          close_button = "Close",
          segment_label = "Segment",
          word_label = "Word",
          granularity_label = "Granularity",
          track_filter_mode_label = "Track Filter Mode",
          include_button = "Include",
          ignore_button = "Ignore",
          track_selector_label = "Track Filter",
          take_markers_label = "Take Markers",
          take_markers_undo_label = "Create take markers from transcript",
          project_markers_label = "Project Markers",
          project_markers_undo_label = "Create project markers from transcript",
          project_regions_label = "Project Regions",
          project_regions_undo_label = "Create project regions from transcript",
          notes_track_track_name = "Transcript",
          notes_track_track_name_label = "Track Name",
          notes_track_undo_label = "Create notes track from transcript",
        }
      },
      column_layout = { -- ColumnLayout
        assert_renderer = "render_column function must be provided",
      },
      controls = { -- ReaSpeechControlsUI
        assert_plugins = "plugins is required",
      },
      editor = { -- TranscriptEditor
        title = "Edit Segment",
        zoom_none = "None",
        zoom_word = "Word",
        zoom_segment = "Segment",
        assert_transcript = "missing transcript",
        save_button = "Save",
        cancel_button = "Cancel",
        add_button = "Add",
        add_button_tooltip = "Add word after current word",
        delete_button = "Delete",
        delete_button_tooltip = "Delete current word",
        split_button = "Split",
        split_button_tooltip = "Split current word into two words",
        merge_button = "Merge",
        merge_button_tooltip = "Merge current word with next word",
        time_start_label = "start",
        time_end_label = "end",
        word_label = "word",
        score_label = "score",
        play_word_tooltip = "Play word",
        stop_tooltip = "Stop",
        sync_time_label = "sync time selection",
        sync_zoom_conjunction = "and",
        zoom_to_label = "zoom to",

      },
      exporter = { -- TranscriptExporter
        title = "Export",
        assert_transcript = "missing transcript",
        apply_extension_label = "Apply Extension",
        project_resources_label = "Project Resources",
        success_title = "Export Successful",
        success_text_format = "Exported %s to:",
        fail_title = "Export Failed",
        target_file_label = "Target File",
        file_exists_warning = "File exists and will be overwritten.",
        export_button = "Export",
        cancel_button = "Cancel",
        error_missing_file = "Please specify a file name.",
        error_opening_file = "Could not open file:",
        format_label = "Format",
        debug_no_available_formats = "no formats to set for default",
        all_files_label = "All files",
        json_one_object_per_label = "One Object per Transcript Segment",
        csv_delimiter_label = "Delimiter",
        csv_include_header_label = "Include Header Row",

      },
      globals = { -- includes/globals.lua
        cirular_reference = "Circular reference detected",
      },
      importer = { -- TranscriptImporter
        title = "Import",
        assert_file_type = "File - must be JSON previously exported from ReaSpeech",
        success_title = "Import Successful",
        success_text_format = "Imported %s",
        fail_title = "Import Failed",
        import_button = "Import",
        no_file_selected = "No file selected",
        close_button = "Close",
        file_not_found = "File not found",

      },
      plugins = { -- ReaSpeechPlugins
        assert_app = "plugin host app is required",
        assert_plugins = "plugins is required",
      },
      transcript_ui = { -- TranscriptUI
        title = "Transcript",
        assert_transcript = "missing transcript",
        separator_text = "Transcript",
        create_markers_button = "Create Markers",
        export_button = "Export",
        clear_button = "Clear",
        auto_play_label = "Auto Play",
        words_label = "Words",
        colorize_label = "Colorize",
        search_hint = "Search",
        edit_tooltip = "Edit",
        -- how to handle transcript columns?

      },
      welcome = { -- ReaSpeechWelcomeUI
        title = "Welcome!",
        heading = "Welcome to ReaSpeech!",
        text = "This is a tool for transcribing audio in REAPER.",
        demo_heading = "Demo Version",
        demo_text = { "Please note that this version is a demo and may not be available at all times.",
          "For a more reliable experience, you can run ReaSpeech locally using the ",
          "ReaSpeechWelcomeUI.DOCKER_HUB_URL",
          "Docker image." },
        button = "Let's Go!",
        website_link = { "ReaSpeechWelcomeUI.HOME_URL", "ReaSpeech Website" },
        github_link = { "ReaSpeechWelcomeUI.GITHUB_URL", "GitHub" },
        docker_link = { "ReaSpeechWelcomeUI.DOCKER_HUB_URL", "Docker Hub" },
      },
      whisper_languages = { -- WhisperLanguages
        --oof
      },
      widgets = { -- Widgets, ReaSpeechWidgets
        assert_tooltip = "missing tooltip for icon",
        assert_missing_default = "default value not provided",
        assert_renderer = "renderer not provided",
        button = { -- Widgets.Button
          assert_on_click = "handler not provided",
        },
        file_selector = { -- Widgets.FileSelector
          default_title = "Save File",
          choose_file = "Choose file",
          input_hint = "...or type one here.",
          jsapi_notice = {
            "To enable file selector, ",
            "FileSelector.JSREASCRIPT_URL",
            "install js_ReaScriptAPI"
          },
        },
      },
    },
    plugins = {
      asr = { -- ASRPlugin
        assert_app = "plugin host app is required",
        actions = { -- ASRActions
          assert_plugin = "plugin is required",
          selected_tracks_label = "Process Selected Tracks",
          selected_tracks_format = "Process %sSelected Track%s",
          selected_items_label = "Process Selected Items",
          selected_items_format = "Process %sSelected Item%s",
          all_items_label = "Process All Items",
          import_label = "Import Transcript",
          no_media_text = "No media found to process.",
          no_media_title = "No media",
        },
        controls = { -- ASRControls
          help_model =
          "Model to use for transcription. Larger models provide better accuracy but use more resources like disk space and memory.",
          help_language = "Language spoken in source audio.\nSet this to 'Detect' to auto-detect the language.",
          help_preserved_words = "Comma-separated list of words to preserve in transcript.\nExample: Jane Doe, CyberCorp",
          help_vad = "Enable Voice Activity Detection (VAD) to filter out non-speech portions.",
          tab_name_simple = "Simple",
          tab_name_advanced = "Advanced",
          assert_plugin = "plugin is required",
          language_label = "Language",
          translate_label_long = "Translate to English",
          translate_label_short = "Translate",
          hotwords_label = "Hotwords",
          initial_prompt_label = "Hotwords",
          vad_label_long = "Voice Activity Detection",
          vad_label_short = "VAD",
          model_name_label = "Model",
        },
      },
      detect_language = { -- DetectLanguagePlugin
        assert_app = "plugin host app is required",
        undo_label = "Add languages to Track Name",
        actions = { -- DetectLanguageActions
          assert_plugin = "plugin is required",
          label_button = "Label Track Languages",

        },
        controls = { -- DetectLanguageControls
          assert_plugin = "plugin is required"
        },
      },
      sample_multiple_upload = { -- SampleMultipleUploadPlugin
        assert_app = "plugin host app is required",
        successful_upload = "Files uploaded successfully",
        actions = { -- SampleMultipleUploadActions
          assert_plugin = "plugin is required",
          upload_label = "Upload Files",
        },
        controls = { -- SampleMultipleUploadControls
          assert_plugin = "plugin is required",
          tab_name = "Multiple Uploader",
          upload_label_1 = "Upload File 1",
          upload_label_2 = "Upload File 2",
        },
      },
      settings = { -- SettingsPlugin
        assert_plugin = "plugin host app is required",
        actions = { -- SettingsActions
          assert_plugin = "plugin is required",
        },
        controls = { -- SettingsControls
          tab_name = "settings",
          assert_plugin = "plugin is required",
          font_size_label = "Font Size",
          logging_label = "Logging",
          logging_basic_long = "Enable",
          logging_basic_short = "Enable",
          logging_debug_long = "Debug",
          logging_debug_short = "Debug",
          locale_label = "Locale",
        },
      },
    },
  },
}
