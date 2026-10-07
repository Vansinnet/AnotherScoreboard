local root = "mods/active/AnotherScoreboard/scripts/mods/AnotherScoreboard/"
local definitions = {
    health = { trait = "gadget_innate_health_increase", description = "health" },
    toughness = { trait = "gadget_innate_toughness_increase", description = "toughness" },
    stamina = { trait = "gadget_stamina_increase", description = "stamina" },
    wounds = { trait = "gadget_innate_max_wounds_increase", description = "wounds" },
    perk = { description = "perk" },
}
local Items = {
    display_name = function(item) return item.description end,
    trait_description = function(item, rarity, value)
        return item.description .. " +" .. tostring(value)
    end,
}
local colors = { 255, 200, 200, 200 }
local Render = {
    set_theme = function() end,
    theme_colors = function()
        return {
            panel = colors, section_bg = colors, accent = colors, title = colors,
            label = colors, sub = colors,
        }
    end,
}
local UIWidget = {
    create_definition = function(passes, scenegraph_id, _, size)
        return { passes = passes, size = size }
    end,
}
local modules = {
    ["scripts/utilities/items"] = Items,
    ["scripts/backend/master_items"] = { get_cached = function() return definitions end },
    ["scripts/utilities/weapon/weapon_template"] = {},
    ["scripts/ui/views/talent_builder_view/utilities/talent_layout_parser"] = {},
    ["scripts/managers/ui/ui_widget"] = UIWidget,
}
local mod = {
    original_require = function(_, path) return assert(modules[path], path) end,
    get_render = function() return Render end,
    localize = function(_, key) return key end,
}
function get_mod() return mod end
Utf8 = Utf8 or { upper = string.upper, string_length = string.len, sub_string = string.sub }
Managers = { backend = { interfaces = { master_data = true } } }

local Loadout = dofile(root .. "AnotherScoreboard_loadout.lua")
local LoadoutRender = dofile(root .. "AnotherScoreboard_loadout_render.lua")
local function curio(kind, perks)
    local result = { item_type = "GADGET", traits = { { id = kind, value = 17 } }, perks = {} }
    for i = 1, perks do
        result.perks[i] = { id = "perk", rarity = 1, value = i }
    end
    return result
end
local profile = { loadout = {
    slot_attachment_1 = curio("health", 1),
    slot_attachment_2 = curio("toughness", 2),
    slot_attachment_3 = curio("stamina", 3),
} }
local snapshot = assert(Loadout.capture(profile))
assert(#snapshot.curios == 3)
for i, kind in ipairs({ "health", "toughness", "stamina" }) do
    local entry = snapshot.curios[i]
    assert(entry.slot == "slot_attachment_" .. i and entry.type == kind)
    assert(entry.main.description == kind .. " +17")
    assert(#entry.perks == i and entry.perks[i].description == "perk +" .. i)
end
profile.loadout.slot_attachment_1 = curio("wounds", 1)
profile.loadout.slot_attachment_3 = nil
local sparse = assert(Loadout.capture(profile))
assert(#sparse.curios == 2 and sparse.curios[1].type == "wounds")
definitions.other = { trait = "unrecognized_trait", description = "other" }
profile.loadout.slot_attachment_1 = curio("other", 0)
assert(Loadout.capture(profile).curios[1].type == "unknown")

local host = { _text_size = function() return 0, 0 end }
local function build(loadout, show_tree)
    return LoadoutRender.build(host, "content", { { loadout_snapshot = loadout } }, 1,
        show_tree, { text_scale = 1 })
end
local built = build(snapshot, false)
assert(built.panel.h == 840 and built.columns[1].widget.size[2] == 840)
local passes = built.columns[1].widget.passes
local hovered = {}
for _, pass in ipairs(passes) do
    if pass.content_id and pass.content_id:match("^curio_hotspot_") then
        hovered[#hovered + 1] = pass.content_id
    end
end
assert(#hovered == 3)
for i, id in ipairs(hovered) do
    local content = {}
    for j = 1, 3 do content["curio_hotspot_" .. j] = { is_hover = j == i } end
    for j = 1, 4 do content["signature_hotspot_" .. j] = { is_hover = false } end
    local visible = 0
    for _, pass in ipairs(passes) do
        if pass.visibility_function and pass.visibility_function(content) then
            visible = visible + 1
        end
    end
    assert(visible >= i + 5)
end
local empty = build(sparse, false)
local empty_slot = false
for _, pass in ipairs(empty.columns[1].widget.passes) do
    if pass.value == "loadout_curio_empty" then empty_slot = true end
end
assert(empty_slot)
local old = build({ weapons = {}, talents = {}, layouts = {}, signature = {} }, false)
assert(old.panel.h == 840)
local unrecorded = false
for _, pass in ipairs(old.columns[1].widget.passes) do
    if pass.value == "loadout_curios_unrecorded" then unrecorded = true end
end
assert(unrecorded)
assert(build(snapshot, true).panel.h == 840)
print("curio snapshot, UI hover and legacy checks passed")
