-- Run from the workspace root: tools/luajit/luajit mods/active/AnotherScoreboard/tests/kill_damage_test.lua
-- Offline test: damage beside enemy kills (category and enemy type), gated by the option.
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
local function hit(aid, unit, damage, result, health)
    return Stats.handle_attack(aid, nil, unit, false, damage, result, "melee", health or {}, false)
end
local function row(stat_id)
    for _, section in ipairs(Stats.sections()) do
        for _, r in ipairs(section.rows) do
            if r.id == stat_id then return r end
        end
    end
end
local function damage(stat_id, aid)
    local values = Stats.kill_damage_values(stat_id)
    return values and values[aid]
end

-- 1. Off (the default): nothing is recorded and no values are offered.
Stats.clear()
local hound = spawn_boss(1, "chaos_hound", 700)
hit("a", hound, 300, "damaged")
eq(Stats.kill_damage_values("specials_killed"), nil, "off: no values")
Stats.set_kill_damage_enabled(true)
eq(damage("specials_killed", "a"), nil, "off: nothing was recorded while off")

-- 2. On: damage goes to the category and the enemy type, including enemies that survive.
Stats.clear()
local gunner = spawn_boss(2, "renegade_gunner", 1000)
local poxwalker = spawn_boss(3, "chaos_poxwalker", 200)
hound = spawn_boss(4, "chaos_hound", 700)
local health = {}
hit("a", gunner, 400, "damaged", health)
hit("b", gunner, 900, "died", health) -- overkill: 600 health left
hit("a", poxwalker, 150, "damaged", health)
hit("a", hound, 0, "damaged", health)
eq(damage("elites_killed", "a"), 400, "elite damage without a kill")
eq(damage("elites_killed", "b"), 600, "killing blow capped at remaining health")
eq(damage("elite_gunner_killed", "b"), 600, "enemy type damage")
eq(damage("lesser_enemies_killed", "a"), 150, "lesser damage on a survivor")
eq(damage("melee_lesser_enemies_killed", "a"), 150, "lesser type damage")
eq(damage("specials_killed", "a"), nil, "zero damage adds nothing")
eq(row("elites_killed").values, nil, "kill row stays a live stat row")

-- 3. Bosses and uncatalogued breeds are not counted.
local spawn = spawn_boss(5, "chaos_spawn", 5000)
local unknown = spawn_boss(6, "some_new_breed", 100)
hit("a", spawn, 1000, "damaged", health)
hit("a", unknown, 50, "damaged", health)
eq(damage("elites_killed", "a"), 400, "boss damage not added")
eq(damage("lesser_enemies_killed", "a"), 150, "unknown breed not added")
eq(Stats.kill_damage_values("total_kills"), nil, "total kills has no damage")

-- 4. Saved scoreboards and rejoin data carry the damage.
local snapshot_sections = Stats.snapshot_sections({ a = true, b = true })
local saved_row
for _, section in ipairs(snapshot_sections) do
    for _, r in ipairs(section.rows) do
        if r.id == "elites_killed" then saved_row = r end
    end
end
eq(saved_row and saved_row.damage_values and saved_row.damage_values.b, 600, "history row has damage")
eq(saved_row.damage_values.a, 400, "history row damage for each player")
local run = Stats.export_active_run()
Stats.clear()
eq(Stats.import_active_run(run), true, "export imports")
eq(damage("elite_gunner_killed", "b"), 600, "rejoin keeps damage")
run.stats.elites_killed_damage = nil
eq(Stats.import_active_run(run), true, "a run saved before this option imports")
eq(damage("elites_killed", "b"), nil, "no damage for an old run")

-- 5. Off again: snapshots carry no damage.
Stats.set_kill_damage_enabled(false)
snapshot_sections = Stats.snapshot_sections({ a = true })
for _, section in ipairs(snapshot_sections) do
    for _, r in ipairs(section.rows) do
        if r.id == "elites_killed" then saved_row = r end
    end
end
eq(saved_row.damage_values, nil, "off: history rows carry no damage")

print("kill_damage_test: " .. checks .. " checks passed")
