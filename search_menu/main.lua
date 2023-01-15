
-- https://github.com/stax76/mpv-scripts

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

----- main

local utils = require "mp.utils"
local msg = require "mp.msg"

local o = {
    mode = "",
}

opt = require "mp.options"
opt.read_options(o)

is_windows = package.config:sub(1,1) == "\\"

if o.mode == "" then
    if is_windows then
        o.mode = "windows-terminal+ps"
    else
        o.mode = "gnome-terminal+sh"
    end
end

function get_media_info()
    if is_windows then
        format_file = os.getenv("TEMP") .. "/media-info-format-4.txt"
    else
        format_file = "/tmp/media-info-format-4.txt"
    end

    if not file_exists(format_file) then
        media_info_format = [[General;N: %FileNameExtension%\\nG: %Format%, %FileSize/String%, %Duration/String%, %OverallBitRate/String%, %Recorded_Date%\\n
Video;V: %Format%, %Format_Profile%, %Width%x%Height%, %BitRate/String%, %FrameRate% FPS\\n
Audio;A: %Language/String%, %Format%, %Format_Profile%, %BitRate/String%, %Channel(s)% ch, %SamplingRate/String%, %Title%\\n
Text;S: %Language/String%, %Format%, %Format_Profile%, %Title%\\n]]

        file_write(format_file, media_info_format)
    end

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

        return output
    end
end

mp.register_script_message("show-search-menu", function (mode)
    local envlist = utils.get_env_list()

    if mode == "binding" then
        title = "Binding"
        table.insert(envlist, "SEARCH_MENU_MODE=binding")
        table.insert(envlist, "SEARCH_MENU_BINDING=" .. mp.get_property("input-bindings"))
    elseif mode == "binding-full" then
        title = "Binding"
        table.insert(envlist, "SEARCH_MENU_MODE=binding-full")
        table.insert(envlist, "SEARCH_MENU_BINDING=" .. mp.get_property("input-bindings"))
    elseif mode == "playlist" then
        title = "Playlist"
        local count = mp.get_property_number("playlist-count")
        if count == 0 then return end
        local playlist = {}

        for i = 0, (count - 1) do
            local name = mp.get_property("playlist/" .. i .. "/title")

            if name == nil then
                name = mp.get_property("playlist/" .. i .. "/filename")
            end

            table.insert(playlist, name)
        end

        local playlist_text =  table.concat(playlist, "\n")
        table.insert(envlist, "SEARCH_MENU_MODE=playlist")
        table.insert(envlist, "SEARCH_MENU_PLAYLIST=" .. playlist_text)
    elseif mode == "command" then
        title = "Command"
        table.insert(envlist, "SEARCH_MENU_MODE=command")
        table.insert(envlist, "SEARCH_MENU_COMMAND=" .. mp.get_property("command-list"))
    elseif mode == "property" then
        title = "Property"
        table.insert(envlist, "SEARCH_MENU_MODE=property")
        table.insert(envlist, "SEARCH_MENU_PROPERTY=" .. mp.get_property("property-list"))
    elseif mode == "audio-track" then
        title = "Audio Track"
        table.insert(envlist, "SEARCH_MENU_MODE=audio-track")
        table.insert(envlist, "SEARCH_MENU_AUDIO_TRACK=" .. get_media_info())
    elseif mode == "sub-track" then
        title = "Subtitle Track"
        table.insert(envlist, "SEARCH_MENU_MODE=sub-track")
        table.insert(envlist, "SEARCH_MENU_SUB_TRACK=" .. get_media_info())
    else
        msg.error("Unknown mode '" .. mode .. "'.")
        return
    end

    local py_file = '~~/scripts/search_menu/search_menu.py'
    py_file = mp.command_native({"expand-path", py_file})
    local dash_code = 'fp="' .. py_file .. '"; python $fp "$(python $fp | fzf --exact)"'

    if o.mode == "gnome-terminal+sh" then
        proc_args = { 'gnome-terminal', '--', 'sh', '-c', dash_code }
    elseif o.mode == 'alacritty+sh' then
        proc_args = { 'alacritty', '-t', title, '-e', 'sh', '-c', dash_code }
    elseif o.mode == 'alacritty+ns' then
        local nu_code = "\"python '" .. py_file .. "' (python '" .. py_file .. "' | fzf --exact | str trim)\""
        proc_args = { 'alacritty', '-t', title, '-e', 'nu', '-c', nu_code }
    elseif o.mode == 'rofi' then
        proc_args = { 'rofi', '-modi', mode .. ':"' .. py_file .. '"', '-show', mode }
    elseif o.mode == 'windows-terminal+ps' then
        local ps_code = "python '" .. py_file .. "' (python '" .. py_file .. "' | fzf --exact)"
        proc_args = { 'wt', '--focus', '--', 'powershell', '-noprofile', '-nologo', '-command', ps_code }
    elseif o.mode == 'windows-terminal+ns' then
        local nu_code = "python '" .. py_file .. "' (python '" .. py_file .. "' | fzf --exact | str trim)"
        proc_args = { 'wt', '--focus', '--', 'nu', '-c', nu_code }
    else
        msg.error("Unknown mode '" .. o.mode .. "'.")
        return
    end

    mp.command_native({
        name = "subprocess",
        playback_only = false,
        detach = true,
        env = envlist,
        args = proc_args,
    })
end)

mp.register_script_message("search_menu-command", function (value)
    print(value)
    local cmd = string.match(value, '%S+')
    mp.commandv("script-message-to", "console", "type", cmd .. " ")
end)

mp.register_script_message("search_menu-property", function (value)
    mp.commandv('script-message-to', 'console', 'type', 'print-text ${' .. value .. '}')
end)
