
-- https://github.com/stax76/mpv-scripts

----- options

local o = {
    lines_to_show = 10,
    pause_on_open = false, -- does not work on my system when enabled, menu won't show
    resume_on_exit = "only-if-was-paused",

    -- styles
    font_size = 50,
    line_bottom_margin = 1,
    menu_x_padding = 5,
    menu_y_padding = 2,
}

local opt = require "mp.options"
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

function starts_with(str, start)
    return str:sub(1, #start) == start
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

function first_to_upper(str)
    return (str:gsub("^%l", string.upper))
end

----- list

function list_contains(list, value)
    for _, v in pairs(list) do
        if v == value then
            return true
        end
    end
end

----- path

function get_temp_dir()
    local is_windows = package.config:sub(1,1) == "\\"

    if is_windows then
        return os.getenv("TEMP") .. "\\"
    else
        return "/tmp/"
    end
end

---- file

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

----- mpv

local utils = require "mp.utils"
local assdraw = require 'mp.assdraw'
local msg = require "mp.msg"

----- path mpv

function file_name(value)
    local _, filename = utils.split_path(value)
    return filename
end

----- main

package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua;" }) .. package.path

local em = require "extended-menu"
local menu = em:new(o)
local menu_content = { list = {}, current_i = nil }
local osc_visibility = nil
local media_info_cache = {}
local original_set_active_func = em.set_active
local original_get_line_func = em.get_line

function em:get_bindings()
    local bindings = {
        { 'esc',         function() self:set_active(false) end                         },
        { 'enter',       function() self:handle_enter() end                            },
        { 'bs',          function() self:handle_backspace() end                        },
        { 'del',         function() self:handle_del() end                              },
        { 'ins',         function() self:handle_ins() end                              },
        { 'left',        function() self:prev_char() end                               },
        { 'right',       function() self:next_char() end                               },
        { 'ctrl+f',      function() self:next_char() end                               },
        { 'up',          function() self:change_selected_index(-1) end                 },
        { 'down',        function() self:change_selected_index(1) end                  },
        { 'ctrl+up',     function() self:move_history(-1) end                          },
        { 'ctrl+down',   function() self:move_history(1) end                           },
        { 'ctrl+left',   function() self:prev_word() end                               },
        { 'ctrl+right',  function() self:next_word() end                               },
        { 'home',        function() self:go_home() end                                 },
        { 'end',         function() self:go_end() end                                  },
        { 'pgup',        function() self:change_selected_index(-o.lines_to_show) end   },
        { 'pgdwn',       function() self:change_selected_index(o.lines_to_show) end    },
        { 'ctrl+u',      function() self:del_to_start() end                            },
        { 'ctrl+v',      function() self:paste(true) end                               },
        { 'ctrl+bs',     function() self:del_word() end                                },
        { 'ctrl+del',    function() self:del_next_word() end                           },
        { 'kp_dec',      function() self:handle_char_input('.') end                    },
    }

    for i = 0, 9 do
        bindings[#bindings + 1] =
            {'kp' .. i, function() self:handle_char_input('' .. i) end}
    end

    return bindings
end

function em:set_active(active)
    original_set_active_func(self, active)

    if not active and osc_visibility then
        mp.command("script-message osc-visibility " .. osc_visibility .. " no_osd")
        osc_visibility = nil
    end
end

menu.index_field = "index"

function get_media_info()
    local path = mp.get_property("path")

    if media_info_cache[path] then
        return media_info_cache[path]
    end

    local format_file = get_temp_dir() .. mp.get_script_name() .. " media-info-format-v1.txt"

    if not file_exists(format_file) then
        media_info_format = [[General;N: %FileNameExtension%\\nG: %Format%, %FileSize/String%, %Duration/String%, %OverallBitRate/String%, %Recorded_Date%\\n
Video;V: %Format%, %Format_Profile%, %Width%x%Height%, %BitRate/String%, %FrameRate% FPS\\n
Audio;A: %Language/String%, %Format%, %Format_Profile%, %BitRate/String%, %Channel(s)% ch, %SamplingRate/String%, %Title%\\n
Text;S: %Language/String%, %Format%, %Format_Profile%, %Title%\\n]]

        file_write(format_file, media_info_format)
    end

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
        output = string.gsub(output, "\\n", "\n")
        output = string.gsub(output, "%.000 FPS", " FPS")
        output = string.gsub(output, "MPEG Audio, Layer 3", "MP3")

        media_info_cache[path] = output

        return output
    end
end

function binding_get_line(self, _, v)
    local a = assdraw.ass_new()
    local cmd = self:ass_escape(v.cmd)
    local key = self:ass_escape(v.key)
    local comment = self:ass_escape(v.comment or '')

    if v.priority == -1 or v.priority == -2 then
        local why_inactive = (v.priority == -1) and 'Inactive' or 'Shadowed'
        a:append(self:get_font_color('comment'))

        if comment ~= "" then
            a:append(comment .. '\\h')
        end

        a:append(key .. '\\h(' .. why_inactive .. ')' .. '\\h' .. cmd)
        return a.text
    end

    if comment ~= "" then
        a:append(self:get_font_color('default'))
        a:append(comment .. '\\h')
    end

    a:append(self:get_font_color('accent'))
    a:append(key)
    a:append(self:get_font_color('comment'))
    a:append(' ' .. cmd)
    return a.text
end

mp.register_script_message("show-command-palette", function (name)
    menu_content.list = {}
    menu_content.current_i = 1
    menu.search_heading = first_to_upper(name)
    menu.filter_by_fields = { "content" }
    em.get_line = original_get_line_func

    if name == "bindings" then
        local bindings = utils.parse_json(mp.get_property("input-bindings"))

        for _, v in ipairs(bindings) do
            v.key = "(" .. v.key .. ")"

            if not is_empty(v.comment) then
                v.comment = first_to_upper(v.comment)
            end
        end

        for _, v in ipairs(bindings) do
            for _, v2 in ipairs(bindings) do
                if v.key == v2.key and v.priority < v2.priority then
                    v.priority = -2
                    break
                end
            end
        end

        table.sort(bindings, function(i, j)
            return i.priority > j.priority
        end)

        menu_content.list = bindings

        function menu:submit(val)
            mp.command(val.cmd)
        end

        menu.filter_by_fields = {'cmd', 'key', 'comment'}
        em.get_line = binding_get_line
    elseif name == "chapters" then
        local count = mp.get_property("chapter-list/count")
        if count == 0 then return end

        for i = 0, count do
            local title = mp.get_property("chapter-list/" .. i .. "/title")

            if title then
                table.insert(menu_content.list, { index = i + 1, content = title })
            end
        end

        menu_content.current_i = mp.get_property_number("chapter") + 1

        function menu:submit(val)
            mp.set_property_number("chapter", val.index - 1)
        end
    elseif name == "playlist" then
        local count = mp.get_property_number("playlist-count")
        if count == 0 then return end

        for i = 0, (count - 1) do
            local text = mp.get_property("playlist/" .. i .. "/title")

            if text == nil then
                text = file_name(mp.get_property("playlist/" .. i .. "/filename"))
            end

            table.insert(menu_content.list, { index = i + 1, content = text })
        end

        menu_content.current_i = mp.get_property_number("playlist-pos") + 1

        function menu:submit(val)
            mp.set_property_number("playlist-pos", val.index - 1)
        end
    elseif name == "commands" then
        local commands = utils.parse_json(mp.get_property("command-list"))

        for k, v in ipairs(commands) do
            local text = v.name

            for _, arg in ipairs(v.args) do
                if arg.optional then
                    text = text .. " [<" .. arg.name .. ">]"
                else
                    text = text .. " <" .. arg.name .. ">"
                end
            end

            table.insert(menu_content.list, { index = k, content = text })
        end

        function menu:submit(val)
            print(val.content)
            local cmd = string.match(val.content, '%S+')
            mp.commandv("script-message-to", "console", "type", cmd .. " ")
        end
    elseif name == "properties" then
        local properties = split(mp.get_property("property-list"), ",")

        for k, v in ipairs(properties) do
            table.insert(menu_content.list, { index = k, content = v })
        end

        function menu:submit(val)
            mp.commandv('script-message-to', 'console', 'type', "print-text ${" .. val.content .. "}")
        end
    elseif name == "options" then
        local options = split(mp.get_property("options"), ",")

        for k, v in ipairs(options) do
            local type = mp.get_property_osd("option-info/" .. v .. "/type", "")
            local default =mp.get_property_osd("option-info/" .. v .. "/default-value", "")
            v = v .. "   (type: " .. type .. ", default: " .. default .. ")"
            table.insert(menu_content.list, { index = k, content = v })
        end

        function menu:submit(val)
            print(val.content)
            local prop = string.match(val.content, '%S+')
            mp.commandv("script-message-to", "console", "type", "set " .. prop .. " ")
        end
    elseif name == "audio" then
        local tracks = split(get_media_info() .. "\nA: None", "\n")
        local id = 0

        for _, v in ipairs(tracks) do
            if starts_with(v, "A: ") then
                id = id + 1
                table.insert(menu_content.list, { index = id, content = string.sub(v, 4) })
            end
        end

        menu_content.current_i = mp.get_property_number("aid") or id

        function menu:submit(val)
            mp.command("set aid " .. ((val.index == id) and 'no' or val.index))
        end
    elseif name == "subtitle" then
        local tracks = split(get_media_info() .. "\nS: None", "\n")
        local id = 0

        for _, v in ipairs(tracks) do
            if starts_with(v, "S: ") then
                id = id + 1
                table.insert(menu_content.list, { index = id, content = string.sub(v, 4) })
            end
        end

        menu_content.current_i = mp.get_property_number("sid") or id

        function menu:submit(val)
            mp.command("set sid " .. ((val.index == id) and 'no' or val.index))
        end
    elseif name == "video" then
        local tracks = split(get_media_info() .. "\nV: None", "\n")
        local id = 0

        for _, v in ipairs(tracks) do
            if starts_with(v, "V: ") then
                id = id + 1
                table.insert(menu_content.list, { index = id, content = string.sub(v, 4) })
            end
        end

        menu_content.current_i = mp.get_property_number("vid") or id

        function menu:submit(val)
            mp.command("set vid " .. ((val.index == id) and 'no' or val.index))
        end
    elseif name == "profiles" then
        local profiles = utils.parse_json(mp.get_property("profile-list"))
        local ignore_list = {"builtin-pseudo-gui", "encoding", "libmpv", "pseudo-gui", "default"}

        for k, v in ipairs(profiles) do
            if not list_contains(ignore_list, v.name) then
                table.insert(menu_content.list, { index = k, content = v.name })
            end
        end

        function menu:submit(val)
            mp.command("show-text " .. val.content);
            mp.command("apply-profile " .. val.content);
        end
    else
        msg.error("Unknown mode " .. name)
        return
    end

    if is_empty(mp.get_property("path")) then
        osc_visibility = utils.shared_script_property_get("osc-visibility")

        if osc_visibility then
            mp.command("script-message osc-visibility never no_osd")
        end
    else
        osc_visibility = nil
    end

    menu:init(menu_content)
end)
