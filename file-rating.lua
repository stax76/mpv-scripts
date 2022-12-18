
--[[

    https://github.com/stax76/mpv-scripts

    This script writes a star rating to the filename
    of rated files when mpv shuts down. When a file
    is rated the last modified file date is set to now.

    In input.conf add:
    KP0 script-message-to file_rating rate-file 0
    KP1 script-message-to file_rating rate-file 1
    KP2 script-message-to file_rating rate-file 2
    KP3 script-message-to file_rating rate-file 3
    KP4 script-message-to file_rating rate-file 4
    KP5 script-message-to file_rating rate-file 5

]]--

----- string

function contains(value, find)
    return value:find(find, 1, true)
end

function string_replace(str, what, with)
    what = string.gsub(what, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
    with = string.gsub(with, "[%%]", "%%%%")
    return string.gsub(str, what, with)
end

----- path

function file_base_name(value)
    return value:match("(.+)%.[^%.]")
end

function get_file_ext(path)
    if path == nil then return nil end
    local val = path:match("^.+(%.[^%./\\]+)$")
    if val == nil then return nil end
    return val:lower()
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

function set_last_write_time_to_now(path)
    local is_windows = package.config:sub(1,1) == "\\"

    if is_windows then
        local ps_code = [[& {
            $file = Get-Item -LiteralPath '__path__'
            $file.LastWriteTime = (Get-Date)
        }]]

        local escaped_path = string.gsub(path, "'", "''")
        escaped_path = string.gsub(escaped_path, "’", "’’")
        escaped_path = string.gsub(escaped_path, "%%", "%%%%")
        ps_code = string.gsub(ps_code, "__path__", escaped_path)

        mp.command_native({
            name = "subprocess",
            playback_only = false,
            detach = true,
            args = { 'powershell', '-NoProfile', '-Command', ps_code },
        })
    else
        mp.command_native({
            name = "subprocess",
            playback_only = false,
            detach = true,
            args = { 'touch', path },
        })
    end
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

----- path mpv

utils = require "mp.utils"

function file_name(value)
    local _, filename = utils.split_path(value)
    return filename
end

function directory_path(value)
    local path, _ = utils.split_path(value)
    return path
end

function join_path(p1, p2)
    return utils.join_path(p1, p2)
end

----- file-rating

ratings = {}

function rate_file(path, rating)
    local base = file_base_name(file_name(path))

    for i = 0, 5 do
        if contains(base, " (" .. i .. "stars)") then
            base = string_replace(base, " (" .. i .. "stars)", "")
            break
        end
    end

    base = base .. " (" .. rating .. "stars)"

    local new_path = join_path(directory_path(path), base .. get_file_ext(path))

    if path:lower() ~= new_path:lower() then
        os.rename(path, new_path)
    end

    set_last_write_time_to_now(new_path)
end

mp.register_event("shutdown", function ()
    for path, rating in pairs(ratings) do
        if file_exists(path) then
            local ext = get_file_ext(mp.get_property("path"))
            rate_file(path, rating)
        end
    end
end)

mp.register_script_message("rate-file", function (rating)
    local path = mp.get_property("path")

    if file_exists(path) then        
        ratings[path] = rating
        mp.command('show-text "Rating: ' .. rating .. '"')
    end
end)
