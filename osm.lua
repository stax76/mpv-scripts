
--[[

Shows a customizable on screen menu,
which is useful to navigate via remote control.

Usage:
1. Define menus at: ~~/script-opts/osm-menu.conf

osm-menu.conf example:

[main]
Write watch later config = write-watch-later-config
Power = script-message-to osm show-menu power

[power]
Shutdown = run shutdown.exe -f -s
Sleep    = run powershell.exe -Command "[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');[Windows.Forms.Application]::SetSuspendState('Suspend',$false,$false)"


2. Add a binding to your input.conf file:
CTRL+M script-message-to osm show-menu main

3. Show the menu and navigate it with the keys:
LEFT   Close the menu
RIGHT  Invoke the selection
UP     Move the selection up
DOWN   Move the selection down
ENTER  Invoke the selection
SPACE  Invoke the selection
BS     Close the menu
ESC    Close the menu

4. Optionally define options at: ~~/script-opts/osm.conf

# Spaces before and after the
# equal sign or not allowed.
font_scale=90
border_size=1.0
# BGR
highlight_color=00ccff
cursor_icon="➜"
indent_icon="\h\h\h"

]]

function string_contains(value, find)
    return value:find(find, 1, true)
end

-- ini reader from: https://forum.rainmeter.net/viewtopic.php?t=38190
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

menus = {}
bindings = {}
selected_index = 1

local o = {
    font_scale = 90,
    border_size = 1.0,
    -- BGR
    highlight_color = "00ccff",
    cursor_icon = "➜",
    indent_icon = [[\h\h\h]],
}

(require "mp.options").read_options(o)

function show(name)
    mp.command("script-message osc-idlescreen no no_osd")

    active_menu = menus[name]

    if active_menu == nil then
        print(name .. ' is unknown.')
        return nil
    end

    close()
    add_bindings()
    draw()
end

function draw()
    local text = string.format("{\\fscx%f}{\\fscy%f}{\\bord%f}", o.font_scale, o.font_scale, o.border_size)
    text = text .. '\\N\\N'
    local hi_start = string.format("{\\1c&H%s}", o.highlight_color)
    local hi_end = "{\\1c&HFFFFFF}"

    for index, value in ipairs(active_menu) do
        local name = value[1]

        if index == selected_index then
            text = text .. hi_start .. ' ' .. o.cursor_icon .. ' ' .. name .. hi_end .. "\\N"
        else
            text = text .. ' ' .. o.indent_icon .. ' ' .. name .. "\\N"
        end
    end

    mp.set_osd_ass(0, 0, text)
end

function close()
    selected_index = 1
    mp.set_osd_ass(0, 0, "")
    remove_bindings()
end

function invoke()
    local index = selected_index
    local cmd = active_menu[index][2]

    if not string_contains(cmd, "#no-close") then
        close()
    end
    
    mp.command(cmd)
end

function up()
    selected_index = selected_index - 1

    if selected_index < 1 then
        selected_index = #active_menu
    end

    draw()
end

function down()
    selected_index = selected_index + 1

    if selected_index > #active_menu then
        selected_index = 1
    end

    draw()
end

function get_bindings()
    return {
        { 'LEFT',  close },
        { 'RIGHT', invoke },
        { 'UP',    up },
        { 'DOWN',  down },
        { 'ENTER', invoke },
        { 'SPACE', invoke },
        { 'BS',    close },
        { 'ESC',   close },
    }
end

function add_bindings()
    if #bindings > 0 then
        return
    end

    local script_name = mp.get_script_name()

    for _, bind in ipairs(get_bindings()) do
        local name = script_name .. "_key_" .. (#bindings + 1)
        bindings[#bindings + 1] = name
        mp.add_forced_key_binding(bind[1], name, bind[2])
    end
end

function remove_bindings()
    if #bindings == 0 then
        return
    end

    for _, name in ipairs(bindings) do
        mp.remove_key_binding(name)
    end

    bindings = {}
end

function show_menu(name)
    show(name)
end

mp.register_script_message("show-menu", show_menu)

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
