local root = "mods/active/AnotherScoreboard/scripts/mods/AnotherScoreboard/"
local checks = 0
local function eq(actual, expected, message)
    checks = checks + 1
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message or "check", tostring(expected), tostring(actual)), 2)
    end
end

table.clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end

local now = 0
local echoes = {}
local mod = {
    info = function() end,
    echo = function(_, line) echoes[#echoes + 1] = line end,
}
function get_mod() return mod end

Managers = {
    time = { has_timer = function() return true end, time = function() return now end },
    state = { player_unit_spawn = { owner = function(_, unit) return unit and unit.owner end } },
}
Unit = {
    alive = function(unit) return unit ~= nil end,
    world_position = function(unit) return unit.pos end,
}
Vector3 = { distance = function(a, b) return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2) end }

local function player(aid, talents)
    local p = { player_unit = { pos = { 0, 0 } } }
    p.player_unit.owner = p
    function p:account_id() return aid end
    function p:name() return aid end
    function p:profile() return { talents = talents or {} } end
    return p
end

local function unit_data(in_progress, local_unit, force_assist)
    return {
        has_component = function() return true end,
        read_component = function() return { in_progress = in_progress, force_assist = force_assist } end,
        is_local_unit = function() return local_unit end,
    }
end

local Observer = dofile(root .. "AnotherScoreboard_forced_assist.lua")
local skitarii = player("skitarii")
local veteran = player("veteran", { veteran_combat_ability_revive_nearby_allies = 1 })
local plain_veteran = player("plain_veteran")
local downed = player("downed")
Observer.set_players({ skitarii, veteran, plain_veteran, downed })

local recorded = {}
Observer.set_recorder(function(kind, aid)
    recorded[kind .. ":" .. aid] = (recorded[kind .. ":" .. aid] or 0) + 1
end)
local function tally(kind, aid)
    return recorded[kind .. ":" .. aid] or 0
end

local function step(dt)
    now = now + dt
    Observer.update()
end

-- 1. Servo skull revives a knocked-down husk.
local skull = { owner = skitarii, pos = { 1, 0 } }
Observer.sample(downed.player_unit, downed, "knocked_down", unit_data(false, false))
step(0.5)
Observer.on_effect_started("companion_servo_skull_heal_effect", skull)
step(1.0)
Observer.sample(downed.player_unit, downed, "knocked_down", unit_data(true, false))
step(1.5)
Observer.sample(downed.player_unit, downed, "walking", unit_data(false, false))
step(0.6)
eq(tally("revives_and_rescues", "skitarii"), 1, "skull revive credited to owner")

-- 2. A player revive is not credited even if the Veteran shouted nearby.
Observer.sample(downed.player_unit, downed, "knocked_down", unit_data(false, false))
step(1)
Observer.on_interaction_started(downed.player_unit)
Observer.on_ability_used(veteran, "veteran", now)
Observer.sample(downed.player_unit, downed, "knocked_down", unit_data(true, false))
step(2)
Observer.sample(downed.player_unit, downed, "walking", unit_data(false, false))
step(0.1)
Observer.on_interaction_success(downed.player_unit) -- RPC after the state change
step(0.6)
eq(tally("revives_and_rescues", "veteran"), 0, "interaction revive not credited to veteran")

-- 3. Veteran shout with the talent revives; a Veteran without it is ignored.
Observer.sample(downed.player_unit, downed, "knocked_down", unit_data(false, false))
step(1)
Observer.on_ability_used(plain_veteran, "plain_veteran", now)
Observer.on_ability_used(veteran, "veteran", now)
step(0.1)
Observer.sample(downed.player_unit, downed, "knocked_down", unit_data(true, false))
step(1.5)
Observer.sample(downed.player_unit, downed, "walking", unit_data(false, false))
step(0.6)
eq(tally("revives_and_rescues", "veteran"), 1, "shout revive credited")
eq(tally("revives_and_rescues", "plain_veteran"), 0, "veteran without talent ignored")

-- 4. Skull frees a netted player: disabled help, not a revive.
Observer.sample(downed.player_unit, downed, "netted", unit_data(false, false))
step(0.5)
Observer.on_effect_started("companion_servo_skull_heal_effect", skull)
step(2.5)
Observer.sample(downed.player_unit, downed, "walking", unit_data(false, false))
step(0.6)
eq(tally("disabled_helped", "skitarii"), 1, "skull net release is disabled help")
eq(tally("revives_and_rescues", "skitarii"), 1, "net release not counted as revive")

-- 5. Unexplained recovery and death are never credited.
Observer.sample(downed.player_unit, downed, "knocked_down", unit_data(false, false))
step(10)
Observer.sample(downed.player_unit, downed, "dead", unit_data(false, false))
step(0.6)
Observer.sample(downed.player_unit, downed, "hogtied", unit_data(false, false))
step(3)
Observer.sample(downed.player_unit, downed, "walking", unit_data(false, false))
step(0.6)
eq(tally("revives_and_rescues", "skitarii"), 1, "no credit without evidence")
eq(tally("revives_and_rescues", "veteran"), 1, "stale shout not reused")

-- 6. A skull too far away is not matched to the downed player.
local far_skull = { owner = skitarii, pos = { 30, 0 } }
Observer.sample(downed.player_unit, downed, "knocked_down", unit_data(false, false))
Observer.on_effect_started("companion_servo_skull_heal_effect", far_skull)
step(2.5)
Observer.sample(downed.player_unit, downed, "walking", unit_data(false, false))
step(0.6)
eq(tally("revives_and_rescues", "skitarii"), 1, "distant skull not credited")

print("forced_assist_test: " .. checks .. " checks passed")
