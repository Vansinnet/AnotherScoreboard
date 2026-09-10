---@type AnotherScoreboardMod
local mod = get_mod("AnotherScoreboard")
local External = mod.external_stats

local pairs              = pairs
local ipairs             = ipairs
local type               = type
local table_clear        = table.clear
local math_max           = math.max
local math_min           = math.min
local math_floor         = math.floor
local math_huge          = math.huge

local ScriptUnit         = ScriptUnit

local Breed = mod:original_require("scripts/utilities/breed")
local EnemyCatalog = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_enemies")

local ENEMY_BY_BREED = {}
local ENEMY_DETAIL_STATS = {}

for _, category in ipairs({ "lesser", "specials", "elites" }) do
    for _, enemy in ipairs(EnemyCatalog[category]) do
        enemy.category = category
        ENEMY_DETAIL_STATS[enemy.stat_id] = true

        for _, breed_name in ipairs(enemy.breeds) do
            ENEMY_BY_BREED[breed_name] = enemy
        end
    end
end

local MELEE_ELITES = {
    cultist_berzerker = true, renegade_berzerker = true, renegade_executor = true,
    chaos_ogryn_bulwark = true, chaos_ogryn_executor = true,
}

local RANGED_ELITES = {
    cultist_gunner = true, renegade_gunner = true,
    cultist_shocktrooper = true, renegade_shocktrooper = true,
    chaos_ogryn_gunner = true, renegade_plasma_gunner = true,
}

local BOSSES = {
    chaos_beast_of_nurgle = true, chaos_daemonhost = true, chaos_spawn = true,
    chaos_plague_ogryn = true, chaos_plague_ogryn_sprayer = true,
    renegade_captain = true, renegade_twin_captain = true, renegade_twin_captain_two = true,
    cultist_captain = true, chaos_mutator_daemonhost = true, chaos_ogryn_houndmaster = true,
}

local TWIN_BREEDS = {
    renegade_twin_captain = true,
    renegade_twin_captain_two = true,
}

local BOSS_GROUP_BY_BREED = {
    chaos_plague_ogryn_sprayer = "chaos_plague_ogryn",
    renegade_captain = "captain",
    cultist_captain = "captain",
}

local BOSS_TYPE_LABELS = {
    captain = "row_boss_captain",
    renegade_twin_captain = "row_boss_twins",
}

local BOSS_BREED_LABELS = {
    chaos_beast_of_nurgle = "row_boss_beast_of_nurgle",
    chaos_daemonhost = "row_boss_daemonhost",
    chaos_spawn = "row_boss_chaos_spawn",
    chaos_plague_ogryn = "row_boss_plague_ogryn",
    renegade_captain = "row_boss_scab_captain",
    cultist_captain = "row_boss_dreg_captain",
    chaos_mutator_daemonhost = "row_boss_hexbound_daemonhost",
    chaos_ogryn_houndmaster = "row_boss_ogryn_houndmaster",
}

local DOT_PROFILES = {
    bleeding = "dot_bleeding_damage",
    burning = "dot_burning_damage",
    flame_grenade_liquid_area_fire_burning = "dot_burning_damage",
    liquid_area_fire_burning_barrel = "dot_burning_damage",
    liquid_area_fire_burning = "dot_burning_damage",
    warpfire = "dot_soulblaze_damage",
    toxin_variant_1 = "dot_toxin_damage",
    toxin_variant_2 = "dot_toxin_damage",
    toxin_variant_3 = "dot_toxin_damage",
    horde_mode_self_propagating_toxin = "dot_toxin_damage",
}

local DOT_DETAIL_STATS = {
    dot_bleeding_damage = true,
    dot_soulblaze_damage = true,
    dot_burning_damage = true,
    dot_toxin_damage = true,
}

local COMPANION_DAMAGE_PROFILES = {
    default_companion_servo_skull_lasgun_killshot = true,
    improved_companion_servo_skull_lasgun_killshot = true,
    companion_servo_skull_flamer = true,
}

local NON_HIT_ATTACK_RESULTS = {
    dodged = true,
    blocked = true,
    shield_blocked = true,
}

local function is_companion_attack(damage_profile, attack_type)
    return attack_type == "companion_dog"
        or damage_profile and COMPANION_DAMAGE_PROFILES[damage_profile.name] == true
end

local Stats = {}

-- Attack reports and the death manager can both report the same kill.
local _killed_units = {}
local _companion_killed_units = {}

local _boss_damage = {}
local _boss_max_health = {}
local _boss_damage_by_type = {}
local _boss_identities = {}

local function _boss_identity(boss_unit, breed)
    local identity = _boss_identities[boss_unit]
    if identity then
        return identity
    end

    local boss_extension = ScriptUnit.has_extension(boss_unit, "boss_system")
    local localization_key = boss_extension and boss_extension:display_name()

    if type(localization_key) ~= "string" or localization_key == "" then
        localization_key = breed.display_name
    end

    if TWIN_BREEDS[breed.name] then
        identity = {
            type_name = "renegade_twin_captain",
            localization_key = localization_key,
            breed_localization_key = breed.display_name,
        }
    else
        identity = {
            type_name = BOSS_GROUP_BY_BREED[breed.name] or breed.name,
            localization_key = localization_key,
            breed_localization_key = breed.display_name,
        }
    end

    _boss_identities[boss_unit] = identity

    return identity
end

local function _record_boss_type_damage(boss_unit, breed, aid, actual)
    local identity = _boss_identity(boss_unit, breed)
    local data = _boss_damage_by_type[identity.type_name]

    if not data then
        data = {
            localization_key = identity.localization_key,
            breed_localization_key = identity.breed_localization_key,
            count = 0,
            values = {},
        }
        _boss_damage_by_type[identity.type_name] = data
    end

    if not identity.counted then
        data.count = (data.count or 0) + 1
        identity.counted = true

        if data.count > 1 and data.breed_localization_key then
            data.localization_key = data.breed_localization_key
        end
    end

    data.values[aid] = (data.values[aid] or 0) + actual
end

local function _hexbound_boss_for_ritualist(ritualist_unit)
    local state = Managers.state
    local game_session_manager = state and state.game_session
    local unit_spawner = state and state.unit_spawner

    if not game_session_manager or not unit_spawner then
        return
    end

    local game_session = game_session_manager:game_session()
    local ritualist_id = unit_spawner:game_object_id(ritualist_unit)

    if not game_session or not ritualist_id
        or not GameSession.game_object_exists(game_session, ritualist_id) then
        return
    end

    local boss_id = GameSession.game_object_field(game_session, ritualist_id, "level_unit_id")
    if type(boss_id) ~= "number" or not unit_spawner:valid_unit_id(boss_id, false) then
        return
    end

    local boss_unit = unit_spawner:unit(boss_id, false)
    local boss_unit_data = boss_unit and ScriptUnit.has_extension(boss_unit, "unit_data_system")
    local boss_breed = boss_unit_data and boss_unit_data:breed()

    if boss_breed and boss_breed.name == "chaos_mutator_daemonhost" then
        return boss_unit, boss_breed
    end
end

function Stats.record_boss_damage(boss_unit, aid, actual)
    if not _boss_damage[boss_unit] then
        _boss_damage[boss_unit] = {}
        local hp_ext = ScriptUnit.has_extension(boss_unit, "health_system")
        _boss_max_health[boss_unit] = hp_ext and hp_ext:max_health() or 0
    end
    local d = _boss_damage[boss_unit]
    d[aid] = (d[aid] or 0) + actual
end

function Stats.finalize_boss_encounter(boss_unit)
    local damage_data = _boss_damage[boss_unit]
    if not damage_data then return nil end

    local max_hp = _boss_max_health[boss_unit] or 0
    local total_damage = 0
    for _, d in pairs(damage_data) do total_damage = total_damage + d end

    local players = {}
    for aid, dmg in pairs(damage_data) do
        players[#players + 1] = {
            aid = aid,
            damage = math_floor(dmg),
            pct = total_damage > 0 and math_floor(dmg / total_damage * 100 + 0.5) or 0,
        }
    end
    table.sort(players, function(a, b) return a.damage > b.damage end)

    local ud = ScriptUnit.has_extension(boss_unit, "unit_data_system")
    local breed = ud and ud:breed()
    local breed_name = breed and breed.name or "unknown"
    local identity = _boss_identities[boss_unit]
    local localization_key = identity and identity.localization_key or breed and breed.display_name
    local display_name = breed_name
    if localization_key then
        local ok, localized = pcall(Localize, localization_key)
        if ok and localized and localized ~= "" then
            display_name = localized
        end
    end

    _boss_damage[boss_unit] = nil
    _boss_max_health[boss_unit] = nil
    _boss_identities[boss_unit] = nil

    return {
        breed_name = breed_name,
        display_name = display_name,
        max_health = max_hp,
        total_damage = total_damage,
        players = players,
    }
end

function Stats.clear_boss_data()
    _boss_damage = {}
    _boss_max_health = {}
    _boss_damage_by_type = {}
    _boss_identities = {}
end

local STAT_DEFS = {
    { id = "total_kills",          label = "row_total_kills",          cat = "combat",       dir = "asc",  accum = "add", style = "main" },
    { id = "lesser_enemies_killed", label = "row_lesser_enemies_killed", cat = "combat",      dir = "asc",  accum = "add", parent = "total_kills", style = "sub" },
    { id = "specials_killed",      label = "row_specials_killed",      cat = "combat",       dir = "asc",  accum = "add", parent = "total_kills", style = "sub" },
    { id = "elites_killed",        label = "row_elites_killed",        cat = "combat",       dir = "asc",  accum = "add", parent = "total_kills", style = "sub" },
    { id = "ranged_elites_killed", label = "row_ranged_elites_killed", cat = "combat",       dir = "asc",  accum = "add", parent = "elites_killed", hidden = true, style = "sub" },
    { id = "melee_elites_killed",  label = "row_melee_elites_killed",  cat = "combat",       dir = "asc",  accum = "add", parent = "elites_killed", hidden = true, style = "sub" },
    { id = "companion_kills",      label = "row_companion_kills",      cat = "combat",       dir = "asc",  accum = "add", parent = "total_kills", style = "sub" },

    { id = "damage_dealt",         label = "row_damage_dealt",         cat = "combat",       dir = "asc",  accum = "add", style = "main" },
    { id = "melee_damage",         label = "row_melee_damage",         cat = "combat",       dir = "asc",  accum = "add", parent = "damage_dealt", style = "sub" },
    { id = "ranged_damage",        label = "row_ranged_damage",        cat = "combat",       dir = "asc",  accum = "add", parent = "damage_dealt", style = "sub" },
    { id = "other_damage",         label = "row_other_damage",         cat = "combat",       dir = "asc",  accum = "add", parent = "damage_dealt", style = "sub" },

    { id = "damage_details",       label = "row_damage_details",       cat = "combat",       dir = "asc",  accum = "set", style = "main", no_values = true },
    { id = "dot_damage",           label = "row_dot_damage",           cat = "combat",       dir = "asc",  accum = "add", parent = "damage_details", style = "sub" },
    { id = "dot_bleeding_damage",  label = "row_dot_bleeding_damage",  cat = "combat",       dir = "asc",  accum = "add", parent = "dot_damage", style = "sub" },
    { id = "dot_soulblaze_damage", label = "row_dot_soulblaze_damage", cat = "combat",       dir = "asc",  accum = "add", parent = "dot_damage", style = "sub" },
    { id = "dot_burning_damage",   label = "row_dot_burning_damage",   cat = "combat",       dir = "asc",  accum = "add", parent = "dot_damage", style = "sub" },
    { id = "dot_toxin_damage",     label = "row_dot_toxin_damage",     cat = "combat",       dir = "asc",  accum = "add", parent = "dot_damage", style = "sub" },
    { id = "companion_damage",     label = "row_companion_damage",     cat = "combat",       dir = "asc",  accum = "add", parent = "damage_details", style = "sub" },
    { id = "damage_to_bosses",     label = "row_damage_to_bosses",     cat = "combat",       dir = "asc",  accum = "add", parent = "damage_details", style = "sub" },

    { id = "combat_utility",       label = "row_utility",              cat = "combat",       dir = "asc",  accum = "set", style = "main", no_values = true },
    { id = "headshots",            label = "row_headshots",            cat = "combat",       dir = "asc",  accum = "add", parent = "combat_utility", style = "sub" },
    { id = "weakspot_ratio_hits",  label = "row_headshots",            cat = "combat",       dir = "asc",  accum = "add", parent = "combat_utility", hidden = true, ranked = false, style = "sub" },
    { id = "melee_ranged_hits",    label = "row_headshots",            cat = "combat",       dir = "asc",  accum = "add", parent = "combat_utility", hidden = true, ranked = false, style = "sub" },
    { id = "critical_hits",        label = "row_critical_hits",        cat = "combat",       dir = "asc",  accum = "add", parent = "combat_utility", style = "sub" },
    { id = "critical_ratio_hits",  label = "row_critical_hits",        cat = "combat",       dir = "asc",  accum = "add", parent = "combat_utility", hidden = true, ranked = false, style = "sub" },
    { id = "enemies_staggered",    label = "row_enemies_staggered",    cat = "combat",       dir = "asc",  accum = "add", parent = "combat_utility", style = "sub" },
    { id = "debuffs_applied",      label = "row_debuffs_applied",      cat = "combat",       dir = "asc",  accum = "add", parent = "combat_utility", style = "sub" },
    { id = "enemies_staggered_weighted", label = "row_enemies_staggered", cat = "combat",       dir = "asc",  accum = "add", parent = "combat_utility", hidden = true, style = "sub" },

    { id = "survivability",        label = "row_survivability",        cat = "survival",     dir = "asc",  accum = "set", style = "main", no_values = true },
    { id = "damage_taken",         label = "row_damage_taken",         cat = "survival",     dir = "desc", accum = "diff", parent = "survivability", style = "sub" },
    { id = "downs_and_deaths",     label = "row_downs_and_deaths",     cat = "survival",     dir = "desc", accum = "add",  parent = "survivability", style = "sub" },
    { id = "downs",                label = "row_downs",                 cat = "survival",     dir = "desc", accum = "add",  parent = "downs_and_deaths", style = "sub" },
    { id = "deaths",               label = "row_deaths",                cat = "survival",     dir = "desc", accum = "add",  parent = "downs_and_deaths", style = "sub" },
    { id = "revives_and_rescues",  label = "row_revives_and_rescues",   cat = "survival",     dir = "asc",  accum = "add",  parent = "downs_and_deaths", style = "sub" },
    { id = "times_disabled",       label = "row_times_disabled",       cat = "survival",     dir = "desc", accum = "add",  parent = "survivability", style = "sub" },
    { id = "disabled_helped",      label = "row_disabled_helped",       cat = "survival",     dir = "asc",  accum = "add",  parent = "times_disabled", style = "sub" },
    { id = "healthstation_uses",   label = "row_healthstation_uses",   cat = "survival",     dir = "desc", accum = "add",  parent = "survivability", style = "sub" },
    { id = "ammo_pickups",         label = "row_ammo_pickups",         cat = "survival",     dir = "asc",  accum = "add", style = "main", ranked = false },
    { id = "ammo_collected",       label = "row_ammo_collected",       cat = "survival",     dir = "asc",  accum = "add", parent = "ammo_pickups", style = "sub", ranked = false },

    { id = "survival_utility",     label = "row_utility",              cat = "survival",     dir = "asc",  accum = "set", style = "main", no_values = true },
    { id = "combat_ability_uses",  label = "row_combat_ability_uses",  cat = "survival",     dir = "asc",  accum = "add", parent = "survival_utility", style = "sub" },
    { id = "enemies_aggroed",      label = "row_enemies_aggroed",      cat = "survival",     dir = "asc",  accum = "add", parent = "survival_utility", style = "sub" },
    { id = "coherency_uptime",     label = "row_coherency_uptime",     cat = "survival",     dir = "asc",  accum = "set", parent = "survival_utility", style = "sub" },

}

for _, category in ipairs({ "lesser", "specials", "elites" }) do
    local parent = category == "lesser" and "lesser_enemies_killed"
        or category == "specials" and "specials_killed"
        or "elites_killed"

    for _, enemy in ipairs(EnemyCatalog[category]) do
        STAT_DEFS[#STAT_DEFS + 1] = {
            id = enemy.stat_id,
            label = enemy.label,
            cat = "combat",
            dir = "asc",
            accum = "add",
            parent = parent,
            style = "sub",
            show_total = true,
        }
    end
end

local CATEGORIES = {
    { key = "combat",       label = "cat_combat"       },
    { key = "survival",     label = "cat_survival"     },
}

local ACCUMULATORS = {
    add  = function(entry, raw) entry.score = entry.score + raw; entry.value = entry.value + raw end,
    diff = function(entry, raw) entry.score = entry.score + math_max(raw - entry.value, 0); entry.value = raw end,
    set  = function(entry, raw) entry.score = raw; entry.value = raw end,
}

local function _validate(data, accounts)
    local scores, all_same = {}, true
    local first_score = nil
    for aid in pairs(accounts) do
        local s = data[aid] and data[aid].score or 0
        scores[aid] = s
        if first_score == nil then first_score = s
        elseif s ~= first_score then all_same = false end
    end
    if all_same then
        for aid in pairs(accounts) do
            if data[aid] then data[aid].best = false; data[aid].worst = false end
        end
        return
    end
    local high, low = first_score, first_score
    for _, s in pairs(scores) do
        if s > high then high = s end
        if s < low then low = s end
    end
    for aid, s in pairs(scores) do
        if data[aid] then
            data[aid].best  = (s == high)
            data[aid].worst = (s == low)
        end
    end
end

local VALIDATORS = {
    asc  = function(data, accounts) _validate(data, accounts) end,
    desc = function(data, accounts)
        -- invert: lowest score is "best", highest is "worst"
        local scores, all_same = {}, true
        local first_score = nil
        for aid in pairs(accounts) do
            local s = data[aid] and data[aid].score or 0
            scores[aid] = s
            if first_score == nil then first_score = s
            elseif s ~= first_score then all_same = false end
        end
        if all_same then
            for aid in pairs(accounts) do
                if data[aid] then data[aid].best = false; data[aid].worst = false end
            end
            return
        end
        local high, low = first_score, first_score
        for _, s in pairs(scores) do
            if s > high then high = s end
            if s < low then low = s end
        end
        for aid, s in pairs(scores) do
            if data[aid] then
                data[aid].best  = (s == low)
                data[aid].worst = (s == high)
            end
        end
    end,
}

local _data = {}

local _def_by_id = {}

local _cat_stats = {}

local function _safe_number(value)
    if type(value) ~= "number" then
        return nil
    end

    if value ~= value or value == math_huge or value == -math_huge or value < 0 then
        return nil
    end

    return value
end

local function _copy_data_entry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local value = _safe_number(entry.value)
    local score = _safe_number(entry.score)

    if not value or not score then
        return nil
    end

    return {
        value = value,
        score = score,
    }
end

local function _copy_stat_table(source)
    if type(source) ~= "table" then
        return nil
    end

    local copy = {}

    for aid, entry in pairs(source) do
        if type(aid) ~= "string" then
            return nil
        end

        local copied_entry = _copy_data_entry(entry)
        if not copied_entry then
            return nil
        end

        copy[aid] = copied_entry
    end

    return copy
end

local function _copy_boss_damage_by_type(source)
    if source == nil then
        return {}
    elseif type(source) ~= "table" then
        return nil
    end

    local copy = {}

    for boss_type, data in pairs(source) do
        if type(boss_type) ~= "string" or type(data) ~= "table" or type(data.values) ~= "table" then
            return nil
        end

        local values = {}
        for aid, damage in pairs(data.values) do
            damage = _safe_number(damage)
            if type(aid) ~= "string" or not damage then
                return nil
            end
            values[aid] = damage
        end

        local count = data.count == nil and 1 or _safe_number(data.count)
        if not count or count < 1 or count ~= math_floor(count) then
            return nil
        end

        copy[boss_type] = {
            localization_key = type(data.localization_key) == "string" and data.localization_key or nil,
            breed_localization_key = type(data.breed_localization_key) == "string" and data.breed_localization_key or nil,
            count = count,
            values = values,
        }
    end

    return copy
end

function Stats.init()
    for _, def in ipairs(STAT_DEFS) do
        _def_by_id[def.id] = def
        _data[def.id] = {}
        def.children = nil
    end
    _data._total_damage = {}

    for _, def in ipairs(STAT_DEFS) do
        if def.parent then
            local parent = _def_by_id[def.parent]
            if parent then
                parent.children = parent.children or {}
                parent.children[#parent.children + 1] = def
                def.depth = (parent.depth or 0) + 1
            end
        else
            def.depth = 0
        end
    end

    for _, cat in ipairs(CATEGORIES) do
        local list = {}
        for _, def in ipairs(STAT_DEFS) do
            if def.cat == cat.key and not def.parent then
                list[#list + 1] = def
            end
        end
        _cat_stats[cat.key] = list
    end
end

function Stats.record(stat_id, aid, raw)
    if type(raw) ~= "number" or raw < 0 then return end
    local d = _data[stat_id]
    if not d then return end
    local def = _def_by_id[stat_id]
    local entry = d[aid] or { value = 0, score = 0 }
    ACCUMULATORS[def.accum](entry, raw)
    d[aid] = entry
end

function Stats.ensure_entries(account_ids)
    for _, def in ipairs(STAT_DEFS) do
        local d = _data[def.id]
        for aid in pairs(account_ids) do
            if not d[aid] then d[aid] = { value = 0, score = 0 } end
        end
    end
    local td = _data._total_damage
    for aid in pairs(account_ids) do
        if not td[aid] then td[aid] = { value = 0, score = 0 } end
    end
end

function Stats.validate(account_ids)
    External.validate(account_ids)
    for _, def in ipairs(STAT_DEFS) do
        if def.ranked ~= false then
            VALIDATORS[def.dir](_data[def.id], account_ids)
        end
    end
end

function Stats.clear()
    External.reset()
    for _, def in ipairs(STAT_DEFS) do
        table_clear(_data[def.id])
    end
    table_clear(_data._total_damage)
    table_clear(_killed_units)
    table_clear(_companion_killed_units)
    Stats.clear_boss_data()
end

function Stats.has_active_run_data()
    if External.has_data() then return true end
    for _, def in ipairs(STAT_DEFS) do
        for _, entry in pairs(_data[def.id]) do
            if entry and ((entry.value or 0) ~= 0 or (entry.score or 0) ~= 0) then
                return true
            end
        end
    end

    for _, entry in pairs(_data._total_damage) do
        if entry and ((entry.value or 0) ~= 0 or (entry.score or 0) ~= 0) then
            return true
        end
    end

    return false
end

function Stats.export_active_run()
    local stats = {}

    for _, def in ipairs(STAT_DEFS) do
        local copied = _copy_stat_table(_data[def.id])
        if copied then
            stats[def.id] = copied
        end
    end

    stats._total_damage = _copy_stat_table(_data._total_damage) or {}

    return {
        version = 1,
        stats = stats,
        external = External.export(),
        boss_damage_by_type = _copy_boss_damage_by_type(_boss_damage_by_type) or {},
    }
end

function Stats.import_active_run(snapshot)
    if type(snapshot) ~= "table" or snapshot.version ~= 1 or type(snapshot.stats) ~= "table" then
        return false
    end

    if not External.validate_snapshot(snapshot.external) then return false end

    local imported = {}

    for _, def in ipairs(STAT_DEFS) do
        local source = snapshot.stats[def.id]
        if source ~= nil then
            local copied = _copy_stat_table(source)
            if not copied then
                return false
            end

            imported[def.id] = copied
        else
            imported[def.id] = {}
        end
    end

    if snapshot.stats.other_damage == nil then
        for aid, damage_entry in pairs(imported.damage_dealt) do
            local melee_entry = imported.melee_damage[aid]
            local ranged_entry = imported.ranged_damage[aid]
            local other = math_max(damage_entry.score
                - (melee_entry and melee_entry.score or 0)
                - (ranged_entry and ranged_entry.score or 0), 0)
            imported.other_damage[aid] = { value = other, score = other }
        end
    end

    local total_damage = snapshot.stats._total_damage
    if total_damage ~= nil then
        total_damage = _copy_stat_table(total_damage)
        if not total_damage then
            return false
        end
    else
        total_damage = {}
    end

    local boss_damage_by_type = _copy_boss_damage_by_type(snapshot.boss_damage_by_type)
    if not boss_damage_by_type then
        return false
    end

    Stats.clear()

    for _, def in ipairs(STAT_DEFS) do
        local target = _data[def.id]
        for aid, entry in pairs(imported[def.id]) do
            target[aid] = entry
        end
    end

    for aid, entry in pairs(total_damage) do
        _data._total_damage[aid] = entry
    end


    _boss_damage_by_type = boss_damage_by_type
    External.restore(snapshot.external)

    return true
end


local function _boss_breakdown_rows()
    local rows = {}
    local boss_types = {}

    for boss_type in pairs(_boss_damage_by_type) do
        boss_types[#boss_types + 1] = boss_type
    end
    table.sort(boss_types)

    for _, boss_type in ipairs(boss_types) do
        local source = _boss_damage_by_type[boss_type]
        local special_label = BOSS_TYPE_LABELS[boss_type]
        local label = special_label or BOSS_BREED_LABELS[boss_type]
        local values = {}
        local account_ids = {}

        for aid in pairs(_data.damage_to_bosses) do
            local damage = source.values[aid] or 0
            values[aid] = { value = damage, score = damage }
            account_ids[aid] = true
        end

        VALIDATORS.asc(values, account_ids)
        rows[#rows + 1] = {
            id = "boss_damage_type_" .. boss_type,
            parent = "damage_to_bosses",
            depth = 2,
            style = "sub",
            boss_detail = true,
            boss_type = boss_type,
            count = not special_label and source.count or nil,
            label = label,
            engine_localization_key = not label and source.localization_key or nil,
            values = values,
        }
    end

    return rows
end

function Stats.sections()
    local result = {}

    local function append_row(rows, row)
        if not row.hidden then
            rows[#rows + 1] = row

            if row.id == "damage_to_bosses" then
                local boss_rows = _boss_breakdown_rows()
                for i = 1, #boss_rows do
                    rows[#rows + 1] = boss_rows[i]
                end
            end
        end

        for _, child in ipairs(row.children or {}) do
            append_row(rows, child)
        end
    end

    for _, cat in ipairs(CATEGORIES) do
        local parents = _cat_stats[cat.key]
        local rows = {}

        for _, p in ipairs(parents) do
            append_row(rows, p)
        end

        if #rows > 0 then
            result[#result + 1] = { category = cat, rows = rows }
        end
    end
    return External.inject(result)
end

function Stats.data_for(stat_id)
    return _data[stat_id]
end

function Stats.hit_percentage_values(stat_id)
    local numerator_id = stat_id == "headshots" and "weakspot_ratio_hits"
        or stat_id == "critical_hits" and "critical_ratio_hits"
    if not numerator_id then
        return nil
    end

    local values = {}
    local numerator = _data[numerator_id]
    local denominator = _data.melee_ranged_hits

    for aid, denominator_entry in pairs(denominator) do
        local hits = denominator_entry.score or 0
        local numerator_entry = numerator[aid]
        local matching_hits = numerator_entry and numerator_entry.score or 0
        values[aid] = hits > 0 and matching_hits / hits * 100 or 0
    end

    return values
end

function Stats.snapshot_sections(account_ids, sections)
    local result = {}
    sections = sections or Stats.sections()

    for _, section in ipairs(sections) do
        local snapshot_rows = {}

        for _, row in ipairs(section.rows) do
            local snapshot_row = {
                id = row.id,
                label = row.label,
                label_text = row.label_text,
                engine_localization_key = row.engine_localization_key,
                boss_detail = row.boss_detail,
                boss_type = row.boss_type,
                count = row.count,
                parent = row.parent,
                depth = row.depth,
                style = row.style,
                show_total = row.show_total,
                ranked = row.ranked,
                no_values = row.no_values,
                suffix = row.suffix,
                decimals = row.decimals,
                external = row.external,
                external_group = row.external_group,
                placement = row.placement,
                group = row.group,
                value_type = row.value_type,
                accumulation = row.accumulation,
                ranking = row.ranking,
                collapsible = row.collapsible,
                collapsed_by_default = row.collapsed_by_default,
                full_width = row.full_width,
                height_scale = row.height_scale,
                font_scale = row.font_scale,
                values = {},
            }
            local percentage_values = Stats.hit_percentage_values(row.id)
            if percentage_values then
                snapshot_row.percentage_values = {}
            end

            for aid in pairs(row.external and row.values or account_ids) do
                local row_value = nil

                if row.values then
                    local value = row.values[aid]

                    if type(value) == "table" then
                        row_value = {
                            score = value.score or value.value or 0,
                            best = value.best or value.is_best or false,
                            worst = value.worst or value.is_worst or false,
                        }
                    elseif value ~= nil or not row.external then
                        row_value = {
                            score = value or 0,
                            best = false,
                            worst = false,
                        }
                    end
                elseif row.id and _data[row.id] then
                    local data = _data[row.id][aid]

                    row_value = {
                        score = data and data.score or 0,
                        best = data and data.best or false,
                        worst = data and data.worst or false,
                    }
                end

                if row_value then
                    snapshot_row.values[aid] = row_value
                end
                if percentage_values then
                    snapshot_row.percentage_values[aid] = percentage_values[aid] or 0
                end
            end

            snapshot_rows[#snapshot_rows + 1] = snapshot_row
        end

        result[#result + 1] = {
            category = {
                key = section.category.key,
                label = section.category.label,
                label_text = section.category.label_text,
                uppercase = section.category.uppercase,
            },
            rows = snapshot_rows,
        }
    end

    return result
end

function Stats.live_summary(aid)
    local damage = 0
    local kills = 0
    local taken = 0
    local total_dmg = _data._total_damage
    local kill_data = _data.total_kills
    local taken_data = _data.damage_taken

    if total_dmg and total_dmg[aid] then
        damage = total_dmg[aid].score or 0
    end

    if kill_data and kill_data[aid] then
        kills = kill_data[aid].score or 0
    end

    if taken_data and taken_data[aid] then
        taken = taken_data[aid].score or 0
    end

    return damage, kills, taken
end

function Stats.def(stat_id)
    return _def_by_id[stat_id]
end

function Stats.defs()
    return STAT_DEFS
end

function Stats.is_enemy_detail(stat_id)
    return ENEMY_DETAIL_STATS[stat_id] == true
end

function Stats.is_dot_detail(stat_id)
    return DOT_DETAIL_STATS[stat_id] == true
end

function Stats.seed_enemy_health(unit, max_health)
    if not unit or not max_health or max_health <= 0 then return end
    local enemy_health = mod._enemy_health
    if not enemy_health[unit] then
        enemy_health[unit] = max_health
    end
end

function Stats.classify_kill(breed_name, aid)
    local enemy = ENEMY_BY_BREED[breed_name]

    if BOSSES[breed_name] then
        return false
    elseif enemy and enemy.category == "lesser" then
        Stats.record("lesser_enemies_killed", aid, 1)
        Stats.record(enemy.stat_id, aid, 1)
    elseif enemy and enemy.category == "specials" then
        Stats.record("specials_killed", aid, 1)
        Stats.record(enemy.stat_id, aid, 1)
    elseif enemy and enemy.category == "elites" then
        Stats.record("elites_killed", aid, 1)
        Stats.record(enemy.stat_id, aid, 1)
        if RANGED_ELITES[breed_name] then
            Stats.record("ranged_elites_killed", aid, 1)
        elseif MELEE_ELITES[breed_name] then
            Stats.record("melee_elites_killed", aid, 1)
        end
    end
    return true
end

function Stats.record_kill_from_death(attacked_unit, last_hitter_account_id)
    if not attacked_unit then return end

    local ud = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
    local breed = ud and ud:breed()
    if not breed or not Breed.is_minion(breed) then return end

    local aid = last_hitter_account_id
    if not aid then return end

    if _killed_units[attacked_unit] then return end

    _killed_units[attacked_unit] = true
    Stats.record("total_kills", aid, 1)
    Stats.classify_kill(breed.name, aid)
end

function Stats.mark_killed(unit)
    _killed_units[unit] = true
end

function Stats.clear_kill_tracking()
    table_clear(_killed_units)
    table_clear(_companion_killed_units)
end

function Stats.handle_attack(aid, damage_profile, attacked_unit, hit_weakspot, damage, attack_result, attack_type, enemy_health, is_critical_strike)
    if not attacked_unit then
        return
    end

    if hit_weakspot then
        Stats.record("headshots", aid, 1)
    end

    local ud = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
    local breed = ud and ud:breed()
    if not breed or not Breed.is_minion(breed) then
        return
    end

    local melee_or_ranged = attack_type == "melee" or attack_type == "ranged"
    if melee_or_ranged and not NON_HIT_ATTACK_RESULTS[attack_result] then
        Stats.record("melee_ranged_hits", aid, 1)
        if hit_weakspot then
            Stats.record("weakspot_ratio_hits", aid, 1)
        end
        if is_critical_strike and (damage or 0) > 0 then
            Stats.record("critical_ratio_hits", aid, 1)
        end
    end

    if is_critical_strike and (damage or 0) > 0 then
        Stats.record("critical_hits", aid, 1)
    end

    local bn = breed.name

    -- Attack RPCs can arrive before client health replication; keep a local balance
    -- so a stale health value cannot turn the killing blow into extra damage.
    local actual = damage or 0
    local current_health = enemy_health[attacked_unit]

    if attack_result == "damaged" or attack_result == "died" then
        if not current_health then
            local hp_ext = ScriptUnit.has_extension(attacked_unit, "health_system")
            local max_health = hp_ext and hp_ext:max_health()
            local replicated_health = hp_ext and hp_ext:current_health()
            current_health = replicated_health and replicated_health + actual or max_health or actual
            if max_health then
                current_health = math_min(current_health, max_health)
            end
        end

        actual = math_min(actual, current_health)
        enemy_health[attacked_unit] = attack_result == "died" and nil or current_health - actual
    end

    local total_dmg = _data._total_damage
    local td_entry = total_dmg[aid] or { value = 0, score = 0 }
    td_entry.score = td_entry.score + actual
    td_entry.value = td_entry.value + actual
    total_dmg[aid] = td_entry

    local boss_result = nil
    local companion_attack = is_companion_attack(damage_profile, attack_type)
    Stats.record("damage_dealt", aid, actual)
    if attack_type == "ranged" then
        Stats.record("ranged_damage", aid, actual)
    elseif attack_type == "melee" then
        Stats.record("melee_damage", aid, actual)
    else
        Stats.record("other_damage", aid, actual)
    end
    local dot_stat_id = damage_profile and DOT_PROFILES[damage_profile.name]
    if dot_stat_id then
        Stats.record("dot_damage", aid, actual)
        Stats.record(dot_stat_id, aid, actual)
    end
    if companion_attack then
        Stats.record("companion_damage", aid, actual)
    end
    if bn == "chaos_mutator_ritualist" and actual > 0 then
        local boss_unit, boss_breed = _hexbound_boss_for_ritualist(attacked_unit)
        if boss_unit then
            Stats.record("damage_to_bosses", aid, actual)
            Stats.record_boss_damage(boss_unit, aid, actual)
            _record_boss_type_damage(boss_unit, boss_breed, aid, actual)
        end
    end
    if BOSSES[bn] then
        Stats.record("damage_to_bosses", aid, actual)
        Stats.record_boss_damage(attacked_unit, aid, actual)
        _record_boss_type_damage(attacked_unit, breed, aid, actual)
    end

    if attack_result == "died" then
        if companion_attack and not _companion_killed_units[attacked_unit] then
            _companion_killed_units[attacked_unit] = true
            Stats.record("companion_kills", aid, 1)
        end

        if _killed_units[attacked_unit] then
            return boss_result
        end
        _killed_units[attacked_unit] = true

        Stats.record("total_kills", aid, 1)
        if BOSSES[bn] then
            boss_result = Stats.finalize_boss_encounter(attacked_unit)
        else
            Stats.classify_kill(bn, aid)
        end
    end

    return boss_result
end

return Stats
