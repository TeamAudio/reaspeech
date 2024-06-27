package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('Polo')

require('source/ColumnLayout')



TestColumnLayout = {
  AVAIL_WIDTH = 100
}

function TestColumnLayout:stub(layout)
  layout._column_gap_calls = {}
  layout._column_gap = function (self, padding)
    table.insert(self._column_gap_calls, {padding})
  end

  layout._get_avail_width_calls = 0
  layout._get_avail_width = function (self)
    self._get_avail_width_calls = self._get_avail_width_calls + 1
    return TestColumnLayout.AVAIL_WIDTH
  end

  layout._horiz_margin_calls = {}
  layout._horiz_margin = function (self, margin)
    table.insert(self._horiz_margin_calls, {margin})
  end

  layout._vert_margin_calls = {}
  layout._vert_margin = function (self, margin, width)
    table.insert(self._vert_margin_calls, {margin, width})
  end

  layout._with_group_calls = 0
  layout._with_group = function (self, f)
    self._with_group_calls = self._with_group_calls + 1
    f()
  end
end

function TestColumnLayout:testInitDefault()
  local layout = ColumnLayout.new {
    render_column = function () end
  }
  lu.assertEquals(layout.column_padding, ColumnLayout.DEFAULT_COLUMN_PADDING)
  lu.assertEquals(layout.margin_bottom, 0)
  lu.assertEquals(layout.margin_left, 0)
  lu.assertEquals(layout.margin_right, 0)
  lu.assertEquals(layout.margin_top, 0)
  lu.assertEquals(layout.num_columns, ColumnLayout.DEFAULT_NUM_COLUMNS)
  lu.assertEquals(layout.width, 0)
end

function TestColumnLayout:testRender()
  local column_padding = 20
  local margin_bottom = 15
  local margin_left = 10
  local margin_right = 30
  local margin_top = 5
  local num_columns = 2

  local expected_column_width = (
    self.AVAIL_WIDTH
    - margin_left
    - margin_right
    - column_padding
  ) / num_columns

  local render_column_calls = {}

  local layout = ColumnLayout.new {
    column_padding = column_padding,
    margin_bottom = margin_bottom,
    margin_left = margin_left,
    margin_right = margin_right,
    margin_top = margin_top,
    num_columns = num_columns,
    render_column = function (column)
      table.insert(render_column_calls, {column})
    end
  }

  self:stub(layout)
  layout:render()

  lu.assertEquals(layout._column_gap_calls, {{column_padding}})
  lu.assertEquals(layout._get_avail_width_calls, 1)
  lu.assertEquals(layout._horiz_margin_calls, {{margin_left}})
  lu.assertEquals(layout._vert_margin_calls, {
    {margin_top, expected_column_width},
    {margin_bottom, expected_column_width},
    {margin_top, expected_column_width},
    {margin_bottom, expected_column_width},
  })
  lu.assertEquals(layout._with_group_calls, num_columns)

  lu.assertEquals(render_column_calls, {
    {{num = 1, width = expected_column_width}},
    {{num = 2, width = expected_column_width}},
  })
end

function TestColumnLayout:testRenderWithWidth()
  local column_padding = 15
  local margin_bottom = 10
  local margin_left = 5
  local margin_right = 20
  local margin_top = 25
  local num_columns = 3
  local width = 205

  local expected_column_width = 50

  local render_column_calls = {}

  local layout = ColumnLayout.new {
    column_padding = column_padding,
    margin_bottom = margin_bottom,
    margin_left = margin_left,
    margin_right = margin_right,
    margin_top = margin_top,
    num_columns = num_columns,
    width = width,
    render_column = function (column)
      table.insert(render_column_calls, {column})
    end
  }

  self:stub(layout)
  layout:render()

  lu.assertEquals(layout._column_gap_calls, {{column_padding}, {column_padding}})
  lu.assertEquals(layout._get_avail_width_calls, 0)
  lu.assertEquals(layout._horiz_margin_calls, {{margin_left}})
  lu.assertEquals(layout._vert_margin_calls, {
    {margin_top, expected_column_width},
    {margin_bottom, expected_column_width},
    {margin_top, expected_column_width},
    {margin_bottom, expected_column_width},
    {margin_top, expected_column_width},
    {margin_bottom, expected_column_width},
  })
  lu.assertEquals(layout._with_group_calls, num_columns)

  lu.assertEquals(render_column_calls, {
    {{num = 1, width = expected_column_width}},
    {{num = 2, width = expected_column_width}},
    {{num = 3, width = expected_column_width}},
  })
end

function TestColumnLayout:testRenderNested()
  local inner_renders = {}
  local outer_renders = {}

  local outer_layout = ColumnLayout.new {
    column_padding = 0,
    num_columns = 2,
    width = 60,

    render_column = function (outer_column)
      table.insert(outer_renders, outer_column)

      local inner_layout = ColumnLayout.new {
        column_padding = 0,
        num_columns = 3,
        width = outer_column.width,

        render_column = function (inner_column)
          table.insert(inner_renders, inner_column)
        end
      }
      self:stub(inner_layout)

      inner_layout:render()
    end
  }
  self:stub(outer_layout)

  outer_layout:render()

  lu.assertEquals(inner_renders, {
    {num=1, width=10},
    {num=2, width=10},
    {num=3, width=10},
    {num=1, width=10},
    {num=2, width=10},
    {num=3, width=10},
  })

  lu.assertEquals(outer_renders, {
    {num=1, width=30},
    {num=2, width=30},
  })
end



os.exit(lu.LuaUnit.run())
