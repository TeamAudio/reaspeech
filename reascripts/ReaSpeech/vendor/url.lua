-- MIT License
--
-- Copyright (C) 2009-2016 Steve Donovan, David Manura.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

--- Python-style URL quoting library.
--
-- @module pl.url

url = (function ()

local url = {}

local function quote_char(c)
    return string.format("%%%02X", string.byte(c))
end

--- Quote the url, replacing special characters using the '%xx' escape.
-- @string s the string
-- @bool quote_plus Also escape slashes and replace spaces by plus signs.
-- @return The quoted string, or if `s` wasn't a string, just plain unaltered `s`.
function url.quote(s, quote_plus)
    if type(s) ~= "string" then
        return s
    end

    s = s:gsub("\n", "\r\n")
    s = s:gsub("([^A-Za-z0-9 %-_%./])", quote_char)
    if quote_plus then
        s = s:gsub(" ", "+")
        s = s:gsub("/", quote_char)
    else
        s = s:gsub(" ", "%%20")
    end

    return s
end

local function unquote_char(h)
    return string.char(tonumber(h, 16))
end

--- Unquote the url, replacing '%xx' escapes and plus signs.
-- @string s the string
-- @return The unquoted string, or if `s` wasn't a string, just plain unaltered `s`.
function url.unquote(s)
    if type(s) ~= "string" then
        return s
    end

    s = s:gsub("+", " ")
    s = s:gsub("%%(%x%x)", unquote_char)
    s = s:gsub("\r\n", "\n")

    return s
end

return url

end)()
