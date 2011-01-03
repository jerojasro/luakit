-------------------------------------------------------------
-- Simple readline functions for input widgets             --
-- (C) 2011 Mason Larobina <mason.larobina@gmail.com>      --
-- (C) 2010 Chris van Dijk (quigybo) <quigybo@hotmail.com> --
-------------------------------------------------------------


local math = require "math"
local lousy = require "lousy"

local key = lousy.bind.key
local string = string

--- Simple readline functions for input widgets
module "readline"

--- Move forward to the end of the next word. Words are composed of
-- alphanumeric characters (letters and digits).
function forward_word(input)
    local text, pos = input.text, input.position
    if text and #text > 1 then
        local right = string.sub(text, pos+1)
        if string.find(right, "%w+") then
            local _, move = string.find(right, "%w+")
            input.position = pos + move
        end
    end
end

--- Move back to the start of the current or previous word. Words are
-- composed of alphanumeric characters (letters and digits).
function backward_word(input, offset)
    local text, pos = input.text, input.position
    if text and #text > 1 then
        local left = string.reverse(string.sub(text, 1 + offset, pos))
        if string.find(left, "%w+") then
            local _, move = string.find(left, "%w+")
            input.position = math.max(pos - move, offset or 0)
        end
    end
end

--- Move forward a character.
function forward_char(input)
    input.position = input.position + 1
end

--- Move back a character.
function backward_char(input, offset)
    input.position = math.max(input.position - 1, offset, 0)
end

--- Move to the start of the line
function beginning_of_line(input, offset)
    input.position = math.max(offset, 0)
end

--- Move to the end of the line.
function end_of_line(input)
    input.position = -1
end

--- Kill the word behind point, using white space as a word boundary.
function unix_word_rubout(input, offset)
    local text, pos = input.text, input.position
    if text and #text > 0 and pos > 0 then
        local left = string.sub(text, 1 + (offset or 0), pos)
        local right = string.sub(text, pos + 1)
        if not string.find(left, "%s") then
            left = ""
        elseif string.find(left, "%w+%s*$") then
            left = string.sub(left, 0, string.find(left, "%w+%s*$") - 1)
        elseif string.find(left, "%W+%s*$") then
            left = string.sub(left, 0, string.find(left, "%W+%s*$") - 1)
        end
        left = string.sub(text, 1, offset or 0) .. left
        input.text = left .. right
        input.position = #left
    end
end

--- Kill all characters on the current line, no matter where point is.
function kill_whole_line(input, offset)
    input.text = string.sub(input.text, 1, offset or 0)
    input.position = offset
end

--- Kill backward from point to the beginning of the line.
function unix_line_discard(input, offset)
    local text, pos = input.text, input.position
    if text and #text > 0 and pos > 0 then
        local left = string.sub(text, offset or 0, offset or 0)
        local right = string.sub(text, 1 + math.max(pos, #left))
        input.text = left .. right
        input.position = #left
    end
end

function make_binds(opts)
    opts = opts or {}
    -- By default the readline functions work on the main input bar but this
    -- behaviour can be overridden if there are multiple entry widgets.
    local get_input = opts.get_input or function (w) return w.ibar.input end
    local offset = opts.offset or 1

    return {
        key({"Control"}, "a", function (w) beginning_of_line(get_input(w), offset) end),
        key({"Control"}, "e", function (w) end_of_line(get_input(w))               end),

        key({"Control"}, "f", function (w) forward_char(get_input(w))              end),
        key({"Control"}, "b", function (w) backward_char(get_input(w), offset)     end),
        key({"Mod1"},    "f", function (w) forward_word(get_input(w))              end),
        key({"Mod1"},    "b", function (w) backward_word(get_input(w), offset)     end),

        key({"Control"}, "u", function (w) unix_line_discard(get_input(w), offset) end),
        key({"Control"}, "w", function (w) unix_word_rubout(get_input(w), offset)  end),
    }
end
