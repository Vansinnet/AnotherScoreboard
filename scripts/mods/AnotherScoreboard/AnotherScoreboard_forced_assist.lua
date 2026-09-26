-- Observes revives and rescues that no player interaction performs: the Skitarii medicae
-- servo skull (bt_inject_syringe) and the Veteran shout talent (shout_ability). Both set
-- assisted_state_input.force_assist on the server; clients only see their consequences.
-- Attributed assists are passed to the recorder set by the main module.
local mod = get_mod("AnotherScoreboard")

local pairs = pairs
local math_huge = math.huge
local string_format = string.format

-- Diagnostics: set to true to log every observation to the console log and chat.
local DEBUG = false

local HELP_STATES = {
    knocked_down = true,
    hogtied = true,
    netted = true,
    ledge_hanging = true,
}
local SKULL_EFFECT = "companion_servo_skull_heal_effect"
local VETERAN_REVIVE_TALENT = "veteran_combat_ability_revive_nearby_allies"

-- Timing from source: skull effect start -> 1 s delay -> 1.5 s forced assist.
local SKULL_MATCH_RADIUS = 4
local SKULL_MATCH_WINDOW = 6
local SHOUT_RADIUS = 10
local SHOUT_BEFORE_PROGRESS = 1.0
local SHOUT_AFTER_PROGRESS = 0.4
local SHOUT_BEFORE_COMPLETION = 3.5
local INTERACTION_GRACE = 1.0
-- State replication and interaction RPCs can arrive in either order; decide after this delay.
local FINISH_DELAY = 0.5

local Observer = {}

local _episodes = {}      -- target account id -> current help-state episode
local _skull_claims = {}  -- target account id -> { owner_aid, owner_name, t }
local _ability_uses = {}  -- account id -> last combat ability use time
local _recorder
local _names = {}         -- account id -> display name
local _pending = {}       -- target account id -> finished episode awaiting a decision
local _players = {}

local function _now()
    local time_manager = Managers.time
    return time_manager and time_manager:has_timer("gameplay") and time_manager:time("gameplay") or nil
end

local function _account_id(player)
    return player and (player:account_id() or player:name()) or nil
end

local function _remember_name(player, aid)
    if player and aid then
        _names[aid] = player:name() or aid
    end
end

local function _position(unit)
    if not unit or not Unit.alive(unit) then
        return nil
    end
    return Unit.world_position(unit, 1)
end

local function _distance(a, b)
    local pa, pb = _position(a), _position(b)
    if not pa or not pb then
        return math_huge
    end
    return Vector3.distance(pa, pb)
end

local function _player_from_unit(unit)
    local spawn = unit and Managers.state and Managers.state.player_unit_spawn
    return spawn and spawn:owner(unit) or nil
end

local function _has_talent(player, talent_name)
    local profile = player and player:profile()
    local talents = profile and profile.talents
    return talents and talents[talent_name] ~= nil and talents[talent_name] ~= 0 or false
end

local function _report(line)
    if DEBUG then
        mod:info("[ForcedAssist] %s", line)
        mod:echo("[AS2 forced assist] " .. line)
    end
end

function Observer.reset()
    table.clear(_episodes)
    table.clear(_pending)
    table.clear(_skull_claims)
    table.clear(_ability_uses)
end

function Observer.set_players(players)
    _players = players or {}
end

-- recorder(kind, helper_account_id), kind: "revives_and_rescues" or "disabled_helped".
function Observer.set_recorder(recorder)
    _recorder = recorder
end

function Observer.on_ability_used(player, aid, t)
    if aid and t then
        _ability_uses[aid] = t
        _remember_name(player, aid)
    end
end

function Observer.on_interaction_started(target_unit)
    local target = _player_from_unit(target_unit)
    local episode = target and _episodes[_account_id(target)]
    if episode then
        episode.interaction_started_t = _now()
    end
end

function Observer.on_interaction_success(target_unit)
    local target = _player_from_unit(target_unit)
    local aid = target and _account_id(target)
    if aid then
        local episode = _episodes[aid] or _pending[aid]
        if episode then
            episode.interaction_success_t = _now()
        end
    end
end

-- The servo skull starts its heal effect when it reaches the ally it is about to inject.
function Observer.on_effect_started(template_name, unit)
    if template_name ~= SKULL_EFFECT or not unit then
        return
    end

    local t = _now()
    local owner = _player_from_unit(unit)
    local owner_aid = _account_id(owner)
    if not t or not owner_aid then
        _report("skull effect without resolvable owner")
        return
    end
    _remember_name(owner, owner_aid)

    local best_aid, best_distance
    for aid, episode in pairs(_episodes) do
        local distance = _distance(unit, episode.unit)
        if distance <= SKULL_MATCH_RADIUS and (not best_distance or distance < best_distance) then
            best_aid, best_distance = aid, distance
        end
    end

    if best_aid then
        _skull_claims[best_aid] = { owner_aid = owner_aid, t = t }
        _report(string_format("skull of %s injecting %s (%.1f m, %s)", _names[owner_aid] or owner_aid,
            _names[best_aid] or best_aid, best_distance, _episodes[best_aid].state))
    end
end

local function _veteran_for(episode, t)
    local best_aid, best_gap
    local progress_t = episode.progress_start_t
    for aid, used_t in pairs(_ability_uses) do
        local in_window
        if progress_t then
            in_window = used_t >= progress_t - SHOUT_BEFORE_PROGRESS and used_t <= progress_t + SHOUT_AFTER_PROGRESS
        else
            in_window = used_t >= t - SHOUT_BEFORE_COMPLETION and used_t <= t
        end
        if in_window then
            local player = episode.players[aid]
            if player and _has_talent(player, VETERAN_REVIVE_TALENT)
                    and _distance(player.player_unit, episode.unit) <= SHOUT_RADIUS then
                local gap = math.abs((progress_t or t) - used_t)
                if not best_gap or gap < best_gap then
                    best_aid, best_gap = aid, gap
                end
            end
        end
    end
    return best_aid
end

local function _finish_episode(aid, episode, new_state, t)
    local target_name = _names[aid] or aid
    local by_interaction = episode.interaction_success_t
        and math.abs(episode.end_t - episode.interaction_success_t) <= INTERACTION_GRACE

    if new_state == "dead" then
        return
    end

    if by_interaction then
        return
    end

    local helper_aid, source
    local claim = _skull_claims[aid]
    if claim and t - claim.t <= SKULL_MATCH_WINDOW then
        helper_aid, source = claim.owner_aid, "servo skull"
    elseif episode.state == "knocked_down" then
        helper_aid = _veteran_for(episode, t)
        source = helper_aid and "veteran shout" or nil
    end
    _skull_claims[aid] = nil

    local evidence = string_format("progress=%s interaction_started=%s forced_local=%s",
        episode.progress_start_t and "yes" or "no", episode.interaction_started_t and "yes" or "no",
        episode.forced_local and "yes" or "no")

    if not helper_aid then
        _report(string_format("UNATTRIBUTED %s left %s -> %s without player interaction (%s)",
            target_name, episode.state, tostring(new_state), evidence))
        return
    end

    local kind = episode.state == "netted" and "disabled_helped"
        or episode.state == "ledge_hanging" and "ledge_pull_up"
        or "revives_and_rescues"
    if _recorder and kind ~= "ledge_pull_up" then
        _recorder(kind, helper_aid)
    end
    _report(string_format("%s by %s: %s %s -> %s [%s] (%s)", kind, _names[helper_aid] or helper_aid,
        target_name, episode.state, tostring(new_state), source, evidence))
end

-- Called from the player health fixed_update hooks for every player unit (local and husk).
function Observer.sample(unit, player, state_name, unit_data_extension)
    local aid = _account_id(player)
    if not aid or not state_name then
        return
    end

    local episode = _episodes[aid]
    if episode and episode.unit ~= unit then
        _episodes[aid] = nil
        episode = nil
    end

    if HELP_STATES[state_name] then
        local t = _now()
        if not t then
            return
        end

        if not episode or episode.state ~= state_name then
            _remember_name(player, aid)
            episode = { unit = unit, state = state_name, start_t = t, players = {} }
            _episodes[aid] = episode
        end

        for _, other in pairs(_players) do
            local other_aid = _account_id(other)
            if other_aid then
                episode.players[other_aid] = other
                _remember_name(other, other_aid)
            end
        end

        if unit_data_extension and unit_data_extension:has_component("assisted_state_input") then
            local assisted = unit_data_extension:read_component("assisted_state_input")
            local in_progress = assisted.in_progress
            if in_progress and not episode.in_progress then
                episode.progress_start_t = t
            end
            episode.in_progress = in_progress
            -- Husk components only replicate in_progress; force_assist exists on the local unit.
            if unit_data_extension:is_local_unit() and assisted.force_assist then
                episode.forced_local = true
            end
        end
    elseif episode then
        _episodes[aid] = nil
        local t = _now()
        if t then
            episode.end_t = t
            episode.new_state = state_name
            _pending[aid] = episode
        end
    end
end

function Observer.update()
    local t = _now()
    if not t then
        return
    end
    for aid, episode in pairs(_pending) do
        if t - episode.end_t >= FINISH_DELAY then
            _pending[aid] = nil
            _finish_episode(aid, episode, episode.new_state, episode.end_t)
        end
    end
end

return Observer
