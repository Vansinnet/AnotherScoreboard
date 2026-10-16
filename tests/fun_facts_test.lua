-- Run from the workspace root: tools/luajit/luajit mods/active/AnotherScoreboard/tests/fun_facts_test.lua
-- Offline test: the Fun Facts (Beta) rows (hits that cost HP, highest single hit, teammates hurt),
-- their saving, rejoin merging and Live Stats choices.
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
local function hit(aid, profile_name, unit, damage, result, attack_type)
    return Stats.handle_attack(aid, profile_name and { name = profile_name }, unit, false,
        damage, result, attack_type, health, false)
end
local attacked = Stats.handle_player_attacked

-- 1. Hits that cost HP: health or corruption damage from a direct attack; toughness and ticks do not count.
Stats.clear()
attacked(nil, "b", 40, "damaged", "melee")
attacked(nil, "b", 0, "toughness_absorbed_melee", "melee")
attacked(nil, "b", 0, "toughness_broken", "ranged")
attacked(nil, "b", 25, "toughness_broken", "ranged") -- spill past broken toughness
attacked(nil, "b", 12, "damaged", nil)    -- fire patch or gas tick
attacked(nil, "b", 12, "damaged", "buff") -- buff damage tick
attacked(nil, "b", 0, "dodged", "melee")
attacked(nil, "b", 90, "knock_down", "explosion")
attacked(nil, "b", 30, "damaged", "incapacitating_pounce")
eq(value("hits_taken", "b"), 4, "hits that cost HP")

-- 2. Teammates hurt: health or toughness damage on another player; no damage, self and ticks do not count.
attacked("a", "b", 60, "damaged", "explosion")          -- barrel
attacked("a", "c", 0, "toughness_absorbed", "explosion") -- barrel on toughness
attacked("a", "c", 0, "friendly_fire", "ranged")         -- a shot through a teammate deals nothing
attacked("a", "a", 50, "damaged", "explosion")          -- own barrel
attacked("a", "b", 8, "damaged", nil)                    -- the fire barrel's burning area
attacked("c", "b", 0, "toughness_broken", "explosion")  -- poxburster credited to its pusher
eq(value("teammates_hurt", "a"), 2, "teammates hurt by a")
eq(value("teammates_hurt", "c"), 1, "teammates hurt by c")
eq(value("teammates_hurt", "b"), 0, "the victim is not credited")
eq(value("hits_taken", "b"), 5, "a teammate's barrel is also a hit that cost HP")
eq(value("hits_taken", "a"), 1, "an own barrel is a hit that cost HP")

-- 3. Highest single hit: the player's own melee or ranged hit on an enemy, overkill included.
local crusher = spawn(1, "chaos_ogryn_executor", 50000)
local poxwalker = spawn(2, "chaos_poxwalker", 200)
hit("a", "light_sword", crusher, 300, "damaged", "melee")
hit("a", "lasgun_killshot", crusher, 900, "damaged", "ranged")
hit("a", "heavy_sword", crusher, 500, "damaged", "melee")
eq(value("highest_hit", "a"), 900, "highest of melee and ranged")
hit("a", "heavy_hammer", poxwalker, 1500, "died", "melee")
eq(value("highest_hit", "a"), 1500, "overkill counts")
eq(value("damage_dealt", "a") - 1700, 200, "damage dealt still capped at health")
hit("a", "default_companion_servo_skull_lasgun_killshot", crusher, 5000, "damaged", "ranged")
hit("a", "frag_grenade", crusher, 4000, "damaged", "explosion")
hit("a", "push", crusher, 3000, "damaged", "push")
hit("a", "light_sword", crusher, 0, "blocked", "melee")
eq(value("highest_hit", "a"), 1500, "companion, explosion, push and blocked hits do not count")

-- 4. Every displayed player gets an entry.
Stats.ensure_entries({ a = true, b = true })
eq(Stats.data_for("highest_hit").b ~= nil, true, "highest hit entry for a player without data")
eq(Stats.data_for("teammates_hurt").b ~= nil, true, "teammates hurt entry for a player without data")

-- 5. The section and its saved rows.
local section
for _, s in ipairs(Stats.sections()) do
    if s.category.key == "fun_facts" then section = s end
end
eq(section and section.category.label, "cat_fun_facts", "fun facts section")
eq(#section.rows, 3, "fun facts row count")
eq(section.rows[1].id .. "," .. section.rows[2].id .. "," .. section.rows[3].id,
    "hits_taken,highest_hit,teammates_hurt", "row order")
for i = 1, 3 do
    eq(section.rows[i].style, "sub", section.rows[i].id .. " uses the detail row size")
end
local saved_rows = {}
for _, s in ipairs(Stats.snapshot_sections({ a = true, b = true })) do
    for _, r in ipairs(s.rows) do saved_rows[r.id] = r end
end
eq(saved_rows.highest_hit.values.a.score, 1500, "saved highest hit")
eq(saved_rows.teammates_hurt.values.b.score, 0, "saved zero for a player without data")

-- 6. Rejoin: a merged run keeps the higher highest hit and adds the counts.
local run = Stats.export_active_run()
Stats.clear()
hit("a", "light_sword", crusher, 1200, "damaged", "melee")
hit("b", "light_sword", crusher, 700, "damaged", "melee")
attacked(nil, "b", 10, "damaged", "melee")
eq(Stats.merge_active_run(run), true, "merge imports")
eq(value("highest_hit", "a"), 1500, "merge keeps the saved higher hit")
eq(value("highest_hit", "b"), 700, "merge keeps the current hit without a saved one")
eq(value("hits_taken", "b"), 6, "merge adds hits")
run = Stats.export_active_run()
Stats.clear()
hit("a", "light_sword", crusher, 2500, "damaged", "melee")
eq(Stats.merge_active_run(run), true, "second merge imports")
eq(value("highest_hit", "a"), 2500, "merge keeps the current higher hit")
run.stats.highest_hit = nil
run.stats.hits_taken = nil
run.stats.teammates_hurt = nil
Stats.clear()
eq(Stats.import_active_run(run), true, "a run saved before Fun Facts imports")
eq(value("highest_hit", "a"), 0, "no highest hit for an old run")

-- 7. Live Stats: the three rows are selectable, and every catalog stat exists.
local live_stats = dofile(root .. "AnotherScoreboard_live_stats.lua")
local live_by_key = {}
for _, stat in ipairs(live_stats) do
    live_by_key[stat.key] = stat
    for _, field in ipairs({ "stat_id", "numerator_stat_id", "denominator_stat_id", "per_second_stat_id" }) do
        if stat[field] then
            eq(Stats.data_for(stat[field]) ~= nil, true, "live stat " .. stat.key .. " " .. field .. " exists")
        end
    end
end
eq(#live_stats, 43, "live stat count")
eq(live_by_key.hits_taken.stat_id .. "," .. live_by_key.highest_hit.stat_id .. "," .. live_by_key.teammates_hurt.stat_id,
    "hits_taken,highest_hit,teammates_hurt", "fun facts live stats")

print(string.format("fun_facts_test: %d checks passed", checks))
