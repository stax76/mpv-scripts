
--[[

https://github.com/stax76/mpv-scripts

This script changes options depending on what type of
file is played. It uses the file extension to detect
if the current file is a video, audio or image file.

The changes happen not on every file load, but only
when a mode change is detected.

On mode change 3 things can be done:

1. Change options
2. Change key bindings
3. Send messages

The configuration is done in code.

]]--


----- start config

-- video mode

function on_video_mode_activate()
    mp.msg.info("Video mode is activated")
    mp.set_property("osd-playing-msg", "${media-title}")       -- in video mode use media-title
    mp.command("script-message osc-visibility auto no_osd")    -- set osc visibility to auto
end

function on_video_mode_deactivate()
end

-- audio mode

function on_audio_mode_activate()
    mp.msg.info("Audio mode is activated")
    mp.set_property("osd-playing-msg", "${media-title}")       -- in audio mode use media-title
    mp.command("script-message osc-visibility never no_osd")   -- in audio mode disable the osc
end

function on_audio_mode_deactivate()
end

-- image mode

function on_image_mode_activate()
    mp.msg.info("Image mode is activated")
    mp.set_property("osd-playing-msg", "")                     -- disable osd-playing-msg for images
    mp.set_property("background-color", "#1A2226")             -- use dark grey background for images
    mp.command("script-message osc-visibility never no_osd")   -- disable osc for images
end

function on_image_mode_deactivate()
    mp.set_property("background-color", "#000000")             -- use black background for audio and video
end

-- called whenever the file extension changes

function on_type_change(old_ext, new_ext)
    if new_ext == "gif" then
        mp.set_property("loop-file", "inf")                    -- loop GIF files
    end

    if old_ext == "gif" then
        mp.set_property("loop-file", "no")                     -- use loop-file=no for anything except GIF
    end
end

-- binding configuration

audio_mode_bindings = {
    { "Left",   function () mp.command("no-osd seek -10") end, "repeatable" }, -- make audio mode seek length longer than video mode seek length
    { "Right",  function () mp.command("no-osd seek  10") end, "repeatable" }, -- make audio mode seek length longer than video mode seek length
}

image_mode_bindings = {
    { "UP",         function () mp.command("no-osd add video-pan-y -0.02") end,  "repeatable" }, -- move image up
    { "DOWN",       function () mp.command("no-osd add video-pan-y  0.02") end,  "repeatable" }, -- move image down
    { "LEFT",       function () mp.command("playlist-prev") end,                 "repeatable" }, -- show previous image
    { "RIGHT",      function () mp.command("playlist-next") end,                 "repeatable" }, -- show next image
    { "SPACE",      function () mp.command("playlist-next") end,                 "repeatable" }, -- show next image
    { "WHEEL_UP",   function () mp.command("add video-zoom  0.1") end,           "repeatable" }, -- increase image size
    { "WHEEL_DOWN", function () mp.command("add video-zoom -0.1") end,           "repeatable" }, -- decrease image size
    { "BS",         function () mp.command("no-osd set video-pan-y 0; no-osd set video-zoom 0") end }, -- reset image options
}

----- end config

----- string

function ends_with(value, ending)
    return ending == "" or value:sub(-#ending) == ending
end

function split(input, sep)
    assert(#sep == 1) -- supports only single character separator
    local tbl = {}

    if input ~= nil then
        for str in string.gmatch(input, "([^" .. sep .. "]+)") do
            table.insert(tbl, str)
        end
    end

    return tbl
end

----- path

function get_file_ext_short(path)
    if path == nil then return nil end
    local val = path:match("^.+%.([^%./\\]+)$")
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

----- key bindings

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

----- main

local active_mode = "video"
local last_type = nil

function enable_video_mode()
    if active_mode == "video" then return end
    active_mode = "video"
    remove_bindings()
    on_video_mode_activate()
end

function enable_audio_mode()
    if active_mode == "audio" then return end
    active_mode = "audio"
    remove_bindings()
    add_bindings(audio_mode_bindings)
    on_audio_mode_activate()
end

function enable_image_mode()
    if active_mode == "image" then return end
    active_mode = "image"
    remove_bindings()
    add_bindings(image_mode_bindings)
    on_image_mode_activate()
end

function disable_video_mode()
    if active_mode ~= "video" then return end
    active_mode = ""
    remove_bindings()
    on_video_mode_deactivate()
end

function disable_image_mode()
    if active_mode ~= "image" then return end
    active_mode = ""
    remove_bindings()
    on_image_mode_deactivate()
end

function disable_audio_mode()
    if active_mode ~= "audio" then return end
    active_mode = ""
    remove_bindings()
    on_audio_mode_deactivate()
end

function on_start_file(event)
    local short_ext = get_file_ext_short(mp.get_property("path"))

    if list_contains(split(mp.get_property("image-exts"), ","), short_ext) then
        disable_video_mode()
        disable_audio_mode()
        enable_image_mode()
    elseif list_contains(split(mp.get_property("audio-exts"), ","), short_ext) then
        disable_image_mode()
        disable_video_mode()
        enable_audio_mode()
    else
        disable_audio_mode()
        disable_image_mode()
        enable_video_mode()
    end

    if last_type ~= short_ext then
        on_type_change(last_type, short_ext)
        last_type = short_ext
    end
end

mp.register_event("start-file", on_start_file)
