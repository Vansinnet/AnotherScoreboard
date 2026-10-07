-- Run from the workspace root: tools/luajit/luajit mods/active/AnotherScoreboard/tests/boss_finalize_test.lua
-- Offline regression test: a boss killed once must count once, whatever order
-- the death and the killing blow's attack report arrive in.
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
-- max_health()/current_health(), boss_system:display_name().
local units = {}
ScriptUnit = {
    has_extension = function(unit, system)
        local u = units[unit]
        return u and u[system]
    end,
}
local function spawn_boss(id, breed_name, max_hp)
    local unit = { id = id }
    local breed = { name = breed_name, display_name = "loc_breed_" .. breed_name }
    units[unit] = {
        unit_data_system = { breed = function() return breed end },
        health_system = { max_health = function() return max_hp end, current_health = function() return max_hp end },
        boss_system = { display_name = function() return "loc_boss_" .. breed_name end },
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
local function boss_row(breed_name)
    for _, section in ipairs(Stats.sections()) do
        for _, row in ipairs(section.rows) do
            if row.id == "boss_damage_type_" .. breed_name then return row end
        end
    end
end
local function hit(aid, unit, damage, result)
    return Stats.handle_attack(aid, nil, unit, false, damage, result, "ranged", {}, false)
end

-- 1. Death seen before the killing blow's attack report (the Prophet of Decay case).
Stats.clear()
local wizard = spawn_boss(1, "renegade_wizard", 1000)
eq(hit("a", wizard, 600, "damaged"), nil, "no popup while alive")
local popup = Stats.finalize_boss_encounter(wizard) -- MinionDeathManager.set_dead
eq(popup and popup.total_damage, 600, "popup at death")
eq(hit("b", wizard, 400, "died"), nil, "late killing blow gives no second popup")
local row = boss_row("renegade_wizard")
eq(row and row.count, 1, "late killing blow does not count a second boss")
eq(row.values.a.value + row.values.b.value, 1000, "killing blow stays on the boss row")

-- 2. Normal order, then a stray report on the dead boss.
Stats.clear()
local ogryn = spawn_boss(2, "chaos_plague_ogryn", 500)
hit("a", ogryn, 300, "damaged")
popup = hit("a", ogryn, 200, "died")
eq(popup and popup.total_damage, 500, "popup on killing blow")
eq(Stats.finalize_boss_encounter(ogryn), nil, "set_dead after the report gives no second popup")
hit("b", ogryn, 0, "damaged")
eq(boss_row("chaos_plague_ogryn").count, 1, "stray report after death does not count a second boss")

-- 3. The count is kills: a second boss of the type counts only when it dies.
Stats.clear()
local first, second = spawn_boss(3, "chaos_spawn", 800), spawn_boss(4, "chaos_spawn", 800)
hit("a", first, 800, "died")
hit("a", second, 100, "damaged")
eq(boss_row("chaos_spawn").count, 1, "a damaged boss that is still alive is not counted")
eq(boss_row("chaos_spawn").values.a.value, 900, "damage to the living boss stays on the row")
Stats.finalize_boss_encounter(second) -- MinionDeathManager.set_dead
eq(boss_row("chaos_spawn").count, 2, "two kills count twice")

-- 4. A boss that is hit but never dies (a Daemonhost that leaves despawns without set_dead).
Stats.clear()
local host = spawn_boss(5, "chaos_daemonhost", 40000)
hit("a", host, 0, "damaged")
hit("b", host, 50, "damaged")
eq(boss_row("chaos_daemonhost").count, 0, "a boss that never dies is not counted")
local snapshot = Stats.export_active_run()
eq(snapshot.boss_damage_by_type.chaos_daemonhost and snapshot.boss_damage_by_type.chaos_daemonhost.count, 0,
    "a row with no kills survives export")
eq(Stats.import_active_run(snapshot), true, "a row with no kills imports")
eq(boss_row("chaos_daemonhost").values.b.value, 50, "imported damage kept")

print("boss_finalize_test: " .. checks .. " checks passed")
