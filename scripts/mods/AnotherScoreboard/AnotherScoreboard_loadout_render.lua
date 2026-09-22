local mod = get_mod("AnotherScoreboard")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")

local LoadoutRender = {}
local PLAYER_COLORS = {
    { 255, 106, 224, 216 },
    { 255, 244, 115, 171 },
    { 255, 255, 139, 82 },
    { 255, 139, 164, 255 },
}
local SIGNATURES = { "blitz", "aura", "ability", "keystone" }
local W, H = 1120, 680

function LoadoutRender.build(host, scenegraph_id, players, selected_player, show_tree, settings)
    local Render = mod:get_render()
    Render.set_theme(settings and settings.scoreboard_theme)
    local C = Render.theme_colors()
    local text_scale = math.max(0.5, math.min(2, settings and settings.text_scale or 1))
    local passes = {}
    local weapon_icons = {}
    local function opaque(color)
        return { 255, color[2], color[3], color[4] }
    end
    local function rect(x, y, w, h, color, z)
        passes[#passes + 1] = {
            pass_type = "rect",
            style = { offset = { x, y, z or 102 }, size = { w, h }, color = color },
        }
    end
    local function text(value, x, y, w, h, size, color, title, align, fit_all)
        -- Snapshot descriptions contain engine markup; plain text also permits safe UTF-8 truncation.
        value = tostring(value or ""):gsub("{#[^}]*}", "")
        local style = {
            offset = { x, y, 110 }, size = { w, h },
            font_type = title and "itc_novarese_bold" or "proxima_nova_bold",
            font_size = math.max(10, math.floor(size * text_scale)),
            text_color = color or C.label,
            text_horizontal_alignment = align or "left", text_vertical_alignment = "top",
        }
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
        passes[#passes + 1] = { pass_type = "text", value_id = "text_" .. (#passes + 1), value = value, style = style }
    end
    local function card(x, y, w, h, accent)
        rect(x, y, w, h, opaque(C.section_bg))
        rect(x, y, w, 1, accent or C.accent, 104)
        rect(x, y + h - 1, w, 1, C.accent, 104)
        rect(x, y, 1, h, C.accent, 104)
        rect(x + w - 1, y, 1, h, C.accent, 104)
    end
    local function loc(id)
        return mod:localize("loadout_" .. id)
    end

    players = players or {}
    local player_index = math.max(1, math.min(math.min(#players, 4), math.floor(selected_player or 1)))
    local player = players[player_index]
    local snapshot = player and player.loadout_snapshot
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

    rect(0, 0, W, H, opaque(C.panel), 100)
    rect(0, 0, W, 2, C.title, 104)
    rect(0, 0, 1, H, C.accent, 104)
    rect(W - 1, 0, 1, H, C.accent, 104)
    rect(0, H - 1, W, 1, C.accent, 104)
    text(loc("title"), 24, 15, 630, 40, 30, C.title, true)
    text(loc("readonly"), 696, 23, 400, 24, 13, C.sub, false, "right")
    for i = 1, math.min(#players, 4) do
        local x = 24 + (i - 1) * 272
        local chosen, color = i == player_index, PLAYER_COLORS[i]
        card(x, 66, 256, 44, chosen and color or C.accent)
        rect(x + 1, 67, 34, 42, chosen and color or opaque(C.panel), 105)
        text(i, x + 5, 77, 26, 24, 17, chosen and opaque(C.panel) or color, false, "center")
        local name = type(players[i].name) == "function" and players[i]:name() or players[i].name
        text(players[i].string_symbol or "", x + 41, 75, 28, 28, 21, color, true, "center")
        text(name or "-", x + 75, 77, 170, 24, 17, color)
        passes[#passes + 1] = {
            pass_type = "hotspot", content_id = "player_select_" .. i,
            content = { pressed_callback = function() host:_select_loadout_player(i) end },
            style = { offset = { x, 66, 115 }, size = { 256, 44 } },
        }
        if chosen then rect(x + 35, 108, 220, 2, color, 105) end
    end
    text(loc(show_tree and "tree" or "equipment"), 24, 125, 730, 30, 22, C.title, true)
    text("[T]  " .. loc(show_tree and "equipment" or "tree"), 794, 130, 302, 23, 14, C.sub, false, "right")

    if not snapshot then
        card(24, 173, 1072, 463)
        text(loc("missing"), 154, 325, 812, 130, 24, C.sub, true, "center")
    elseif not show_tree then
        for i, slot in ipairs({ "slot_primary", "slot_secondary" }) do
            local weapon
            for _, candidate in ipairs(snapshot.weapons or {}) do
                if candidate.slot == slot then weapon = candidate break end
            end
            local x = 24 + (i - 1) * 544
            card(x, 168, 528, 300, player_color)
            text(string.format("%02d", i), x + 16, 180, 32, 28, 17, player_color)
            local weapon_name = weapon and weapon.name
            if weapon_name and weapon_name:find("<unlocalized", 1, true) then
                weapon_name = slot == "slot_primary" and "Bot Melee Weapon" or "Bot Ranged Weapon"
            end
            text(weapon_name or loc("no_weapon"), x + 57, 179, 453, 48, 23, C.label, true)
            if weapon then
                text(loc("expertise") .. "  " .. tostring(weapon.rating or "-"), x + 16, 229, 242, 24, 15, C.title)
                text(loc("stats") .. "  " .. tostring(weapon.base_rating or "-"), x + 278, 229, 232, 24, 15, C.sub, false, "right")
                rect(x + 16, 260, 496, 1, C.accent)
                local stats = weapon.base_stats or {}
                local row_h = math.min(22, 118 / math.max(#stats, 1))
                for j, stat in ipairs(stats) do
                    local y = 271 + (j - 1) * row_h
                    local value = math.max(0, math.min(1, tonumber(stat.value) or 0))
                    text(stat.name or stat.id, x + 16, y, 113, row_h, 12, C.sub)
                    rect(x + 137, y + row_h * 0.3, 66, math.max(1, row_h * 0.3), opaque(C.panel))
                    rect(x + 137, y + row_h * 0.3, 66 * value, math.max(1, row_h * 0.3), player_color, 105)
                    text(string.format("%.0f%%", value * 100), x + 209, y, 42, row_h, 12, C.label, false, "right")
                end
                text(loc("perks"), x + 278, 271, 234, 20, 13, C.title)
                text(loc("blessings"), x + 278, 363, 234, 20, 13, C.title)
                for group_index, key in ipairs({ "perks", "blessings" }) do
                    local lines = {}
                    for _, trait in ipairs(weapon[key] or {}) do
                        local tier = trait.rarity ~= nil and (" [" .. tostring(trait.rarity) .. "]") or ""
                        local name = trait.name or trait.id or "-"
                        local description = trait.description
                        if key == "perks" then
                            lines[#lines + 1] = description and description ~= "" and description or loc("no_description")
                        else
                            lines[#lines + 1] = name .. tier .. (description and description ~= name and (": " .. description) or "")
                        end
                    end
                    text(#lines > 0 and table.concat(lines, "\n") or loc("no_selection"),
                        x + 278, group_index == 1 and 294 or 386, 234, 59, 14, C.label)
                end
                if weapon.master_item_name then
                    local style_id = "weapon_icon_" .. i
                    local size = { 242, 68 }
                    passes[#passes + 1] = {
                        pass_type = "texture", style_id = style_id,
                        value = "content/ui/materials/icons/items/containers/item_container_landscape_no_rarity",
                        style = {
                            offset = { x + 16, 390, 105 }, size = size,
                            color = { 0, 255, 255, 255 },
                            material_values = { use_placeholder_texture = 1 },
                        },
                    }
                    weapon_icons[#weapon_icons + 1] = {
                        style_id = style_id, master_item_name = weapon.master_item_name,
                        slot = slot, size = size,
                    }
                end
            end
        end
        for i, category in ipairs(SIGNATURES) do
            local x = 24 + (i - 1) * 272
            card(x, 486, 256, 169, C.title)
            text(loc(category), x + 14, 498, 228, 22, 15, C.title, true)
            local names, descriptions, icons = {}, {}, {}
            for _, id in ipairs(snapshot.signature and snapshot.signature[category] or {}) do
                local talent = talent_by_id[id]
                names[#names + 1] = talent and talent.name or id
                descriptions[#descriptions + 1] = talent and talent.description or loc("no_description")
                if talent and talent.icon then icons[#icons + 1] = talent.icon end
            end
            text(#names > 0 and table.concat(names, " / ") or loc("no_selection"), x + 14, 529, 228, 41, 18, C.label, true)
            for j, icon in ipairs(icons) do
                passes[#passes + 1] = {
                    pass_type = "texture", value = "content/ui/materials/frames/talents/talent_icon_container",
                    style = {
                        offset = { x + 128 - #icons * 34 + (j - 1) * 68, 578, 111 }, size = { 64, 64 },
                        color = { 255, 255, 255, 255 },
                        material_values = { icon = icon, frame = "content/ui/textures/frames/talents/circular_frame",
                            icon_mask = "content/ui/textures/frames/talents/circular_frame_mask", intensity = 0, saturation = 1 },
                    },
                }
            end
            local hotspot_id = "signature_hotspot_" .. i
            passes[#passes + 1] = {
                pass_type = "hotspot", content_id = hotspot_id,
                style = { offset = { x, 486, 115 }, size = { 256, 169 } },
            }
            local first = #passes + 1
            card(170, 170, 780, 304, C.title)
            text(table.concat(names, " / "), 190, 184, 740, 50, 23, C.title, true)
            local remaining = table.concat(descriptions, "\n\n"):gsub("{#[^}]*}", "")
            local pages = {}
            local tooltip_style = { font_type = "proxima_nova_bold", font_size = math.max(14, math.floor(18 * text_scale)) }
            while remaining ~= "" do
                local low, high, best = 1, Utf8.string_length(remaining), 1
                while low <= high do
                    local middle = math.floor((low + high) / 2)
                    local _, height = host:_text_size(Utf8.sub_string(remaining, 1, middle), tooltip_style, { 740, 100000 }, true)
                    if height <= 190 then best, low = middle, middle + 1 else high = middle - 1 end
                end
                pages[#pages + 1] = Utf8.sub_string(remaining, 1, best)
                remaining = Utf8.sub_string(remaining, best + 1)
            end
            local page_first = #passes + 1
            for page, value in ipairs(pages) do
                text(value, 190, 239, 740, 200, tooltip_style.font_size / text_scale, C.label)
                local page_pass = passes[#passes]
                page_pass.visibility_function = function(content)
                    return content[hotspot_id].is_hover and (content[hotspot_id].page or 1) == page
                end
            end
            passes[#passes + 1] = {
                pass_type = "text", value = #pages > 1 and mod:localize("loadout_hover_scroll") or "",
                style = { offset = { 190, 445, 110 }, size = { 740, 24 }, font_type = "proxima_nova_bold",
                    font_size = 14, text_color = C.sub },
            }
            -- The view consumes wheel input over the card before player navigation.
            passes[first - 1].content = { page = 1, pages = #pages }
            for index = first, #passes do
                passes[index].style.offset[3] = passes[index].style.offset[3] + 100
                if index < page_first or not passes[index].visibility_function then
                    passes[index].visibility_function = function(content) return content[hotspot_id].is_hover end
                end
            end
        end
    else
        card(24, 168, 1072, 487, player_color)
        if host._loadout_tree_error then
            text(host._loadout_tree_error,
                154, 280, 812, 240, 22, C.sub, true, "center")
        end
    end

    return {
        weapon_icons = weapon_icons,
        columns = { { widget = UIWidget.create_definition(passes, scenegraph_id, nil, { W, H }), offset = { (900 - W) / 2, 0, 0 } } },
        panel = { x = (900 - W) / 2, y = 0, w = W, h = H },
        content_height = H + 42,
        text_scale = text_scale,
    }
end

return LoadoutRender
