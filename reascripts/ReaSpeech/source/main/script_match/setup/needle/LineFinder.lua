LineFinder = Polo {}

function LineFinder:init()
  Logging().init(self, 'LineFinder')

  self.has_header_row = self.has_header_row or false
  self.line_filters = self.line_filters or {}
  self.rows = self.rows or {}

  -- Rows hidden in the source spreadsheet usually mean "not part of this
  -- session", so they are skipped by default.
  self.hidden_rows = self.hidden_rows or {}
  if self.skip_hidden_rows == nil then
    self.skip_hidden_rows = true
  end

  self._hidden_row_set = {}
  if self.skip_hidden_rows then
    for _, row_number in ipairs(self.hidden_rows) do
      self._hidden_row_set[row_number] = true
    end
  end

  self:log("Initialized LineFinder")
end

-- Return a Lua iterator that yields (row_index, line_content) pairs
function LineFinder:find_lines()
  local current_row = self.has_header_row and 2 or 1

  return function()
    while current_row <= #self.rows do
      local row_number = current_row
      local row = self.rows[row_number]

      current_row = current_row + 1

      if not self._hidden_row_set[row_number] and self:matches_filters(row) then
        return row_number, row
      end
    end
  end
end

function LineFinder:matches_filters(row)
  for _, filter in ipairs(self.line_filters) do
    if not LineFinder.FILTER_TYPES[filter.type].predicate(row[filter.column], filter.value) then
      return false
    end
  end
  return true
end

LineFinder.FILTER_TYPES = {
  is_not_blank = {
    needs_value = false,
    label = "Is Not Blank",
    predicate = function(value)
      return value ~= nil and value ~= ''
    end
  },

  is_blank = {
    needs_value = false,
    label = "Is Blank",
    predicate = function(value)
      return value == nil or value == ''
    end
  },
  is = {
    needs_value = true,
    label = "Is",
    predicate = function(value, filter_value)
      return value == filter_value
    end
  },
  is_not = {
    needs_value = true,
    label = "Is Not",
    predicate = function(value, filter_value)
      return value ~= filter_value
    end
  },
  contains = {
    needs_value = true,
    label = "Contains",
    predicate = function(value, filter_value)
      return value ~= nil and value:find(filter_value) ~= nil
    end
  },
  does_not_contain = {
    needs_value = true,
    label = "Does Not Contain",
    predicate = function(value, filter_value)
      return value == nil or value:find(filter_value) == nil
    end
  },
  starts_with = {
    needs_value = true,
    label = "Starts With",
    predicate = function(value, filter_value)
      return value ~= nil and value:sub(1, #filter_value) == filter_value
    end
  },
  ends_with = {
    needs_value = true,
    label = "Ends With",
    predicate = function(value, filter_value)
      return value ~= nil and value:sub(-#filter_value) == filter_value
    end
  }
}

LineFinder.FILTER_TYPE_VALUES = (function()
  local values = {}
  for key, _ in pairs(LineFinder.FILTER_TYPES) do
    table.insert(values, key)
  end
  return values
end)()

LineFinder.FILTER_TYPE_LABELS = (function()
  local labels = {}
  for key, value in pairs(LineFinder.FILTER_TYPES) do
    labels[key] = value.label
  end
  return labels
end)()
