
--[[
    When seeking displays position and duration like
    so: 70:00 / 80:00, which is different from most
    players which use: 01:10:00 / 01:20:00.
    In input.conf set the input command prefix
    no-osd infront of the seek command.
]]--

function round(value)
    return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

function add_zero(value)
    local value = round(value)

    if value > 9 then
        return "" .. value
    else
        return "0" .. value
    end
end

function format(value)
    local seconds = round(value)

    if seconds < 0 then
        seconds = 0
    end

    local pos_min_floor = math.floor(seconds / 60)
    local sec_rest = seconds - pos_min_floor * 60

    return add_zero(pos_min_floor) .. ":" .. add_zero(sec_rest)
end

function seek(event)
    local position = mp.get_property_number("time-pos")
    local duration = mp.get_property_number("duration")

    if position > duration then
        position = duration
    end

    if position ~= 0 then
        mp.commandv("show-text", format(position) .. " / " .. format(duration))
    end
end

mp.register_event("seek", seek)
