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
-- Replicated health percent per unit (husk_health_extension.lua:47-55); 1 unless a test sets it.
local health_percent = {}
local function spawn_boss(id, breed_name, max_hp, has_scripted_death_sequence)
    local unit = { id = id }
    local breed = { name = breed_name, display_name = "loc_breed_" .. breed_name,
        has_scripted_death_sequence = has_scripted_death_sequence }
    units[unit] = {
        unit_data_system = { breed = function() return breed end },
        health_system = { max_health = function() return max_hp end, current_health = function() return max_hp end,
            current_health_percent = function() return health_percent[unit] or 1 end },
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

-- 5. Since Darktide 1.13.3 the Prophet of Decay's killing blow reports "damaged" (attack.lua:539-541)
-- and set_dead never runs for it, so the kill is read from its health. on_death does what the
-- set_dead hook does (AnotherScoreboard.lua, _record_enemy_death).
local alive = {}
Unit = { alive = function(unit) return alive[unit] == true end }
local deaths, popups = 0, {}
local function on_death(unit, aid)
    deaths = deaths + 1
    Stats.record_kill_from_death(unit, aid)
    local result = Stats.finalize_boss_encounter(unit)
    if result then popups[#popups + 1] = result end
end
local function kills(aid)
    local entry = Stats.data_for("total_kills")[aid]
    return entry and entry.value or 0
end

Stats.clear()
local prophet = spawn_boss(6, "renegade_wizard", 1000, true)
alive[prophet] = true
hit("a", prophet, 600, "damaged")
hit("b", prophet, 0, "damaged")
health_percent[prophet] = 0.4
Stats.update_scripted_deaths(on_death)
eq(deaths, 0, "living Prophet is not a kill")
hit("b", prophet, 400, "damaged")
health_percent[prophet] = 0
hit("c", prophet, 0, "damaged")
Stats.update_scripted_deaths(on_death)
eq(deaths, 1, "Prophet at zero health is a kill")
eq(kills("b"), 1, "kill goes to the last player who dealt damage")
eq(kills("c"), 0, "a hit without damage takes no kill")
eq(kills("a"), 0, "earlier damage takes no kill")
eq(#popups, 1, "one boss popup")
eq(popups[1].total_damage, 1000, "popup has the whole fight's damage")
eq(boss_row("renegade_wizard").count, 1, "boss row counts the kill")
Stats.update_scripted_deaths(on_death)
eq(deaths, 1, "the kill fires once")
on_death(prophet, "a") -- a later set_dead
eq(kills("a") + kills("b"), 1, "a later set_dead adds no kill")
eq(#popups, 1, "a later set_dead adds no popup")
eq(boss_row("renegade_wizard").count, 1, "a later set_dead adds no boss")
deaths = 0
hit("a", prophet, 50, "damaged")
Stats.update_scripted_deaths(on_death)
eq(deaths, 0, "a hit after the kill is not watched again")

-- A "died" report on such a breed still counts once and ends the watch.
Stats.clear()
deaths = 0
local twin = spawn_boss(7, "renegade_wizard", 1000, true)
alive[twin] = true
hit("a", twin, 600, "damaged")
hit("a", twin, 400, "died")
health_percent[twin] = 0
Stats.update_scripted_deaths(on_death)
eq(deaths, 0, "no second kill after a died report")
eq(kills("a"), 1, "died report counts once")

-- A Prophet that despawns, a cleared watch and a breed without the flag never give a kill.
Stats.clear()
deaths = 0
local gone = spawn_boss(8, "renegade_wizard", 1000, true)
alive[gone] = true
hit("a", gone, 100, "damaged")
alive[gone] = nil
Stats.update_scripted_deaths(on_death)
alive[gone] = true
health_percent[gone] = 0
Stats.update_scripted_deaths(on_death)
eq(deaths, 0, "a despawned unit is dropped")
local cleared = spawn_boss(9, "renegade_wizard", 1000, true)
alive[cleared] = true
hit("a", cleared, 100, "damaged")
Stats.clear_scripted_deaths() -- mission exit
health_percent[cleared] = 0
Stats.update_scripted_deaths(on_death)
eq(deaths, 0, "mission exit clears the watch")
local plain = spawn_boss(10, "chaos_beast_of_nurgle", 1000)
alive[plain] = true
hit("a", plain, 100, "damaged")
health_percent[plain] = 0
Stats.update_scripted_deaths(on_death)
eq(deaths, 0, "other bosses wait for died or set_dead")

print("boss_finalize_test: " .. checks .. " checks passed")
