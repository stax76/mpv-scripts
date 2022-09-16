
--[[

    1. Jump to a random position in the playlist
    --------------------------------------------
    Add binding to input.conf:
    ctrl+r  script-message-to misc playlist-random

    If pos=last it jumps to first instead of random.



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
    


    4. Show media info on screen
    ----------------------------
    Prints media info on the screen.
    
    Depends on the CLI tool 'mediainfo':
    sudo apt install mediainfo
    https://mediaarea.net/en/MediaInfo/Download

    Add binding to input.conf:
    ctrl+i  script-message-to misc print-media-info
 
]]--

----- options

local o = {
    alternative_seek_text = false,
    auto_play = false,
}

opt = require "mp.options"
opt.read_options(o)

----- string

function is_empty(input)
    if input == nil or input == "" then
        return true
    end
end

function contains(input, find)
    if not is_empty(input) and not is_empty(find) then
        return input:find(find, 1, true)
    end
end

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

----- file

function file_exists(path)
    local file = io.open(path, "r")

    if file ~= nil then
        io.close(file)
        return true
    end
end

function file_write(path, content)
    local file = assert(io.open(path, "w"))
    file:write(content)
    file:close()
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

----- alternative seek OSD message

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

----- Print media info on screen

media_info_format = [[General;N: %FileNameExtension%\\nG: %Format%, %FileSize/String%, %Duration/String%, %OverallBitRate/String%\\n
Video;V: %Format%, %Format_Profile%, %Width%x%Height%, %BitRate/String%, %FrameRate% FPS\\n
Audio;A: %Language/String%, %Format%, %Format_Profile%, %BitRate/String%, %Channel(s)% ch, %SamplingRate/String%, %Title%\\n
Text;S: %Language/String%, %Format%, %Format_Profile%, %Title%\\n]]

is_windows = package.config:sub(1,1) == "\\"

if is_windows then
    format_file = os.getenv("TEMP") .. "/media-info-format.txt"
else
    format_file = "/tmp/media-info-format.txt"
end

if not file_exists(format_file) then
    file_write(format_file, media_info_format)
end

function show_text(text, duration, font_size)
    mp.command('show-text "${osd-ass-cc/0}{\\\\fs' .. font_size ..
        '}${osd-ass-cc/1}' .. text .. '" ' .. duration)
end

function on_print_media_info()
    local path = mp.get_property("path")

    if contains(path, "://") or not file_exists(path) then
        return
    end

    local arg2 = "--inform=file://" .. format_file

    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = {"mediainfo", arg2, path},
    })

    if r.status == 0 then
        local output = r.stdout

        output = string.gsub(output, ", , ,", ",")
        output = string.gsub(output, ", ,", ",")
        output = string.gsub(output, ": , ", ": ")
        output = string.gsub(output, ", \\n\r*\n", "\\n")
        output = string.gsub(output, "\\n\r*\n", "\\n")
        output = string.gsub(output, ", \\n", "\\n")
        output = string.gsub(output, "%.000 FPS", " FPS")

        show_text(output, 5000, 16)
    end
end

mp.register_script_message("print-media-info", on_print_media_info)
