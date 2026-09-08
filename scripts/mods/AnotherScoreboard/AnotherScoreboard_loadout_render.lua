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
local SPECIAL = { tactical = true, aura = true, ability = true, keystone = true }
local W, H = 1120, 680

function LoadoutRender.build(host, scenegraph_id, players, selected_player, show_tree, selected_talent, settings)
    local Render = mod:get_render()
    Render.set_theme(settings and settings.scoreboard_theme)
    local C = Render.theme_colors()
    local text_scale = math.max(0.5, math.min(2, settings and settings.text_scale or 1))
    local passes = {}
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
    local entries, talent_by_id = {}, {}
    for i, layout in ipairs(snapshot and snapshot.layouts or {}) do
        for j, node in ipairs(layout.nodes or {}) do
            if (node.tier or 0) > 0 then
                entries[#entries + 1] = { node = node, layout = i, order = j }
                if node.talent_id then
                    talent_by_id[node.talent_id] = node
                end
            end
        end
    end
    table.sort(entries, function(a, b)
        if a.layout ~= b.layout then return a.layout < b.layout end
        if (a.node.y or 0) ~= (b.node.y or 0) then return (a.node.y or 0) < (b.node.y or 0) end
        if (a.node.x or 0) ~= (b.node.x or 0) then return (a.node.x or 0) < (b.node.x or 0) end
        if tostring(a.node.id) ~= tostring(b.node.id) then return tostring(a.node.id) < tostring(b.node.id) end
        return a.order < b.order
    end)
    local has_tree = #entries > 0
    for _, talent in ipairs(snapshot and snapshot.talents or {}) do
        if talent.id and not talent_by_id[talent.id] then
            talent_by_id[talent.id] = talent
        end
        if not has_tree then
            entries[#entries + 1] = { node = talent }
        end
    end
    local talent_index = math.max(1, math.min(#entries, math.floor(selected_talent or 1)))

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
        text(name or "-", x + 46, 77, 199, 24, 17, color)
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
                text(loc("rank"), x + 16, 411, 242, 20, 12, C.sub)
                text(weapon.rarity or "-", x + 16, 434, 242, 22, 14, C.label)
            end
        end
        for i, category in ipairs(SIGNATURES) do
            local x = 24 + (i - 1) * 272
            card(x, 486, 256, 169, C.title)
            text(loc(category), x + 14, 498, 228, 22, 15, C.title, true)
            local names, descriptions = {}, {}
            for _, id in ipairs(snapshot.signature and snapshot.signature[category] or {}) do
                local talent = talent_by_id[id]
                names[#names + 1] = talent and talent.name or id
                descriptions[#descriptions + 1] = talent and talent.description or loc("no_description")
            end
            text(#names > 0 and table.concat(names, " / ") or loc("no_selection"), x + 14, 529, 228, 41, 18, C.label, true)
            text(table.concat(descriptions, "\n"), x + 14, 579, 228, 72, 13, C.sub, false, nil, true)
        end
    else
        card(24, 168, 646, 487)
        card(686, 168, 410, 487, player_color)
        if has_tree then
            local groups, group_order = {}, {}
            for index, entry in ipairs(entries) do
                local group = groups[entry.layout]
                if not group then
                    group = { nodes = {}, by_id = {}, min_x = math.huge, max_x = -math.huge, min_y = math.huge, max_y = -math.huge }
                    groups[entry.layout] = group
                    group_order[#group_order + 1] = entry.layout
                end
                local node = entry.node
                local point = { node = node, index = index }
                group.nodes[#group.nodes + 1] = point
                if node.id then group.by_id[node.id] = point end
                group.min_x, group.max_x = math.min(group.min_x, node.x or 0), math.max(group.max_x, node.x or 0)
                group.min_y, group.max_y = math.min(group.min_y, node.y or 0), math.max(group.max_y, node.y or 0)
            end
            local lane_w = 610 / #group_order
            for lane, layout_index in ipairs(group_order) do
                local group = groups[layout_index]
                local range_x, range_y = group.max_x - group.min_x, group.max_y - group.min_y
                local scale = math.min((lane_w - 32) / math.max(range_x, 1), 404 / math.max(range_y, 1))
                local center_x = 42 + (lane - 0.5) * lane_w
                for _, point in ipairs(group.nodes) do
                    point.x = center_x + ((point.node.x or 0) - (group.min_x + group.max_x) * 0.5) * scale
                    point.y = 398 + ((point.node.y or 0) - (group.min_y + group.max_y) * 0.5) * scale
                end
                local linked = {}
                for _, point in ipairs(group.nodes) do
                    for _, key in ipairs({ "parents", "children" }) do
                        for _, id in ipairs(point.node[key] or {}) do
                            local other = group.by_id[id]
                            if other and other ~= point then
                                local edge = math.min(point.index, other.index) .. ":" .. math.max(point.index, other.index)
                                if not linked[edge] then
                                    linked[edge] = true
                                    local mid_y = (point.y + other.y) * 0.5
                                    local color = (point.index == talent_index or other.index == talent_index) and player_color or C.accent
                                    rect(point.x - 1, math.min(point.y, mid_y), 2, math.max(1, math.abs(point.y - mid_y)), color, 105)
                                    rect(math.min(point.x, other.x), mid_y - 1, math.max(2, math.abs(point.x - other.x)), 2, color, 105)
                                    rect(other.x - 1, math.min(other.y, mid_y), 2, math.max(1, math.abs(other.y - mid_y)), color, 105)
                                end
                            end
                        end
                    end
                end
                for _, point in ipairs(group.nodes) do
                    local selected = point.index == talent_index
                    local special = SPECIAL[point.node.type]
                    local spacing = math.huge
                    for _, other in ipairs(group.nodes) do
                        if other ~= point then
                            spacing = math.min(spacing, math.max(math.abs(point.x - other.x), math.abs(point.y - other.y)))
                        end
                    end
                    -- Dense lower branches must retain distinct nodes at overview scale.
                    local size = math.min(special and 18 or 14, math.max(1, spacing - 2))
                    local border = math.min(2, size / 4)
                    local color = selected and player_color or special and C.title or C.accent
                    rect(point.x - size / 2, point.y - size / 2, size, size, color, 107)
                    rect(point.x - size / 2 + border, point.y - size / 2 + border,
                        size - border * 2, size - border * 2, selected and player_color or opaque(C.panel), 108)
                end
            end
            text(string.format("%02d / %02d", #entries > 0 and talent_index or 0, #entries), 42, 622, 610, 22, 13, C.sub, false, "center")
        else
            text(loc("tree_missing"), 44, 186, 606, 69, 19, C.sub, true)
            local first = math.max(1, math.min(talent_index - 6, #entries - 12))
            for index = first, math.min(#entries, first + 12) do
                local y = 267 + (index - first) * 28
                if index == talent_index then rect(40, y, 614, 27, opaque(C.panel), 105) end
                text(string.format("%02d", index), 48, y + 3, 34, 24, 14, index == talent_index and player_color or C.sub)
                text(entries[index].node.name or entries[index].node.id, 94, y + 3, 546, 24, 15,
                    index == talent_index and player_color or C.label)
            end
        end
        local selected = entries[talent_index] and entries[talent_index].node
        text(string.format("%02d / %02d", selected and talent_index or 0, #entries), 710, 188, 362, 24, 15, player_color)
        text(selected and (selected.name or selected.talent_id or selected.id) or loc("no_selection"),
            710, 224, 362, 76, 28, C.title, true)
        rect(710, 322, 362, 1, C.accent, 104)
        text(selected and selected.description or loc("no_description"), 710, 342, 362, 262, 19, C.label)
        text("[LEFT / RIGHT]", 710, 623, 362, 22, 13, C.sub, false, "right")
    end

    return {
        columns = { { widget = UIWidget.create_definition(passes, scenegraph_id, nil, { W, H }), offset = { (900 - W) / 2, 0, 0 } } },
        panel = { x = (900 - W) / 2, y = 0, w = W, h = H },
        content_height = H + 42,
        text_scale = text_scale,
        talent_count = #entries,
    }
end

return LoadoutRender
