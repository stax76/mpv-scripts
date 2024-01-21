
--[[

    https://github.com/stax76/mpv-scripts

    This script records the volume per song in order to restore
    it in future sessions.

    What is recorded and restored is the volume offset relative
    to the session average volume.

    For every song the last ten sessions are recorded,
    the average of that is used.

    It gives much better results than replay gain.

    Configuration: ~~\script-opts\average_volume.conf
    monitored_directories=<directories seperated with a semicolon>
    #storage_path=~~/average_volume.json

    Files not updated or orphaned get removed
    automatically after 500 days.

]]--

----- options

local o = {
    monitored_directories = "",
    storage_path = "~~/average_volume.json",
}

----- math

function round(value)
    return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

----- string

function is_empty(input)
    if input == nil or input == "" then
        return true
    end
end

function contains(value, find)
    return value:find(find, 1, true)
end

function replace(str, what, with)
    what = string.gsub(what, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
    with = string.gsub(with, "[%%]", "%%%%")
    return string.gsub(str, what, with)
end

function starts_with(str, start)
    return str:sub(1, #start) == start
end

function split(value, sep)
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

    if is_windows and ((contains(path, ":/") and not contains(path, "://")) or
       (contains(path, ":\\") and contains(path, "/"))) then

        path = replace(path, "/", "\\")
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
    local file = io.open(name, "r")

    if file ~= nil then
        io.close(file)
        return true
    else
        return false
    end
end

function file_read(file_path)
    local file = assert(io.open(file_path, "r"))
    local content = file:read("*all")
    file:close()
    return content
end

function file_write(file_path, content)
    local file = assert(io.open(file_path, "w"))
    file:write(content)
    file:close()
end

----- average_volume

local utils = require "mp.utils"
local msg = require "mp.msg"
local previous_name = nil
local data = nil
local session_data = {}

local opt = require "mp.options"
opt.read_options(o)
o.storage_path = mp.command_native({"expand-path", o.storage_path})

if is_empty(o.monitored_directories) then
    msg.warn("No directory to be monitored found.")
    return
end

local monitored_directories = split(o.monitored_directories, ";")

function get_filename(path)
    local _, filename = utils.split_path(path)
    return filename
end

function get_average(array)
    local sum = 0
    local count = 0

    for _, v in pairs(array) do
        sum = sum + v
        count = count + 1
    end

    if count > 0 then
        return round(sum / count)
    else
        return 0
    end
end

function get_item(name)
    for _, v in pairs(data) do
        if name == v.name then
            return v
        end
    end
end

mp.register_event("start-file", function (event)
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

    if data == nil then
        if file_exists(o.storage_path) then
            data = utils.parse_json(file_read(o.storage_path))
        else
            data = {}
        end
    end

    local volume = mp.get_property_number("volume")

    if volume == 0 and previous_name ~= nil then
        for _, v in pairs(data) do
            if v.name == previous_name then
                v.volumes = { 0 }
                break
            end
        end
    end

    if volume ~= 0 and previous_name ~= nil then
        session_data[previous_name] = volume
    end

    previous_name = get_filename(file)

    if starts_with(previous_name, "00 - ") then
        previous_name = string.sub(previous_name, 6)
    end

    local session_average = get_average(session_data)

    if session_average == 0 then
        session_average = volume
    end

    if session_data[previous_name] ~= nil then
        mp.set_property_number("volume", session_data[previous_name])
    elseif get_item(previous_name) ~= nil then
        local item = get_item(previous_name)
        mp.set_property_number("volume", session_average + get_average(item.volumes))
    else
        mp.set_property_number("volume", session_average)
    end
end)

mp.register_event("shutdown", function ()
    if table_count(session_data) < 3 then
        return
    end

    local session_average = get_average(session_data)

    for name, volume in pairs(session_data) do
        local item = get_item(name)

        if item == nil then
            item = {}
            item.name = name
            item.date = os.time()
            item.volumes = { volume - session_average }
            table.insert(data, item)
        else
            while #item.volumes > 9 do
                table.remove(item.volumes, 1)
            end

            table.insert(item.volumes, volume - session_average)
            item.date = os.time()
        end
    end

    for i=#data,1,-1 do
        local item = data[i]
        local days = (os.time() - item.date) / 60 / 24

        if days > 500 then
            table.remove(data, i)
        end
    end

    file_write(o.storage_path, utils.format_json(data))
end)
