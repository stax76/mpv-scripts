
-- Allows to invoke commands with suppressed OSD
-- Example:
-- Ctrl+F script-message-to silent_invoke silent-invoke script-message osc-idlescreen no

function restore_osd_level()
    mp.set_property_number("osd-level", osd_level)
end

function silent_2_sec()
    osd_level = mp.get_property_number("osd-level")
    mp.set_property_number("osd-level", 0)
    mp.add_timeout(2, restore_osd_level)
end

function client_message(event)
    if event.args[1] == "silent-invoke" then
        silent_2_sec()
        table.remove(event.args, 1)
        mp.command_native(event.args)
    end
end

mp.register_event("client-message", client_message)
