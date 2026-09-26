local mod = get_mod("AnotherScoreboard")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")

local LoadoutRender = {}
local PLAYER_COLORS = {
    { 255, 106, 224, 216 },
    { 255, 244, 115, 171 },
    { 255, 255, 139, 82 },
    { 255, 139, 164, 255 },
}
local CURIO_COLORS = {
    health = { 255, 232, 96, 92 },
    toughness = { 255, 96, 172, 242 },
    stamina = { 255, 236, 204, 96 },
    wounds = { 255, 214, 124, 214 },
}
local SIGNATURES = { "blitz", "aura", "ability", "keystone" }
-- One panel height for every mode, so switching views or players never resizes the window.
local W, H = 1120, 840
local CONTENT_H = 639
local WEAPON_ICON_DISPLAY_SIZE = { 300, 108 }
local TOOLTIP_Z = 100

function LoadoutRender.weapon_icon_render_size()
    return { 600, 216 }
end

function LoadoutRender.build(host, scenegraph_id, players, selected_player, show_tree, settings)
    local Render = mod:get_render()
    Render.set_theme(settings and settings.scoreboard_theme)
    local C = Render.theme_colors()
    local text_scale = math.max(0.5, math.min(2, settings and settings.text_scale or 1))
    local weapon_icon_render_size = LoadoutRender.weapon_icon_render_size()
    local passes = {}
    local weapon_icons = {}

    local function opaque(color)
        return { 255, color[2], color[3], color[4] }
    end
    local function alpha(color, a)
        return { a, color[2], color[3], color[4] }
    end

    local accent = C.accent
    local border = C.border or C.accent
    local surface = C.header_bg or C.section_bg
    local raised = C.section_bg
    local text_main = C.normal or C.label
    local text_sub = C.sub
    local text_dim = C.text_dim or C.sub
    local divider = C.row_div or alpha(C.accent, 40)

    local function rect(x, y, w, h, color, z)
        local pass = {
            pass_type = "rect",
            style = { offset = { x, y, z or 102 }, size = { w, h }, color = color },
        }
        passes[#passes + 1] = pass
        return pass
    end
    local function outline(x, y, w, h, color, z)
        rect(x, y, w, 1, color, z or 104)
        rect(x, y + h - 1, w, 1, color, z or 104)
        rect(x, y + 1, 1, h - 2, color, z or 104)
        rect(x + w - 1, y + 1, 1, h - 2, color, z or 104)
    end
    local function text_style(size, color, title, align)
        return {
            font_type = title and "itc_novarese_bold" or "proxima_nova_bold",
            font_size = math.max(10, math.floor(size * text_scale)),
            text_color = color or C.label,
            text_horizontal_alignment = align or "left", text_vertical_alignment = "top",
        }
    end
    local function text(value, x, y, w, h, size, color, title, align, fit_all)
        -- Snapshot descriptions contain engine markup; plain text also permits safe UTF-8 truncation.
        value = tostring(value or ""):gsub("{#[^}]*}", "")
        local style = text_style(size, color, title, align)
        style.offset, style.size = { x, y, 110 }, { w, h }
        -- BaseView:_text_size accepts a wrap size, not an explicit renderer argument.
        local wrap_size = { w, 100000 }
        local function fits(candidate)
            local width, height = host:_text_size(candidate, style, wrap_size, true)
            return width <= w and height <= h - 6
        end
        if not fits(value) then
            local minimum = fit_all and 1 or 10
            local low, high, best = minimum, style.font_size - 1, minimum
            while low <= high do
                local middle = math.floor((low + high) / 2)
                style.font_size = middle
                if fits(value) then
                    best, low = middle, middle + 1
                else
                    high = middle - 1
                end
            end
            style.font_size = best
            if not fit_all and not fits(value) then
                local first, last, shortened = 0, Utf8.string_length(value), ""
                while first <= last do
                    local middle = math.floor((first + last) / 2)
                    local candidate = (middle > 0 and Utf8.sub_string(value, 1, middle) or "") .. "..."
                    if fits(candidate) then
                        shortened, first = candidate, middle + 1
                    else
                        last = middle - 1
                    end
                end
                value = shortened
            end
        end
        local pass = { pass_type = "text", value_id = "text_" .. (#passes + 1), value = value, style = style }
        passes[#passes + 1] = pass
        return pass
    end
    local function text_width(value, size, title)
        local width = host:_text_size(tostring(value or ""), text_style(size, nil, title), { 1000, 100000 }, true)
        return width or 0
    end
    local function loc(id)
        return mod:localize("loadout_" .. id)
    end
    local function hovered(hotspot_id)
        return function(content)
            local hotspot = content[hotspot_id]
            return hotspot and hotspot.is_hover
        end
    end
    -- Rect whose opacity rises while the given hotspot is hovered.
    local function hover_rect(x, y, w, h, color, hotspot_id, idle_alpha, hover_alpha, z)
        local pass = rect(x, y, w, h, alpha(color, idle_alpha), z)
        pass.change_function = function(content, style)
            local hotspot = content[hotspot_id]
            style.color[1] = hotspot and hotspot.is_hover and hover_alpha or idle_alpha
        end
        return pass
    end
    local function hover_outline(x, y, w, h, color, hotspot_id)
        hover_rect(x, y, w, 1, color, hotspot_id, 0, 255, 106)
        hover_rect(x, y + h - 1, w, 1, color, hotspot_id, 0, 255, 106)
        hover_rect(x, y, 1, h, color, hotspot_id, 0, 255, 106)
        hover_rect(x + w - 1, y, 1, h, color, hotspot_id, 0, 255, 106)
    end
    local function card(x, y, w, h, bar_color, background)
        rect(x, y, w, h, opaque(background or raised))
        outline(x, y, w, h, border)
        if bar_color then
            rect(x, y, w, 2, bar_color, 105)
        end
    end
    local function tooltip_card(x, y, w, h, bar_color)
        for i, spread in ipairs({ 3, 7, 12 }) do
            rect(x - spread, y - spread + 4, w + spread * 2, h + spread * 2, { 70 - i * 18, 0, 0, 0 }, 101)
        end
        rect(x, y, w, h, opaque(C.panel))
        outline(x, y, w, h, alpha(bar_color or accent, 160))
        rect(x, y, w, 3, bar_color or accent, 105)
    end
    local function keycap(x, y, label, h)
        h = h or 22
        local size = 13
        local w = math.max(h, math.floor(text_width(label, size) + 12))
        rect(x, y, w, h, opaque(C.panel), 104)
        outline(x, y, w, h, alpha(accent, 150), 105)
        rect(x + 1, y + h - 2, w - 2, 1, alpha(accent, 90), 105)
        text(label, x, y + 3, w, h + 2, size, accent, false, "center", true)
        return w
    end
    local function section_header(x, y, w, label, right_text)
        rect(x, y + 2, 3, 20, accent, 104)
        text(Utf8.upper(label or ""), x + 12, y + 2, w * 0.6, 26, 15, accent, true)
        if right_text then
            text(right_text, x + w * 0.45, y + 5, w * 0.55, 22, 13, text_dim, false, "right")
        end
        rect(x, y + 27, w, 1, alpha(accent, 60), 103)
    end
    local function pips(x, y, count, color)
        count = math.max(0, math.min(4, math.floor(tonumber(count) or 0)))
        for i = 1, 4 do
            rect(x + (i - 1) * 7, y, 5, 5, i <= count and color or alpha(text_dim, 70), 105)
        end
    end
    local function trait_title(trait)
        return trait.name or trait.id or "-"
    end

    players = players or {}
    local player_index = math.max(1, math.min(math.min(#players, 4), math.floor(selected_player or 1)))
    local player = players[player_index]
    local snapshot = player and player.loadout_snapshot
    local panel_h = H
    local player_color = PLAYER_COLORS[player_index]
    local talent_by_id = {}
    for _, layout in ipairs(snapshot and snapshot.layouts or {}) do
        for _, node in ipairs(layout.nodes or {}) do
            if (node.tier or 0) > 0 then
                if node.talent_id then
                    talent_by_id[node.talent_id] = node
                end
            end
        end
    end
    for _, talent in ipairs(snapshot and snapshot.talents or {}) do
        if talent.id and not talent_by_id[talent.id] then
            talent_by_id[talent.id] = talent
        end
    end

    -- Frame and header
    for i, spread in ipairs({ 2, 5, 9, 14 }) do
        rect(-spread, -spread + 4, W + spread * 2, panel_h + spread * 2, { 64 - i * 14, 0, 0, 0 }, 96 + i)
    end
    rect(0, 0, W, panel_h, opaque(C.panel), 100)
    rect(0, 0, W, 60, opaque(surface), 101)
    outline(0, 0, W, panel_h, border, 104)
    rect(0, 0, W, 2, accent, 105)
    rect(0, 59, W, 1, alpha(accent, 60), 103)
    text(loc("title"), 24, 10, 520, 36, 28, text_main, true)
    text(loc("readonly"), 25, 40, 520, 22, 11, text_dim)

    -- View switch: segmented control, toggled with T or by clicking.
    local modes = { { key = "equipment", active = not show_tree }, { key = "tree", active = show_tree } }
    local seg_w, seg_h = 190, 30
    local seg_x = W - 24 - seg_w * 2
    local seg_y = 15
    keycap(seg_x - 34, seg_y + 4, "T")
    rect(seg_x, seg_y, seg_w * 2, seg_h, opaque(C.panel), 102)
    outline(seg_x, seg_y, seg_w * 2, seg_h, border, 104)
    for i, entry in ipairs(modes) do
        local x = seg_x + (i - 1) * seg_w
        local hotspot_id = "loadout_mode_" .. i
        if entry.active then
            rect(x + 1, seg_y + 1, seg_w - 2, seg_h - 2, alpha(accent, 46), 103)
            rect(x + 1, seg_y + seg_h - 3, seg_w - 2, 2, accent, 105)
        else
            hover_rect(x + 1, seg_y + 1, seg_w - 2, seg_h - 2, text_main, hotspot_id, 0, 16, 103)
            passes[#passes + 1] = {
                pass_type = "hotspot", content_id = hotspot_id,
                content = { pressed_callback = function()
                    if host._request_loadout_tree_toggle then host:_request_loadout_tree_toggle() end
                end },
                style = { offset = { x, seg_y, 115 }, size = { seg_w, seg_h } },
            }
        end
        text(loc(entry.key), x + 8, seg_y + 6, seg_w - 16, seg_h - 4, 13, entry.active and text_main or text_dim,
            false, "center")
    end

    -- Player tabs
    local tab_y, tab_h = 72, 48
    for i = 1, math.min(#players, 4) do
        local x = 24 + (i - 1) * 272
        local chosen, color = i == player_index, PLAYER_COLORS[i]
        local hotspot_id = "player_select_" .. i
        rect(x, tab_y, 256, tab_h, opaque(chosen and raised or surface), 102)
        if chosen then
            rect(x, tab_y, 256, tab_h, alpha(color, 42), 103)
            rect(x, tab_y, 256, 3, color, 105)
        else
            hover_rect(x, tab_y, 256, tab_h, color, hotspot_id, 0, 22, 103)
            rect(x, tab_y, 256, 1, alpha(color, 110), 105)
        end
        outline(x, tab_y, 256, tab_h, chosen and alpha(color, 150) or border, 104)
        keycap(x + 10, tab_y + 13, tostring(i))
        local name = type(players[i].name) == "function" and players[i]:name() or players[i].name
        text(players[i].string_symbol or "", x + 40, tab_y + 9, 30, 30, 22, chosen and color or alpha(color, 170), true, "center")
        text(name or "-", x + 76, tab_y + 14, 170, 24, 17, chosen and text_main or text_sub)
        passes[#passes + 1] = {
            pass_type = "hotspot", content_id = hotspot_id,
            content = { pressed_callback = function() host:_select_loadout_player(i) end },
            style = { offset = { x, tab_y, 115 }, size = { 256, tab_h } },
        }
    end
    rect(24, tab_y + tab_h + 4, 1072, 2, alpha(player_color, 200), 103)

    if not snapshot then
        card(24, 168, 1072, CONTENT_H, player_color)
        text(loc("missing"), 154, 420, 812, 130, 22, text_sub, true, "center")
    elseif not show_tree then
        section_header(24, 132, 1072, loc("weapons"), loc("weapon_hover"))
        for i, slot in ipairs({ "slot_primary", "slot_secondary" }) do
            local weapon
            for _, candidate in ipairs(snapshot.weapons or {}) do
                if candidate.slot == slot then weapon = candidate break end
            end
            local x, y = 24 + (i - 1) * 544, 168
            local hotspot_id = "weapon_hotspot_" .. i
            card(x, y, 528, 300, player_color)
            -- Icon well
            rect(x + 12, y + 14, 300, 108, opaque(C.panel), 103)
            outline(x + 12, y + 14, 300, 108, divider, 104)
            -- Slot and name
            text(string.format("%02d", i), x + 326, y + 15, 40, 24, 13, player_color)
            text(Utf8.upper(loc(slot == "slot_primary" and "slot_primary" or "slot_secondary")),
                x + 354, y + 16, 160, 24, 12, text_dim)
            local weapon_name = weapon and weapon.name
            if weapon_name and weapon_name:find("<unlocalized", 1, true) then
                weapon_name = slot == "slot_primary" and "Bot Melee Weapon" or "Bot Ranged Weapon"
            end
            text(weapon_name or loc("no_weapon"), x + 326, y + 40, 190, 80, 21, text_main, true)
            rect(x + 12, y + 132, 504, 1, divider, 104)

            if weapon then
                -- Base stats
                text(loc("stats"), x + 16, y + 138, 230, 22, 11, text_dim)
                local stats = weapon.base_stats or {}
                local row_h = math.min(26, 130 / math.max(#stats, 1))
                for j, stat in ipairs(stats) do
                    local sy = y + 160 + (j - 1) * row_h
                    local value = math.max(0, math.min(1, tonumber(stat.value) or 0))
                    text(stat.name or stat.id, x + 16, sy, 112, row_h, 12, text_sub)
                    local bar_y = sy + math.floor(row_h * 0.35)
                    rect(x + 130, bar_y, 80, 6, alpha(text_dim, 60), 103)
                    rect(x + 130, bar_y, math.floor(80 * value + 0.5), 6, player_color, 105)
                    text(string.format("%.0f%%", value * 100), x + 212, sy, 40, row_h, 12, text_main, false, "right")
                end
                rect(x + 262, y + 140, 1, 150, divider, 104)

                -- Perks and blessings, compact; full descriptions in the hover card.
                local list_x, list_w = x + 274, 240
                text(loc("perks"), list_x, y + 138, list_w, 22, 11, text_dim)
                local perks = weapon.perks or {}
                for j = 1, math.min(#perks, 2) do
                    local perk = perks[j]
                    local py = y + 160 + (j - 1) * 22
                    pips(list_x, py + 7, perk.rarity, accent)
                    text((perk.description and perk.description ~= "") and perk.description or trait_title(perk), list_x + 34, py, list_w - 34, 22, 13, text_main)
                end
                if #perks == 0 then text(loc("no_selection"), list_x, y + 160, list_w, 22, 13, text_dim) end
                text(loc("blessings"), list_x, y + 210, list_w, 22, 11, text_dim)
                local blessings = weapon.blessings or {}
                for j = 1, math.min(#blessings, 2) do
                    local blessing = blessings[j]
                    local by = y + 232 + (j - 1) * 24
                    pips(list_x, by + 8, blessing.rarity, accent)
                    text(trait_title(blessing), list_x + 34, by, list_w - 34, 24, 15, text_main, true)
                end
                if #blessings == 0 then text(loc("no_selection"), list_x, y + 232, list_w, 22, 13, text_dim) end

                if weapon.master_item_name then
                    local style_id = "weapon_icon_" .. i
                    passes[#passes + 1] = {
                        pass_type = "texture", style_id = style_id,
                        value = "content/ui/materials/icons/items/containers/item_container_landscape_no_rarity",
                        style = {
                            offset = { x + 12, y + 14, 105 }, size = WEAPON_ICON_DISPLAY_SIZE,
                            color = { 0, 255, 255, 255 },
                            material_values = { use_placeholder_texture = 1 },
                        },
                    }
                    weapon_icons[#weapon_icons + 1] = {
                        style_id = style_id, master_item_name = weapon.master_item_name,
                        slot = slot, size = weapon_icon_render_size,
                    }
                end

                hover_outline(x, y, 528, 300, player_color, hotspot_id)
                passes[#passes + 1] = {
                    pass_type = "hotspot", content_id = hotspot_id,
                    style = { offset = { x, y, 115 }, size = { 528, 300 } },
                }

                -- Hover card over the other weapon, so the hovered card stays visible.
                local first = #passes + 1
                local tx = i == 1 and 568 or 24
                tooltip_card(tx, y, 528, 300, player_color)
                text(weapon_name or "-", tx + 18, y + 14, 492, 30, 20, text_main, true)
                text(loc("perks"), tx + 18, y + 48, 492, 22, 11, text_dim)
                local ty = y + 68
                for j = 1, math.min(#perks, 2) do
                    local perk = perks[j]
                    pips(tx + 18, ty + 7, perk.rarity, accent)
                    text((perk.description and perk.description ~= "") and perk.description or trait_title(perk), tx + 52, ty, 458, 22, 14, text_main)
                    ty = ty + 22
                end
                if #perks == 0 then
                    text(loc("no_selection"), tx + 18, ty, 492, 22, 14, text_dim)
                    ty = ty + 22
                end
                ty = ty + 8
                text(loc("blessings"), tx + 18, ty - 2, 492, 22, 11, text_dim)
                ty = ty + 18
                local remaining = y + 292 - ty
                local count = math.min(#blessings, 2)
                local block_h = count > 0 and math.floor(remaining / count) or 0
                for j = 1, count do
                    local blessing = blessings[j]
                    pips(tx + 18, ty + 8, blessing.rarity, accent)
                    text(trait_title(blessing), tx + 52, ty, 458, 24, 16, accent, true)
                    local description = blessing.description
                    if description and description ~= blessing.name then
                        text(description, tx + 52, ty + 24, 458, block_h - 26, 14, text_sub)
                    end
                    ty = ty + block_h
                end
                if count == 0 then text(loc("no_selection"), tx + 18, ty, 492, 22, 14, text_dim) end
                for index = first, #passes do
                    passes[index].style.offset[3] = passes[index].style.offset[3] + TOOLTIP_Z
                    passes[index].visibility_function = hovered(hotspot_id)
                end
            end
        end

        -- Curios
        section_header(24, 478, 1072, loc("curios"), loc("curio_hover"))
        if not snapshot.curios then
            card(24, 514, 1072, 90)
            text(loc("curios_unrecorded"), 44, 544, 1032, 34, 16, text_sub, false, "center")
        else
            for i = 1, 3 do
                local slot = "slot_attachment_" .. i
                local curio
                for _, candidate in ipairs(snapshot.curios) do
                    if candidate.slot == slot then curio = candidate break end
                end
                local x, y = 24 + (i - 1) * 364, 514
                local type_color = curio and CURIO_COLORS[curio.type] or accent
                card(x, y, 344, 90, nil, curio and raised or surface)
                if curio then
                    local hotspot_id = "curio_hotspot_" .. i
                    rect(x, y, 4, 90, type_color, 105)
                    rect(x + 4, y, 340, 90, alpha(type_color, 14), 103)
                    text(string.format("%02d", i), x + 18, y + 12, 30, 24, 12, text_dim)
                    text(loc("curio_" .. (curio.type or "unknown")), x + 48, y + 8, 220, 28, 20, text_main, true)
                    local extra = #(curio.perks or {})
                    if extra > 0 then
                        local label = "+" .. extra
                        local chip_w = math.floor(text_width(label, 12) + 16)
                        rect(x + 344 - 14 - chip_w, y + 12, chip_w, 20, alpha(type_color, 40), 104)
                        text(label, x + 344 - 14 - chip_w, y + 13, chip_w, 22, 12, type_color, false, "center", true)
                    end
                    local main = curio.main
                    text(main and (main.description or main.name) or loc("no_description"),
                        x + 18, y + 42, 312, 42, 15, type_color)
                    hover_outline(x, y, 344, 90, type_color, hotspot_id)
                    passes[#passes + 1] = {
                        pass_type = "hotspot", content_id = hotspot_id,
                        style = { offset = { x, y, 115 }, size = { 344, 90 } },
                    }
                    local first = #passes + 1
                    local tooltip_x = math.min(x, W - 504)
                    tooltip_card(tooltip_x, 620, 480, 180, type_color)
                    text(loc("curio_" .. (curio.type or "unknown")) .. "  " .. string.format("%02d", i),
                        tooltip_x + 18, 634, 444, 29, 19, text_main, true)
                    text(main and (main.description or main.name) or loc("no_description"),
                        tooltip_x + 18, 662, 444, 24, 14, type_color)
                    rect(tooltip_x + 18, 690, 444, 1, divider, 104)
                    if #(curio.perks or {}) == 0 then
                        text(loc("no_selection"), tooltip_x + 18, 700, 444, 40, 15, text_sub)
                    else
                        for j = 1, math.min(#curio.perks, 3) do
                            local perk = curio.perks[j]
                            local py = 698 + (j - 1) * 32
                            pips(tooltip_x + 18, py + 8, perk.rarity, accent)
                            text(perk.description or perk.name or loc("no_description"),
                                tooltip_x + 52, py, 410, 32, 15, text_main)
                        end
                    end
                    for index = first, #passes do
                        passes[index].style.offset[3] = passes[index].style.offset[3] + TOOLTIP_Z
                        passes[index].visibility_function = hovered(hotspot_id)
                    end
                else
                    outline(x, y, 344, 90, alpha(text_dim, 60), 105)
                    text(string.format("%02d", i), x + 18, y + 12, 30, 24, 12, text_dim)
                    text(loc("curio_empty"), x + 48, y + 34, 280, 30, 16, text_dim)
                end
            end
        end

        -- Signature talents
        local signature_y = 650
        section_header(24, 614, 1072, loc("signature"))
        for i, category in ipairs(SIGNATURES) do
            local x = 24 + (i - 1) * 272
            local hotspot_id = "signature_hotspot_" .. i
            card(x, signature_y, 256, 169, accent)
            text(Utf8.upper(loc(category)), x + 14, signature_y + 10, 228, 24, 12, accent)
            local names, descriptions, icons = {}, {}, {}
            for _, id in ipairs(snapshot.signature and snapshot.signature[category] or {}) do
                local talent = talent_by_id[id]
                names[#names + 1] = talent and talent.name or id
                descriptions[#descriptions + 1] = talent and talent.description or loc("no_description")
                if talent and talent.icon then icons[#icons + 1] = talent.icon end
            end
            local icon_count = math.min(#icons, 3)
            for j = 1, icon_count do
                passes[#passes + 1] = {
                    pass_type = "texture", value = "content/ui/materials/frames/talents/talent_icon_container",
                    style = {
                        offset = { x + 128 - icon_count * 30 + (j - 1) * 60, signature_y + 36, 111 }, size = { 60, 60 },
                        color = { 255, 255, 255, 255 },
                        material_values = { icon = icons[j], frame = "content/ui/textures/frames/talents/circular_frame",
                            icon_mask = "content/ui/textures/frames/talents/circular_frame_mask", intensity = 0, saturation = 1 },
                    },
                }
            end
            local names_y = icon_count > 0 and signature_y + 102 or signature_y + 40
            text(#names > 0 and table.concat(names, " / ") or loc("no_selection"), x + 12, names_y, 232,
                signature_y + 164 - names_y, 16, #names > 0 and text_main or text_dim, true, "center")
            hover_outline(x, signature_y, 256, 169, accent, hotspot_id)
            passes[#passes + 1] = {
                pass_type = "hotspot", content_id = hotspot_id,
                style = { offset = { x, signature_y, 115 }, size = { 256, 169 } },
            }
            local first = #passes + 1
            tooltip_card(170, 300, 780, 304, accent)
            text(Utf8.upper(loc(category)), 190, 312, 740, 24, 12, accent)
            text(table.concat(names, " / "), 190, 332, 740, 40, 23, text_main, true)
            rect(190, 374, 740, 1, divider, 104)
            local remaining = table.concat(descriptions, "\n\n"):gsub("{#[^}]*}", "")
            local pages = {}
            local tooltip_style = { font_type = "proxima_nova_bold", font_size = math.max(14, math.floor(18 * text_scale)) }
            while remaining ~= "" do
                local low, high, best = 1, Utf8.string_length(remaining), 1
                while low <= high do
                    local middle = math.floor((low + high) / 2)
                    local _, height = host:_text_size(Utf8.sub_string(remaining, 1, middle), tooltip_style, { 740, 100000 }, true)
                    if height <= 180 then best, low = middle, middle + 1 else high = middle - 1 end
                end
                pages[#pages + 1] = Utf8.sub_string(remaining, 1, best)
                remaining = Utf8.sub_string(remaining, best + 1)
            end
            local page_first = #passes + 1
            for page, value in ipairs(pages) do
                text(value, 190, 384, 740, 190, tooltip_style.font_size / text_scale, C.label)
                local page_pass = passes[#passes]
                page_pass.visibility_function = function(content)
                    local hotspot = content[hotspot_id]
                    return hotspot and hotspot.is_hover and (hotspot.page or 1) == page
                end
            end
            passes[#passes + 1] = {
                pass_type = "text", value = #pages > 1 and mod:localize("loadout_hover_scroll") or "",
                style = { offset = { 190, 576, 110 }, size = { 740, 24 }, font_type = "proxima_nova_bold",
                    font_size = 13, text_color = text_dim },
            }
            -- The view consumes wheel input over the card before player navigation.
            passes[first - 1].content = { page = 1, pages = #pages }
            for index = first, #passes do
                passes[index].style.offset[3] = passes[index].style.offset[3] + TOOLTIP_Z
                if index < page_first or not passes[index].visibility_function then
                    passes[index].visibility_function = hovered(hotspot_id)
                end
            end
        end
    else
        section_header(24, 132, 1072, loc("tree"))
        -- The talent tree widgets are positioned inside this frame by AnotherScoreboard_talent_tree.
        rect(24, 168, 1072, CONTENT_H, opaque(surface), 101)
        outline(24, 168, 1072, CONTENT_H, border, 104)
        rect(24, 168, 1072, 2, player_color, 105)
        if host._loadout_tree_error then
            text(host._loadout_tree_error,
                154, 360, 812, 240, 22, text_sub, true, "center")
        end
    end

    return {
        weapon_icons = weapon_icons,
        columns = { { widget = UIWidget.create_definition(passes, scenegraph_id, nil, { W, panel_h }), offset = { (900 - W) / 2, 0, 0 } } },
        panel = { x = (900 - W) / 2, y = 0, w = W, h = panel_h },
        content_height = panel_h + 42,
        text_scale = text_scale,
    }
end

return LoadoutRender
