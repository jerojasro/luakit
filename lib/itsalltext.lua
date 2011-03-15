--------------------------------------------------------------
-- edit form fields (textarea, input) in an external editor --
-- @author Javier Rojas &lt;jerojasro@devnull.li&gt;        --
--------------------------------------------------------------

-- Design:
--
-- get text from selected element
--
-- define JS callback, and store it in a variable global for the document
-- (IAT_CB).  The defined JS callback must store as a closure the element whose
-- text we'll modify, and receive such text as its only argument
--
-- create a lua callback that stores the proper luakit tab, via closures.
--
-- when editing finishes, execute a chunk of JS that calls the JS function that
-- sets the field text, and deletes such function

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

        if (typeof window.IAT_CB != 'undefined') {
            alert("You are already editing something!");
            return "";
        }
        var act_el = document.activeElement;
        window.IAT_CB = function(new_text) {act_el.value = new_text;};
        return "%s" + act_el.value;
    })()]==]

local js_set_text = [==[
    (function () {
        window.IAT_CB("%s");
        delete window.IAT_CB;
    })()]==]

local function get_temp_filename(uri)
    local fn = string.match(string.gsub(uri, "%w+://", ""), "(.-)/.*")
    return string.format("%s/iat_%s_%d.txt", luakit.data_dir, fn, math.random(5000))
end

local function get_editor()
    local editor = globals.editor or (os.getenv("EDITOR") or "vim")
    return editor
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
    local function editor_callback(n, m)
        view_idx = w.tabs:indexof(view)
        if not view_idx then
            w:warning("You closed the tab, dude/gal!")
            os.remove(fn)
            return
        end
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
        w:goto_tab(w.tabs:indexof(view))
    end
    luakit.spawn(string.format("%s %q", editor_cmd, fn), editor_callback)
end

add_binds("insert", {
    key({"Control"}, "e", call_external_editor),
})

