
--[[

https://github.com/stax76/mpv-scripts

This script shows a customizable on screen menu.

Some code parts are derived from:

https://github.com/dyphire/mpv-scripts/blob/main/chapter-list.lua


Usage:

Download the following dependency:

https://github.com/CogentRedTester/mpv-scroll-list/blob/master/scroll-list.lua

Save it at: ~~/script-modules/scroll-list.lua


Define menus using INI format at: ~~/script-opts/osm-menu.conf

osm-menu.conf example:

[main]
Quit = quit
Zoom = script-message-to osm show-menu zoom

[zoom]
Zoom In  = add video-zoom  0.1 #keep-open
Zoom Out = add video-zoom -0.1 #keep-open


Add a binding to your input.conf file:
<key> script-message-to osm show-menu main


Show the menu and navigate it with the keys:

Move selection up:   UP, WHEEL_UP
Move selection down: DOWN, WHEEL_DOWN
Invoke selection:    ENTER, RIGHT, SPACE, MBTN_LEFT
Close menu:          LEFT, ESC, BS, MBTN_RIGHT
HOME:                Move selection to top
END:                 Move selection to bottom
PGUP:                Move selection page up
PGDWN:               Move selection page down


Optionally create and configure options at: ~~/script-opts/osm.conf

## https://fileformats.fandom.com/wiki/SubStation_Alpha#Style_overrides
## https://github.com/CogentRedTester/mpv-scroll-list

#header_style={\q2\fs45\c&00ccff&}
#list_style={\q2\fs45\c&Hffffff&}
#selected_style={\c&H00ccff&}
#wrapper_style={\c&00ccff&\fs35}
#cursor=➜\h
#show_header=no
#num_entries=12

#key_move_begin=HOME
#key_move_end=END
#key_move_pageup=PGUP
#key_move_pagedown=PGDWN
#key_scroll_down=DOWN WHEEL_DOWN
#key_scroll_up=UP WHEEL_UP
#key_invoke=ENTER SPACE RIGHT MBTN_LEFT
#key_close=ESC LEFT BS MBTN_RIGHT


If the command contains 'keep-open' in the comment,
the menu stays open after the command is executed.

]]--

----- options

local o = {
    header_style = "{\\q2\\fs45\\c&00ccff&}",
    list_style = "{\\q2\\fs45\\c&Hffffff&}",
    selected_style = "{\\c&H00ccff&}",
    wrapper_style = "{\\c&00ccff&\\fs35}",
    cursor = "➜\\h",
    show_header = false,
    num_entries = 12,

    key_move_begin = "HOME",
    key_move_end = "END",
    key_move_pageup = "PGUP",
    key_move_pagedown = "PGDWN",
    key_scroll_down = "DOWN WHEEL_DOWN",
    key_scroll_up = "UP WHEEL_UP",
    key_invoke = "ENTER SPACE RIGHT MBTN_LEFT",
    key_close = "ESC LEFT BS MBTN_RIGHT",
}

opt = require "mp.options"
opt.read_options(o)

----- string

function contains(value, find)
    return value:find(find, 1, true)
end

----- file

-- https://forum.rainmeter.net/viewtopic.php?t=38190
function read_ini(input_file)
    local file = assert(io.open(input_file, 'r'), 'Unable to open ' .. input_file)
    local tbl = {}
    local section_read_order, key_read_order = {}, {}
    local section = '_default_'
    local num = 0
    tbl[section] = {}
    table.insert(section_read_order, section)
    key_read_order[section] = {}
    for line in file:lines() do
        num = num + 1
        if not line:match('^%s-#') then
            local key, command = line:match('^([^=]-)%s*=%s*(.+)')
            if line:match('^%s-%[.+') then
                section = line:match('^%s-%[([^%]]+)')
                if not tbl[section] then
                    tbl[section] = {}
                    table.insert(section_read_order, section)
                    if not key_read_order[section] then key_read_order[section] = {} end
                end
            elseif key and command and section then
                tbl[section][key:match('^%s*(.+)%s*$')] = command:match('^%s*(.-)%s*$')
                table.insert(key_read_order[section], key)
            end
        end
    end
    file:close()
    local final_table = {}
    final_table['ini'] = tbl
    final_table['section_order'] = section_read_order
    final_table['key_order'] = key_read_order
    return final_table
end

----- osm

menus = {}
lists = {}
msg = require "mp.msg"

local function add_keys(list, keys, name, fn, flags)
    local i = 1

    for key in keys:gmatch("%S+") do
        table.insert(list.keybinds, { key, name .. i, fn, flags })
        i = i + 1
    end
end

function show(name)
    mp.command("script-message osc-idlescreen no no_osd")
    local menu = menus[name]

    if menu == nil then
        msg.error("A menu named '" .. name .. "' does not exist.")
        return
    end

    if lists[name] == nil then
        local list = dofile(mp.command_native({"expand-path", "~~/script-modules/scroll-list.lua"}))

        list.name = name
        list.menu = menu
        list.cursor = o.cursor
        list.list_style = o.list_style
        list.header_style = o.header_style
        list.wrapper_style = o.wrapper_style
        list.selected_style = o.selected_style
        list.num_entries = o.num_entries
        list.list = {}

        function list:invoke()
            local cmd = self.menu[self.selected][2]

            if not contains(cmd, "keep-open") then
                list:close()
            end

            mp.command(cmd)
        end

        if o.show_header then
            list.header = name .. "\\N ----------------------------------------------"
        else
            list.header = "\\N"
        end

        for index, value in ipairs(menu) do
            list.list[index] = { ass = value[1] }
        end

        list.keybinds = {}

        add_keys(list, o.key_scroll_down, 'scroll_down', function() list:scroll_down() end, {repeatable = true})
        add_keys(list, o.key_scroll_up, 'scroll_up', function() list:scroll_up() end, {repeatable = true})
        add_keys(list, o.key_move_pageup, 'move_pageup', function() list:move_pageup() end, {})
        add_keys(list, o.key_move_pagedown, 'move_pagedown', function() list:move_pagedown() end, {})
        add_keys(list, o.key_move_begin, 'move_begin', function() list:move_begin() end, {})
        add_keys(list, o.key_move_end, 'move_end', function() list:move_end() end, {})
        add_keys(list, o.key_invoke, 'invoke', function() list:invoke() end, {})
        add_keys(list, o.key_close, 'close', function() list:close() end, {})

        lists[name] = list
    end

    lists[name]:open()
end

mp.register_script_message("show-menu", function (name)
    show(name)
end)

menu_conf_path = mp.command_native({"expand-path", "~~/script-opts"}) .. "/osm-menu.conf"

ini = read_ini(menu_conf_path)

for k, v in pairs(ini.ini) do
    if k ~= '_default_' then
        menus[k] = {}

        for _, v2 in ipairs(ini.key_order[k]) do
            table.insert(menus[k], { v2, v[v2]})
        end
    end
end
