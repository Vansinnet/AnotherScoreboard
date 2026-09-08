local mod = get_mod("AnotherScoreboard")

local BreedActions = mod:original_require("scripts/settings/breed/breed_actions")
local StaggerSettings = mod:original_require("scripts/settings/damage/stagger_settings")
local STAGGER_IMPACT = StaggerSettings.stagger_impact_comparison

local Catalog = {}
local _breed_events = {}
local _machine_indices = {}
local _breed_maps = {}
local _unit_keys = setmetatable({}, { __mode = "k" })

local function _add_event(events, event_name, stagger_type, controlled)
    if type(event_name) ~= "string" then return end

    local metadata = events[event_name]
    if not metadata then
        metadata = {
            event_name = event_name,
            stagger_types = {},
            controlled = false,
        }
        events[event_name] = metadata
    end

    if stagger_type then
        metadata.stagger_types[stagger_type] = true
    end
    if controlled then
        metadata.controlled = true
    end
end

local function _collect_values(events, value, stagger_type, controlled)
    if type(value) == "string" then
        _add_event(events, value, stagger_type, controlled)
    elseif type(value) == "table" then
        for _, nested in pairs(value) do
            _collect_values(events, nested, stagger_type, controlled)
        end
    end
end

local function _finalize_metadata(metadata)
    local min_impact
    local max_impact

    for stagger_type in pairs(metadata.stagger_types) do
        local impact = STAGGER_IMPACT[stagger_type]
        if impact then
            min_impact = min_impact and math.min(min_impact, impact) or impact
            max_impact = max_impact and math.max(max_impact, impact) or impact
        end
    end

    if metadata.controlled then
        min_impact = min_impact and math.min(min_impact, 1) or 1
        max_impact = max_impact and math.max(max_impact, 4) or 4
    end

    metadata.min_impact = min_impact
    metadata.max_impact = max_impact
end

local function _events_for_breed(breed)
    local tree_name = breed.behavior_tree_name or breed.name
    local cached = _breed_events[tree_name]
    if cached then return cached end

    local events = {}
    local actions = BreedActions[tree_name] or BreedActions[breed.name]

    if actions then
        for _, action_data in pairs(actions) do
            if type(action_data) == "table" then
                local stagger_anims = action_data.stagger_anims
                if stagger_anims then
                    for stagger_type, direction_events in pairs(stagger_anims) do
                        _collect_values(events, direction_events, stagger_type, false)
                    end
                end

                if action_data.controlled_stagger then
                    _collect_values(events, action_data.running_stagger_anim_left, nil, true)
                    _collect_values(events, action_data.running_stagger_anim_right, nil, true)
                    _collect_values(events, action_data.in_air_staggers, nil, true)
                end
            end
        end
    end

    for _, metadata in pairs(events) do
        _finalize_metadata(metadata)
    end

    _breed_events[tree_name] = events
    return events
end

local function _machine_key(breed)
    local state_machine = breed.state_machine or breed.base_unit or ""
    return state_machine .. "|" .. (breed.base_unit or "")
end

local function _breed_key(breed)
    local tree_name = breed.behavior_tree_name or breed.name or ""
    return _machine_key(breed) .. "|" .. tree_name
end

local function _restore_animation(unit, snapshot)
    local restored = true

    local function restore(func, values, count)
        if count > 0 then
            local ok = pcall(func, unit, unpack(values, 1, count))
            restored = restored and ok
        end
    end

    restore(Unit.animation_set_time, snapshot.times, snapshot.num_times)
    restore(Unit.animation_set_animation, snapshot.animations, snapshot.num_animations)
    restore(Unit.animation_set_state, snapshot.states, snapshot.num_states)
    restore(Unit.animation_set_seeds, snapshot.seeds, snapshot.num_seeds)

    return restored
end

local function _animation_snapshot(unit)
    local states, num_states = Unit.animation_get_state(unit)
    local animations, num_animations = Unit.animation_get_animation(unit)
    local times, num_times = Unit.animation_get_time(unit)
    local seeds, num_seeds = Unit.animation_get_seeds(unit)
    return {
        states = states,
        num_states = num_states or 0,
        animations = animations,
        num_animations = num_animations or 0,
        times = times,
        num_times = num_times or 0,
        seeds = seeds,
        num_seeds = num_seeds or 0,
    }
end

local function _event_index(unit, event_name, snapshot)
    -- The engine exposes no side-effect-free name-to-index lookup.
    local ok, index = pcall(Unit.animation_event, unit, event_name)
    local restore_ok, restored = pcall(_restore_animation, unit, snapshot)
    if not ok or not restore_ok or not restored then return nil, false end
    return index, true
end

local function _build_breed_map(unit, breed, key)
    local map = { by_index = {} }
    local state_checked, has_state_machine = pcall(Unit.has_animation_state_machine, unit)
    if not state_checked then return nil end
    if not has_state_machine then
        _breed_maps[key] = map
        return map
    end

    local events = _events_for_breed(breed)
    if not next(events) then
        _breed_maps[key] = map
        return map
    end

    local snapshot_ok, snapshot = pcall(_animation_snapshot, unit)
    if not snapshot_ok then return nil end

    local machine_key = _machine_key(breed)
    local indices = _machine_indices[machine_key]
    if not indices then
        indices = {}
        _machine_indices[machine_key] = indices
    end
    local build_ok = true
    for event_name, metadata in pairs(events) do
        local index = indices[event_name]
        if index == nil then
            local checked, has_event = pcall(Unit.has_animation_event, unit, event_name)
            if not checked then
                build_ok = false
                break
            elseif has_event then
                local probe_ok
                index, probe_ok = _event_index(unit, event_name, snapshot)
                if not probe_ok or index == nil then
                    build_ok = false
                    break
                end
                if index then
                    indices[event_name] = index
                end
            else
                indices[event_name] = false
            end
        end

        if index then
            map.by_index[index] = metadata
        end
    end

    if not build_ok then return nil end
    _breed_maps[key] = map
    return map
end

local function _breed_from_unit(unit)
    if not unit or not Unit.alive(unit) then return nil end
    local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
    return unit_data and unit_data:breed()
end

function Catalog.prepare_unit(unit)
    local breed = _breed_from_unit(unit)
    if not breed then return nil end

    local key = _breed_key(breed)
    _unit_keys[unit] = key

    local map = _breed_maps[key]
    if map then return map end
    return _build_breed_map(unit, breed, key)
end

function Catalog.event_metadata(unit, event_index)
    local key = _unit_keys[unit]
    local map = key and _breed_maps[key] or Catalog.prepare_unit(unit)
    return map and map.by_index[event_index]
end

function Catalog.clear()
    _breed_events = {}
    _machine_indices = {}
    _breed_maps = {}
    _unit_keys = setmetatable({}, { __mode = "k" })
end

return Catalog
