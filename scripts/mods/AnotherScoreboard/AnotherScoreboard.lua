---@class AnotherScoreboardMod: DMFMod
local mod = get_mod("AnotherScoreboard")

do
    local External = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_external")
    mod.external_stats_api_version = 1
    mod.external_stats = External

    ---@param owner DMFMod
    ---@param definition ASExternalGroupDefinition
    ---@return string? key
    ---@return string? error_code
    function mod:register_external_group(owner, definition)
        return External.register_group(owner, definition)
    end

    ---@param owner DMFMod
    ---@param definition ASExternalStatDefinition
    ---@return string? key
    ---@return string? error_code
    function mod:register_external_stat(owner, definition)
        return External.register_stat(owner, definition)
    end

    ---@param key string
    ---@param player_id string
    ---@param value number|string
    ---@return boolean? success
    ---@return string? error_code
    function mod:update_external_stat(key, player_id, value)
        if not self:is_enabled() then return nil, "scoreboard_disabled" end
        return External.update(key, player_id, value)
    end

    ---@param key string
    ---@param player_id? string
    ---@return number|string|table<string, number|string>|nil value Scalar or copied player-value map; nil without error means missing.
    ---@return string? error_code
    function mod:get_external_stat(key, player_id)
        return External.get(key, player_id)
    end

    ---@param owner DMFMod
    ---@param callback? fun(owner: DMFMod, scoreboard: AnotherScoreboardMod)
    ---@return boolean? success
    ---@return string? error_code
    function mod:set_external_stat_collector(owner, callback)
        return External.set_collector(owner, callback)
    end

    ---@param owner DMFMod
    ---@return boolean? success
    ---@return string? error_code
    function mod:unregister_external_provider(owner)
        return External.unregister(owner)
    end

    function mod.toggle_external_details()
        local hud = Managers.ui and Managers.ui:get_hud()
        local overlay = hud and hud:element("HudElementTacticalOverlay")
        if not overlay or not overlay._active then return end
        External.details_expanded = not External.details_expanded
        External.revision = External.revision + 1
    end
end

local CLASS              = CLASS
local pairs              = pairs
local ipairs             = ipairs
local type               = type
local tostring           = tostring
local setmetatable       = setmetatable
local table_clear        = table.clear

local ScriptUnit         = ScriptUnit
local Managers           = Managers
local GameSession        = GameSession
local Keyboard           = Keyboard
local rawget             = rawget
local select             = select
local Unit               = Unit

local Q_KEY = Keyboard.button_index("q")

local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local InteractionSettings = mod:original_require("scripts/settings/interaction/interaction_settings")
local Havoc = mod:original_require("scripts/utilities/havoc")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local Breed = mod:original_require("scripts/utilities/breed")
local LIVE_STAT_CATALOG = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_live_stats")
local ARCHETYPE_CATALOG = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_archetypes")
local SCOREBOARD_STAT_CATALOG = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_scoreboard_stats")
local THEME_CATALOG = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_themes")
mod._forced_assist = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_forced_assist")
mod._late_players = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_late_players")

local math_floor = math.floor
local math_max   = math.max
local math_huge  = math.huge
local string_find = string.find

mod._enemy_health = setmetatable({}, { __mode = "k" })
mod._last_hitter_account_id = setmetatable({}, { __mode = "k" })  -- enemy unit to account ID
mod._ammo_processed_units = setmetatable({}, { __mode = "k" })
mod.current_ammo = setmetatable({}, { __mode = "k" })
mod.pending_ammo_pickups = {}

local _Stats         = nil
local _Render        = nil
local _History       = nil
local _history_preload_done = false
local _history_preload_delay = 1.0

local _coherency_time = {}
local _coherency_eligible_time = {}
local _mission_start_time = nil
local _mission_elapsed_final = nil
local _mission_metadata = {}
local _pending_mission_board_data = nil
local _active_run_store = mod:persistent_table("active_run", {})
---@cast _active_run_store table
mod._active_run_prefix_pending = _active_run_store.snapshot ~= nil
local _state_gameplay_enter_handled = false
local _scoreboard_history_saved = false
local _end_player_snapshot = nil
mod._late_departures = {}
local _coherency_last_sample = nil
local _state_tracker = {}
local _disabled_tracker = {}
local _combat_ability_charges = {}
mod._damage_taken_unit_by_account = {}
mod._player_roster = {}
local _runtime_stat_revision = 0
local _enemy_aggro_targets = setmetatable({}, { __mode = "k" })
local _aggro_baseline_pending = false
local _aggro_sequence_order = 0
local _aggro_diagnostics = {}
local _unit_to_player = setmetatable({}, { __mode = "k" })
local _recent_attack_by_unit = setmetatable({}, { __mode = "k" })

local _boss_popup_queue = {}
local _boss_popup_active = nil
local _boss_popup_timer = 0

local COHERENCY_SAMPLE_INTERVAL = 0.25
local AGGRO_SAMPLE_INTERVAL = 0.25
local AGGRO_INITIAL_CONFIRM_SAMPLES = 12
local AGGRO_SWITCH_CONFIRM_SAMPLES = 12
local AGGRO_BOSS_CONFIRM_SAMPLES = 4
local AGGRO_TAUNT_CONFIRM_SAMPLES = 2
local AGGRO_DEATH_FALLBACK_SAMPLES = 4
local AGGRO_DIAGNOSTIC_THRESHOLDS = { 4, 8, 12, 20 }
local COMBAT_ABILITY_CHARGES_FIELD = "combat_ability_num_charges"
local _coherency_sample_timer = 0
local _aggro_sample_timer = 0
local interaction_results = InteractionSettings.results

local function _reset_aggro_diagnostics()
    _aggro_sequence_order = 0
    _aggro_diagnostics = {
        awarded_pairs = 0,
        credited_enemies = 0,
        tracked_enemies = 0,
        normal_credits = 0,
        boss_credits = 0,
        taunt_credits = 0,
        death_fallback_credits = 0,
        rejected_short_sequences = 0,
        confirmed_switches = 0,
        deaths_seen = 0,
        deaths_without_tracking = 0,
        finalized_enemies = 0,
        finalized_by_player_count = { [0] = 0, 0, 0, 0, 0 },
        despawned_enemies = 0,
        threshold_pairs = { [4] = 0, [8] = 0, [12] = 0, [20] = 0 },
    }
end

_reset_aggro_diagnostics()

local AMMO_PICKUP_TYPES = {
    loc_pickup_consumable_small_clip_01 = "small_clip",
    loc_pickup_consumable_large_clip_01 = "large_clip",
    loc_pickup_deployable_ammo_crate_01 = "crate",
}

local AMMO_PICKUP_AMOUNTS = {
    small_clip = 15,
    large_clip = 50,
    crate = 100,
}

local DEBUFF_TEMPLATES_BY_GROUP = {
    bleed = {
        "bleed",
        "bleed_long",
    },
    burn = {
        "flamer_assault",
        "phosphor_burn",
    },
    warpfire = {
        "warp_fire",
    },
    toxin = {
        "neurotoxin_interval_buff",
        "neurotoxin_interval_buff2",
        "neurotoxin_interval_buff3",
        "exploding_toxin_interval_buff",
    },
    electrocuted = {
        "shock_grenade_interval",
        "shock_mine_interval",
        "shockmaul_stun_interval",
        "power_maul_p2_special_hit_primer",
        "power_maul_p2_activated_stun_extra",
        "power_maul_p2_activated_stun_basic",
        "power_maul_stun",
        "power_maul_sticky_tick",
        "shotgun_special_stun",
        "chain_lightning_interval",
        "psyker_protectorate_spread_chain_lightning_interval",
        "shock_effect",
        "toxin_special_stun",
    },
    brittleness = {
        "rending_debuff",
        "rending_debuff_medium",
        "rending_burn_debuff",
        "shotgun_special_rending_debuff",
        "saw_rending_debuff",
        "phosphor_rending_debuff",
        "hordes_buff_grenade_explosion_applies_rending_debuff_effect",
    },
    skullcrusher = {
        "increase_damage_received_while_staggered",
    },
    thunderstrike = {
        "increase_impact_received_while_staggered",
    },
    melee_damage_taken = {
        "ogryn_staggering_damage_taken_increase",
        "adamant_staggering_enemies_take_more_damage",
    },
    damage_taken = {
        "ogryn_recieve_damage_taken_increase_debuff",
        "increase_damage_taken",
        "broker_passive_toxin_infected_enemies_take_increased_damage_debuff",
        "ogryn_taunt_increased_damage_taken_buff",
        "adamant_drone_enemy_debuff",
        "psyker_discharge_damage_debuff",
        "zealot_bled_enemies_take_more_damage_effect",
        "psyker_protectorate_spread_chain_lightning_interval_improved",
        "psyker_protectorate_spread_charged_chain_lightning_interval_improved",
        "psyker_heavy_swings_shock_improved",
        "veteran_improved_tag_debuff",
        "cryptic_servo_skull_debuff",
        "cryptic_overload_keystone_increase_damage_taken_debuff",
    },
    empyric_shock = {
        "psyker_force_staff_quick_attack_debuff",
    },
    count_as_staggered = {
        "adamant_melee_weakspot_hits_count_as_stagger_debuff",
    },
    enemy_damage_reduction = {
        "adamant_drone_talent_debuff",
        "adamant_staggered_enemies_deal_less_damage_debuff",
        "broker_punk_rage_improved_shout_debuff",
        "toxin_damage_debuff",
        "toxin_damage_debuff_monster",
    },
}

local DEBUFF_GROUP_BY_TEMPLATE = {}
for group, template_names in pairs(DEBUFF_TEMPLATES_BY_GROUP) do
    for i = 1, #template_names do
        DEBUFF_GROUP_BY_TEMPLATE[template_names[i]] = group
    end
end

local DEBUFF_GROUP_BY_KEYWORD = {
    bleeding = "bleed",
    burning = "burn",
    warpfire_burning = "warpfire",
    toxin = "toxin",
    electrocuted = "electrocuted",
    electrocuted_arc = "electrocuted",
    electrocuted_arc_ability = "electrocuted",
    electrocuted_arc_grenade = "electrocuted",
    electrocuted_chain_lightning = "electrocuted",
    electrocuted_shock_mine = "electrocuted",
    count_as_staggered = "count_as_staggered",
}

local CRYPTIC_SOURCELESS_DEBUFFS = {
    cryptic_servo_skull_debuff = true,
    flamer_assault = true,
}

local CRYPTIC_DEBUFF_ATTRIBUTION_WINDOW = 0.5

local LIVE_STAT_SETTINGS = {
    "live_scoreboard_stat_1",
    "live_scoreboard_stat_2",
    "live_scoreboard_stat_3",
}

local LIVE_STAT_DEFAULTS = { "damage", "kills", "hp_lost" }
local LIVE_ARCHETYPE_SETTING = "live_scoreboard_archetype"
local LIVE_STAT_COUNT_SETTING = "live_scoreboard_stat_count"
local LIVE_STAT_COUNT_DEFAULT = 3

local LIVE_STATS = {}
local LIVE_ARCHETYPES = {}

for i = 1, #LIVE_STAT_CATALOG do
    local stat = LIVE_STAT_CATALOG[i]
    LIVE_STATS[stat.key] = stat
end

for i = 1, #ARCHETYPE_CATALOG do
    LIVE_ARCHETYPES[ARCHETYPE_CATALOG[i].id] = true
end

local function _archetype_stat_setting(archetype_id, index)
    return "live_scoreboard_" .. archetype_id .. "_stat_" .. tostring(index)
end

local function _archetype_stat_count_setting(archetype_id)
    return "live_scoreboard_" .. archetype_id .. "_stat_count"
end

local function _valid_live_stat_count(value)
    return type(value) == "number" and value >= 1 and value <= #LIVE_STAT_SETTINGS
end

for i = 1, #ARCHETYPE_CATALOG do
    local archetype_id = ARCHETYPE_CATALOG[i].id
    for stat_index = 1, #LIVE_STAT_DEFAULTS do
        local setting_id = _archetype_stat_setting(archetype_id, stat_index)
        if mod:get(setting_id) == nil then
            mod:set(setting_id, LIVE_STAT_DEFAULTS[stat_index], false)
        end
    end

    local count_setting_id = _archetype_stat_count_setting(archetype_id)
    if mod:get(count_setting_id) == nil then
        local count = mod:get(LIVE_STAT_COUNT_SETTING)
        mod:set(count_setting_id, _valid_live_stat_count(count) and count or LIVE_STAT_COUNT_DEFAULT, false)
    end
end

local _settings = {
    show_in_mission  = true,
    scale            = 1.0,
    text_scale       = 1.15,
    local_player_first = false,
    alternating_row_shading = true,
    scoreboard_opacity = 206,
    vertical_offset  = 0,
    horizontal_offset = 0,
    show_at_end      = true,
    end_scoreboard_scale = 1.0,
    end_scoreboard_opacity = 206,
    end_scoreboard_vertical_offset = 180,
    end_scoreboard_horizontal_offset = 0,
    boss_popup_duration = 10,
    show_boss_popup_damage = true,
    show_boss_popup_percent = true,
    show_boss_popup_total_damage = false,
    boss_popup_scale = 0.7,
    boss_popup_x = 0,
    boss_popup_y = -310,
    boss_popup_bg_opacity = 0,
    show_live_scoreboard = true,
    live_scoreboard_scale = 1.0,
    live_scoreboard_x = 0,
    live_scoreboard_y = -455,
    live_scoreboard_bg_opacity = 0,
    live_scoreboard_archetype = nil,
    live_scoreboard_stat_count = 3,
    live_scoreboard_stats = { "damage", "kills", "hp_lost" },
    live_scoreboard_columns = { {}, {}, {} },
    scoreboard_stat_visibility = {},
    scoreboard_theme = THEME_CATALOG.default,
    show_weakspot_percentage = true,
    show_critical_percentage = true,
}

local SCOREBOARD_STAT_SETTING_BY_ID = {}
for i = 1, #SCOREBOARD_STAT_CATALOG do
    local stat_id = SCOREBOARD_STAT_CATALOG[i].id
    SCOREBOARD_STAT_SETTING_BY_ID[stat_id] = "show_scoreboard_stat_" .. stat_id
end

local _dmf_options_active = false
local _dmf_options_reset_installed = false

local function _local_archetype_name()
    local player_manager = Managers.player
    local player = player_manager and player_manager:local_player_safe(1)
    local profile = player and player:profile()
    local archetype = profile and profile.archetype
    local archetype_name = archetype and archetype.name

    return LIVE_ARCHETYPES[archetype_name] and archetype_name or nil
end

local function _archetype_stat_key(archetype_id, index)
    local stat_key = mod:get(_archetype_stat_setting(archetype_id, index))
    return LIVE_STATS[stat_key] and stat_key or LIVE_STAT_DEFAULTS[index]
end

local function _archetype_stat_count(archetype_id)
    local count = mod:get(_archetype_stat_count_setting(archetype_id))
    return _valid_live_stat_count(count) and count or LIVE_STAT_COUNT_DEFAULT
end

local function _refresh_live_archetype(archetype_id)
    if not LIVE_ARCHETYPES[archetype_id] then
        return false
    end

    for i = 1, #LIVE_STAT_SETTINGS do
        local stat_key = _archetype_stat_key(archetype_id, i)
        local stat = LIVE_STATS[stat_key]
        local column = _settings.live_scoreboard_columns[i]

        _settings.live_scoreboard_stats[i] = stat_key
        column.key = stat_key
        column.label = mod:localize(stat.header)
        column.format = stat.format
        column.lower_better = stat.lower_better
    end

    _settings.live_scoreboard_archetype = archetype_id
    _settings.live_scoreboard_stat_count = _archetype_stat_count(archetype_id)
    return true
end

local function _ensure_live_archetype()
    local archetype_id = _local_archetype_name()
    if not archetype_id then
        return false
    end

    if _settings.live_scoreboard_archetype ~= archetype_id then
        _refresh_live_archetype(archetype_id)
    end

    return true
end

local function _sync_live_editor(archetype_id)
    if not LIVE_ARCHETYPES[archetype_id] then
        return
    end

    for i = 1, #LIVE_STAT_SETTINGS do
        mod:set(LIVE_STAT_SETTINGS[i], _archetype_stat_key(archetype_id, i), false)
    end
    mod:set(LIVE_STAT_COUNT_SETTING, _archetype_stat_count(archetype_id), false)
end

local function _reset_live_archetypes()
    for i = 1, #ARCHETYPE_CATALOG do
        local archetype_id = ARCHETYPE_CATALOG[i].id
        for stat_index = 1, #LIVE_STAT_DEFAULTS do
            mod:set(_archetype_stat_setting(archetype_id, stat_index), LIVE_STAT_DEFAULTS[stat_index], false)
        end
        mod:set(_archetype_stat_count_setting(archetype_id), LIVE_STAT_COUNT_DEFAULT, false)
    end

    local archetype_id = _local_archetype_name() or ARCHETYPE_CATALOG[1].id
    mod:set(LIVE_ARCHETYPE_SETTING, archetype_id, false)
    _sync_live_editor(archetype_id)
    _refresh_live_archetype(archetype_id)
end

local function _install_live_options_reset(view)
    local category_name = mod:localize("mod_name")
    local reset_functions = view and view._reset_functions_by_category
    local category_defaults = view and view._settings_category_default_values
        and view._settings_category_default_values[category_name]

    if not reset_functions or not category_defaults then
        return false
    end

    reset_functions[category_name] = function()
        for setting, default_value in pairs(category_defaults) do
            if setting.on_activated then
                setting.on_activated(default_value, setting)
            end
        end

        _reset_live_archetypes()
    end

    return true
end

local function _update_dmf_options_archetype()
    local ui = Managers.ui
    local active = ui and ui:view_active("dmf_options_view") or false

    if active and not _dmf_options_reset_installed then
        _dmf_options_reset_installed = _install_live_options_reset(ui:view_instance("dmf_options_view"))
    end

    if active and not _dmf_options_active then
        local archetype_id = _local_archetype_name()
        if archetype_id then
            mod:set(LIVE_ARCHETYPE_SETTING, archetype_id, false)
            _sync_live_editor(archetype_id)
            _dmf_options_active = true
        end
    elseif not active then
        _dmf_options_active = false
        _dmf_options_reset_installed = false
    end
end

local function _get_boss_popup_element()
    local hud = Managers.ui and Managers.ui:get_hud()
    return hud and hud:element("HudElementBossPopup")
end

local function _is_alive_unit(unit)
    return unit and Unit.alive(unit)
end

local function _clear_unit_runtime_caches()
    for k in pairs(_state_tracker) do _state_tracker[k] = nil end
    for k in pairs(_disabled_tracker) do _disabled_tracker[k] = nil end
    for k in pairs(_combat_ability_charges) do _combat_ability_charges[k] = nil end
    for k in pairs(mod._damage_taken_unit_by_account) do mod._damage_taken_unit_by_account[k] = nil end
    for k in pairs(mod._player_roster) do mod._player_roster[k] = nil end
    mod._forced_assist.reset()

    table_clear(mod._enemy_health)
    table_clear(mod._last_hitter_account_id)
    table_clear(mod._ammo_processed_units)
    table_clear(mod.current_ammo)
    table_clear(mod.pending_ammo_pickups)
    table_clear(_unit_to_player)
    table_clear(_recent_attack_by_unit)
    table_clear(_enemy_aggro_targets)
end

local function _pump_boss_popup_queue()
    if _boss_popup_active or not _settings.show_boss_popup or #_boss_popup_queue == 0 then
        return
    end

    local el = _get_boss_popup_element()
    if el then
        _boss_popup_active = table.remove(_boss_popup_queue, 1)
        _boss_popup_timer = _settings.boss_popup_duration
        el:show(_boss_popup_active, _settings.boss_popup_x, _settings.boss_popup_y, _settings.boss_popup_scale)
    end
end

local function _hide_boss_popup()
    table_clear(_boss_popup_queue)
    _boss_popup_active = nil
    _boss_popup_timer = 0

    local el = _get_boss_popup_element()
    if el then
        el:hide()
    end
end

local function _reset_runtime_state()
    mod.external_stats.details_expanded = false
    if _Stats then
        _Stats.clear()
    end
    mod._active_run_prefix_pending = _active_run_store.snapshot ~= nil

    _clear_unit_runtime_caches()
    _runtime_stat_revision = _runtime_stat_revision + 1
    if mod.stagger_clear_cache then mod:stagger_clear_cache() end
    table_clear(_coherency_time)
    table_clear(_coherency_eligible_time)

    _coherency_last_sample = nil
    _coherency_sample_timer = 0
    _aggro_sample_timer = 0
    _aggro_baseline_pending = false
    _reset_aggro_diagnostics()
    _mission_start_time = nil
    _mission_elapsed_final = nil
    _scoreboard_history_saved = false
    _end_player_snapshot = nil
    mod._late_departures = {}

    table_clear(_boss_popup_queue)
    _boss_popup_active = nil
    _boss_popup_timer = 0
end

local function _refresh_settings()
    _settings.show_in_mission   = mod:get("show_in_mission") ~= false
    _settings.scale             = (mod:get("scoreboard_scale") or 100) * 0.01
    _settings.text_scale        = (mod:get("scoreboard_text_scale") or 115) * 0.01
    _settings.local_player_first = mod:get("local_player_first") == true
    _settings.alternating_row_shading = mod:get("alternating_row_shading") ~= false
    _settings.scoreboard_opacity = mod:get("scoreboard_opacity") or 206
    _settings.vertical_offset   = mod:get("vertical_offset") or 0
    _settings.horizontal_offset = mod:get("horizontal_offset") or 0
    _settings.show_at_end       = mod:get("show_at_end") ~= false
    _settings.end_scoreboard_scale = (mod:get("end_scoreboard_scale") or 100) * 0.01
    _settings.end_scoreboard_opacity = mod:get("end_scoreboard_opacity") or 206
    _settings.end_scoreboard_vertical_offset = mod:get("end_scoreboard_vertical_offset") or 180
    _settings.end_scoreboard_horizontal_offset = mod:get("end_scoreboard_horizontal_offset") or 0
    _settings.show_boss_popup   = mod:get("show_boss_popup") ~= false
    _settings.show_boss_popup_damage = mod:get("show_boss_popup_damage") ~= false
    _settings.show_boss_popup_percent = mod:get("show_boss_popup_percent") ~= false
    _settings.show_boss_popup_total_damage = mod:get("show_boss_popup_total_damage") == true
    _settings.boss_popup_scale  = (mod:get("boss_popup_scale") or 70) * 0.01
    _settings.boss_popup_duration = mod:get("boss_popup_duration") or 10
    _settings.boss_popup_x      = mod:get("boss_popup_x_offset") or 0
    _settings.boss_popup_y      = mod:get("boss_popup_y_offset") or -310
    _settings.boss_popup_bg_opacity = mod:get("boss_popup_bg_opacity") or 0
    _settings.show_live_scoreboard = mod:get("show_live_scoreboard") ~= false
    _refresh_live_archetype(_local_archetype_name())
    _settings.live_scoreboard_scale = (mod:get("live_scoreboard_scale") or 100) * 0.01
    _settings.live_scoreboard_x = mod:get("live_scoreboard_x_offset") or 0
    _settings.live_scoreboard_y = mod:get("live_scoreboard_y_offset") or -455
    _settings.live_scoreboard_bg_opacity = mod:get("live_scoreboard_bg_opacity") or 0
    local scoreboard_theme = mod:get("scoreboard_theme")
    _settings.scoreboard_theme = THEME_CATALOG.by_id[scoreboard_theme] and scoreboard_theme or THEME_CATALOG.default
    _settings.show_weakspot_percentage = mod:get("show_scoreboard_weakspot_percentage") ~= false
    _settings.show_critical_percentage = mod:get("show_scoreboard_critical_percentage") ~= false

    for stat_id, setting_id in pairs(SCOREBOARD_STAT_SETTING_BY_ID) do
        _settings.scoreboard_stat_visibility[stat_id] = mod:get(setting_id) ~= false
    end

    if _Render then
        _Render.update_dimensions(_settings.scale, _settings.text_scale)
    end
end

local function _first_number(value)
    if type(value) == "table" then
        return tonumber(value[1])
    end

    return tonumber(value)
end

local function _read_ammo_snapshot(unit)
    if not _is_alive_unit(unit) then
        return nil
    end

    local unit_data_extension = unit and ScriptUnit.has_extension(unit, "unit_data_system")
    local wieldable_component = unit_data_extension and unit_data_extension:read_component("slot_secondary")

    if not wieldable_component then
        return nil
    end

    local clip = _first_number(wieldable_component.current_ammunition_clip)
    local reserve = _first_number(wieldable_component.current_ammunition_reserve)

    if clip == nil or reserve == nil then
        return nil
    end

    return {
        clip = clip,
        reserve = reserve,
    }
end

local function _ammo_amount_from_snapshots(before, after, fallback)
    if before and after then
        local before_total = before.clip + before.reserve
        local after_total = after.clip + after.reserve

        return math_max(after_total - before_total, 0)
    end

    return fallback or 0
end

local function _record_ammo_pickup_count(account_id, pickup_unit)
    if not _Stats or not account_id or not pickup_unit or mod._ammo_processed_units[pickup_unit] then
        return false
    end

    mod._ammo_processed_units[pickup_unit] = true
    _Stats.record("ammo_pickups", account_id, 1)

    return true
end

local function _player_from_unit(unit)
    if not unit then return nil end
    local cached = _unit_to_player[unit]
    if cached then return cached end

    local player_unit_spawn = Managers.state and Managers.state.player_unit_spawn
    local owner = player_unit_spawn and player_unit_spawn:owner(unit)
    if owner then
        _unit_to_player[unit] = owner
        return owner
    end

    local pm = Managers.player
    if not pm then return nil end
    for _, p in pairs(pm:players()) do
        if p.player_unit == unit then
            _unit_to_player[unit] = p
            return p
        end
    end
    return nil
end

local function _account_id(player)
    return player:account_id() or player:name()
end

function mod._retire_player_unit(aid, unit)
    _state_tracker[aid] = nil
    _disabled_tracker[aid] = nil
    _combat_ability_charges[aid] = nil
    mod._damage_taken_unit_by_account[aid] = nil

    if unit then
        _unit_to_player[unit] = nil
        mod.current_ammo[unit] = nil
        for pickup_unit, pending in pairs(mod.pending_ammo_pickups) do
            if pending.player_unit == unit then
                mod.pending_ammo_pickups[pickup_unit] = nil
            end
        end
    end
end

function mod._baseline_player_unit(aid, player, unit, previous_unit)
    mod._retire_player_unit(aid, previous_unit)
    if not unit or not ScriptUnit then return end

    _unit_to_player[unit] = player
    local health = ScriptUnit.has_extension(unit, "health_system")
    local damage = health and health._damage
    if _Stats and type(damage) == "number" and _Stats.rebaseline_diff("damage_taken", aid, damage) then
        mod._damage_taken_unit_by_account[aid] = unit
    end

    local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
    if not unit_data then return end

    local character_state = unit_data:read_component("character_state")
    _state_tracker[aid] = character_state and character_state.state_name or nil

    if unit_data:has_component("disabled_character_state") then
        local disabled = unit_data:read_component("disabled_character_state")
        local state_name = disabled and disabled.disabling_type
        if state_name and state_name ~= "none" then
            _disabled_tracker[aid] = {
                state_name = state_name,
                disabling_unit = disabled.disabling_unit,
                player_aid = aid,
                credited = true,
            }
        end
    end
end

function mod._sync_player_roster(players)
    local current = {}
    local changed = false

    for _, player in pairs(players or {}) do
        local aid = _account_id(player)
        if aid then
            local unit = player.player_unit
            current[aid] = { player = player, unit = unit }
            local previous = mod._player_roster[aid]
            if not previous or previous.player ~= player or previous.unit ~= unit then
                changed = true
                mod._baseline_player_unit(aid, player, unit, previous and previous.unit)
            end
        end
    end

    for aid, previous in pairs(mod._player_roster) do
        if not current[aid] then
            changed = true
            mod._retire_player_unit(aid, previous.unit)
        end
    end

    mod._player_roster = current
    if changed then
        _runtime_stat_revision = _runtime_stat_revision + 1
        local ui = Managers.ui
        local view = ui and ui:view_instance("another_scoreboard_view")
        if view and view._build and not (view._context and view._context.scoreboard_history)
                and (not ui.is_view_closing or not ui:is_view_closing("another_scoreboard_view")) then
            view:_build()
        end
    end

    return changed
end

function mod._record_damage_taken(unit, player, damage)
    if not _Stats or type(damage) ~= "number" or damage <= 0 then return end

    local aid = _account_id(player)
    if mod._damage_taken_unit_by_account[aid] ~= unit then
        _Stats.rebaseline_diff("damage_taken", aid, damage)
        mod._damage_taken_unit_by_account[aid] = unit
    else
        _Stats.record("damage_taken", aid, damage)
    end
end

function mod.order_scoreboard_players(players)
    if not _settings.local_player_first or not players or #players < 2 then
        return players
    end

    local player_manager = Managers.player
    local local_player = player_manager and player_manager:local_player_safe(1)
    if not local_player then
        return players
    end

    local local_player_id = _account_id(local_player)
    local local_index

    for i = 1, #players do
        local player = players[i]
        if player == local_player or _account_id(player) == local_player_id then
            local_index = i
            break
        end
    end

    if not local_index or local_index == 1 then
        return players
    end

    local reordered = { players[local_index] }
    for i = 1, #players do
        if i ~= local_index then
            reordered[#reordered + 1] = players[i]
        end
    end

    return reordered
end

local function _gameplay_time()
    local time_manager = Managers.time

    return time_manager and time_manager:has_timer("gameplay") and time_manager:time("gameplay") or nil
end

local function _player_archetype_name(player)
    local profile = player and player:profile()

    return profile and profile.archetype and profile.archetype.name or nil
end

local function _recent_cryptic_attacker_account_id(unit, template_name)
    if not CRYPTIC_SOURCELESS_DEBUFFS[template_name] then
        return nil
    end

    local record = _recent_attack_by_unit[unit]
    local now = record and _gameplay_time()
    if not now or now - record.time > CRYPTIC_DEBUFF_ATTRIBUTION_WINDOW then
        return nil
    end

    return record.archetype_name == "cryptic" and record.account_id or nil
end

local function _buff_owner_unit(...)
    local num_args = select("#", ...)

    for i = 1, num_args - 1, 2 do
        if select(i, ...) == "owner_unit" then
            return select(i + 1, ...)
        end
    end

    return nil
end

local function _debuff_group_active(buff_extension, group)
    local template_names = DEBUFF_TEMPLATES_BY_GROUP[group]

    for i = 1, #template_names do
        if buff_extension:has_buff_using_buff_template(template_names[i]) then
            return true
        end
    end

    return false
end

local function _template_has_stat_buff(template, stat_name)
    local stat_buffs = template.stat_buffs
    local conditional_stat_buffs = template.conditional_stat_buffs

    return stat_buffs and stat_buffs[stat_name] ~= nil
        or conditional_stat_buffs and conditional_stat_buffs[stat_name] ~= nil
end

local function _template_keyword_group(template)
    local keywords = template.keywords
    if not keywords then
        return nil
    end

    for key, value in pairs(keywords) do
        local keyword = type(key) == "number" and value or key
        local group = DEBUFF_GROUP_BY_KEYWORD[keyword]

        if group then
            return group
        end
    end

    return nil
end

local function _register_debuff_template(template_name, group)
    DEBUFF_GROUP_BY_TEMPLATE[template_name] = group

    local template_names = DEBUFF_TEMPLATES_BY_GROUP[group]
    if not template_names then
        template_names = {}
        DEBUFF_TEMPLATES_BY_GROUP[group] = template_names
    end

    template_names[#template_names + 1] = template_name
end

local function _debuff_group_for_template(template, player_owned)
    local template_name = template and template.name
    if not template_name then
        return nil
    end

    local group = DEBUFF_GROUP_BY_TEMPLATE[template_name]
    if group then
        return group
    end

    if _template_has_stat_buff(template, "rending_multiplier") then
        group = "brittleness"
    elseif _template_has_stat_buff(template, "melee_damage_taken_modifier")
            or _template_has_stat_buff(template, "melee_damage_taken_multiplier") then
        group = "melee_damage_taken"
    elseif _template_has_stat_buff(template, "damage_taken_modifier")
            or _template_has_stat_buff(template, "damage_taken_multiplier") then
        group = "damage_taken"
    else
        group = _template_keyword_group(template)
    end

    if not group and (player_owned or string_find(template_name, "debuff", 1, true)) then
        group = "template:" .. template_name
    end

    if group then
        _register_debuff_template(template_name, group)
    end

    return group
end

local function _is_coherency_eligible(unit)
    if not _is_alive_unit(unit) then
        return false
    end

    local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
    if not unit_data_extension then
        return false
    end

    local character_state = unit_data_extension:read_component("character_state")
    local state_name = character_state and character_state.state_name

    return state_name and state_name ~= "dead" and state_name ~= "hogtied"
end

local function _read_combat_ability_charges(unit)
    if not _is_alive_unit(unit) then
        return nil, nil
    end

    ---@type AbilityChargeUnitDataExtension?
    local unit_data_extension = unit and ScriptUnit.has_extension(unit, "unit_data_system")
    if not unit_data_extension or not unit_data_extension._game_session then
        return nil, nil
    end

    local game_session = unit_data_extension._game_session
    local game_object_id = unit_data_extension._server_data_state_game_object_id
    if type(game_object_id) ~= "number" or not GameSession.game_object_exists(game_session, game_object_id) then
        game_object_id = unit_data_extension._server_husk_hud_data_state_game_object_id
    end

    if type(game_object_id) ~= "number" or not GameSession.game_object_exists(game_session, game_object_id) then
        return nil, nil
    end

    local charges = GameSession.game_object_field(game_session, game_object_id, COMBAT_ABILITY_CHARGES_FIELD)

    return type(charges) == "number" and charges or nil, game_object_id
end

local function _sample_combat_ability_uses(players)
    if not _Stats then
        return
    end

    for _, player in pairs(players) do
        local aid = _account_id(player)
        if aid then
            local unit = player.player_unit
            local charges, game_object_id = _read_combat_ability_charges(unit)
            local previous = _combat_ability_charges[aid]

            if charges ~= nil then
                if previous
                        and previous.unit == unit
                        and previous.game_object_id == game_object_id
                        and charges < previous.charges then
                    _Stats.record("combat_ability_uses", aid, 1)
                    _runtime_stat_revision = _runtime_stat_revision + 1
                    mod._forced_assist.on_ability_used(player, aid, _gameplay_time())
                end

                _combat_ability_charges[aid] = {
                    unit = unit,
                    game_object_id = game_object_id,
                    charges = charges,
                }
            else
                _combat_ability_charges[aid] = nil
            end
        end
    end
end

local function _aggro_record(enemy_unit, breed)
    local record = _enemy_aggro_targets[enemy_unit]
    if not record then
        local tags = breed and breed.tags
        record = {
            credited = {},
            threshold_credited = { [4] = {}, [8] = {}, [12] = {}, [20] = {} },
            credited_count = 0,
            is_boss = breed and (breed.is_boss or tags and tags.monster) or false,
        }
        _enemy_aggro_targets[enemy_unit] = record
        _aggro_diagnostics.tracked_enemies = _aggro_diagnostics.tracked_enemies + 1
    end

    return record
end

local function _finish_aggro_sequence(record)
    local aid = record.candidate_aid
    local samples = record.candidate_samples or 0

    if aid then
        for i = 1, #AGGRO_DIAGNOSTIC_THRESHOLDS do
            local threshold = AGGRO_DIAGNOSTIC_THRESHOLDS[i]
            local threshold_credited = record.threshold_credited[threshold]
            if samples >= threshold and not threshold_credited[aid] then
                threshold_credited[aid] = true
                _aggro_diagnostics.threshold_pairs[threshold] = _aggro_diagnostics.threshold_pairs[threshold] + 1
            end
        end

        if samples < AGGRO_DEATH_FALLBACK_SAMPLES then
            _aggro_diagnostics.rejected_short_sequences = _aggro_diagnostics.rejected_short_sequences + 1
        elseif not record.credited[aid] then
            local best = record.fallback
            if not best or samples > best.samples or samples == best.samples and record.candidate_order < best.order then
                record.fallback = {
                    aid = aid,
                    samples = samples,
                    order = record.candidate_order,
                }
            end
        end
    end

    record.candidate_target_id = nil
    record.candidate_aid = nil
    record.candidate_samples = 0
    record.candidate_order = nil
end

local function _credit_enemy_aggro(record, aid, reason)
    if not aid or record.credited[aid] then
        return false
    end

    if record.credited_count > 0 then
        _aggro_diagnostics.confirmed_switches = _aggro_diagnostics.confirmed_switches + 1
    else
        _aggro_diagnostics.credited_enemies = _aggro_diagnostics.credited_enemies + 1
    end

    record.credited[aid] = true
    record.credited_count = record.credited_count + 1
    record.fallback = nil
    _Stats.record("enemies_aggroed", aid, 1)
    _runtime_stat_revision = _runtime_stat_revision + 1
    _aggro_diagnostics.awarded_pairs = _aggro_diagnostics.awarded_pairs + 1
    _aggro_diagnostics[reason .. "_credits"] = _aggro_diagnostics[reason .. "_credits"] + 1

    return true
end

local function _finalize_enemy_aggro(enemy_unit)
    local record = _enemy_aggro_targets[enemy_unit]
    _aggro_diagnostics.deaths_seen = _aggro_diagnostics.deaths_seen + 1
    if not record then
        _aggro_diagnostics.deaths_without_tracking = _aggro_diagnostics.deaths_without_tracking + 1
        return
    end

    _finish_aggro_sequence(record)

    if record.credited_count == 0 and record.fallback then
        _credit_enemy_aggro(record, record.fallback.aid, "death_fallback")
    end

    local credited_count = math.min(record.credited_count, 4)
    _aggro_diagnostics.finalized_enemies = _aggro_diagnostics.finalized_enemies + 1
    _aggro_diagnostics.finalized_by_player_count[credited_count] =
        _aggro_diagnostics.finalized_by_player_count[credited_count] + 1
    _enemy_aggro_targets[enemy_unit] = nil
end

local function _discard_enemy_aggro(enemy_unit)
    local record = _enemy_aggro_targets[enemy_unit]
    if record then
        _finish_aggro_sequence(record)
        _aggro_diagnostics.despawned_enemies = _aggro_diagnostics.despawned_enemies + 1
        _enemy_aggro_targets[enemy_unit] = nil
    end
end

local function _sample_enemy_aggro()
    if not _Stats then
        return
    end

    local state = Managers.state
    local player_manager = Managers.player
    local local_player = player_manager and player_manager:local_player_safe(1)
    local local_player_unit = local_player and local_player.player_unit
    local extension_manager = state and state.extension
    local unit_spawner = state and state.unit_spawner
    local game_session_manager = state and state.game_session
    local game_session = game_session_manager and game_session_manager:game_session()

    if not _is_alive_unit(local_player_unit) or not extension_manager or not unit_spawner or not game_session then
        return
    end

    local side_system = extension_manager:system("side_system")
    local player_side = side_system and side_system.side_by_unit and side_system.side_by_unit[local_player_unit]
    local hostile_units = player_side and player_side:relation_units("enemy")
    if not hostile_units then
        return
    end

    local account_id_by_target_id = {}
    for _, player in pairs(player_manager:human_players() or {}) do
        local unit = player.player_unit
        local target_id = unit and unit_spawner:game_object_id(unit)
        if target_id then
            account_id_by_target_id[target_id] = _account_id(player)
        end
    end

    local baseline = _aggro_baseline_pending
    for i = 1, #hostile_units do
        local enemy_unit = hostile_units[i]
        if Unit.alive(enemy_unit) and HEALTH_ALIVE[enemy_unit] then
            local game_object_id = unit_spawner:game_object_id(enemy_unit)
            if game_object_id and GameSession.has_game_object_field(game_session, game_object_id, "target_unit_id") then
                local target_id = GameSession.game_object_field(game_session, game_object_id, "target_unit_id")
                local unit_data_extension = ScriptUnit.has_extension(enemy_unit, "unit_data_system")
                local breed = unit_data_extension and unit_data_extension:breed()
                local record = _aggro_record(enemy_unit, breed)
                local aid = account_id_by_target_id[target_id]

                if record.candidate_target_id == target_id and record.candidate_aid == aid then
                    record.candidate_samples = record.candidate_samples + 1
                else
                    _finish_aggro_sequence(record)
                    _aggro_sequence_order = _aggro_sequence_order + 1
                    record.candidate_target_id = target_id
                    record.candidate_aid = aid
                    record.candidate_samples = 1
                    record.candidate_order = _aggro_sequence_order
                end

                if baseline and aid then
                    record.credited[aid] = true
                    record.credited_count = record.credited_count + 1
                elseif aid and not record.credited[aid] then
                    ---@type BuffExtensionBase?
                    local buff_extension = ScriptUnit.has_extension(enemy_unit, "buff_system")
                    local taunter_unit = buff_extension and buff_extension:owner_of_buff_with_id("taunted")
                    local taunter = taunter_unit and _player_from_unit(taunter_unit)
                    local taunter_aid = taunter and _account_id(taunter)
                    local confirm_samples = record.is_boss and AGGRO_BOSS_CONFIRM_SAMPLES
                        or record.credited_count == 0 and AGGRO_INITIAL_CONFIRM_SAMPLES
                        or AGGRO_SWITCH_CONFIRM_SAMPLES
                    local reason = record.is_boss and "boss" or "normal"

                    if taunter_aid == aid then
                        confirm_samples = AGGRO_TAUNT_CONFIRM_SAMPLES
                        reason = "taunt"
                    end

                    if record.candidate_samples >= confirm_samples then
                        _credit_enemy_aggro(record, aid, reason)
                    end
                end

                if aid then
                    for threshold, threshold_credited in pairs(record.threshold_credited) do
                        if record.candidate_samples >= threshold and not threshold_credited[aid] then
                            threshold_credited[aid] = true
                            _aggro_diagnostics.threshold_pairs[threshold] = _aggro_diagnostics.threshold_pairs[threshold] + 1
                        end
                    end
                end
            end
        end
    end

    _aggro_baseline_pending = false
end

local function _is_hub()
    local gm = Managers.state and Managers.state.game_mode
    return gm and gm:game_mode_name() == "hub"
end

local function _can_open_scoreboard_history()
    local game_mode = Managers.state and Managers.state.game_mode
    local game_mode_name = game_mode and game_mode:game_mode_name()

    return game_mode_name == "hub" or game_mode_name == "shooting_range"
end

local function _request_history_preload()
    _history_preload_done = false
    _history_preload_delay = 1.0
end

local function _update_history_preload(dt)
    if _history_preload_done or not _History then
        return
    end

    _history_preload_delay = _history_preload_delay - dt
    if _history_preload_delay > 0 then
        return
    end

    _History.refresh_cache(true)
    _history_preload_done = true
end

local function _update_history(dt)
    if _History and _History.update then
        _History.update(dt)
    end
end

local function _is_in_mission()
    local presence = Managers.presence
    local state_name = presence and presence._current_game_state_name

    if state_name ~= "StateGameplay" then
        return false
    end

    return not _is_hub()
end

local DISABLED_STATES = {
    netted          = true,  -- trapper
    pounced         = true,  -- hound
    mutant_charged  = true,  -- mutant charge
    warp_grabbed    = true,  -- mutant grab
    consumed        = true,  -- Beast of Nurgle
    grabbed         = true,  -- Chaos Spawn
    vortex_grabbed  = true,  -- vortex attacks
}

local function _credit_disabled_help(event, helper_aid)
    if not event or event.credited or not helper_aid or helper_aid == event.player_aid or not _Stats then
        return
    end

    event.credited = true
    _Stats.record("disabled_helped", helper_aid, 1)
end

local function _finish_player_disabled(unit, aid)
    local event = _disabled_tracker[aid]
    if event and event.state_name == "pounced" and _is_alive_unit(unit) then
        -- Hound saves are credited by the game to the hound's last damaging player.
        local disabling_unit = event.disabling_unit
        local helper_aid = disabling_unit and mod._last_hitter_account_id[disabling_unit]
        _credit_disabled_help(event, helper_aid)
    end

    _disabled_tracker[aid] = nil
end

local function _track_player_disabled(unit, state_name, disabling_unit)
    if not state_name then return end
    local p = _player_from_unit(unit)
    if not p then return end
    local aid = _account_id(p)
    local prev = _disabled_tracker[aid]
    if (not prev or prev.state_name ~= state_name) and DISABLED_STATES[state_name] and _Stats then
        _Stats.record("times_disabled", aid, 1)
        _disabled_tracker[aid] = {
            state_name = state_name,
            disabling_unit = disabling_unit,
            player_aid = aid,
            credited = false,
        }
    elseif prev and not prev.disabling_unit then
        prev.disabling_unit = disabling_unit
    end
end

local function _track_player_state(unit, state_name)
    if not state_name then return end
    local p = _player_from_unit(unit)
    if not p then return end
    local aid = _account_id(p)
    local prev = _state_tracker[aid]
    if prev ~= state_name then
        _state_tracker[aid] = state_name
        if (state_name == "knocked_down" or state_name == "dead") and _Stats then
            _Stats.record("downs_and_deaths", aid, 1)
            _Stats.record(state_name == "knocked_down" and "downs" or "deaths", aid, 1)
        end
    end
end

function mod.get_stats()
    return _Stats
end

function mod.get_render()
    return _Render
end

function mod.get_history()
    return _History
end

function mod.open_player_social(account_id)
    if mod._social then
        return mod._social.request(account_id)
    end

    return false
end

local function _scoreboard_render_settings()
    return {
        scale = _settings.scale,
        text_scale = _settings.text_scale,
        alternating_row_shading = _settings.alternating_row_shading,
        horizontal_offset = _settings.horizontal_offset,
        vertical_offset = _settings.vertical_offset,
        title_text = mod.get_scoreboard_title_text and mod.get_scoreboard_title_text() or nil,
        theme = _settings.scoreboard_theme,
    }
end

function mod.open_scoreboard_history()
    local ui = Managers.ui
    if not ui or not _can_open_scoreboard_history() then
        return
    end

    local view_name = "another_scoreboard_history_view"
    local scoreboard_view_name = "another_scoreboard_view"

    if ui:view_active(view_name)
        and not ui:is_view_closing(view_name)
        and ui:view_active(scoreboard_view_name)
        and not ui:is_view_closing(scoreboard_view_name) then
        ui:close_view(scoreboard_view_name, true)
        return
    end

    if ui:view_active(view_name) and not ui:is_view_closing(view_name) then
        ui:close_view(view_name, true)
    else
        ui:open_view(view_name, nil, false, false, nil, {}, { use_transition_ui = false })
    end
end

function mod.get_cached_settings()
    return _settings
end

local function _is_effectiveness_section(section)
    local category = section and section.category
    return category and (
        category.key == "effectiveness" or
        category.label == "cat_effectiveness" or
        category.label == "<cat_effectiveness>"
    )
end

local function _is_effectiveness_row(row)
    return row and (
        row.id == "effectiveness_score" or
        row.label == "row_effectiveness_score" or
        row.label == "eff_row_category_scores" or
        row.label == "<row_effectiveness_score>" or
        row.label == "<eff_row_category_scores>"
    )
end

local function _section_key(section)
    local category = section and section.category
    if not category then
        return nil
    end

    if category.key then
        return category.key
    elseif category.label == "cat_combat" or category.label == "<cat_combat>" then
        return "combat"
    elseif category.label == "cat_survival" or category.label == "<cat_survival>" then
        return "survival"
    elseif category.label == "cat_performance" or category.label == "<cat_performance>" then
        return "performance"
    end

    return nil
end

local function _utility_heading()
    return {
        id = "history_utility",
        label = "row_utility",
        style = "main",
        no_values = true,
    }
end

local function _survivability_heading()
    return {
        id = "history_survivability",
        label = "row_survivability",
        style = "main",
        no_values = true,
    }
end

local function _has_row(rows, row_id)
    for i = 1, #rows do
        if rows[i].id == row_id then
            return true
        end
    end

    return false
end

local function _insert_survivability_heading(rows)
    if _has_row(rows, "survivability") then
        return
    end

    for i = 1, #rows do
        if rows[i].id == "damage_taken" then
            table.insert(rows, i, _survivability_heading())
            return
        end
    end
end

local function _append_utility_rows(section, rows)
    if section and #rows > 0 then
        section.rows[#section.rows + 1] = _utility_heading()

        for i = 1, #rows do
            section.rows[#section.rows + 1] = rows[i]
        end
    end
end

local ALPHABETICAL_ROW_PARENTS = {
    "specials_killed",
    "elites_killed",
    "dot_damage",
    "damage_to_bosses",
}

local SCOREBOARD_HEADING_CHILDREN = {
    damage_details = { "dot_damage", "companion_damage", "damage_to_bosses" },
    combat_utility = { "headshots", "critical_hits", "enemies_staggered", "debuffs_applied" },
    survivability = { "damage_taken", "downs_and_deaths", "times_disabled", "healthstation_uses" },
    survival_utility = { "combat_ability_uses", "enemies_aggroed", "coherency_uptime" },
}

local function _scoreboard_stat_visible(stat_id)
    return not SCOREBOARD_STAT_SETTING_BY_ID[stat_id]
        or _settings.scoreboard_stat_visibility[stat_id] ~= false
end

local function _scoreboard_heading_visible(row_id)
    local child_ids = SCOREBOARD_HEADING_CHILDREN[row_id]
    if not child_ids then
        return nil
    end

    for i = 1, #child_ids do
        if _scoreboard_stat_visible(child_ids[i]) then
            return true
        end
    end

    return false
end

function mod.scoreboard_detail_available(detail)
    if detail == "enemy" then
        return _scoreboard_stat_visible("lesser_enemies_killed")
            or _scoreboard_stat_visible("specials_killed")
            or _scoreboard_stat_visible("elites_killed")
    elseif detail == "dot" then
        return _scoreboard_stat_visible("dot_damage")
    elseif detail == "boss" then
        return _scoreboard_stat_visible("damage_to_bosses")
    elseif detail == "survival" then
        return _scoreboard_stat_visible("downs_and_deaths")
            or _scoreboard_stat_visible("times_disabled")
            or _scoreboard_stat_visible("combat_ability_uses")
    end

    return false
end

function mod.get_scoreboard_hint_text(show_enemy_details, show_dot_details, show_boss_details, show_survival_details, history)
    local parts = {}

    if history then
        parts[#parts + 1] = mod:localize("scoreboard_hint_back")
    end

    local show_lesser = _scoreboard_stat_visible("lesser_enemies_killed")
    local show_specials = _scoreboard_stat_visible("specials_killed")
    local show_elites = _scoreboard_stat_visible("elites_killed")
    if show_lesser or show_specials or show_elites then
        local hint_id
        if show_lesser then
            hint_id = show_enemy_details and "scoreboard_hint_hide_enemy_details" or "scoreboard_hint_enemy_details"
        elseif show_specials and show_elites then
            hint_id = show_enemy_details and "scoreboard_hint_hide_specials_elites" or "scoreboard_hint_specials_elites"
        elseif show_specials then
            hint_id = show_enemy_details and "scoreboard_hint_hide_specials" or "scoreboard_hint_specials"
        else
            hint_id = show_enemy_details and "scoreboard_hint_hide_elites" or "scoreboard_hint_elites"
        end
        parts[#parts + 1] = mod:localize(hint_id)
    end

    if _scoreboard_stat_visible("dot_damage") then
        parts[#parts + 1] = mod:localize(show_dot_details and "scoreboard_hint_hide_dot" or "scoreboard_hint_dot")
    end

    if _scoreboard_stat_visible("damage_to_bosses") then
        parts[#parts + 1] = mod:localize(show_boss_details and "scoreboard_hint_hide_boss" or "scoreboard_hint_boss")
    end

    local show_downs_deaths = _scoreboard_stat_visible("downs_and_deaths")
    local show_disabled = _scoreboard_stat_visible("times_disabled")
    local show_ability_rate = _scoreboard_stat_visible("combat_ability_uses")
    if show_downs_deaths or show_disabled or show_ability_rate then
        local hint_id
        if show_disabled or (show_downs_deaths and show_ability_rate) then
            hint_id = show_survival_details and "scoreboard_hint_hide_survival_details" or "scoreboard_hint_survival_details"
        elseif show_downs_deaths then
            hint_id = show_survival_details and "scoreboard_hint_hide_downs_deaths" or "scoreboard_hint_downs_deaths"
        else
            hint_id = show_survival_details and "scoreboard_hint_hide_ability_rate" or "scoreboard_hint_ability_rate"
        end
        parts[#parts + 1] = mod:localize(hint_id)
    end

    if not history then
        parts[#parts + 1] = mod:localize("scoreboard_hint_end_hide")
    end

    return table.concat(parts, "  |  ")
end

local function _scoreboard_row_sort_text(row)
    local text

    if row.engine_localization_key then
        local ok, localized = pcall(Localize, row.engine_localization_key)
        if ok and localized and localized ~= "" then
            text = localized
        end
    end

    text = text or row.label_text

    if not text and row.label then
        text = mod:localize(row.label)
    end

    if not text or text == "<>" or text:match("^<.*>$") then
        text = row.label or row.id or ""
    end

    return string.lower(text)
end

local function _sort_scoreboard_detail_rows(rows)
    for _, parent_id in ipairs(ALPHABETICAL_ROW_PARENTS) do
        local indices = {}
        local detail_rows = {}

        for index, row in ipairs(rows) do
            if row.parent == parent_id then
                indices[#indices + 1] = index
                detail_rows[#detail_rows + 1] = row
            end
        end

        table.sort(detail_rows, function(a, b)
            local a_text = _scoreboard_row_sort_text(a)
            local b_text = _scoreboard_row_sort_text(b)

            if a_text == b_text then
                return tostring(a.id or "") < tostring(b.id or "")
            end

            return a_text < b_text
        end)

        for index, row_index in ipairs(indices) do
            rows[row_index] = detail_rows[index]
        end
    end
end

local function _ability_rate_row(row, duration)
    local source = row.values or _Stats and _Stats.data_for("combat_ability_uses") or {}
    local values = {}
    local minutes = type(duration) == "number" and duration > 0 and duration / 60 or nil

    for aid, entry in pairs(source) do
        local score = type(entry) == "table" and (entry.score or entry.value or 0) or entry or 0
        values[aid] = {
            score = minutes and score / minutes or 0,
            best = type(entry) == "table" and (entry.best or entry.is_best) or false,
            worst = type(entry) == "table" and (entry.worst or entry.is_worst) or false,
        }
    end

    return {
        id = "combat_ability_uses_per_minute",
        label = "row_combat_ability_uses_per_minute",
        parent = "combat_ability_uses",
        depth = (row.depth or 1) + 1,
        style = "sub",
        decimals = 1,
        suffix = "/min",
        values = values,
    }
end

local function _ability_average_time_row(row, duration)
    local source = row.values or _Stats and _Stats.data_for("combat_ability_uses") or {}
    local values = {}
    local seconds = type(duration) == "number" and duration > 0 and duration or nil

    for aid, entry in pairs(source) do
        local score = type(entry) == "table" and (entry.score or entry.value or 0) or entry or 0
        values[aid] = {
            score = seconds and score > 0 and seconds / score or 0,
            best = type(entry) == "table" and (entry.best or entry.is_best) or false,
            worst = type(entry) == "table" and (entry.worst or entry.is_worst) or false,
        }
    end

    return {
        id = "combat_ability_average_time",
        label = "row_combat_ability_average_time",
        parent = "combat_ability_uses",
        depth = (row.depth or 1) + 1,
        style = "sub",
        decimals = 1,
        suffix = "s",
        zero_text = "--",
        values = values,
    }
end

local function _configure_hit_percentage(row)
    local enabled
    if row.id == "headshots" then
        enabled = _settings.show_weakspot_percentage
    elseif row.id == "critical_hits" then
        enabled = _settings.show_critical_percentage
    else
        return
    end

    local percentage_values
    if row.values then
        percentage_values = row.percentage_values
    elseif _Stats and _Stats.hit_percentage_values then
        percentage_values = _Stats.hit_percentage_values(row.id)
    end

    row.show_percentage = enabled and percentage_values ~= nil
    row.display_percentage_values = row.show_percentage and percentage_values or nil
    row.rate_label = row.show_percentage
end

local function _append_ability_detail_rows(rows, row, show_survival_details, duration)
    if row.id == "combat_ability_uses" and show_survival_details then
        rows[#rows + 1] = _ability_rate_row(row, duration)
        rows[#rows + 1] = _ability_average_time_row(row, duration)
    end
end

local function _filter_scoreboard_sections(sections, show_all_enemy_rows, show_all_dot_rows, show_boss_details,
        show_survival_details, duration)
    local filtered_sections = {}
    local combat_section = nil
    local survival_section = nil
    local combat_utility_rows = {}
    local survival_utility_rows = {}

    for _, section in ipairs(sections) do
        if not _is_effectiveness_section(section) then
            local section_key = _section_key(section)
            local rows = {}
            local external_parents = {}
            for _, row in ipairs(section.rows) do
                if row.external_group and row.parent then external_parents[row.parent] = true end
            end

            for _, row in ipairs(section.rows) do
                local enemy_detail = _Stats and _Stats.is_enemy_detail(row.id)
                local dot_detail = _Stats and _Stats.is_dot_detail(row.id)
                local enemy_row_visible = show_all_enemy_rows or not enemy_detail
                local dot_row_visible = show_all_dot_rows or not dot_detail
                local boss_row_visible = show_boss_details or not row.boss_detail
                local survival_detail = row.parent == "downs_and_deaths" or row.parent == "times_disabled"
                local survival_row_visible = show_survival_details or not survival_detail
                local visibility_stat_id = row.id
                if enemy_detail then
                    visibility_stat_id = row.parent
                elseif dot_detail then
                    visibility_stat_id = "dot_damage"
                elseif row.boss_detail then
                    visibility_stat_id = "damage_to_bosses"
                elseif survival_detail then
                    visibility_stat_id = row.parent
                end

                local heading_visible = _scoreboard_heading_visible(row.id)
                if external_parents[row.id] then heading_visible = true end
                local setting_visible = heading_visible == nil and _scoreboard_stat_visible(visibility_stat_id)
                    or heading_visible
                local row_visible = enemy_row_visible and dot_row_visible and boss_row_visible
                    and survival_row_visible and setting_visible

                local removed_row = row.id == "killed_by_other"
                    or row.id == "elite_radio_operator_killed"
                    or row.id == "dot_electrocution_damage"

                if not removed_row and row_visible and not _is_effectiveness_row(row) then
                    _configure_hit_percentage(row)
                    if section_key == "performance" then
                        if row.id == "headshots" or row.id == "enemies_staggered" then
                            combat_utility_rows[#combat_utility_rows + 1] = row
                        elseif row.id == "combat_ability_uses" or row.id == "enemies_aggroed" or row.id == "coherency_uptime" then
                            survival_utility_rows[#survival_utility_rows + 1] = row
                            _append_ability_detail_rows(survival_utility_rows, row, show_survival_details, duration)
                        end
                    else
                        rows[#rows + 1] = row
                        _append_ability_detail_rows(rows, row, show_survival_details, duration)
                    end
                end
            end

            if section_key ~= "performance" and #rows > 0 then
                _sort_scoreboard_detail_rows(rows)

                local filtered_section = {
                    category = section.category,
                    rows = rows,
                }

                if section_key == "combat" then
                    combat_section = filtered_section
                elseif section_key == "survival" then
                    _insert_survivability_heading(rows)
                    survival_section = filtered_section
                end

                filtered_sections[#filtered_sections + 1] = filtered_section
            end
        end
    end

    _append_utility_rows(combat_section, combat_utility_rows)
    _append_utility_rows(survival_section, survival_utility_rows)

    return filtered_sections
end

function mod.filter_scoreboard_sections(sections, show_all_enemy_rows, show_all_dot_rows, show_boss_details,
        show_survival_details, duration)
    return _filter_scoreboard_sections(sections, show_all_enemy_rows, show_all_dot_rows, show_boss_details,
        show_survival_details, duration)
end

function mod.is_live_scoreboard_visible()
    if not mod:is_enabled() then
        return false
    end

    if not _settings.show_live_scoreboard then
        return false
    end

    if not _is_in_mission() then
        return false
    end

    if not _ensure_live_archetype() then
        return false
    end

    local ui = Managers.ui
    if ui and ui.allow_hud and not ui:allow_hud() then
        return false
    end

    return true
end

function mod.get_live_scoreboard_rows()
    if not _Stats then
        return nil
    end

    local player_manager = Managers.player
    if not player_manager then
        return nil
    end

    local rows = {}
    local local_aid = mod._me()
    local players = player_manager:human_players()

    for _, player in pairs(players) do
        local aid = _account_id(player)
        local values = {}
        local profile = type(player.profile) == "function" and player:profile()
        local archetype_name = profile and profile.archetype and profile.archetype.name

        for i = 1, _settings.live_scoreboard_stat_count do
            local stat = LIVE_STATS[_settings.live_scoreboard_stats[i]]
            local value = 0

            if stat.stat_id then
                local data = _Stats.data_for(stat.stat_id)
                local entry = data and data[aid]
                value = entry and entry.score or 0
            elseif stat.numerator_stat_id and stat.denominator_stat_id then
                local numerator_data = _Stats.data_for(stat.numerator_stat_id)
                local denominator_data = _Stats.data_for(stat.denominator_stat_id)
                local numerator_entry = numerator_data and numerator_data[aid]
                local denominator_entry = denominator_data and denominator_data[aid]
                local numerator = numerator_entry and numerator_entry.score or 0
                local denominator = denominator_entry and denominator_entry.score or 0
                value = denominator > 0 and numerator / denominator * 100 or 0
            else
                local coherency_time = _coherency_time[aid] or 0
                local eligible_time = _coherency_eligible_time[aid] or 0
                value = math_floor((coherency_time / math_max(eligible_time, 1)) * 100 + 0.5)
            end

            values[i] = value
        end

        rows[#rows + 1] = {
            aid = aid,
            name = player:name() or "Player",
            archetype_icon = archetype_name and UISettings.archetype_font_icon[archetype_name],
            values = values,
            is_self = aid == local_aid,
        }
    end

    return rows
end

function mod.get_live_scoreboard_columns()
    return _settings.live_scoreboard_columns
end

function mod.get_live_scoreboard_stat_count()
    return _settings.live_scoreboard_stat_count
end

function mod:get_stat_data(stat_id)
    return _Stats and _Stats.data_for(stat_id)
end

function mod.get_aggro_diagnostics()
    local result = {
        awarded_pairs = _aggro_diagnostics.awarded_pairs,
        credited_enemies = _aggro_diagnostics.credited_enemies,
        tracked_enemies = _aggro_diagnostics.tracked_enemies,
        normal_credits = _aggro_diagnostics.normal_credits,
        boss_credits = _aggro_diagnostics.boss_credits,
        taunt_credits = _aggro_diagnostics.taunt_credits,
        death_fallback_credits = _aggro_diagnostics.death_fallback_credits,
        rejected_short_sequences = _aggro_diagnostics.rejected_short_sequences,
        confirmed_switches = _aggro_diagnostics.confirmed_switches,
        deaths_seen = _aggro_diagnostics.deaths_seen,
        deaths_without_tracking = _aggro_diagnostics.deaths_without_tracking,
        finalized_enemies = _aggro_diagnostics.finalized_enemies,
        finalized_with_0_players = _aggro_diagnostics.finalized_by_player_count[0],
        finalized_with_1_player = _aggro_diagnostics.finalized_by_player_count[1],
        finalized_with_2_players = _aggro_diagnostics.finalized_by_player_count[2],
        finalized_with_3_players = _aggro_diagnostics.finalized_by_player_count[3],
        finalized_with_4_players = _aggro_diagnostics.finalized_by_player_count[4],
        despawned_enemies = _aggro_diagnostics.despawned_enemies,
        threshold_1s = _aggro_diagnostics.threshold_pairs[4],
        threshold_2s = _aggro_diagnostics.threshold_pairs[8],
        threshold_3s = _aggro_diagnostics.threshold_pairs[12],
        threshold_5s = _aggro_diagnostics.threshold_pairs[20],
        active_tracked_enemies = 0,
        scoreboard_total = 0,
        scoreboard_offset = 0,
        scoreboard_slots = { 0, 0, 0, 0 },
    }

    for _ in pairs(_enemy_aggro_targets) do
        result.active_tracked_enemies = result.active_tracked_enemies + 1
    end

    local player_manager = Managers.player
    local stat_data = _Stats and _Stats.data_for("enemies_aggroed")
    for _, player in pairs(player_manager and player_manager:human_players() or {}) do
        local slot = player.slot and player:slot()
        local aid = _account_id(player)
        local entry = stat_data and stat_data[aid]
        if slot and slot >= 1 and slot <= 4 then
            result.scoreboard_slots[slot] = entry and entry.score or 0
            result.scoreboard_total = result.scoreboard_total + result.scoreboard_slots[slot]
        end
    end

    result.scoreboard_offset = result.scoreboard_total - result.awarded_pairs

    return result
end

local function _update_coherency_stat(account_ids)
    if not account_ids then
        account_ids = {}
        local pm = Managers.player
        if not pm then return end
        for _, p in pairs(pm:players()) do
            local aid = p:account_id() or p:name()
            account_ids[aid] = true
        end
    end

    for aid in pairs(account_ids) do
        local ct = _coherency_time[aid] or 0
        local eligible = _coherency_eligible_time[aid] or 0
        mod.record_stat("coherency_uptime", aid, math_floor((ct / math_max(eligible, 1)) * 100 + 0.5))
    end
end

function mod.record_stat(stat_id, aid, value)
    if _Stats then
        _Stats.record(stat_id, aid, value)
    end
end

function mod._is_me(aid)
    local pm = Managers.player
    if not pm then return false end
    local p = pm:local_player_safe(1)
    return p and _account_id(p) == aid
end

function mod._me()
    local pm = Managers.player
    if not pm then return nil end
    local p = pm:local_player_safe(1)
    return p and _account_id(p)
end

local function _open_view(context)
    local ui = Managers.ui
    if ui:view_active("another_scoreboard_view") and not ui:is_view_closing("another_scoreboard_view") then
        ui:close_view("another_scoreboard_view", true)
    end
    ui:open_view("another_scoreboard_view", nil, false, false, nil, context or {}, { use_transition_ui = false })
end

local function _history_players()
    local players = {}

    if _end_player_snapshot then
        return _end_player_snapshot
    end

    local player_manager = Managers.player
    if not player_manager then
        return players
    end

    local count = 0
    for _, player in pairs(player_manager:players()) do
        count = count + 1
        if count <= 4 then
            local aid = _account_id(player)
            local profile = type(player.profile) == "function" and player:profile()
            local archetype_name = profile and profile.archetype and profile.archetype.name
            players[#players + 1] = {
                account_id = aid,
                name = player:name(),
                archetype_icon = archetype_name and UISettings.archetype_font_icon[archetype_name],
                loadout_snapshot = mod._loadout and mod._loadout.capture(profile),
                social_account_id = mod._social and mod._social.account_id_for_player(player) or nil,
            }
        end
    end

    return players
end

local function _sort_player_snapshot(players)
    table.sort(players, function(a, b)
        local a_slot = a.slot or math_huge
        local b_slot = b.slot or math_huge

        if a_slot ~= b_slot then
            return a_slot < b_slot
        end

        return tostring(a.account_id) < tostring(b.account_id)
    end)
end

local function _player_snapshot(player)
    if not player then
        return nil
    end

    local aid = _account_id(player)
    if not aid then
        return nil
    end

    local profile = type(player.profile) == "function" and player:profile()
    local archetype_name = profile and profile.archetype and profile.archetype.name

    return {
        account_id = aid,
        name = player:name(),
        archetype_icon = archetype_name and UISettings.archetype_font_icon[archetype_name],
        slot = type(player.slot) == "function" and player:slot() or nil,
        is_human = player:is_human_controlled(),
        loadout_snapshot = mod._loadout and mod._loadout.capture(profile),
        social_account_id = mod._social and mod._social.account_id_for_player(player) or nil,
    }
end

local function _capture_end_player_snapshot()
    if _end_player_snapshot then return end

    local player_manager = Managers.player
    if not player_manager then
        return
    end

    local snapshot = {}
    for _, player in pairs(player_manager:players()) do
        local record = _player_snapshot(player)
        if record then
            snapshot[#snapshot + 1] = record
        end
    end

    local time_manager = Managers.time
    if time_manager and time_manager:has_timer("main") then
        snapshot = mod._late_players.resolve(mod._late_departures, snapshot, time_manager:time("main"))
    end

    if #snapshot > 0 then
        _sort_player_snapshot(snapshot)

        while #snapshot > 4 do
            snapshot[#snapshot] = nil
        end

        _end_player_snapshot = snapshot
    end
end

local function _history_havoc_rank()
    local difficulty = Managers.state and Managers.state.difficulty
    local havoc_data = nil

    if difficulty and difficulty.get_parsed_havoc_data then
        local ok, parsed = pcall(difficulty.get_parsed_havoc_data, difficulty)
        if ok then
            havoc_data = parsed
        end
    end

    havoc_data = havoc_data or difficulty and difficulty._parsed_havoc_data

    if not havoc_data and _mission_metadata.havoc_data then
        local ok, parsed = pcall(Havoc.parse_data, _mission_metadata.havoc_data)
        if ok then
            havoc_data = parsed
        end
    end

    return havoc_data and havoc_data.havoc_rank
end

local function _history_duration()
    if _mission_elapsed_final then
        return _mission_elapsed_final
    end

    local tm = Managers.time
    if _mission_start_time and tm and tm:has_timer("gameplay") then
        return tm:time("gameplay") - _mission_start_time
    end

    return 0
end

function mod.get_scoreboard_duration()
    return _history_duration()
end

local function _is_expedition_mechanism_data(mechanism_data)
    return mechanism_data and (mechanism_data.current_location_index ~= nil or mechanism_data.node_id ~= nil or mechanism_data.settings_version ~= nil)
end

local function _matching_pending_mission_board_data(mission_name, mechanism_data)
    local data = _pending_mission_board_data
    _pending_mission_board_data = nil

    if not data or data.map ~= mission_name then
        return nil
    end

    if mechanism_data then
        if data.challenge and mechanism_data.challenge and data.challenge ~= mechanism_data.challenge then
            return nil
        end

        if data.resistance and mechanism_data.resistance and data.resistance ~= mechanism_data.resistance then
            return nil
        end
    end

    return data
end

local function _current_session_id()
    local connection = Managers.connection

    if connection and type(connection.matched_game_session_id) == "function" then
        local ok, session_id = pcall(connection.matched_game_session_id, connection)
        if ok and session_id and session_id ~= "" then
            return tostring(session_id)
        end
    end

    local party_immaterium = Managers.party_immaterium
    if party_immaterium and type(party_immaterium.current_game_session_id) == "function" then
        local ok, session_id = pcall(party_immaterium.current_game_session_id, party_immaterium)
        if ok and session_id and session_id ~= "" then
            return tostring(session_id)
        end
    end

    return nil
end

local function _current_mechanism_data()
    local mechanism = Managers.mechanism
    if not mechanism or type(mechanism.mechanism_data) ~= "function" then
        return nil
    end

    local ok, mechanism_data = pcall(mechanism.mechanism_data, mechanism)

    return ok and mechanism_data or nil
end

local function _current_mission_metadata(params, mechanism_data, pending_mission_board_data)
    mechanism_data = mechanism_data or _current_mechanism_data() or {}
    local use_existing = not params and not mechanism_data.mission_name

    local game_mode = Managers.state and Managers.state.game_mode
    local game_mode_name = game_mode and game_mode:game_mode_name() or nil
    local mission_name = params and params.mission_name or mechanism_data.mission_name or _mission_metadata.mission_name

    return {
        mission_name = mission_name,
        category = pending_mission_board_data and pending_mission_board_data.category or use_existing and _mission_metadata.category,
        circumstance_name = mechanism_data.circumstance_name or use_existing and _mission_metadata.circumstance_name,
        challenge = mechanism_data.challenge or use_existing and _mission_metadata.challenge,
        resistance = mechanism_data.resistance or use_existing and _mission_metadata.resistance,
        game_mode_name = game_mode_name or use_existing and _mission_metadata.game_mode_name,
        havoc_data = mechanism_data.havoc_data or use_existing and _mission_metadata.havoc_data,
        is_expedition = _is_expedition_mechanism_data(mechanism_data) == true or use_existing and _mission_metadata.is_expedition,
        outcome = _mission_metadata.outcome,
    }
end

local function _active_run_key(metadata)
    metadata = metadata or _current_mission_metadata()
    if not metadata.mission_name then
        return nil
    end

    return {
        session_id = _current_session_id(),
        mission_name = metadata.mission_name,
        circumstance_name = metadata.circumstance_name,
        challenge = metadata.challenge,
        resistance = metadata.resistance,
        game_mode_name = metadata.game_mode_name,
        is_expedition = metadata.is_expedition == true,
    }
end

local function _active_run_key_matches(saved_key, current_key)
    if type(saved_key) ~= "table" or type(current_key) ~= "table" then
        return false
    end

    if not current_key.mission_name then
        return nil
    end

    if saved_key.session_id and not current_key.session_id then
        return nil
    end

    return saved_key.session_id ~= nil
        and saved_key.session_id == current_key.session_id
        and saved_key.mission_name == current_key.mission_name
end

local function _active_run_mission_snapshot(metadata)
    metadata = metadata or {}

    return {
        mission_name = metadata.mission_name,
        category = metadata.category,
        circumstance_name = metadata.circumstance_name,
        challenge = metadata.challenge,
        resistance = metadata.resistance,
        game_mode_name = metadata.game_mode_name,
        is_expedition = metadata.is_expedition == true,
        outcome = metadata.outcome,
    }
end

local function _copy_number_map(source)
    local copy = {}

    if type(source) ~= "table" then
        return copy
    end

    for key, value in pairs(source) do
        if type(key) == "string" and type(value) == "number" and value == value and value ~= math_huge and value ~= -math_huge and value >= 0 then
            copy[key] = value
        end
    end

    return copy
end

local function _has_coherency_time()
    for _, value in pairs(_coherency_time) do
        if type(value) == "number" and value > 0 then
            return true
        end
    end

    for _, value in pairs(_coherency_eligible_time) do
        if type(value) == "number" and value > 0 then
            return true
        end
    end

    return false
end

local function _clear_active_run_snapshot()
    for key in pairs(_active_run_store) do
        _active_run_store[key] = nil
    end
    mod._active_run_prefix_pending = false
end

local function _restore_mission_elapsed(elapsed)
    elapsed = type(elapsed) == "number" and elapsed or 0
    if elapsed ~= elapsed or elapsed == math_huge or elapsed == -math_huge or elapsed < 0 then
        elapsed = 0
    end

    local tm = Managers.time

    if tm and tm:has_timer("gameplay") then
        _mission_start_time = tm:time("gameplay") - elapsed
        _mission_elapsed_final = nil
    else
        _mission_start_time = nil
        _mission_elapsed_final = elapsed
    end
end

local function _capture_active_run_snapshot(reason)
    if not _Stats or not _Stats.export_active_run or not _Stats.has_active_run_data then
        return false
    end

    if _scoreboard_history_saved then
        return false
    end

    if not _is_in_mission() and not _mission_metadata.mission_name then
        return false
    end

    if not _Stats.has_active_run_data() and not _has_coherency_time() then
        return false
    end

    local metadata = _current_mission_metadata()
    local run_key = _active_run_key(metadata)
    if not run_key or not run_key.session_id then
        return false
    end

    local stats = _Stats.export_active_run()
    local coherency_time = _copy_number_map(_coherency_time)
    local coherency_eligible_time = _copy_number_map(_coherency_eligible_time)
    local mission_elapsed = _history_duration()
    local previous = mod._active_run_prefix_pending and _active_run_store.snapshot or nil

    if type(previous) == "table" and previous.version == 1
            and _active_run_key_matches(previous.run_key, run_key) == true then
        if not _Stats.merge_active_run(previous.stats) then return false end
        for aid, seconds in pairs(_copy_number_map(previous.coherency_time)) do
            _coherency_time[aid] = (_coherency_time[aid] or 0) + seconds
        end
        for aid, seconds in pairs(_copy_number_map(previous.coherency_eligible_time)) do
            _coherency_eligible_time[aid] = (_coherency_eligible_time[aid] or 0) + seconds
        end
        local previous_elapsed = previous.mission_elapsed
        if type(previous_elapsed) ~= "number" or previous_elapsed ~= previous_elapsed
                or previous_elapsed == math_huge or previous_elapsed == -math_huge or previous_elapsed < 0 then
            previous_elapsed = 0
        end
        _restore_mission_elapsed(mission_elapsed + previous_elapsed)
        stats = _Stats.export_active_run()
        coherency_time = _copy_number_map(_coherency_time)
        coherency_eligible_time = _copy_number_map(_coherency_eligible_time)
        mission_elapsed = _history_duration()
        _runtime_stat_revision = _runtime_stat_revision + 1
        mod._late_players.merge(mod._late_departures, previous.late_departures)
    end

    _active_run_store.snapshot = {
        version = 1,
        reason = reason,
        run_key = run_key,
        mission = _active_run_mission_snapshot(metadata),
        mission_elapsed = mission_elapsed,
        coherency_time = coherency_time,
        coherency_eligible_time = coherency_eligible_time,
        stats = stats,
        late_departures = mod._late_players.merge({}, mod._late_departures),
    }
    mod._active_run_prefix_pending = false

    return true
end

local function _try_restore_active_run(metadata)
    if not mod._active_run_prefix_pending or not _Stats or not _Stats.merge_active_run then
        return false
    end

    local snapshot = _active_run_store.snapshot
    if snapshot == nil then
        return false
    end

    if type(snapshot) ~= "table" or snapshot.version ~= 1 then
        _clear_active_run_snapshot()
        return false
    end

    local current_key = _active_run_key(metadata)
    if not current_key then
        return false
    end

    local key_matches = _active_run_key_matches(snapshot.run_key, current_key)
    if key_matches == nil then
        return false
    end

    if not key_matches then
        _clear_active_run_snapshot()
        return false
    end

    local live_elapsed = _history_duration()
    local ok = _Stats.merge_active_run(snapshot.stats)
    if not ok then
        _clear_active_run_snapshot()
        return false
    end

    _aggro_baseline_pending = true

    for aid, seconds in pairs(_copy_number_map(snapshot.coherency_time)) do
        _coherency_time[aid] = (_coherency_time[aid] or 0) + seconds
    end

    local eligible_time = _copy_number_map(snapshot.coherency_eligible_time)
    local previous_elapsed = snapshot.mission_elapsed
    if next(eligible_time) == nil and type(previous_elapsed) == "number" and previous_elapsed >= 0 and previous_elapsed < math_huge then
        for aid in pairs(_coherency_time) do
            eligible_time[aid] = previous_elapsed
        end
    end
    for aid, seconds in pairs(eligible_time) do
        _coherency_eligible_time[aid] = (_coherency_eligible_time[aid] or 0) + seconds
    end

    if type(snapshot.mission) == "table" then
        _mission_metadata.category = snapshot.mission.category or _mission_metadata.category
        _mission_metadata.is_expedition = snapshot.mission.is_expedition or _mission_metadata.is_expedition
    end

    local saved_elapsed = snapshot.mission_elapsed
    if type(saved_elapsed) ~= "number" or saved_elapsed ~= saved_elapsed
            or saved_elapsed == math_huge or saved_elapsed == -math_huge or saved_elapsed < 0 then
        saved_elapsed = 0
    end
    _restore_mission_elapsed(saved_elapsed + live_elapsed)
    mod._late_players.merge(mod._late_departures, snapshot.late_departures)
    _clear_active_run_snapshot()

    return true
end

local function _try_restore_current_active_run()
    if not _is_in_mission() then
        return false
    end

    _mission_metadata = _current_mission_metadata()

    return _try_restore_active_run(_mission_metadata)
end

function mod.get_scoreboard_title_text(snapshot)
    local title = mod:localize("loc_another_scoreboard_view_display_name") or "Scoreboard"
    if not _History then
        return title
    end

    local mission_display
    local duration_display
    local custom_name

    if snapshot then
        custom_name = type(snapshot.custom_name) == "string" and snapshot.custom_name ~= "" and snapshot.custom_name or nil
        mission_display = snapshot.mission_display
        if not mission_display and snapshot.mission then
            mission_display = _History.mission_display(snapshot.mission)
        end

        duration_display = snapshot.duration_display
        if not duration_display then
            duration_display = _History.format_duration(snapshot.duration or 0)
        end
    else
        if not _mission_metadata.mission_name and not _mission_metadata.map_id then
            return title
        end

        mission_display = _History.mission_display(_mission_metadata)
        duration_display = _History.format_duration(_history_duration())
    end

    if not mission_display or mission_display == "" or not duration_display or duration_display == "" then
        return custom_name and string.format("%s - %s", title, custom_name) or title
    end

    if custom_name then
        return string.format("%s - %s - %s - %s %s", title, custom_name, mission_display,
            mod:localize("scoreboard_mission_time"), duration_display)
    end

    return string.format("%s - %s - %s %s", title, mission_display, mod:localize("scoreboard_mission_time"), duration_display)
end

local function _history_sections(players)
    if not _Stats then
        return nil
    end

    local ids = {}
    for i = 1, #players do
        ids[players[i].account_id] = true
    end

    _Stats.ensure_entries(ids)
    _update_coherency_stat(ids)
    _Stats.validate(ids)

    return _Stats.snapshot_sections(ids, _Stats.sections())
end

local function _save_history_snapshot(players)
    if _scoreboard_history_saved or not _History or not _Stats then
        return
    end

    players = players or _history_players()
    if #players == 0 then
        return
    end

    if mod:is_enabled() then
        local errors = mod.external_stats.collect(mod)
        for provider, err in pairs(errors) do
            mod:warning("External stats collector %s failed: %s", provider, err)
        end
    end
    local sections = _history_sections(players)
    if not sections then
        return
    end

    local mission = {
        mission_name = _mission_metadata.mission_name,
        map_id = _mission_metadata.mission_name,
        category = _mission_metadata.category,
        circumstance_name = _mission_metadata.circumstance_name,
        challenge = _mission_metadata.challenge,
        resistance = _mission_metadata.resistance,
        outcome = _mission_metadata.outcome,
        havoc_rank = _history_havoc_rank() or _mission_metadata.havoc_rank,
        havoc_data = _mission_metadata.havoc_data,
        is_expedition = _mission_metadata.is_expedition,
    }
    local game_mode = Managers.state and Managers.state.game_mode
    mission.game_mode_name = game_mode and game_mode:game_mode_name() or _mission_metadata.game_mode_name

    local saved = _History.save({
        duration = _history_duration(),
        mission = mission,
        players = players,
        sections = sections,
    })

    if saved then
        _scoreboard_history_saved = true
        _clear_active_run_snapshot()
    end
end

local function _close_view()
    local ui = Managers.ui
    if ui and ui:view_active("another_scoreboard_view") and not ui:is_view_closing("another_scoreboard_view") then
        ui:close_view("another_scoreboard_view", true)
    end
end

local function _cleanup_hud_widgets(hud, ui_renderer)
    if not hud or not hud._as_widgets then
        return
    end

    ui_renderer = ui_renderer or hud.ui_renderer and hud:ui_renderer() or hud._ui_renderer

    for i = 1, #hud._as_widgets do
        local w = hud._as_widgets[i]

        if ui_renderer then
            UIWidget.destroy(ui_renderer, w)
        end

        if hud._widgets_by_name then
            hud._widgets_by_name[w.name] = nil
        end

        if hud._unregister_widget_name then
            hud:_unregister_widget_name(w.name)
        end
    end

    hud._as_widgets = nil
    hud._as_title_widget = nil
    hud._as_title_max_font_size = nil
    hud._as_title_max_width = nil
    hud._as_runtime_stat_revision = nil

    if ui_renderer then
        UIRenderer.clear_scenegraph_queue(ui_renderer)
        UIRenderer.clear_render_pass_queue(ui_renderer)
    end
end

local function _cleanup_tactical_overlay_widgets()
    local hud = Managers.ui and Managers.ui:get_hud()
    local overlay = hud and hud:element("HudElementTacticalOverlay")
    local ui_renderer = hud and hud:ui_renderer()

    if overlay then
        overlay._as_temporarily_hidden = false
    end

    _cleanup_hud_widgets(overlay, ui_renderer)
end

local function _rebuild_hud(hud, ui_renderer)
    if not _Render or not _Stats then return end

    _cleanup_hud_widgets(hud, ui_renderer)
    hud._as_widgets = {}
    hud._as_title_widget = nil
    hud._as_runtime_stat_revision = _runtime_stat_revision
    hud._as_external_revision = mod.external_stats.revision
    hud._as_external_refresh_timer = 0.25

    local players, n = {}, 0
    local pm = Managers.player
    if not pm then return end
    for _, p in pairs(pm:players()) do
        n = n + 1
        if n <= 4 then players[#players + 1] = p end
    end
    if #players == 0 then return end

    players = mod.order_scoreboard_players(players)

    local ids = {}
    for i = 1, #players do
        ids[_account_id(players[i])] = true
    end
    _Stats.ensure_entries(ids)

    _update_coherency_stat(ids)
    _Stats.validate(ids)

    local sections = _filter_scoreboard_sections(_Stats.sections())
    sections = mod.external_stats.filter(sections, nil, mod.external_stats.details_expanded)
    local widgets = _Render.build_hud_widgets(hud, ui_renderer, players, sections, _scoreboard_render_settings())
    if widgets then
        hud._as_widgets = widgets
    end
end

local function _hook_minion_buff_extension(MinionBuffExtension)
    mod:hook(MinionBuffExtension, "_add_buff",
    function(func, self, template, t, from_server_correction, ...)
        local buff_context = self._buff_context
        local breed = buff_context and buff_context.breed

        if not breed or not Breed.is_minion(breed) then
            return func(self, template, t, from_server_correction, ...)
        end

        local template_name = template and template.name
        local owner_unit = _buff_owner_unit(...)
        local group = _debuff_group_for_template(template, false)
        local was_active = group and _debuff_group_active(self, group)
            or template_name and self:has_buff_using_buff_template(template_name)
        local index = func(self, template, t, from_server_correction, ...)
        local player = owner_unit and _player_from_unit(owner_unit)
        local aid = player and _account_id(player)

        if not aid then
            aid = _recent_cryptic_attacker_account_id(self._unit, template_name)
        end

        if not group and aid then
            group = _debuff_group_for_template(template, true)
        end

        if group and not was_active and index and aid and _Stats then
            _Stats.record("debuffs_applied", aid, 1)
        end

        return index
    end)
end

local MINION_BUFF_EXTENSION_PATH = "scripts/extension_systems/buff/minion_buff_extension"
mod:hook_require(MINION_BUFF_EXTENSION_PATH, _hook_minion_buff_extension)

local minion_buff_extension_instances = mod:get_require_store(MINION_BUFF_EXTENSION_PATH)
if minion_buff_extension_instances then
    for i = 1, #minion_buff_extension_instances do
        _hook_minion_buff_extension(minion_buff_extension_instances[i])
    end
end

mod:hook(CLASS.AttackReportManager, "add_attack_result",
function(func, self, damage_profile, attacked_unit, attacking_unit,
         attack_direction, hit_world_position, hit_weakspot, damage,
         attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
    local player = _player_from_unit(attacking_unit)
    local aid = player and _account_id(player)
    if attacked_unit and player then
        local attack_time = _gameplay_time()
        if attack_time then
            _recent_attack_by_unit[attacked_unit] = {
                account_id = aid,
                archetype_name = _player_archetype_name(player),
                time = attack_time,
            }
        end
    end
    if aid and _Stats then
        local boss_result = _Stats.handle_attack(aid, damage_profile, attacked_unit,
            hit_weakspot, damage, attack_result, attack_type, mod._enemy_health, is_critical_strike)
        if boss_result then
            _boss_popup_queue[#_boss_popup_queue + 1] = boss_result
            _pump_boss_popup_queue()
        end
    end
    if mod.stagger_register_attack then
        mod.stagger_register_attack(attacked_unit, attacking_unit, damage_profile, attack_type,
            aid, attack_direction, hit_world_position)
    end
    -- Used if the death manager reports the kill before the attack report.
    if attacked_unit and attacking_unit then
        mod._last_hitter_account_id[attacked_unit] = aid
    end
    return func(self, damage_profile, attacked_unit, attacking_unit,
        attack_direction, hit_world_position, hit_weakspot, damage,
        attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
end)

-- Establish the initial health value before damage reports arrive.
mod:hook("HealthExtension", "init",
function(func, self, extension_init_context, unit, extension_init_data, game_object_data, ...)
    func(self, extension_init_context, unit, extension_init_data, game_object_data, ...)
    if _Stats and extension_init_data and extension_init_data.health then
        _Stats.seed_enemy_health(unit, extension_init_data.health)
    end
end)

mod:hook("HuskHealthExtension", "init",
function(func, self, extension_init_context, unit, extension_init_data, game_session, game_object_id, owner_id, ...)
    func(self, extension_init_context, unit, extension_init_data, game_session, game_object_id, owner_id, ...)
    if _Stats then
        _Stats.seed_enemy_health(unit, self:max_health())
    end
end)

-- Covers kills that do not produce an attack report; Stats deduplicates them.
mod:hook("MinionDeathManager", "set_dead",
function(func, self, unit, attack_direction, hit_zone_name, damage_profile_name, do_ragdoll_push, herding_template_name, ...)
    if _Stats and unit then
        _finalize_enemy_aggro(unit)
        _Stats.record_kill_from_death(unit, mod._last_hitter_account_id[unit])
        local boss_result = _Stats.finalize_boss_encounter(unit)
        if boss_result then
            _boss_popup_queue[#_boss_popup_queue + 1] = boss_result
            _pump_boss_popup_queue()
        end
    end
    return func(self, unit, attack_direction, hit_zone_name, damage_profile_name, do_ragdoll_push, herding_template_name, ...)
end)

mod:hook("MinionSpawnManager", "unregister_unit",
function(func, self, unit, ...)
    local result = func(self, unit, ...)
    if result then
        _discard_enemy_aggro(unit)
    end
    return result
end)

mod:hook(CLASS.PlayerHuskHealthExtension, "fixed_update",
function(func, self, unit, dt, t, ...)
    func(self, unit, dt, t, ...)
    if unit then
        local p = _player_from_unit(unit)
        if p and _Stats then
            mod._record_damage_taken(unit, p, self._damage)
        end
        local comp = self._character_state_read_component
        if comp then _track_player_state(unit, comp.state_name) end
        local ud_ext = ScriptUnit.has_extension(unit, "unit_data_system")
        if p and comp then mod._forced_assist.sample(unit, p, comp.state_name, ud_ext) end
        if ud_ext and ud_ext:has_component("disabled_character_state") then
            local dc = ud_ext:read_component("disabled_character_state")
            local dtype = dc and dc.disabling_type
            if dtype and dtype ~= "none" then
                _track_player_disabled(unit, dtype, dc.disabling_unit)
            else
                local aid = p and _account_id(p)
                if aid then _finish_player_disabled(unit, aid) end
            end
        end
    end
end)

mod:hook(CLASS.PlayerUnitHealthExtension, "fixed_update",
function(func, self, unit, dt, t, ...)
    func(self, unit, dt, t, ...)
    if unit then
        local p = _player_from_unit(unit)
        if p and _Stats then
            mod._record_damage_taken(unit, p, self._damage)
        end
        local comp = self._character_state_component
        if comp then _track_player_state(unit, comp.state_name) end
        local ud_ext = ScriptUnit.has_extension(unit, "unit_data_system")
        if p and comp then mod._forced_assist.sample(unit, p, comp.state_name, ud_ext) end
        if ud_ext and ud_ext:has_component("disabled_character_state") then
            local dc = ud_ext:read_component("disabled_character_state")
            local dtype = dc and dc.disabling_type
            if dtype and dtype ~= "none" then
                _track_player_disabled(unit, dtype, dc.disabling_unit)
            else
                local aid = p and _account_id(p)
                if aid then _finish_player_disabled(unit, aid) end
            end
        end
    end
end)

mod:hook("InteracteeExtension", "started",
function(func, self, interactor_unit, ...)
    if interactor_unit then
        mod.current_ammo[interactor_unit] = _read_ammo_snapshot(interactor_unit)
    end

    return func(self, interactor_unit, ...)
end)

local function _handle_ammo_interaction(self, unit, account_id)
    local interaction_type = self:interaction_type() or ""

    if interaction_type == "ammunition" then
        local ammo_description = self._override_contexts and self._override_contexts.ammunition and self._override_contexts.ammunition.description
        local ammo_kind = ammo_description and AMMO_PICKUP_TYPES[ammo_description]

        if ammo_kind then
            local pickup_unit = self._unit
            if pickup_unit and _record_ammo_pickup_count(account_id, pickup_unit) then
                mod.pending_ammo_pickups[pickup_unit] = {
                    account_id = account_id,
                    player_unit = unit,
                    before = unit and mod.current_ammo[unit],
                    ammo_kind = ammo_kind,
                    frames = 2,
                }
            end
        end
    elseif interaction_type == "pocketable" then
        local pocketable = self._override_contexts and self._override_contexts.pocketable
        local pickup_name = pocketable and pocketable.description

        if pickup_name == "loc_pickup_pocketable_ammo_crate_01" then
            _record_ammo_pickup_count(account_id, self._unit)
        end
    end
end

mod:hook("InteracteeExtension", "stopped",
function(func, self, result, interactor_unit, ...)
    if result == interaction_results.success and _Stats then
        local unit = interactor_unit or self._interactor_unit
        if unit then
            local p = _player_from_unit(unit)
            if p then
                local interaction_type = self:interaction_type() or ""

                if interaction_type == "health_station" then
                    _Stats.record("healthstation_uses", _account_id(p), 1)
                else
                    _handle_ammo_interaction(self, unit, _account_id(p))
                end

                if interaction_type ~= "ammunition" then
                    mod.current_ammo[unit] = nil
                end
            end
        end
    end
    return func(self, result, interactor_unit, ...)
end)

mod:hook("PlayerInteracteeExtension", "stopped",
function(func, self, result, interactor_unit, ...)
    if result == interaction_results.success and _Stats then
        local unit = interactor_unit or self._interactor_unit
        if unit and self._unit and not mod._ammo_processed_units[self._unit] then
            local p = _player_from_unit(unit)
            if p then
                local interaction_type = self:interaction_type() or ""
                local aid = _account_id(p)

                if interaction_type == "revive" or interaction_type == "rescue"
                        or interaction_type == "remove_net" or interaction_type == "pull_up" then
                    mod._forced_assist.on_interaction_success(self._unit)
                end

                if interaction_type == "revive" or interaction_type == "rescue" then
                    _Stats.record("revives_and_rescues", aid, 1)
                elseif interaction_type == "remove_net" then
                    local target_player = self._unit and _player_from_unit(self._unit)
                    local target_aid = target_player and _account_id(target_player)
                    local event = target_aid and _disabled_tracker[target_aid]
                    if event and event.state_name == "netted" then
                        _credit_disabled_help(event, aid)
                    end
                end

                _handle_ammo_interaction(self, unit, _account_id(p))
                if interaction_type ~= "ammunition" then
                    mod.current_ammo[unit] = nil
                end
            end
        end
    end
    return func(self, result, interactor_unit, ...)
end)

-- Forced assists (servo skull, Veteran shout) have no player interaction; see AnotherScoreboard_forced_assist.
mod:hook_safe("PlayerInteracteeExtension", "started", function(self, interactor_unit)
    mod._forced_assist.on_interaction_started(self._unit)
end)

-- Dedicated/remote server: the skull's effect arrives as an RPC.
mod:hook_safe("FxSystem", "rpc_start_template_effect",
function(self, channel_id, buffer_index, template_id, optional_unit_id)
    local template_name = template_id and NetworkLookup.effect_templates[template_id]
    if template_name ~= "companion_servo_skull_heal_effect" then return end
    local unit_spawner = Managers.state and Managers.state.unit_spawner
    mod._forced_assist.on_effect_started(template_name, unit_spawner and optional_unit_id and unit_spawner:unit(optional_unit_id))
end)

-- Local server (Psykanium): the behavior tree starts the effect directly.
mod:hook_safe("FxSystem", "start_template_effect", function(self, template, optional_unit)
    if template and template.name == "companion_servo_skull_heal_effect" then
        mod._forced_assist.on_effect_started(template.name, optional_unit)
    end
end)

-- Skull and shout assists count like the equivalent player interactions (player ledge pull-ups are not counted).
mod._forced_assist.set_recorder(function(kind, helper_aid)
    if _Stats then
        _Stats.record(kind, helper_aid, 1)
        _runtime_stat_revision = _runtime_stat_revision + 1
    end
end)

-- The tactical overlay is not registered in every game mode.
mod:hook_require("scripts/ui/hud/hud_elements_player_onboarding", function(instance)
    local found = false
    for _, e in ipairs(instance) do
        if e.class_name == "HudElementTacticalOverlay" then found = true end
    end
    if not found then
        instance[#instance + 1] = {
            package = "packages/ui/hud/tactical_overlay/tactical_overlay",
            use_hud_scale = false,
            class_name = "HudElementTacticalOverlay",
            filename = "scripts/ui/hud/elements/tactical_overlay/hud_element_tactical_overlay",
            visibility_groups = { "tactical_overlay" },
        }
    end
end)

mod:hook(CLASS.HudElementTacticalOverlay, "_draw_widgets",
function(func, self, dt, t, input_service, ui_renderer, render_settings, ...)
    func(self, dt, t, input_service, ui_renderer, render_settings, ...)
    if not _settings.show_in_mission then return end
    if self._as_temporarily_hidden then return end
    if not self._as_widgets then return end

    local alpha = (self._alpha_multiplier or 0) * (_settings.scoreboard_opacity / 255)
    for i = 1, #self._as_widgets do
        local w = self._as_widgets[i]
        w.alpha_multiplier = alpha
        UIWidget.draw(w, ui_renderer)
    end
end)

mod:hook(CLASS.HudElementTacticalOverlay, "update",
function(func, self, dt, t, ui_renderer, render_settings, input_service, ...)
    func(self, dt, t, ui_renderer, render_settings, input_service, ...)
    if not _settings.show_in_mission then
        self._as_temporarily_hidden = false
        _cleanup_hud_widgets(self, ui_renderer)
        self._as_was_active = self._active
        return
    end
    if self._active then
        if Keyboard.pressed(Q_KEY) then
            self._as_temporarily_hidden = true
        end
    else
        self._as_temporarily_hidden = false
    end
    if self._active and not self._as_was_active then
        _rebuild_hud(self, ui_renderer)
    elseif not self._active and self._as_was_active then
        _cleanup_hud_widgets(self, ui_renderer)
    end
    if self._active and self._as_runtime_stat_revision ~= _runtime_stat_revision then
        _rebuild_hud(self, ui_renderer)
    end
    self._as_external_refresh_timer = (self._as_external_refresh_timer or 0) - dt
    if self._active and self._as_external_revision ~= mod.external_stats.revision
        and self._as_external_refresh_timer <= 0 then
        _rebuild_hud(self, ui_renderer)
    end
    if self._as_widgets then
        local hub = _is_hub()
        for i = 1, #self._as_widgets do
            self._as_widgets[i].visible = not hub
        end
    end
    if self._active and self._as_title_widget then
        self._as_title_update_timer = (self._as_title_update_timer or 0) - dt
        if self._as_title_update_timer <= 0 then
            self._as_title_update_timer = 1.0
            local title_text = mod.get_scoreboard_title_text()
            self._as_title_widget.content.t = title_text
            _Render.fit_title_widget(self, ui_renderer, self._as_title_widget, title_text,
                self._as_title_max_font_size, self._as_title_max_width)
        end
    end
    self._as_was_active = self._active
end)

mod:hook("MissionBoardViewLogic", "start_mission_matchmaking",
function(func, self, party_manager, selected_mission_id, ...)
    local mission = selected_mission_id and self:get_mission_data_by_id(selected_mission_id)

    if mission then
        _pending_mission_board_data = {
            map = mission.map,
            category = mission.category,
            challenge = mission.challenge,
            resistance = mission.resistance,
        }
    else
        _pending_mission_board_data = nil
    end

    return func(self, party_manager, selected_mission_id, ...)
end)

mod:hook("MissionBoardViewLogic", "start_quickplay_matchmaking",
function(func, self, party_manager, categories, ...)
    _pending_mission_board_data = nil

    return func(self, party_manager, categories, ...)
end)

mod:hook("MultiplayerSessionManager", "leave",
function(func, self, reason, ...)
    _capture_active_run_snapshot("multiplayer_leave")

    return func(self, reason, ...)
end)

mod:hook(CLASS.StateGameplay, "on_enter",
function(func, self, parent, params, creation_context, ...)
    func(self, parent, params, creation_context, ...)

    local mechanism_data = params and params.mechanism_data or {}
    local pending_mission_board_data = _matching_pending_mission_board_data(params and params.mission_name, mechanism_data)
    _mission_metadata = _current_mission_metadata(params, mechanism_data, pending_mission_board_data)
    _reset_runtime_state()
    _try_restore_active_run(_mission_metadata)
    _state_gameplay_enter_handled = true
    _scoreboard_history_saved = false

    if not _can_open_scoreboard_history() then
        local ui = Managers.ui
        if ui and ui:view_active("another_scoreboard_history_view") and not ui:is_view_closing("another_scoreboard_history_view") then
            ui:close_view("another_scoreboard_history_view", true)
        end
    end
end)

mod:hook("PlayerManager", "remove_player",
function(func, self, peer_id, local_player_id)
    local time_manager = Managers.time
    if not _end_player_snapshot and _is_in_mission() and time_manager and time_manager:has_timer("main") then
        local player = self:player(peer_id, local_player_id)
        if player and player:is_human_controlled() then
            mod._late_players.remember(mod._late_departures, _player_snapshot(player), time_manager:time("main"))
        end
    end

    return func(self, peer_id, local_player_id)
end)

mod:hook(CLASS.GameModeManager, "_set_end_conditions_met",
function(func, self, outcome, ...)
    _capture_end_player_snapshot()

    local result = func(self, outcome, ...)
    _mission_metadata.outcome = outcome

    return result
end)

mod:hook("UIManager", "open_view",
function(func, self, view_name, transition_time, close_previous, close_all, close_transition_time, context, settings_override)
    if view_name == "inventory_background_view" then
        local history_view = self:view_instance("another_scoreboard_history_view")
        if history_view and history_view._popup_id then
            return false
        end
    end

    return func(self, view_name, transition_time, close_previous, close_all, close_transition_time, context, settings_override)
end)

mod:hook("EndView", "on_enter",
function(func, self, ...)
    func(self, ...)

    local player_records = _history_players()
    _save_history_snapshot(player_records)

    if _settings.show_at_end then
        local context = { end_view = true }
        local players = _History and _History.player_adapters and _History.player_adapters(player_records)
        if players and #players > 0 then
            context.players = players
        end

        _open_view(context)
    end
end)

mod:hook("EndView", "on_exit",
function(func, self, ...)
    func(self, ...)
    _close_view()
end)

mod:hook("EndPlayerView", "on_enter",
function(func, self, ...)
    func(self, ...)
    local v = Managers.ui:view_instance("another_scoreboard_view")
    if v then v:move_scoreboard(0, -300) end
end)

mod:hook("EndPlayerView", "on_exit",
function(func, self, ...)
    func(self, ...)
    local v = Managers.ui:view_instance("another_scoreboard_view")
    if v then v:move_scoreboard(-300, 0) end
end)

mod.update = function(dt)
    _update_dmf_options_archetype()

    if not mod:is_enabled() then
        return
    end

    if mod.stagger_update_frame then mod.stagger_update_frame() end
    _update_history_preload(dt)
    _update_history(dt)
    if mod._social then mod._social.update(dt) end

    local tm = Managers.time
    if not tm or not tm:has_timer("gameplay") then return end

    if not _mission_start_time then
        _mission_start_time = tm:time("gameplay")
    end

    if mod._active_run_prefix_pending and _active_run_store.snapshot and _Stats then
        _try_restore_current_active_run()
    end

    local player_mgr = Managers.player
    if not player_mgr then return end

    local players = player_mgr:human_players() or {}
    mod._sync_player_roster(players)
    _sample_combat_ability_uses(players)
    mod._forced_assist.set_players(players)
    mod._forced_assist.update()

    _aggro_sample_timer = _aggro_sample_timer + dt
    if _aggro_sample_timer >= AGGRO_SAMPLE_INTERVAL then
        _aggro_sample_timer = 0
        _sample_enemy_aggro()
    end

    _coherency_sample_timer = _coherency_sample_timer + dt
    local sample_coherency = false
    if _coherency_sample_timer >= COHERENCY_SAMPLE_INTERVAL then
        _coherency_sample_timer = 0
        sample_coherency = true
    end

    if sample_coherency then
        local now = tm:time("gameplay")
        local elapsed = _coherency_last_sample and (now - _coherency_last_sample) or 0
        _coherency_last_sample = now

        if elapsed > 0 then
            for _, player in pairs(players) do
                local unit = player.player_unit
                if not _is_coherency_eligible(unit) then goto continue end

                local aid = _account_id(player)
                _coherency_eligible_time[aid] = (_coherency_eligible_time[aid] or 0) + elapsed

                local ext = ScriptUnit.has_extension(unit, "coherency_system")
                if not ext then goto continue end

                -- The count includes the player, so more than one means coherency.
                local n = ext.num_units_in_coherency and ext:num_units_in_coherency() or ext._num_units_in_coherence or 0
                if n > 1 then
                    _coherency_time[aid] = (_coherency_time[aid] or 0) + elapsed
                end
                ::continue::
            end
        end
    end

    if _boss_popup_active then
        _boss_popup_timer = _boss_popup_timer - dt
        if _boss_popup_timer <= 0 then
            _boss_popup_active = nil
            local el = _get_boss_popup_element()
            if el then el:hide() end
        end
    end

    if not _settings.show_boss_popup then
        table_clear(_boss_popup_queue)
        if _boss_popup_active then
            _boss_popup_active = nil
            local el = _get_boss_popup_element()
            if el then el:hide() end
        end
    else
        _pump_boss_popup_queue()
    end

    for pickup_unit, pending in pairs(mod.pending_ammo_pickups) do
        pending.frames = (pending.frames or 0) - 1
        if pending.frames <= 0 then
            local after = pending.player_unit and _read_ammo_snapshot(pending.player_unit)
            local amount = _ammo_amount_from_snapshots(pending.before, after, AMMO_PICKUP_AMOUNTS[pending.ammo_kind])

            if _Stats and amount > 0 then
                _Stats.record("ammo_collected", pending.account_id, amount)
            end

            mod.pending_ammo_pickups[pickup_unit] = nil
            if pending.player_unit then
                mod.current_ammo[pending.player_unit] = nil
            end
        end
    end
end

function mod.on_all_mods_loaded()
    _Stats  = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_stats")
    _Render = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_render")
    _History = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_history")
    mod._loadout = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_loadout")
    mod._social = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_social")
    mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_stagger")
    _request_history_preload()

    if _Stats then
        _Stats.init()
        _refresh_settings()

        if _is_in_mission() then
            _try_restore_current_active_run()
        end
    end

    if _Render then
        _Render.update_dimensions(_settings.scale, _settings.text_scale)
    end

    mod:register_hud_element({
        class_name = "HudElementBossPopup",
        filename = "AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_boss_popup",
        use_hud_scale = true,
        visibility_groups = { "alive", "communication_wheel", "tactical_overlay", "player_in_danger_zone" },
    })

    mod:register_hud_element({
        class_name = "HudElementLiveScoreboard",
        filename = "AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_live_scoreboard",
        use_hud_scale = true,
        visibility_groups = { "alive", "dead", "communication_wheel", "player_in_danger_zone" },
    })

    mod:add_require_path("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_view")
    mod:add_require_path("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_history_view")
    mod:register_view({
        view_name = "another_scoreboard_view",
        view_settings = {
            init_view_function = function() return true end,
            class = "AnotherScoreboardView",
            disable_game_world = false,
            display_name = "loc_another_scoreboard_view_display_name",
            game_world_blur = 0,
            load_always = true,
            load_in_hub = true,
            package = {
                "packages/ui/views/options_view/options_view",
                "packages/ui/views/talent_builder_view/talent_builder_view",
                "packages/ui/views/talent_builder_view/veteran",
                "packages/ui/views/talent_builder_view/zealot",
                "packages/ui/views/talent_builder_view/psyker",
                "packages/ui/views/talent_builder_view/ogryn",
                "packages/ui/views/talent_builder_view/adamant",
                "packages/ui/views/talent_builder_view/broker",
                "packages/ui/views/talent_builder_view/cryptic",
            },
            path = "AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_view",
            state_bound = false,
            enter_sound_events = { "wwise/events/ui/play_ui_enter_short" },
            exit_sound_events = { "wwise/events/ui/play_ui_back_short" },
            wwise_states = { options = "ingame_menu" },
        },
        view_transitions = {},
        view_options = { close_all = false, close_previous = false },
    })
    mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_view")

    mod:register_view({
        view_name = "another_scoreboard_history_view",
        view_settings = {
            init_view_function = function() return _can_open_scoreboard_history() end,
            class = "AnotherScoreboardHistoryView",
            disable_game_world = false,
            display_name = "loc_another_scoreboard_history_view_display_name",
            game_world_blur = 1.1,
            load_always = true,
            load_in_hub = true,
            package = "packages/ui/views/options_view/options_view",
            path = "AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_history_view",
            state_bound = false,
            enter_sound_events = { "wwise/events/ui/play_ui_enter_short" },
            exit_sound_events = { "wwise/events/ui/play_ui_back_short" },
            wwise_states = { options = "ingame_menu" },
        },
        view_transitions = {},
        view_options = { close_all = false, close_previous = false },
    })
    mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_history_view")

end

function mod.on_setting_changed(setting_id)
    if setting_id == LIVE_ARCHETYPE_SETTING then
        _sync_live_editor(mod:get(LIVE_ARCHETYPE_SETTING))
    elseif setting_id == LIVE_STAT_COUNT_SETTING then
        local archetype_id = mod:get(LIVE_ARCHETYPE_SETTING)
        if not LIVE_ARCHETYPES[archetype_id] then
            archetype_id = ARCHETYPE_CATALOG[1].id
        end

        local selected_count = mod:get(setting_id)
        if _valid_live_stat_count(selected_count) then
            mod:set(_archetype_stat_count_setting(archetype_id), selected_count, false)
        else
            mod:set(setting_id, _archetype_stat_count(archetype_id), false)
        end
    else
        for changed_index = 1, #LIVE_STAT_SETTINGS do
            if setting_id == LIVE_STAT_SETTINGS[changed_index] then
                local archetype_id = mod:get(LIVE_ARCHETYPE_SETTING)
                if not LIVE_ARCHETYPES[archetype_id] then
                    archetype_id = ARCHETYPE_CATALOG[1].id
                end

                local previous_key = _archetype_stat_key(archetype_id, changed_index)
                local selected_key = mod:get(setting_id)

                if LIVE_STATS[selected_key] and selected_key ~= previous_key then
                    for other_index = 1, #LIVE_STAT_SETTINGS do
                        if other_index ~= changed_index and _archetype_stat_key(archetype_id, other_index) == selected_key then
                            mod:set(_archetype_stat_setting(archetype_id, other_index), previous_key, false)
                            mod:set(LIVE_STAT_SETTINGS[other_index], previous_key, false)
                            break
                        end
                    end

                    mod:set(_archetype_stat_setting(archetype_id, changed_index), selected_key, false)
                elseif not LIVE_STATS[selected_key] then
                    mod:set(setting_id, previous_key, false)
                end

                break
            end
        end
    end

    _refresh_settings()
    if not mod:is_enabled() then
        return
    end

    if setting_id == "scoreboard_theme"
        or setting_id == "scoreboard_text_scale"
        or setting_id == "local_player_first"
        or setting_id == "alternating_row_shading" then
        _runtime_stat_revision = _runtime_stat_revision + 1

        local ui = Managers.ui
        local scoreboard_view = ui and ui:view_instance("another_scoreboard_view")
        if scoreboard_view and scoreboard_view._build then
            scoreboard_view:_build()
        end

        if setting_id == "scoreboard_theme" then
            local history_view = ui and ui:view_instance("another_scoreboard_history_view")
            if history_view and history_view._build then
                history_view:_build()
            end
        end
    end

    if setting_id == "scoreboard_theme"
        or setting_id == "boss_popup_scale"
        or setting_id == "boss_popup_duration"
        or setting_id == "boss_popup_x_offset"
        or setting_id == "boss_popup_y_offset"
        or setting_id == "boss_popup_bg_opacity"
        or setting_id == "show_boss_popup_damage"
        or setting_id == "show_boss_popup_percent"
        or setting_id == "show_boss_popup_total_damage" then
        local test_data = {
            display_name = "Boss Damage Preview",
            total_damage = 12345,
            max_health = 50000,
            players = {
                { aid = "You", damage = 5000, pct = 40 },
                { aid = "Teammate A", damage = 3500, pct = 28 },
                { aid = "Teammate B", damage = 2500, pct = 20 },
                { aid = "Teammate C", damage = 1345, pct = 11 },
            },
        }
        _boss_popup_active = test_data
        _boss_popup_timer = _settings.boss_popup_duration
        local el = _get_boss_popup_element()
        if el then
            el:show(test_data, _settings.boss_popup_x, _settings.boss_popup_y, _settings.boss_popup_scale)
        end
    end
end

function mod.on_enabled(initial_call)
    _refresh_settings()
    if not _is_in_mission() then
        _reset_runtime_state()
    elseif _Stats then
        _try_restore_current_active_run()
    end
    _request_history_preload()
end

function mod.on_disabled(initial_call)
    _capture_active_run_snapshot("disabled")
    _close_view()
    if mod._social then mod._social.reset() end
    _hide_boss_popup()
    _cleanup_tactical_overlay_widgets()
    _reset_runtime_state()
end

function mod.on_unload(exit_game)
    _capture_active_run_snapshot("unload")
    _close_view()
    if mod._social then mod._social.reset() end
    _hide_boss_popup()
    _cleanup_tactical_overlay_widgets()
    if mod.stagger_shutdown then mod:stagger_shutdown() end
    _reset_runtime_state()
end

function mod.on_game_state_changed(status, state_name)
    if state_name == "StateGameplay" then
        if status == "enter" then
            if not _state_gameplay_enter_handled then
                _reset_runtime_state()
            end

            if mod.stagger_clear_cache then mod:stagger_clear_cache() end
            local tm = Managers.time
            if not _mission_start_time then
                _mission_start_time = tm and tm:has_timer("gameplay") and tm:time("gameplay") or nil
            end
        elseif status == "exit" then
            if _mission_start_time then
                local tm = Managers.time
                if tm and tm:has_timer("gameplay") then
                    _mission_elapsed_final = tm:time("gameplay") - _mission_start_time
                end
            end
            _capture_active_run_snapshot("gameplay_exit")
            _close_view()
            if mod._social then mod._social.reset() end
            _cleanup_tactical_overlay_widgets()
            _clear_unit_runtime_caches()
            if mod.stagger_clear_cache then mod:stagger_clear_cache() end
            _hide_boss_popup()
            _mission_start_time = nil
            _state_gameplay_enter_handled = false
        end
    end
end

local initial_editor_archetype = mod:get(LIVE_ARCHETYPE_SETTING)
if not LIVE_ARCHETYPES[initial_editor_archetype] then
    initial_editor_archetype = ARCHETYPE_CATALOG[1].id
    mod:set(LIVE_ARCHETYPE_SETTING, initial_editor_archetype, false)
end
_sync_live_editor(initial_editor_archetype)
_refresh_settings()
