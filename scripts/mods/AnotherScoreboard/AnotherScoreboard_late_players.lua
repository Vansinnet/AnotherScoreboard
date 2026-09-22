local LatePlayers = {}
local WINDOW = 30

function LatePlayers.remember(departures, player, left_at)
    if not player or not player.is_human or not player.slot then return end

    local previous = departures[player.slot]
    if previous and previous.left_at > left_at then return end

    for _, entry in pairs(departures) do
        if entry.player.account_id == player.account_id and entry.left_at > left_at then return end
    end
    for slot, entry in pairs(departures) do
        if entry.player.account_id == player.account_id or left_at - entry.left_at > WINDOW then
            departures[slot] = nil
        end
    end

    departures[player.slot] = { player = player, left_at = left_at }
end

function LatePlayers.merge(departures, saved)
    if departures == saved then return departures end
    for _, entry in pairs(saved or {}) do
        LatePlayers.remember(departures, entry.player, entry.left_at)
    end
    return departures
end

function LatePlayers.resolve(departures, players, now)
    local result = {}
    local present = {}
    local slots = {}

    for _, player in ipairs(players) do
        if not player.is_human or not present[player.account_id] then
            result[#result + 1] = player
            present[player.account_id] = true
            if player.slot then slots[player.slot] = #result end
        end
    end

    for slot, entry in pairs(departures) do
        local age = now - entry.left_at
        local player = entry.player
        local index = slots[slot]
        local occupant = index and result[index]
        if age >= 0 and age <= WINDOW and not present[player.account_id]
                and (not occupant or not occupant.is_human) then
            local record = {}
            for key, value in pairs(player) do record[key] = value end
            record.left_near_end = true
            result[index or #result + 1] = record
            present[player.account_id] = true
        end
    end

    return result
end

return LatePlayers
