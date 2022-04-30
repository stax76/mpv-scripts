
-- Shows a customizable on screen menu,
-- which is useful to navigate via remote control.

-- Usage:
-- 1. Define the menu directly in the script
-- 2. Add a binding to your input.conf file:
--    M script-message-to osm show-menu root
-- 3. Show the menu and navigate it with the keys:
--    LEFT   Close the menu
--    RIGHT  Invoke the selection
--    UP     Move the selection up
--    DOWN   Move the selection down
--    ENTER  Invoke the selection
--    SPACE  Invoke the selection
--    BS     Close the menu
--    ESC    Close the menu


menus = {}

-- Define as many menus and nested sub menus as you want.

--                 Caption            Input command
menus['root'] = {{'Test 1',          'show-text "value 1"'},
                 {'Test 2',          'show-text "value 2"'},
                 {'Nested Sub Test', 'script-message-to osm show-menu sub'},
}

menus['sub'] = {{'Sub 1', 'show-text "sub value 1"'},
                {'Sub 2', 'show-text "sub value 2"'},
                {'Sub 3', 'show-text "sub value 3"'}
}

bindings = {}
selected_index = 1

function show(name)
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
    local text = ''

    for index, value in ipairs(active_menu) do
        local name = value[1]
        local val = value[2]

        if index == selected_index then
            text = text .. '● ' .. name .. '\n'
        else
            text = text .. '○ ' .. name .. '\n'
        end
    end

    mp.set_property("osd-level", 3)
    mp.set_property("osd-msg3", text)
    mp.command("show-text ''")
end

function close()
    selected_index = 1
    mp.set_property("osd-msg3", "")
    mp.set_property("osd-level", 1)
    remove_bindings()
end

function invoke()
    local index = selected_index
    close()
    local cmd = active_menu[index][2]
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

function client_message(event)
    if event.args[1] == "show-menu" then
        show(event.args[2])
    end
end

mp.register_event("client-message", client_message)
