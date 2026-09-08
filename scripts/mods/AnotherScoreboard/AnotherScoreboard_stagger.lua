local mod = get_mod("AnotherScoreboard")

local Stagger = mod:original_require("scripts/utilities/attack/stagger")
local StaggerSettings = mod:original_require("scripts/settings/damage/stagger_settings")
local AttackingUnitResolver = mod:original_require("scripts/utilities/attack/attacking_unit_resolver")
local MinionMovement = mod:original_require("scripts/utilities/minion_movement")
local BtStaggerAction = mod:original_require("scripts/extension_systems/behavior/nodes/actions/bt_stagger_action")
local BtChaosHoundLeapAction = mod:original_require("scripts/extension_systems/behavior/nodes/actions/bt_chaos_hound_leap_action")
local Catalog = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_stagger_catalog")

local MIN_IMPACT = 2
local MATCH_EXPIRY = 3
local REPORT_RETENTION = 5
local MAX_REPORT_BEFORE_EVENT = 1
local MAX_REPORT_AFTER_EVENT = 0.75
local MATCH_GRACE = MAX_REPORT_AFTER_EVENT
local MAX_REPORTS_PER_UNIT = 24
local STAGGER_IMPACT = StaggerSettings.stagger_impact_comparison
local STAGGER_CATEGORIES = StaggerSettings.stagger_categories
local ZERO_IMPACT_DOT_PROFILES = {
    bleeding = true,
    burning = true,
    flame_grenade_liquid_area_fire_burning = true,
    horde_mode_self_propagating_toxin = true,
    liquid_area_fire_burning = true,
    liquid_area_fire_burning_barrel = true,
    phosphor_burning = true,
    toxin_variant_1 = true,
    toxin_variant_2 = true,
    toxin_variant_3 = true,
    warpfire = true,
}

local _reports = setmetatable({}, { __mode = "k" })
local _pending_events = setmetatable({}, { __mode = "k" })
local _server_pending = setmetatable({}, { __mode = "k" })
local _sequence = 0

local function _time()
    local time_manager = Managers.time
    return time_manager and time_manager:has_timer("gameplay") and time_manager:time("gameplay") or 0
end

local function _is_server()
    local game_session = Managers.state and Managers.state.game_session
    return game_session and game_session:is_server() or false
end

local function _account_id_from_unit(unit)
    if not unit then return nil end

    local resolved_unit = unit
    if Managers.state and Managers.state.extension and Managers.state.player_unit_spawn then
        local ok, resolved = pcall(AttackingUnitResolver.resolve, unit)
        if ok and resolved then
            resolved_unit = resolved
        end
    end

    local spawn_manager = Managers.state and Managers.state.player_unit_spawn
    local player = spawn_manager and spawn_manager:owner(resolved_unit)
    if not player then
        local player_manager = Managers.player
        local players = player_manager and player_manager:players()
        if players then
            for _, candidate in pairs(players) do
                if candidate.player_unit == resolved_unit then
                    player = candidate
                    break
                end
            end
        end
    end

    return player and (player:account_id() or player:name()) or nil
end

local function _record(aid, impact)
    if not aid or not impact or impact < MIN_IMPACT then return end

    local Stats = mod.get_stats()
    if Stats then
        Stats.record("enemies_staggered", aid, 1)
        Stats.record("enemies_staggered_weighted", aid, impact >= 3 and 2 or 1)
    end
end

local function _profile_types(damage_profile)
    if not damage_profile then return nil end

    local types = {}
    local function add_category(category)
        local stagger_types = category and STAGGER_CATEGORIES[category]
        if stagger_types then
            for i = 1, #stagger_types do
                types[stagger_types[i]] = true
            end
        end
    end

    local override = damage_profile.stagger_override
    if override then
        types[override] = true
    else
        add_category(damage_profile.stagger_category)
    end
    add_category(damage_profile.shield_stagger_category)

    return next(types) and types or nil
end

local function _event_impact(metadata, damage_profile)
    -- One animation can represent several stagger types; use the lowest compatible impact.
    local profile_types = _profile_types(damage_profile)
    local min_impact
    local matched_type = false

    if profile_types then
        for stagger_type in pairs(metadata.stagger_types) do
            if profile_types[stagger_type] then
                local impact = STAGGER_IMPACT[stagger_type]
                if impact then
                    min_impact = min_impact and math.min(min_impact, impact) or impact
                    matched_type = true
                end
            end
        end

        if metadata.controlled and not matched_type then
            for stagger_type in pairs(profile_types) do
                local impact = STAGGER_IMPACT[stagger_type]
                if impact then
                    min_impact = min_impact and math.min(min_impact, impact) or impact
                end
            end
        end
    end

    if not min_impact then
        min_impact = metadata.min_impact
    end

    return min_impact, matched_type
end

local function _remove_old_reports(unit, now)
    local reports = _reports[unit]
    if not reports then return end

    local write = 1
    for i = 1, #reports do
        local report = reports[i]
        if not report.consumed and now - report.t <= REPORT_RETENTION then
            reports[write] = report
            write = write + 1
        end
    end
    for i = write, #reports do
        reports[i] = nil
    end

    if #reports == 0 then
        _reports[unit] = nil
    end
end

local function _best_report(unit, event)
    local reports = _reports[unit]
    if not reports then return nil end

    local best
    local best_min_impact
    local best_delta = math.huge
    local ambiguous = false

    for i = 1, #reports do
        local report = reports[i]
        if not report.consumed then
            local min_impact, matched_type = _event_impact(event.metadata, report.damage_profile)
            local signed_delta = event.t - report.t
            local in_window = signed_delta >= -MAX_REPORT_AFTER_EVENT and signed_delta <= MAX_REPORT_BEFORE_EVENT
            local compatible = matched_type or event.metadata.controlled and _profile_types(report.damage_profile) ~= nil
            local delta = math.abs(signed_delta)

            if in_window and compatible then
                if delta < best_delta then
                    best = report
                    best_min_impact = min_impact
                    best_delta = delta
                    ambiguous = false
                elseif delta == best_delta then
                    if report.aid ~= best.aid then
                        ambiguous = true
                    elseif report.sequence > best.sequence then
                        best = report
                        best_min_impact = min_impact
                    end
                end
            end
        end
    end

    return best, best_min_impact, ambiguous
end

local function _finalize_event(unit, event)
    local report, impact, ambiguous = _best_report(unit, event)
    if ambiguous then return true end
    if not report then return false end

    report.consumed = true
    _record(report.aid, impact)
    return true
end

local function _process_pending(unit, now)
    local events = _pending_events[unit]
    if not events then return end

    local write = 1
    for i = 1, #events do
        local event = events[i]
        local age = now - event.t
        local finalized = age >= MATCH_GRACE and _finalize_event(unit, event)
        if not finalized and age < MATCH_EXPIRY then
            events[write] = event
            write = write + 1
        end
    end
    for i = write, #events do
        events[i] = nil
    end

    if #events == 0 then
        _pending_events[unit] = nil
    end
end

function mod.stagger_register_attack(attacked_unit, attacking_unit, damage_profile, attack_type, aid, attack_direction, hit_world_position)
    if not attacked_unit or not aid then return end
    if damage_profile and ZERO_IMPACT_DOT_PROFILES[damage_profile.name] then return end

    _sequence = _sequence + 1
    local reports = _reports[attacked_unit]
    if not reports then
        reports = {}
        _reports[attacked_unit] = reports
    end

    reports[#reports + 1] = {
        aid = aid,
        damage_profile = damage_profile,
        sequence = _sequence,
        t = _time(),
    }

    if #reports > MAX_REPORTS_PER_UNIT then
        table.remove(reports, 1)
    end

    _process_pending(attacked_unit, _time())
end

local function _handle_minion_event(unit_id, event_index)
    local unit_spawner = Managers.state and Managers.state.unit_spawner
    local unit = unit_spawner and unit_spawner:unit(unit_id)
    if not unit then return end

    local metadata = Catalog.event_metadata(unit, event_index)
    if not metadata then return end

    _sequence = _sequence + 1
    local events = _pending_events[unit]
    if not events then
        events = {}
        _pending_events[unit] = events
    end

    events[#events + 1] = {
        metadata = metadata,
        t = _time(),
    }
end

local function _server_record(attacking_unit, stagger_type)
    return {
        aid = _account_id_from_unit(attacking_unit),
        impact = stagger_type and STAGGER_IMPACT[stagger_type],
        stagger_type = stagger_type,
        t = _time(),
    }
end

local function _server_state(unit)
    local state = _server_pending[unit]
    if not state then
        state = { normal = {} }
        _server_pending[unit] = state
    end
    return state
end

local function _commit_server_record(unit, record)
    if not record then return end
    _record(record.aid, record.impact)
end

mod:hook(Stagger, "apply_stagger",
function(func, unit, damage_profile, damage_profile_lerp_values, target_settings, attacking_unit, power_level, charge_level, is_critical_strike, is_backstab, is_flanking, hit_weakspot, dropoff_scalar, attack_direction, attack_type, attack_result, herding_template_or_nil, hit_shield, damage_type)
    local blackboard = unit and BLACKBOARDS[unit]
    local component = blackboard and blackboard.stagger
    local before_count = component and component.num_triggered_staggers
    local before_controlled = component and component.controlled_stagger
    local applied, stagger_type = func(unit, damage_profile, damage_profile_lerp_values, target_settings, attacking_unit, power_level, charge_level, is_critical_strike, is_backstab, is_flanking, hit_weakspot, dropoff_scalar, attack_direction, attack_type, attack_result, herding_template_or_nil, hit_shield, damage_type)

    if _is_server() and component then
        local state = _server_state(unit)
        local after_count = component.num_triggered_staggers
        if before_count and after_count > before_count then
            state.normal[after_count] = _server_record(attacking_unit, stagger_type)
        elseif not before_controlled and component.controlled_stagger then
            state.controlled = _server_record(attacking_unit, stagger_type)
        end
    end

    return applied, stagger_type
end)

mod:hook(Stagger, "force_stagger",
function(func, unit, stagger_type, attack_direction, duration, length_scale, immune_time, attacker_unit, ignore_no_stagger)
    local blackboard = unit and BLACKBOARDS[unit]
    local component = blackboard and blackboard.stagger
    local before_count = component and component.num_triggered_staggers
    local result = func(unit, stagger_type, attack_direction, duration, length_scale, immune_time, attacker_unit, ignore_no_stagger)

    if _is_server() and component and before_count and component.num_triggered_staggers > before_count then
        local state = _server_state(unit)
        state.normal[component.num_triggered_staggers] = _server_record(attacker_unit, stagger_type)
    end

    return result
end)

mod:hook(BtStaggerAction, "enter",
function(func, self, unit, breed, blackboard, scratchpad, action_data, t)
    local component = blackboard and blackboard.stagger
    local counter = component and component.num_triggered_staggers
    local result = func(self, unit, breed, blackboard, scratchpad, action_data, t)

    if _is_server() and counter and counter > 0 then
        local state = _server_pending[unit]
        local record = state and state.normal[counter]
        _commit_server_record(unit, record)

        if state then
            for pending_counter in pairs(state.normal) do
                if pending_counter <= counter then
                    state.normal[pending_counter] = nil
                end
            end
        end
    end

    return result
end)

mod:hook(MinionMovement, "update_running_stagger",
function(func, unit, t, dt, scratchpad, action_data, optional_reset_stagger_immune_time)
    local before_duration = scratchpad.stagger_duration
    local result = func(unit, t, dt, scratchpad, action_data, optional_reset_stagger_immune_time)

    if _is_server() and not before_duration and scratchpad.stagger_duration then
        local state = _server_pending[unit]
        _commit_server_record(unit, state and state.controlled)
        if state then state.controlled = nil end
    end

    return result
end)

mod:hook(BtChaosHoundLeapAction, "run",
function(func, self, unit, breed, blackboard, scratchpad, action_data, dt, t)
    local before_duration = scratchpad.stagger_duration
    local result = func(self, unit, breed, blackboard, scratchpad, action_data, dt, t)

    if _is_server() and not before_duration and scratchpad.stagger_duration and scratchpad.state == "in_air_stagger" then
        local state = _server_pending[unit]
        _commit_server_record(unit, state and state.controlled)
        if state then state.controlled = nil end
    end

    return result
end)

mod:hook("AnimationSystem", "rpc_minion_anim_event",
function(func, self, channel_id, unit_id, event_index, ...)
    if not _is_server() then
        _handle_minion_event(unit_id, event_index)
    end
    return func(self, channel_id, unit_id, event_index, ...)
end)

function mod.stagger_unit_registered(self, unit)
    if self:is_enabled() and not _is_server() then
        Catalog.prepare_unit(unit)
    end
end

function mod.stagger_update_frame()
    local now = _time()
    if now == 0 then return end

    for unit in pairs(_pending_events) do
        _process_pending(unit, now)
    end
    for unit in pairs(_reports) do
        _remove_old_reports(unit, now)
    end
end

function mod.stagger_clear_cache()
    _reports = setmetatable({}, { __mode = "k" })
    _pending_events = setmetatable({}, { __mode = "k" })
    _server_pending = setmetatable({}, { __mode = "k" })
    _sequence = 0
    Catalog.clear()
end

function mod.stagger_shutdown()
    if Managers.event then
        Managers.event:unregister(mod, "unit_registered")
    end
    mod.stagger_clear_cache()
end

if Managers.event then
    Managers.event:unregister(mod, "unit_registered")
    Managers.event:register(mod, "unit_registered", "stagger_unit_registered")
end
