
--[[

    This script records the volume per file in order to restore
    it in future sessions.
    What is recorded and restored is the volume offset relative
    to the session average volume.

    Usage:
    1. In the mpv config directory create a directory called: 'script-settings'
       C:\Users\JD\AppData\Roaming\mpv.net\script-settings
    2. Create a conf file 'smart_volume.conf' in the 'script-opts' directory:
       C:\Users\JD\AppData\Roaming\mpv.net\script-opts\smart_volume.conf
    3. In smart_volume.conf add the option monitored_directories=<directory>
    4. Multiple directories are seperated with a semicolon.
    5. The script is ready to be used now, when mpv exits,
       the script creates or updates the file:
       C:\Users\JD\AppData\Roaming\mpv.net\script-settings\smart-volume.json

]]--

----- options

local o = {
    -- semicolon used as seperator
    monitored_directories = "",
}

----- math

function round(value)
    return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

----- string

function string_contains(value, find)
    return value:find(find, 1, true)
end

function string_replace(str, what, with)
    what = string.gsub(what, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
    with = string.gsub(with, "[%%]", "%%%%")
    return string.gsub(str, what, with)
end

function starts_with(str, start)
    return str:sub(1, #start) == start
end

function string_split(value, sep)
    local t = {}

    for str in string.gmatch(value, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end

    return t
end

----- path

function normalize_path(path)
    if path == nil then
        return ""
    end

    local is_windows = package.config:sub(1,1) == "\\"

    if is_windows and ((string_contains(path, ":/") and not string_contains(path, "://")) or
       (string_contains(path, ":\\") and string_contains(path, "/"))) then

        path = string_replace(path, "/", "\\")
    end

    return path
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

----- table

function table_count(t)
    local count = 0

    for _ in pairs(t) do
        count = count + 1
    end

    return count
end

----- file

function file_exists(name)
    local f = io.open(name, "r")

    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

function file_read(file_path)
    local h = assert(io.open(file_path, "rb"))
    local content = h:read("*all")
    h:close()
    return content
end

function file_write(file_path, content)
    local h = assert(io.open(file_path, "wb"))
    h:write(content)
    h:close()
end

----- smart-volume

utils = require "mp.utils"
msg = require "mp.msg"
options = require "mp.options"

previous_file = nil
data = {}
session_data = {}
settings_file_path = mp.command_native({"expand-path", "~~/script-settings"}) .. "/smart-volume.json"
volume_list = {}
options.read_options(o)

if o.monitored_directories == nil or o.monitored_directories == "" then
    msg.error("No directory to be monitored found.")
    return
end

monitored_directories = string_split(o.monitored_directories, ";")

function get_average(array)
    if array == nil or #array == 0 then
        return 0
    end

    local sum = 0

    for _, v in pairs(array) do
        sum = sum + v
    end

    return round(sum / #array)
end

function get_average_volume()
    if #volume_list > 0 then
        return get_average(volume_list)
    end

    return mp.get_property("volume")
end

function on_start_file(event)
    local file = normalize_path(mp.get_property("path"))
    local found = false

    for _, dir in pairs(monitored_directories) do
        dir = normalize_path(dir)

        if starts_with(file, dir) then
            found = true
            break
        end
    end

    if not found then
        return
    end

    local volume = mp.get_property("volume")

    if previous_file ~= nil then
        session_data[previous_file] = volume
        table.insert(volume_list, volume)
    end

    previous_file = file

    if data[previous_file] ~= nil then
        local past_offset = get_average(data[previous_file])
        local current_average = get_average(volume_list)

        if current_average == 0 then
            current_average = volume
        end

        local new_volume = current_average + past_offset
        local remainder = new_volume % 5

        if remainder ~= 0 then
            if remainder > 2.5 then
                new_volume = new_volume - remainder + 5
            else
                new_volume = new_volume - remainder
            end
        end

        mp.set_property("volume", round(new_volume))
    end
end

mp.register_event("start-file", on_start_file)

function on_shutdown()
    if table_count(session_data) == 0 then
        return
    end

    local average = get_average(volume_list)

    for path, volume in pairs(session_data) do
        if data[path] == nil then
            data[path] = { volume - average }
        else
            while table_count(data[path]) > 5 do
                table.remove(data[path], 1)
            end

            table.insert(data[path], volume - average)
        end
    end

    file_write(settings_file_path, utils.format_json(data))
end

mp.register_event("shutdown", on_shutdown)

if file_exists(settings_file_path) then
    data = utils.parse_json(file_read(settings_file_path))
end
