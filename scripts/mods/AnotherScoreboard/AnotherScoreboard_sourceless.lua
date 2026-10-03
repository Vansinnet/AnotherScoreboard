-- Attributes enemy debuffs whose applying player the game does not replicate.
-- Clients see such a buff with no player owner. It goes to the most recent attacker of a
-- listed archetype on that enemy. The buff and that attacker's attack report can arrive in
-- either order, so an unmatched buff waits for an attack report within the window.
-- A debuff the game adds with no owner at all also deals its damage ticks with no attacker;
-- those ticks go to the player the debuff was attributed to.
local pairs = pairs
local next = next
local math_abs = math.abs

-- template name -> {
--     archetypes = { [archetype name] = true or required talent name },
--     dot_profile = damage profile of the debuff's ticks when the game adds it with no owner,
-- }
local SOURCELESS_DEBUFFS = {
    -- Skitarii servo skull hack; the owner is the skull, not the player.
    cryptic_servo_skull_debuff = {
        archetypes = { cryptic = true },
    },
    flamer_assault = {
        archetypes = {
            -- Skitarii servo skull flamer; the owner is the skull, not the player.
            cryptic = true,
            -- Zealot Fire and Fury: game 1.13.0 adds the burn with no owner_unit, so its
            -- ticks also have no attacker (zealot_buff_templates, zealot_resist_death_fire).
            zealot = "zealot_resist_death_fire",
        },
        dot_profile = "burning",
    },
}

-- Game 1.13.0: the on-hit proc adds the debuff in the same fixed frame as the hit,
-- and the attack report follows in the same frame's update.
local ATTRIBUTION_WINDOW = 0.5

local DOT_TEMPLATE_BY_PROFILE = {}
for template_name, entry in pairs(SOURCELESS_DEBUFFS) do
    if entry.dot_profile then
        DOT_TEMPLATE_BY_PROFILE[entry.dot_profile] = template_name
    end
end

local Sourceless = {}

local _recent_attacks = setmetatable({}, { __mode = "k" })  -- enemy unit -> archetype -> { aid, player, t }
local _pending = setmetatable({}, { __mode = "k" })         -- enemy unit -> template name -> pending debuff
local _dot_owners = setmetatable({}, { __mode = "k" })      -- enemy unit -> template name -> account id
local _recorder

local function _clear(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function _player_qualifies(requirement, player)
    if requirement == true then
        return true
    end

    local profile = player and player.profile and player:profile()
    local talents = profile and profile.talents

    return talents ~= nil and talents[requirement] ~= nil
end

local function _apply(unit, template_name, pending, aid)
    if pending.counts_debuff and _recorder then
        _recorder("debuffs_applied", aid, 1)
    end

    if pending.owns_dot then
        local owners = _dot_owners[unit]
        if not owners then
            owners = {}
            _dot_owners[unit] = owners
        end
        owners[template_name] = aid
    end
end

local function _recent_attacker(unit, entry, t)
    local attacks = _recent_attacks[unit]
    if not attacks then
        return nil
    end

    local best_record = nil
    for archetype_name, requirement in pairs(entry.archetypes) do
        local record = attacks[archetype_name]
        if record and math_abs(t - record.t) <= ATTRIBUTION_WINDOW
                and (not best_record or record.t > best_record.t)
                and _player_qualifies(requirement, record.player) then
            best_record = record
        end
    end

    return best_record and best_record.aid or nil
end

function Sourceless.set_recorder(recorder)
    _recorder = recorder
end

function Sourceless.reset()
    _clear(_recent_attacks)
    _clear(_pending)
    _clear(_dot_owners)
end

function Sourceless.is_sourceless(template_name)
    return template_name ~= nil and SOURCELESS_DEBUFFS[template_name] ~= nil
end

-- A debuff was added to an enemy without a player owner.
-- created: the add created a new buff instance rather than a stack on an existing one.
-- ownerless: the game passed no owner_unit, so the debuff's ticks have no attacker.
-- counts_debuff: the add counts toward Debuffs applied once attributed.
-- Returns the account id when it can be attributed now.
function Sourceless.on_debuff_added(unit, template_name, created, ownerless, counts_debuff, t)
    local entry = SOURCELESS_DEBUFFS[template_name]
    if not entry or not unit or not t then
        return nil
    end

    local owns_dot = created and ownerless and entry.dot_profile ~= nil
    if owns_dot then
        -- A new instance replaces the previous one; its ticks must not go to the old owner.
        local owners = _dot_owners[unit]
        if owners then
            owners[template_name] = nil
        end
    end

    if not counts_debuff and not owns_dot then
        return nil
    end

    local pending = {
        counts_debuff = counts_debuff,
        owns_dot = owns_dot,
        t = t,
    }

    local aid = _recent_attacker(unit, entry, t)
    if aid then
        _apply(unit, template_name, pending, aid)
        return aid
    end

    local pending_by_template = _pending[unit]
    if not pending_by_template then
        pending_by_template = {}
        _pending[unit] = pending_by_template
    end

    local previous = pending_by_template[template_name]
    if previous and t - previous.t <= ATTRIBUTION_WINDOW then
        previous.counts_debuff = previous.counts_debuff or counts_debuff
        previous.owns_dot = previous.owns_dot or owns_dot
    else
        pending_by_template[template_name] = pending
    end

    return nil
end

-- A player's attack report on an enemy.
function Sourceless.on_attack(unit, aid, archetype_name, player, t)
    if not unit or not aid or not archetype_name or not t then
        return
    end

    local attacks = _recent_attacks[unit]
    if not attacks then
        attacks = {}
        _recent_attacks[unit] = attacks
    end

    local record = attacks[archetype_name]
    if record then
        record.aid = aid
        record.player = player
        record.t = t
    else
        attacks[archetype_name] = { aid = aid, player = player, t = t }
    end

    local pending_by_template = _pending[unit]
    if not pending_by_template then
        return
    end

    for template_name, pending in pairs(pending_by_template) do
        local requirement = SOURCELESS_DEBUFFS[template_name].archetypes[archetype_name]

        if t - pending.t > ATTRIBUTION_WINDOW then
            pending_by_template[template_name] = nil
        elseif requirement and _player_qualifies(requirement, player) then
            pending_by_template[template_name] = nil
            _apply(unit, template_name, pending, aid)
        end
    end

    if next(pending_by_template) == nil then
        _pending[unit] = nil
    end
end

-- Account id owning an ownerless damage tick on an enemy, or nil.
function Sourceless.dot_owner(unit, damage_profile_name)
    local template_name = damage_profile_name and DOT_TEMPLATE_BY_PROFILE[damage_profile_name]
    local owners = template_name and unit and _dot_owners[unit]

    return owners and owners[template_name] or nil
end

return Sourceless
