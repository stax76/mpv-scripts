
--[[

    https://github.com/stax76/mpv-scripts

    All this script does is writing to a log file.
    
    It writes:
    
    1. The date and time:     10.09.2022 19:50
    2. How many minutes:      3
    3. Filename and location: D:\Samples\Big Buck Bunny.mkv

    This is how it looks:
    
    10.09.2022 19:50  3 D:\Samples\Big Buck Bunny.mkv

    There are two conf options:

    exclude=<list of folders to be excluded, separated via semicolon>
    storage_path=~~/history.log

    Similar or related scripts:
    https://github.com/yuukidach/mpv-scripts/blob/master/history-bookmark.lua
    https://gist.github.com/Abject-Web/3f4f0e85dad73303b9dd1ef1f55c3147
    https://gist.github.com/garoto/e0eb539b210ee077c980e01fb2daef4a
    https://github.com/Eisa01/mpv-scripts#simplehistory
    https://github.com/hacel/recent

]]--

----- string

function is_empty(input)
    if input == nil or input == "" then
        return true
    end
end

function trim(input)
    if is_empty(input) then
        return ""
    end

    return input:match "^%s*(.-)%s*$"
end

function contains(input, find)
    if not is_empty(input) and not is_empty(find) then
        return input:find(find, 1, true)
    end
end

function replace(str, what, with)
    if is_empty(str) then return "" end
    if is_empty(what) then return str end
    if with == nil then with = "" end
    what = string.gsub(what, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
    with = string.gsub(with, "[%%]", "%%%%")
    return string.gsub(str, what, with)
end

function split(input, sep)
    local tbl = {}

    if not is_empty(input) then
        for str in string.gmatch(input, "([^" .. sep .. "]+)") do
            table.insert(tbl, str)
        end
    end

    return tbl
end

function pad_left(input, len, char)
    if input == nil then
        input = ""
    end

    if char == nil then
        char = ' '
    end

    return string.rep(char, len - #input) .. input
end

----- math

function round(value)
    return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

----- file

function file_exists(path)
    local f = io.open(path, "r")

    if f ~= nil then
        io.close(f)
        return true
    end
end

function file_append(path, content)
    local h = assert(io.open(path, "ab"))
    h:write(content)
    h:close()
end

----- history

time = 0 -- number of seconds since epoch
path = ""

local o = {
    exclude = "",
    storage_path = "~~/history.log",
}

opt = require "mp.options"
opt.read_options(o)

o.storage_path = mp.command_native({"expand-path", o.storage_path})

function discard()
    for _, v in pairs(split(o.exclude, ";")) do
        local p = replace(path, "/", "\\")
        v = replace(trim(v), "/", "\\")

        if contains(p, v) then
            return true
        end
    end
end

function history()
    local seconds = round(os.time() - time)

    if not is_empty(path) and seconds > 60 and not discard() then
        local minutes = round(seconds / 60)
        local line = os.date("%d.%m.%Y %H:%M ") ..
            pad_left(tostring(minutes), 3) .. " " .. path .. "\n"
        file_append(o.storage_path, line)
    end

    path = mp.get_property("path")

    if contains(path, "://") then
        path = mp.get_property("media-title")
    end

    time = os.time()
end

mp.register_event("shutdown", history)
mp.register_event("file-loaded", history)
