
--[[

    This script consist of various small unrelated features.

    Not used code sections can be removed.

    Bindings must be added manually to input.conf.



    Show media info on screen
    -------------------------
    Prints detailed media info on the screen.
    
    Depends on the CLI tool 'mediainfo':
    https://mediaarea.net/en/MediaInfo/Download

    i script-message-to misc print-media-info



    Load files/URLs from clipboard
    ------------------------------
    Loads one or multiple files/URLs from the clipboard.
    The clipboard format can be of type string or file object.
    Allows appending to the playlist.
    On Linux requires xclip being installed.

    ctrl+v script-message-to misc load-from-clipboard
    ctrl+V script-message-to misc append-from-clipboard



    Jump to a random position in the playlist
    -----------------------------------------
    ctrl+r script-message-to misc playlist-random

    If pos=last it jumps to first instead of random.



    Quick Bookmark
    --------------
    Creates or restores a single bookmark that persists
    as long as a file is opened.

    ctrl+q script-message-to misc quick-bookmark

 

    Playlist Next/Prev
    ------------------
    Like the regular playlist-next/playlist-prev, but does not restart playback
    of the first or last file, in case the first or last track already plays,
    instead shows a OSD message.

    F11 script-message-to misc playlist-prev # Go to previous file in playlist
    F12 script-message-to misc playlist-next # Go to next file in playlist



    Playlist First/Last
    -------------------
    Navigates to the first or last track in the playlist,
    in case the first or last track already plays, it does not
    restart playback, instead shows a OSD message.

    Home script-message-to misc playlist-first # Go to first file in playlist
    End  script-message-to misc playlist-last  # Go to last file in playlist



    Restart mpv
    -----------
    Restarts mpv restoring the properties path, time-pos,
    pause and volume, the playlist is not restored.

    r script-message-to misc restart-mpv



    Execute Lua code
    ----------------
    Allows to execute Lua Code directly from input.conf.

    It's necessary to add a binding to input.conf:
    #Navigates to the last file in the playlist
    END script-message-to misc execute-lua-code "mp.set_property_number('playlist-pos', mp.get_property_number('playlist-count') - 1)"



    When seeking displays position and duration like so:
    ----------------------------------------------------
    70:00 / 80:00

    Which is different from most players which use:

    01:10:00 / 01:20:00

    In input.conf set the input command prefix
    no-osd infront of the seek commands.

    Must be enabled in conf file:
    ~~home/script-opts/misc.conf: alternative_seek_text=yes

]]--

----- options

local o = {
    alternative_seek_text = false,
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

function trim(input)
    if not is_empty(input) then
        return input:match "^%s*(.-)%s*$"
    end
end

----- math

function round(value)
    return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

----- file

function file_exists(path)
    if is_empty(path) then return false end
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

----- shared

is_windows = package.config:sub(1,1) == "\\"

msg = require "mp.msg"

----- Jump to a random position in the playlist

mp.register_script_message("playlist-random", function ()
    local count = mp.get_property_number("playlist-count")
    local new_pos = math.random(0, count - 1)
    local current_pos = mp.get_property_number("playlist-pos")

    if current_pos == count - 1 then
        new_pos = 0
    end

    mp.set_property_number("playlist-pos", new_pos)
end)

----- Quick Bookmark

quick_bookmark_position = 0
quick_bookmark_file = ""

mp.register_script_message("quick-bookmark", function ()
    if quick_bookmark_position == 0 then
        quick_bookmark_position = mp.get_property_number("time-pos")
        quick_bookmark_file = mp.get_property("path")

        if quick_bookmark_position ~= 0 then
            mp.osd_message("Bookmark Saved")
        end
    elseif quick_bookmark_file == mp.get_property("path") then
        mp.set_property_number("time-pos", quick_bookmark_position)
        quick_bookmark_position = 0
    end
end)

----- Execute Lua code

mp.register_script_message("execute-lua-code", function (code)
    loadstring(code)()
end)

----- Alternative seek OSD message

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
        mp.osd_message(format(position) .. " / " .. format(duration))
    end
end

if o.alternative_seek_text then
    mp.register_event("seek", on_seek)
end

----- Print media info on screen

media_info_format = [[General;N: %FileNameExtension%\\nG: %Format%, %FileSize/String%, %Duration/String%, %OverallBitRate/String%, %Recorded_Date%\\n
Video;V: %Format%, %Format_Profile%, %Width%x%Height%, %BitRate/String%, %FrameRate% FPS\\n
Audio;A: %Language/String%, %Format%, %Format_Profile%, %BitRate/String%, %Channel(s)% ch, %SamplingRate/String%, %Title%\\n
Text;S: %Language/String%, %Format%, %Format_Profile%, %Title%\\n]]

if is_windows then
    format_file = os.getenv("TEMP") .. "/media-info-format-2.txt"
else
    format_file = "/tmp/media-info-format-2.txt"
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

    local proc_result = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = {"mediainfo", "--inform=file://" .. format_file, path},
    })

    if proc_result.status == 0 then
        local output = proc_result.stdout

        output = string.gsub(output, ", , ,", ",")
        output = string.gsub(output, ", ,", ",")
        output = string.gsub(output, ": , ", ": ")
        output = string.gsub(output, ", \\n\r*\n", "\\n")
        output = string.gsub(output, "\\n\r*\n", "\\n")
        output = string.gsub(output, ", \\n", "\\n")
        output = string.gsub(output, "%.000 FPS", " FPS")
        output = string.gsub(output, "MPEG Audio, Layer 3", "MP3")

        show_text(output, 5000, 16)
    end
end

mp.register_script_message("print-media-info", on_print_media_info)

----- Playlist Next/Prev

mp.register_script_message("playlist-next", function ()
    local count = mp.get_property_number("playlist-count")
    if count == 0 then return end
    local pos = mp.get_property_number("playlist-pos")

    if pos == count - 1 then
        mp.osd_message("Already last track")
        return
    end

    mp.set_property_number("playlist-pos", pos + 1)
end)

mp.register_script_message("playlist-prev", function ()
    local count = mp.get_property_number("playlist-count")
    if count == 0 then return end
    local pos = mp.get_property_number("playlist-pos")

    if pos == 0 then
        mp.osd_message("Already first track")
        return
    end

    mp.set_property_number("playlist-pos", pos - 1)
end)

----- Playlist First/Last

mp.register_script_message("playlist-first", function ()
    local count = mp.get_property_number("playlist-count")
    if count == 0 then return end
    local pos = mp.get_property_number("playlist-pos")

    if pos == 0 then
        mp.osd_message("Already first track")
        return
    end

    mp.set_property_number("playlist-pos", 0)
end)

mp.register_script_message("playlist-last", function ()
    local count = mp.get_property_number("playlist-count")
    if count == 0 then return end
    local pos = mp.get_property_number("playlist-pos")

    if pos == count - 1 then
        mp.osd_message("Already last track")
        return
    end

    mp.set_property_number("playlist-pos", count - 1)
end)

----- Load files from clipboard

function loadfiles(mode)
    if is_windows then
        local ps_code = [[
            Add-Type -AssemblyName System.Windows.Forms
            $containsFiles = [Windows.Forms.Clipboard]::ContainsFileDropList()
            
            if ($containsFiles) {
                [Windows.Forms.Clipboard]::GetFileDropList() -join [Environment]::NewLine
            } else {
                Get-Clipboard
            }
        ]]

        proc_args = { "powershell", "-command", ps_code }
    else
        proc_args = { "xclip", "-o", "-selection", "clipboard" }
    end

    subprocess = {
        name = "subprocess",
        args = proc_args,
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true
    }

    proc_result = mp.command_native(subprocess)

    if proc_result.status < 0 then
        msg.error("Error string: " .. proc_result.error_string)
        msg.error("Error stderr: " .. proc_result.stderr)
        return
    end

    proc_output = trim(proc_result.stdout)

    if is_empty(proc_output) then return end

    if contains(proc_output, "\n") then
        mp.commandv("loadlist", "memory://" .. proc_output, mode)
    else
        mp.commandv("loadfile", proc_output, mode)
    end
end

mp.register_script_message("load-from-clipboard", function ()
    loadfiles("replace")
end)

mp.register_script_message("append-from-clipboard", function ()
    loadfiles("append")
end)

----- Restart mpv

mp.register_script_message("restart-mpv", function ()
    local restart_args = {
        "mpv",
        "--pause=" .. mp.get_property("pause"),
        "--volume=" .. mp.get_property("volume"),
    }

    local playlist_pos = mp.get_property_number("playlist-pos")

    if playlist_pos > -1 then
        table.insert(restart_args, "--start=" .. mp.get_property("time-pos"))
        table.insert(restart_args, mp.get_property("path"))
    end

    mp.command_native({
        name = "subprocess",
        playback_only = false,
        detach = true,
        args = restart_args,
    })

    mp.command("quit")
end)
