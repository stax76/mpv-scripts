
----- This script allows to automatically switch between video,
----- audio and image mode. All configuration is done in code.

----- config

-- executes when image mode is activated
function on_image_mode_activate()
    mp.command("script-message osc-visibility never no_osd")
    mp.command("no-osd set osd-playing-msg ''")
end

-- executes when image mode is deactivated,
-- use it to undo changes made by on_image_mode_activate
function on_image_mode_deactivate()
    mp.command("script-message osc-visibility auto no_osd")
    mp.command("no-osd set osd-playing-msg '${media-title}'")
end

-- executes when audio mode is activated
function on_audio_mode_activate()
    mp.command("no-osd set osd-playing-msg '${filtered-metadata}'")
end

-- executes when audio mode is deactivated
-- use it to undo changes made by on_audio_mode_activate
function on_audio_mode_deactivate()
    mp.command("no-osd set osd-playing-msg '${media-title}'")
end

-- bindings active in audio mode
audio_mode_bindings = {
}

-- bindings active in image mode
image_mode_bindings = {
    { "UP",     function () mp.command("no-osd add video-pan-y -0.02") end, { repeatable = true } },
    { "DOWN",   function () mp.command("no-osd add video-pan-y  0.02") end, { repeatable = true } },
    { "LEFT",   function () mp.command("playlist-prev") end,                { repeatable = true } },
    { "RIGHT",  function () mp.command("playlist-next") end,                { repeatable = true } },
    { "SPACE",  function () mp.command("playlist-next") end,                { repeatable = true } },
    { "BS",     function () mp.command("no-osd set video-pan-y 0; no-osd set video-zoom 0") end   },
}

-- file extensions used to determine which mode is active
image_file_extensions = { ".jpg", ".png", ".bmp", ".gif", ".webp" }
audio_file_extensions = { ".mp3", ".ogg", ".opus", ".flac", ".m4a", ".mka", ".ac3", ".dts", ".dtshd", ".dtshr", ".dtsma", ".eac3", ".mp2", ".mpa", ".thd", ".w64", ".wav", ".aac" }

----- end config

----- string

function ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

----- path

function get_ext(path)
    if path == nil then return nil end
    local val = path:match("^.+(%.[^%./\\]+)$")
    if val == nil then return nil end
    return val:lower()
end

----- list

function list_contains(list, value)
    for _, v in pairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

----- mpv

-- msg = require 'mp.msg' --   msg.warn()   msg.error()
-- mp.osd_message("hello")

----- mpv key bindings

function add_bindings(definition)
    if type(active_bindings) ~= "table" then
        active_bindings = {}
    end

    local script_name = mp.get_script_name()

    for _, bind in ipairs(definition) do
        local name = script_name .. "_key_" .. (#active_bindings + 1)
        active_bindings[#active_bindings + 1] = name
        mp.add_forced_key_binding(bind[1], name, bind[2], bind[3])
    end
end

function remove_bindings()
    if type(active_bindings) == "table" then
        for _, name in ipairs(active_bindings) do
            mp.remove_key_binding(name)
        end
    end
end

----- image-mode

active_mode = nil

function enable_image_mode()
    if active_mode == "image" then return end
    active_mode = "image"
    remove_bindings()
    add_bindings(image_mode_bindings)
    on_image_mode_activate()
end

function enable_audio_mode()
    if active_mode == "audio" then return end
    active_mode = "audio"
    remove_bindings()
    add_bindings(audio_mode_bindings)
    on_audio_mode_activate()
end

function disable_image_mode()
    if active_mode ~= "image" then return end
    active_mode = nil
    remove_bindings()
    on_image_mode_deactivate()
end

function disable_audio_mode()
    if active_mode ~= "audio" then return end
    active_mode = nil
    remove_bindings()
    on_audio_mode_deactivate()
end

function file_loaded(event)
    local ext = get_ext(mp.get_property("path"))

    if list_contains(image_file_extensions, ext) then
        disable_audio_mode()
        enable_image_mode()
    elseif list_contains(audio_file_extensions, ext) then
        disable_image_mode()
        enable_audio_mode()
    else
        disable_audio_mode()
        disable_image_mode()
    end
end

mp.register_event("file-loaded", file_loaded)
