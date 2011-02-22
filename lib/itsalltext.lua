--------------------------------------------------------------
-- edit form fields (textarea, input) in an external editor --
-- @author Javier Rojas &lt;jerojasro@devnull.li&gt;        --
--------------------------------------------------------------

-- Design:
--
-- get text from selected element
--
-- define JS callback, and store it in a table inside document. return the key
-- for the JS table callback to the lua side. The defined JS callback must
-- store as a closure the element whose text we'll modify, and receive such
-- text as its only argument
--
-- create a lua callback that stores the key to the js callback, and stores the
-- proper luakit tab. These data must be stored as a closure.
--
-- when editing finishes, execute a chunk of JS that does the following:
-- fetches the function holding the element whose text we are editing, and calls
-- it. The new text must be interpolated in the JS code string, after being
-- properly escaped
--
--
-- NOTES:
-- How to fetch the current tab:
--
-- 06:41 < mason-l> It's just a webview widget in each of the notebook tabs so just `local 
--                  view = notebook:atindex(1)` to get the first tab.

local string = string
local io = io
local os = os
local math = math

local luakit = luakit
local add_binds = add_binds
local key = lousy.bind.key
local split = lousy.util.string.split

module("itstalltext")

local js_get_text = [==[
    (function () {
        var input_focused = document.activeElement instanceof HTMLInputElement;
        input_focused = input_focused || document.activeElement instanceof HTMLTextAreaElement;
        if (!input_focused) {
            return "";
        }
        return "%s" + document.activeElement.value;
    })()]==]

local js_set_text = [==[
    (function () {
        document.activeElement.value = "%s";
    })()]==]

local function get_temp_filename(uri)
    local fn = string.match(string.gsub(uri, "%w+://", ""), "(.-)/.*")
    return string.format("%s/iat_%s_%d.txt", luakit.data_dir, fn, math.random(5000))
end

local function get_editor()
    -- TODO write me. refactor editor selection, so it is a function. don't forget
    -- to check other lua modules that do use the editor (formfiller)
    return "gvim -f"
end

local function call_external_editor(w)
    local view = w:get_current()
    local sentinel = "X"
    local curr_text = view:eval_js(string.format(js_get_text, sentinel),
                                   "itsalltext.lua:js_get_text")
    if #curr_text < #sentinel then return end
    -- remove sentinel text
    curr_text = string.sub(curr_text, 1 + #sentinel)
    -- TODO make sure fn doesn't exist
    local fn = get_temp_filename(view.uri)
    local fd, err = io.open(fn, "w")
    if not fd then return end
    fd:write(curr_text)
    fd:close()
    
    local editor_cmd = get_editor()
    luakit.spawn_sync(string.format("%s %q", editor_cmd, fn))

    fd, err = io.open(fn, "r")
    if not fd then
        w:warning("Could not read text back!")
        return
    end
    curr_text = fd:read("*a")
    fd:close()
    os.remove(fn)
    curr_text = string.gsub(curr_text, "\"", "\\\"")
    curr_text = string.gsub(curr_text, "\n", "\\n")
    view:eval_js(string.format(js_set_text, curr_text), "itsalltext.lua:js_set_text")
end

add_binds("insert", {
    key({"Control"}, "e", call_external_editor),
})

