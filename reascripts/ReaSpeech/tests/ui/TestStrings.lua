package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')
require('include/globals')
require('ui/Strings')

Strings = Strings or {}

Strings.en = {
  _name = "English",
  _fallback = nil,

  GB = {
    _name = 'British English',
    _fallback = 'en',
    _strings = {
      color_or_colour = 'colour',
      nested = {
        isnt_it = "innit",
      },
      how = {
        deep = {
          can = {
            we = {
              go = "what's all this then",
            }
          }
        }
      }
    }
  },

  US = {
    _name = 'American English',
    _fallback = 'en',
    _strings = {
    }
  },

  _strings = {
    color_or_colour = 'color',
    english_only = {
      only_in_base_english = "'merica!",
    },
    nested = {
      isnt_it = "isn't it",
    },
    how = {
      deep = {
        can = {
          we = {
            go = "very deep",
          }
        }
      }
    }
  }
}

Strings.pt = {
  _name = "Portuguese",
  _fallback = 'en',

  BR = {
    _name = 'Brazilian Portuguese',
    _fallback = 'pt',
    _strings = {
      nested = {
        isnt_it = "não é!",
      },
      how = {
        deep = {
          can = {
            we = {
              go = "muito fundo!",
            }
          }
        }
      }
    }
  },

  _strings = {
    color_or_colour = 'cor',
    nested = {
      isnt_it = "não é",
    },
    how = {
      deep = {
        can = {
          we = {
            go = "muito fundo",
          }
        }
      }
    }
  }
}

TestStrings = {}

function TestStrings:testLocalize()
  local strings = Strings.localize('en')
  lu.assertEquals(strings.color_or_colour, 'color')
  lu.assertEquals(strings.english_only.only_in_base_english, "'merica!")

  strings = Strings.localize('en-US')
  lu.assertEquals(strings.color_or_colour, 'color')
  lu.assertEquals(strings.english_only.only_in_base_english, "'merica!")

  strings = Strings.localize('en-GB')
  lu.assertEquals(strings.color_or_colour, 'colour')
  lu.assertEquals(strings.english_only.only_in_base_english, "'merica!")

  strings = Strings.localize('pt-BR')
  lu.assertEquals(strings.color_or_colour, 'cor')
  lu.assertEquals(strings.english_only.only_in_base_english, "'merica!")

  strings = Strings.localize('pt')
  lu.assertEquals(strings.color_or_colour, 'cor')
  lu.assertEquals(strings.english_only.only_in_base_english, "'merica!")
end

function TestStrings:testNestedString()
  local strings = Strings.localize('en-US')
  lu.assertEquals(strings.nested.isnt_it, "isn't it")
  lu.assertEquals(strings.how.deep.can.we.go, "very deep")

  strings = Strings.localize('en-GB')
  lu.assertEquals(strings.nested.isnt_it, 'innit')
  lu.assertEquals(strings.how.deep.can.we.go, "what's all this then")

  strings = Strings.localize('pt-BR')
  lu.assertEquals(strings.nested.isnt_it, "não é!")
  lu.assertEquals(strings.how.deep.can.we.go, "muito fundo!")
end

function TestStrings:testAvailableLanguages()
  lu.assertItemsEquals(Strings.available_languages(), {
    en = "English",
    ['en-GB'] = "British English",
    ['en-US'] = "American English",
    pt = "Portuguese",
    ['pt-BR'] = "Brazilian Portuguese",
  })
end

os.exit(lu.LuaUnit.run())