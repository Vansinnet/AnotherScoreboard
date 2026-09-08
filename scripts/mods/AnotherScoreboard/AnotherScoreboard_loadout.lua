local mod = get_mod("AnotherScoreboard")
local Items = mod:original_require("scripts/utilities/items")
local MasterItems = mod:original_require("scripts/backend/master_items")
local WeaponTemplate = mod:original_require("scripts/utilities/weapon/weapon_template")
local TalentLayoutParser = mod:original_require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")

local Loadout = {}
local weapon_slots = { "slot_primary", "slot_secondary" }
local signature_types = { tactical = "blitz", aura = "aura", ability = "ability", keystone = "keystone" }
local bot_weapon_names = {
    bot_autogun_killshot = "Autogun",
    high_bot_autogun_killshot = "Autogun",
    bot_combataxe_linesman = "Combat Axe",
    bot_combatsword_linesman_p1 = "Combat Sword",
    bot_combatsword_linesman_p2 = "Combat Sword",
    bot_lasgun_killshot = "Lasgun",
    high_bot_lasgun_killshot = "Lasgun",
    bot_laspistol_killshot = "Laspistol",
    bot_zola_laspistol = "Laspistol",
}

local function copy_links(links)
    local result = {}
    for i = 1, #(links or {}) do
        result[i] = links[i]
    end
    return result
end

local function capture_traits(traits, definitions)
    local result = {}
    for i = 1, #(traits or {}) do
        local trait = traits[i]
        local definition = definitions and definitions[trait.id]
        result[i] = {
            id = trait.id,
            rarity = trait.rarity,
            value = trait.value,
            name = definition and definition.display_name and definition.display_name ~= ""
                and Items.display_name(definition) or trait.id,
            description = definition and definition.description and trait.rarity ~= nil
                and Items.trait_description(definition, trait.rarity, trait.value) or nil,
        }
    end
    return result
end

local function weapon_name(item)
    local template_name = item.weapon_progression_template or item.weapon_template
    local bot_name = template_name and bot_weapon_names[template_name]
    if bot_name then
        return bot_name, template_name
    end

    local name = Items.display_name(item)
    if type(name) == "string" and name:find("<unlocalized", 1, true) then
        return template_name or "Weapon", template_name
    end

    return name, template_name
end

local function capture_profile(profile)
    if not profile then
        return nil
    end

    local archetype = profile.archetype
    local snapshot = {
        version = 1,
        archetype = archetype and archetype.name,
        weapons = {},
        talents = {},
        layouts = {},
        signature = { blitz = {}, aura = {}, ability = {}, keystone = {} },
    }
    local backend = Managers.backend
    local definitions = backend and backend.interfaces and backend.interfaces.master_data and MasterItems.get_cached()
    local loadout = profile.loadout

    for i = 1, #weapon_slots do
        local slot = weapon_slots[i]
        local item = loadout and loadout[slot]
        if item then
            local name, template_name = weapon_name(item)
            local template = WeaponTemplate.weapon_template_from_item(item)
            local stat_definitions = template and template.base_stats
            local stats = {}
            for j = 1, #(item.base_stats or {}) do
                local stat = item.base_stats[j]
                local definition = stat_definitions and stat_definitions[stat.name]
                stats[j] = {
                    id = stat.name,
                    name = definition and definition.display_name and Localize(definition.display_name) or stat.name,
                    value = stat.value,
                }
            end
            snapshot.weapons[#snapshot.weapons + 1] = {
                slot = slot,
                name = name,
                template_name = template_name,
                item_type = item.item_type,
                rarity = item.rarity,
                rating = tonumber((Items.expertise_level(item, true))),
                base_rating = Items.total_stats_value(item),
                perks = capture_traits(item.perks, definitions),
                blessings = capture_traits(item.traits, definitions),
                base_stats = stats,
            }
        end
    end

    if not archetype then
        return snapshot
    end

    local talent_definitions = archetype.talents or {}
    local selected_talents = profile.talents or {}
    local selected_nodes = profile.selected_nodes
    local points_by_talent = {}
    local layouts = TalentLayoutParser.archetype_layouts(archetype)
    for i = 1, #layouts do
        local layout = layouts[i]
        local captured_layout = { name = layout.name, version = layout.version, nodes = {} }
        snapshot.layouts[#snapshot.layouts + 1] = captured_layout
        for j = 1, #layout.nodes do
            local node = layout.nodes[j]
            -- Talents also include granted base tiers; only node tiers prove tree selection.
            local tier = selected_nodes and selected_nodes[node.widget_name]
            if type(tier) == "number" and tier > 0 then
                local definition = talent_definitions[node.talent]
                local points = tier * (node.cost or 1)
                if node.talent then
                    points_by_talent[node.talent] = (points_by_talent[node.talent] or 0) + points
                end
                local record = {
                    id = node.widget_name,
                    talent_id = node.talent,
                    tier = tier,
                    points_spent = points,
                    cost = node.cost,
                    max_points = node.max_points,
                    type = node.type,
                    x = node.x,
                    y = node.y,
                    icon = node.icon,
                    parents = copy_links(node.parents),
                    children = copy_links(node.children),
                    name = definition and TalentLayoutParser.talent_title(definition, points) or node.talent or node.widget_name,
                    description = definition and definition.description and TalentLayoutParser.talent_description(definition, points),
                }
                captured_layout.nodes[#captured_layout.nodes + 1] = record
                local category = signature_types[node.type]
                if category and node.talent and node.talent ~= "not_selected" then
                    local entries = snapshot.signature[category]
                    entries[#entries + 1] = node.talent
                end
            end
        end
    end

    local talent_ids = {}
    for id, tier in pairs(selected_talents) do
        if type(tier) == "number" and tier > 0 then
            talent_ids[#talent_ids + 1] = id
        end
    end
    table.sort(talent_ids)
    local fallback_signature = { blitz = {}, aura = {}, ability = {} }
    for i = 1, #talent_ids do
        local id = talent_ids[i]
        local tier = selected_talents[id]
        local definition = talent_definitions[id]
        local points = points_by_talent[id] or tier
        snapshot.talents[i] = {
            id = id,
            tier = tier,
            name = definition and TalentLayoutParser.talent_title(definition, points) or id,
            description = definition and definition.description and TalentLayoutParser.talent_description(definition, points),
            icon = definition and definition.icon,
        }
        local ability = definition and definition.player_ability
        local category = ability and (ability.ability_type == "grenade_ability" and "blitz"
            or ability.ability_type == "combat_ability" and "ability") or definition and definition.coherency and "aura"
        if category then
            local entries = fallback_signature[category]
            entries[#entries + 1] = id
        end
    end
    for category, entries in pairs(fallback_signature) do
        if #snapshot.signature[category] == 0 then
            snapshot.signature[category] = entries
        end
    end

    return snapshot
end

function Loadout.capture(profile)
    local ok, snapshot = pcall(capture_profile, profile)
    if not ok then
        mod:warning("Loadout capture failed; omitting optional loadout snapshot: %s", tostring(snapshot))
        return nil
    end

    return snapshot
end

return Loadout
