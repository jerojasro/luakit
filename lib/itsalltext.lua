--------------------------------------------------------------
-- edit form fields (textarea, input) in an external editor --
-- @author Javier Rojas &lt;jerojasro@devnull.li&gt;        --
--------------------------------------------------------------

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
        document.activeElement.value = %q;
    })()]==]

local function get_temp_filename(uri)
    local fn = string.match(string.gsub(uri, "%w+://", ""), "(.-)/.*")
    return string.format("%s/iat_%s_%d.txt", luakit.data_dir, fn, math.random(5000))
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
    
    local editor_cmd = "gvim -f"
    luakit.spawn_sync(string.format("%s %q", editor_cmd, fn))

    fd, err = io.open(fn, "r")
    if not fd then
        w:warning("Could not read text back!")
        return
    end
    curr_text = fd:read("*a")
    fd:close()
    view:eval_js(string.format(js_set_text, curr_text), "itsalltext.lua:js_set_text")
    os.remove(fn)
end

add_binds("insert", {
    key({"Control"}, "e", call_external_editor),
})

