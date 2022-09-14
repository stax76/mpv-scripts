
--[[

    1. Jump to a random position in the playlist
    --------------------------------------------
    Binding: Ctrl+r  script-message-to misc playlist-random
    If pos=last it jumps to first instead of random.
    mpv.net has the same feature built-in.



    2. When seeking displays position and duration like so:
    -------------------------------------------------------
    70:00 / 80:00

    Which is different from most players which use:

    01:10:00 / 01:20:00

    In input.conf set the input command prefix
    no-osd infront of the seek commands.

    Must be enabled in conf file:
    ~~home/script-opts/misc.conf: alternative_seek_text=yes



    3. Auto Play
    ------------
    When a new file is loaded, sets pause=no to start playback.
    
    Must be enabled in conf file:
    ~~home/script-opts/misc.conf: auto_play=yes
    
    mpv.net has the same feature built-in.

]]--

----- options

local o = {
    alternative_seek_text = false,
    auto_play = false,
}

opt = require "mp.options"
opt.read_options(o)

----- math

function round(value)
    return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

----- path mpv

utils = require "mp.utils"

function file_name(value)
    local _, filename = utils.split_path(value)
    return filename
end

----- playlist

function random()
    local count = mp.get_property("playlist-count")
    local new_pos = math.random(0, count - 1)
    local current_pos = mp.get_property("playlist-pos")

    if current_pos == count - 1 then
        new_pos = 0
    end

    mp.set_property_number("playlist-pos", new_pos)
end

mp.register_script_message("playlist-random", random)

----- alternative seek text

function add_zero(value)
    local value = round(value)

    if value > 9 then
        return "" .. value
    else
        return "0" .. value
    end
end

function format(value)
    local seconds = round(value)

    if seconds < 0 then
        seconds = 0
    end

    local pos_min_floor = math.floor(seconds / 60)
    local sec_rest = seconds - pos_min_floor * 60

    return add_zero(pos_min_floor) .. ":" .. add_zero(sec_rest)
end

function on_seek()
    local position = mp.get_property_number("time-pos")
    local duration = mp.get_property_number("duration")

    if position > duration then
        position = duration
    end

    if position ~= 0 then
        mp.commandv("show-text", format(position) .. " / " .. format(duration))
    end
end

if o.alternative_seek_text then
    mp.register_event("seek", on_seek)
end

----- Auto play

function on_file_loaded()
    mp.set_property_bool("pause", false)
end

if o.auto_play then
    mp.register_event("file-loaded", on_file_loaded)
end
