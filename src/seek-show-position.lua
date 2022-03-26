
-- When seeking displays position and duration like so: 70:00 / 80:00
-- Which is different from most players which use: 01:10:00 / 01:20:00
-- In input.conf set the input command prefix no-osd infront of the seek command.

function Round(value)
    return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

function AddZero(value)
    local value = Round(value)

    if value > 9 then
        return "" .. value
    else
        return "0" .. value
    end
end

function Format(value)
    local seconds = Round(value)

    if seconds < 0 then
        seconds = 0
    end

    PosMinFloor = math.floor(seconds / 60)
    SecRest = seconds - PosMinFloor * 60

    return AddZero(PosMinFloor) .. ":" .. AddZero(SecRest)
end

function Seek(event)
    Position = mp.get_property_number("time-pos")
    Duration = mp.get_property_number("duration")

    if Position > Duration then
        Position = Duration
    end

    mp.commandv("show-text", Format(Position) .. " / " .. Format(Duration))
end

mp.register_event("seek", Seek)
