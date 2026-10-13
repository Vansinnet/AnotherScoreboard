-- Run from the workspace root: tools/luajit/luajit mods/active/AnotherScoreboard/tests/companion_damage_test.lua
-- Offline regression test: the Skitarii servo skull's shots and flames (reported as ranged)
-- count as companion damage under Other damage, not as the player's ranged damage or hits.
local root = arg and arg[1] or "mods/active/AnotherScoreboard/scripts/mods/AnotherScoreboard/"
local stats_file = arg and arg[2] or (root .. "AnotherScoreboard_stats.lua")
local registered = {}
Utf8 = { upper = string.upper }
table.clear = function(t) for k in pairs(t) do t[k] = nil end end
function get_mod(name) return registered[name] end
function Localize(key) return "L:" .. key end

local scoreboard = { name = "AnotherScoreboard", enabled = true }
function scoreboard:get_name() return self.name end
function scoreboard:is_enabled() return self.enabled end
function scoreboard:original_require(path)
    if path == "scripts/utilities/breed" then
        return { is_minion = function(breed) return breed ~= nil end }
    end
    return {}
end
function scoreboard:io_dofile(path) return dofile(root .. path:match("([^/]+)$") .. ".lua") end
registered.AnotherScoreboard = scoreboard

-- Mocks follow the source contracts: unit_data_system:breed(), health_system
-- max_health()/current_health().
local units = {}
ScriptUnit = {
    has_extension = function(unit, system)
        local u = units[unit]
        return u and u[system]
    end,
}
local function spawn(id, breed_name, max_hp)
    local unit = { id = id }
    local breed = { name = breed_name, display_name = "loc_breed_" .. breed_name }
    units[unit] = {
        unit_data_system = { breed = function() return breed end },
        health_system = { max_health = function() return max_hp end, current_health = function() return max_hp end },
    }
    return unit
end

scoreboard.external_stats = dofile(root .. "AnotherScoreboard_external.lua")
local Stats = dofile(stats_file)
Stats.init()

local checks = 0
local function eq(actual, expected, what)
    checks = checks + 1
    assert(actual == expected, string.format("check %d (%s): expected %s, got %s",
        checks, what, tostring(expected), tostring(actual)))
end
local function value(stat_id, aid)
    local entry = Stats.data_for(stat_id)[aid]
    return entry and entry.value or 0
end
local health = {}
local function hit(aid, profile_name, unit, damage, result, attack_type, weakspot)
    return Stats.handle_attack(aid, profile_name and { name = profile_name }, unit, weakspot or false,
        damage, result, attack_type, health, false)
end

-- 1. Servo skull lasgun shot (minion hit scan, attack_type ranged): companion, not ranged.
Stats.clear()
local poxwalker = spawn(1, "chaos_poxwalker", 1000)
hit("a", "default_companion_servo_skull_lasgun_killshot", poxwalker, 300, "damaged", "ranged", true)
eq(value("damage_dealt", "a"), 300, "skull shot: total damage")
eq(value("ranged_damage", "a"), 0, "skull shot: not ranged damage")
eq(value("other_damage", "a"), 300, "skull shot: other damage")
eq(value("other_companion_damage", "a"), 300, "skull shot: other companion damage")
eq(value("companion_damage", "a"), 300, "skull shot: companion damage (Live Stats)")
eq(value("melee_ranged_hits", "a"), 0, "skull shot: not a player ranged hit")
eq(value("weakspot_ratio_hits", "a"), 0, "skull shot: not in the weakspot ratio")

-- 2. Improved skull shot and skull flamer direct hits (RangedAction, attack_type ranged).
hit("a", "improved_companion_servo_skull_lasgun_killshot", poxwalker, 200, "damaged", "ranged")
hit("a", "companion_servo_skull_flamer", poxwalker, 100, "damaged", "ranged")
eq(value("other_companion_damage", "a"), 600, "improved shot and flamer: other companion damage")
eq(value("ranged_damage", "a"), 0, "improved shot and flamer: not ranged damage")

-- 3. A skull killing blow counts as a companion kill and a total kill.
local gunner = spawn(2, "renegade_gunner", 500)
hit("a", "default_companion_servo_skull_lasgun_killshot", gunner, 500, "died", "ranged")
eq(value("companion_kills", "a"), 1, "skull kill: companion kill")
eq(value("total_kills", "a"), 1, "skull kill: total kill")
eq(value("other_companion_damage", "a"), 1100, "skull kill: other companion damage")

-- 4. The player's own ranged and melee hits are unchanged.
local ogryn = spawn(3, "chaos_ogryn_executor", 5000)
hit("a", "default_lasgun_killshot", ogryn, 400, "damaged", "ranged", true)
hit("a", "default_light_chainsword", ogryn, 250, "damaged", "melee")
eq(value("ranged_damage", "a"), 400, "player shot: ranged damage")
eq(value("melee_damage", "a"), 250, "player swing: melee damage")
eq(value("melee_ranged_hits", "a"), 2, "player hits: counted")
eq(value("weakspot_ratio_hits", "a"), 1, "player weakspot hit: counted")
eq(value("other_companion_damage", "a"), 1100, "player hits: not companion damage")

-- 5. The Arbites dog (attack_type companion_dog) still goes to other companion damage.
hit("b", nil, ogryn, 150, "damaged", "companion_dog")
eq(value("other_companion_damage", "b"), 150, "dog: other companion damage")
eq(value("companion_damage", "b"), 150, "dog: companion damage")
eq(value("melee_ranged_hits", "b"), 0, "dog: not a player hit")

print(string.format("companion_damage_test: %d checks passed", checks))
