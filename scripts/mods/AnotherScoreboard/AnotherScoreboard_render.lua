---@type AnotherScoreboardMod
local mod = get_mod("AnotherScoreboard")

local pairs              = pairs
local ipairs             = ipairs
local type               = type
local math_floor         = math.floor
local math_max           = math.max
local math_min           = math.min
local string_format      = string.format
local utf8_string_length = Utf8.string_length
local utf8_sub_string    = Utf8.sub_string

local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local UIWorkspace = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local Themes = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_themes")

local BASE_Z          = 100
local PANEL_W         = 800
local COL_W           = 150
local LABEL_W         = 148
local SPACING         = 6
local ROW_H           = 22
local HEADER_H        = 42
local TITLE_H         = 42
local TITLE_GAP       = 6
local SECTION_H       = 26
local NAME_FONT       = 15
local ROW_FONT        = 13
local TITLE_FONT      = 26
local SECTION_FONT    = 14
local FONT_INCREASE   = 2
local SUB_FONT_SCALE  = 0.85
local SUB_INDENT      = 16
local PANEL_PAD       = 6
local PANEL_HEADER_H  = 50
local PLAYER_BAR_H    = 3
local SCOREBOARD_FOOTER_H = 36
local SHADOW_LAYERS   = { { 2, 60 }, { 4, 40 }, { 7, 24 }, { 11, 12 } }
local FIT_MARGIN       = 32
local FIT_MIN_SCALE    = 0.70

local SCREEN_ORIGIN_X = 480
local SCREEN_ORIGIN_Y = 190
local VIEW_W          = 900
local VIEW_H          = 700
local SCREEN_H         = UIWorkspace.screen.size[2]

local C = Themes.by_id[Themes.default].colors

local PLAYER_COLORS = {
    { 255, 106, 224, 216 },
    { 255, 244, 115, 171 },
    { 255, 255, 139,  82 },
    { 255, 139, 164, 255 },
}

local PLACEHOLDER_NAMES = {
    "Varlet", "Reject", "Interrogator", "Acolyte",
    "Penitent", "Templar", "Crusader", "Witch Hunter",
}

local UNRANKED_ROWS = {
    ammo_pickups = true,
    ammo_collected = true,
}

local _dim = { scale = 1.0, text_scale = 1.0 }
local _rect
local _txt

local function _shorten(v)
    if v >= 1e6 then return string_format("%.1fM", v * 1e-6) end
    if v >= 1e3 then return string_format("%.1fK", v * 1e-3) end
    return string_format("%.0f", v)
end

local function _truncate(text, max_len)
    if not text or utf8_string_length(text) <= max_len then
        return text
    end

    return utf8_sub_string(text, 1, max_len)
end

local function _player_archetype_icon(player)
    if not player then
        return nil
    end

    if player.string_symbol and player.string_symbol ~= "" then
        return player.string_symbol
    end

    if type(player.profile) ~= "function" then
        return nil
    end

    local profile = player:profile()
    local archetype_name = profile and profile.archetype and profile.archetype.name

    return archetype_name and UISettings.archetype_font_icon[archetype_name]
end

local function _row_height(row)
    if row.height_scale then
        return math_floor(_dim.row_h * row.height_scale)
    end

    if row.full_width then
        return math_floor(_dim.row_h * (row.height_scale or 0.85))
    end

    local row_style = row.style or (row.parent and "sub" or "main")

    if row_style == "sub" or row.parent then
        return math_floor(_dim.row_h * SUB_FONT_SCALE)
    end

    return _dim.row_h
end

local function _row_label(row, player_data)
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

    if type(row.count) == "number" and row.count > 1 then
        text = string_format("%s (%d)", text, row.count)
    end

    if row.rate_label then
        text = text .. " (rate)"
    end

    local enemy_detail = row.show_total or row.parent == "lesser_enemies_killed"
        or row.parent == "specials_killed" or row.parent == "elites_killed"
    if enemy_detail and player_data then
        local total = 0
        for i = 1, #player_data do
            total = total + player_data[i].score
        end
        text = string_format("%s (%s)", text, _shorten(total))
    end

    return text
end

local function _row_depth(row)
    if type(row.depth) == "number" then
        return row.depth
    end

    return row.parent and 1 or 0
end

local function _row_value(row, score, percentage)
    if score == 0 and row.zero_text then
        return row.zero_text
    end

    local suffix = row.suffix or (row.id == "coherency_uptime" and "%" or "")
    local value = row.decimals and string_format("%." .. row.decimals .. "f", score) or _shorten(score)

    value = value .. suffix
    if type(percentage) == "number" then
        value = string_format("%s (%.0f%%)", value, percentage)
    end

    return value
end

local function _fit_label_font_size(host, ui_renderer, text, font_type, font_size, max_width, max_height)
    if max_height then
        font_size = math_min(font_size, math_max(1, math_floor(max_height)))
    end

    if not host or type(host._text_size) ~= "function" or max_width <= 0 then
        return font_size
    end

    local style = {
        font_size = font_size,
        font_type = font_type,
    }
    local text_width = ui_renderer and host:_text_size(ui_renderer, text, style)
        or host:_text_size(text, style)

    if text_width > max_width then
        return math_max(1, math_floor(font_size * max_width / text_width))
    end

    return font_size
end

local function _text_font_size(font_size)
    return math_max(1, math_floor(font_size * _dim.text_scale))
end

local function _scaled(value)
    return math_floor(value * _dim.scale)
end

local function _panel_pad()
    return math_max(4, _scaled(PANEL_PAD))
end

local function _panel_header_h()
    return math_max(24, _scaled(PANEL_HEADER_H))
end

local function _panel_metrics(width, num_players)
    local gap = math_max(4, _scaled(SPACING))
    local label_w = math_min(_dim.label_w, math_floor(width * 0.30))
    local col_w = math_floor((width - label_w - gap * (num_players + 2)) / num_players)
    local min_col_w = math_max(44, _scaled(44))

    if col_w < min_col_w then
        col_w = min_col_w
        label_w = width - col_w * num_players - gap * (num_players + 2)
        label_w = math_max(math_floor(width * 0.24), label_w)
    end

    return label_w, col_w, gap
end

local function _combined_panel_height(sections)
    local h = _panel_pad() * 2 + _panel_header_h()

    for _, section in ipairs(sections) do
        h = h + _dim.section_h

        for _, row in ipairs(section.rows) do
            h = h + _row_height(row)
        end
    end

    return h
end

local function _combined_panel_layout(sections, settings)
    local panel_h = _combined_panel_height(sections)

    if settings and settings.panel_min_h and panel_h < settings.panel_min_h then
        panel_h = settings.panel_min_h
    end

    return {
        x = -_dim.panel_w * 0.5,
        y = _dim.title_h + _scaled(TITLE_GAP),
        w = _dim.panel_w,
        h = panel_h,
    }
end

local function _player_name(player, aid, index, max_len)
    local real = aid and aid ~= ""
    local name = real and player:name()
    if not name or name == "" then
        return PLACEHOLDER_NAMES[index]
    end

    return _truncate(name, max_len or 16)
end

local function _row_player_data(row, ids, num_players)
    local player_data = {}
    local ranked = row.ranked ~= false and not UNRANKED_ROWS[row.id]

    for pi = 1, num_players do
        local aid = ids[pi]
        local score = 0
        local percentage = row.display_percentage_values and row.display_percentage_values[aid]
        local vc = _row_depth(row) > 0 and C.sub or C.normal
        local rank

        if row.values then
            local value = row.values[aid]

            if type(value) == "table" then
                score = value.score or value.value or 0
                if ranked and value.best then vc, rank = C.best, "best" end
                if ranked and value.worst and (row.external or score ~= 0) then vc, rank = C.worst, "worst" end
            else
                score = value or 0
            end
        else
            local sd = mod:get_stat_data(row.id)
            if sd then
                local rd = sd[aid]
                score = rd and rd.score or 0
                if ranked and rd and rd.best then vc, rank = C.best, "best" end
                if ranked and rd and rd.worst and score ~= 0 then vc, rank = C.worst, "worst" end
            end
        end

        player_data[pi] = { score = score, percentage = percentage, color = vc, rank = rank }
        if row.external and not (row.values and row.values[aid]) then player_data[pi].score = nil end
    end

    return player_data
end

local function _hline(passes, x, y, z, w, color)
    passes[#passes + 1] = _rect(x, y, z, w, 1, color)
end

local function _outline(passes, x, y, z, w, h, color)
    passes[#passes + 1] = _rect(x, y, z, w, 1, color)
    passes[#passes + 1] = _rect(x, y + h - 1, z, w, 1, color)
    passes[#passes + 1] = _rect(x, y + 1, z, 1, h - 2, color)
    passes[#passes + 1] = _rect(x + w - 1, y + 1, z, 1, h - 2, color)
end

local function _soft_shadow(passes, x, y, w, h)
    local base_alpha = C.shadow[1]
    for i = 1, #SHADOW_LAYERS do
        local spread = math_max(1, _scaled(SHADOW_LAYERS[i][1]))
        local alpha = math_floor(base_alpha * SHADOW_LAYERS[i][2] / 60)
        passes[#passes + 1] = _rect(x - spread, y - math_floor(spread * 0.3), BASE_Z - 1 - i,
            w + spread * 2, h + math_floor(spread * 1.6), { alpha, C.shadow[2], C.shadow[3], C.shadow[4] })
    end
end

-- Symmetric line that fades out toward both ends.
local function _fade_line(passes, x, y, z, w, h, color, steps)
    steps = steps or 8
    local half = w * 0.5
    local segment = half / steps
    for i = 0, steps - 1 do
        local alpha = math_floor(color[1] * (1 - i / steps))
        local seg_w = math_max(1, math_floor(segment + 0.5))
        local offset = math_floor(segment * i)
        local c = { alpha, color[2], color[3], color[4] }
        passes[#passes + 1] = _rect(x + math_floor(half) + offset, y, z, seg_w, h, c)
        passes[#passes + 1] = _rect(x + math_floor(half) - offset - seg_w, y, z, seg_w, h, c)
    end
end

local function _add_row_passes(passes, row, row_key, row_y, layout, label_x, label_w, col_w, gap, ox, ids,
        num_players, row_background, host, ui_renderer)
    local row_style = row.style or (row.parent and "sub" or "main")
    local full_width = row.full_width
    local child = row_style == "sub" or row.parent
    local depth = _row_depth(row)
    local rh = _row_height(row)
    local fs = _text_font_size(child and math_floor(_dim.base_row_font * SUB_FONT_SCALE) + FONT_INCREASE
        or _dim.base_row_font + FONT_INCREASE)
    local label_fs = row.font_scale and math_floor(_dim.base_row_font * row.font_scale) + FONT_INCREASE
        or full_width and math_floor(_dim.base_row_font * 0.82) + FONT_INCREASE
        or child and math_floor(_dim.base_row_font * 0.78) + FONT_INCREASE
        or _dim.base_row_font + FONT_INCREASE
    label_fs = _text_font_size(label_fs)
    local label_color = full_width and C.section or depth >= 2 and C.label_nested or child and C.label_sub or C.label
    local player_data = _row_player_data(row, ids, num_players)
    local rtext = _row_label(row, player_data)
    if row.external_group and row.collapsible then
        rtext = (row.external_collapsed and "+ " or "− ") .. rtext
        if not ui_renderer and host and host._toggle_external_group then
            passes[#passes + 1] = {
                pass_type = "hotspot", content_id = "external_hotspot_" .. row_key,
                content = { pressed_callback = function() host:_toggle_external_group(row.id, row.external_collapsed) end },
                style = { offset = { label_x, row_y, BASE_Z + 9 }, size = { label_w, rh } },
            }
        end
    end

    if full_width then
        passes[#passes + 1] = _rect(ox + 1, row_y, BASE_Z + 4, layout.w - 2, rh, C.section_col)
    elseif row_background then
        passes[#passes + 1] = _rect(ox + 1, row_y, BASE_Z + 2, layout.w - 2, rh, row_background)
    end

    if not full_width then
        _hline(passes, label_x, row_y + rh - 1, BASE_Z + 4, layout.w - gap * 2, C.row_div)
    end

    if full_width then
        label_fs = _fit_label_font_size(host, ui_renderer, rtext, "proxima_nova_bold", label_fs,
            layout.w - _scaled(4), rh)
        passes[#passes + 1] = _txt("label_" .. row_key, rtext, ox, row_y, BASE_Z + 5,
            layout.w, rh, "proxima_nova_bold", label_fs, "center", "center", label_color)
    elseif row.no_values then
        label_fs = _fit_label_font_size(host, ui_renderer, rtext, "proxima_nova_bold", label_fs,
            label_w - _scaled(2), rh)
        passes[#passes + 1] = _txt("label_" .. row_key, rtext, label_x + _scaled(6), row_y, BASE_Z + 5,
            label_w - _scaled(6), rh, "proxima_nova_bold", label_fs, "left", "center", label_color)
    else
        local indent = _scaled(6) + _dim.sub_indent * depth
        local text_width = label_w - indent

        if depth > 0 then
            local guide_x = label_x + indent - math_floor(_dim.sub_indent * 0.55)
            passes[#passes + 1] = _rect(guide_x, row_y, BASE_Z + 4, math_max(1, _scaled(2)), rh - 1, C.accent_soft)
        end

        if row.boss_detail then
            text_width = text_width + gap + math_floor(col_w * 0.3)
        end

        label_fs = _fit_label_font_size(host, ui_renderer, rtext, "proxima_nova_bold", label_fs,
            text_width - _scaled(2), rh)

        passes[#passes + 1] = _txt("label_" .. row_key, rtext, label_x + indent, row_y, BASE_Z + 5,
            text_width, rh, "proxima_nova_bold", label_fs, "left", "center", label_color)

        local pill_w = math_max(math_floor(col_w * 0.64), math_min(col_w - 4, _scaled(40)))
        local pill_inset = math_max(1, _scaled(2))

        for pi = 1, num_players do
            local col_x = ox + gap + label_w + gap + (pi - 1) * (col_w + gap)
            local pd = player_data[pi]
            local value_text = row.external and mod.external_stats.format(row, pd.score)
                or _row_value(row, pd.score, pd.percentage)
            local value_fs = _fit_label_font_size(host, ui_renderer, value_text, "proxima_nova_bold", fs,
                col_w - _scaled(2), rh)

            if pd.rank == "best" then
                local pill_x = col_x + math_floor((col_w - pill_w) * 0.5)
                local pill_h = rh - pill_inset * 2 - 1
                passes[#passes + 1] = _rect(pill_x, row_y + pill_inset, BASE_Z + 3, pill_w, pill_h, C.best_bg)
                passes[#passes + 1] = _rect(pill_x, row_y + pill_inset, BASE_Z + 4, math_max(1, _scaled(2)), pill_h, C.best)
            end

            passes[#passes + 1] = _txt("value_" .. row_key .. "_" .. pi, value_text, col_x, row_y, BASE_Z + 5,
                col_w, rh, "proxima_nova_bold", value_fs, "center", "center", pd.color)
        end
    end

    return row_y + rh
end

local function _add_player_header_passes(passes, players, ids, layout, ox, header_y, label_w, col_w, gap, header_h, host, ui_renderer, social_icons)
    local num_players = #players
    local bar_h = math_max(2, _scaled(PLAYER_BAR_H))
    local tint_alpha = C.header_tint_alpha or 26

    for pi = 1, num_players do
        local aid = ids[pi]
        local col_x = ox + gap + label_w + gap + (pi - 1) * (col_w + gap)
        local name_color = PLAYER_COLORS[pi] or PLAYER_COLORS[1]
        local icon = _player_archetype_icon(players[pi])
        local social_account_id = social_icons and players[pi].social_account_id or nil
        local content_y = header_y + bar_h
        local content_h = header_h - bar_h
        local icon_h = icon and math_floor(content_h * 0.44) or 0
        local status_key = players[pi].left_near_end and "player_left_near_end" or players[pi].is_bot and "player_bot"
        local status_h = status_key and math_floor(content_h * 0.26) or 0
        local name_y = content_y + icon_h
        local name_h = content_h - icon_h - status_h

        passes[#passes + 1] = _rect(col_x, header_y, BASE_Z + 3, col_w, header_h,
            { tint_alpha, name_color[2], name_color[3], name_color[4] })
        passes[#passes + 1] = _rect(col_x, header_y, BASE_Z + 6, col_w, bar_h, name_color)

        local name_len = layout.w < VIEW_W and 14 or 18
        if icon then
            passes[#passes + 1] = _txt("player_icon_" .. pi, icon, col_x, content_y + _scaled(2), BASE_Z + 8,
                col_w, icon_h, "itc_novarese_bold", math_max(_dim.icon_font, 10), "center", "center", name_color)
        end

        local player_name = _player_name(players[pi], aid, pi, name_len)
        local name_font_size = _fit_label_font_size(host, ui_renderer, player_name, "proxima_nova_bold",
            math_max(_dim.name_font, 9), col_w - _scaled(8), name_h)
        passes[#passes + 1] = _txt("player_" .. pi, player_name, col_x, name_y, BASE_Z + 8,
            col_w, name_h, "proxima_nova_bold", name_font_size, "center", "center", C.normal)

        if status_h > 0 then
            local text = mod:localize(status_key)
            local font_size = _fit_label_font_size(host, ui_renderer, text, "proxima_nova_bold",
                math_max(_dim.name_font - 3, 9), col_w - _scaled(8), status_h)
            passes[#passes + 1] = _txt("player_status_" .. pi, text, col_x, name_y + name_h, BASE_Z + 8,
                col_w, status_h, "proxima_nova_bold", font_size, "center", "center", C.text_dim)
        end

        if social_account_id and host then
            local hotspot_id = "social_hotspot_" .. pi
            local hotspot_size = math_min(math_floor(24 * _dim.scale), content_h)
            local icon_size = math_min(math_max(math_floor(16 * _dim.scale), 10), 18)
            icon_size = math_min(icon_size, hotspot_size)
            local hotspot_x = col_x + col_w - hotspot_size - _scaled(2)
            local hotspot_y = content_y + _scaled(2)
            local icon_x = hotspot_x + math_floor((hotspot_size - icon_size) / 2)
            local icon_y = hotspot_y + math_floor((hotspot_size - icon_size) / 2)
            passes[#passes + 1] = {
                pass_type = "hotspot", content_id = hotspot_id,
                content = { pressed_callback = function() host:_open_player_social(social_account_id) end },
                style = { offset = { hotspot_x, hotspot_y, BASE_Z + 9 }, size = { hotspot_size, hotspot_size } },
            }
            passes[#passes + 1] = {
                pass_type = "rect",
                style_id = "social_bg_" .. pi,
                style = {
                    offset = { hotspot_x, hotspot_y, BASE_Z + 7 },
                    size = { hotspot_size, hotspot_size },
                    color = { 0, name_color[2], name_color[3], name_color[4] },
                },
                change_function = function(content, style)
                    style.color[1] = content[hotspot_id].is_hover and 90 or 0
                end,
            }
            passes[#passes + 1] = {
                pass_type = "texture",
                style_id = "social_icon_" .. pi,
                value = "content/ui/materials/icons/system/escape/social",
                style = {
                    offset = { icon_x, icon_y, BASE_Z + 8 },
                    size = { icon_size, icon_size },
                    color = { 160, name_color[2], name_color[3], name_color[4] },
                },
                change_function = function(content, style)
                    style.color[1] = content[hotspot_id].is_hover and 255 or 160
                end,
            }
        end
    end
end

local function _combined_panel_passes(players, ids, sections, layout, ox, oy, settings,
        host, ui_renderer)
    local num_players = #players
    local label_w, col_w, gap = _panel_metrics(layout.w, num_players)
    local header_h = _panel_header_h()
    local alternating_row_shading = settings and settings.alternating_row_shading
    local social_icons = settings and settings.social_icons
    local passes = {}

    _soft_shadow(passes, ox, oy, layout.w, layout.h)
    passes[#passes + 1] = _rect(ox, oy, BASE_Z, layout.w, layout.h, C.panel)
    _outline(passes, ox, oy, BASE_Z + 7, layout.w, layout.h, C.border)

    local label_x = ox + gap
    local row_y = oy + _panel_pad()
    local header_band_h = header_h + _panel_pad() * 2

    passes[#passes + 1] = _rect(ox + 1, oy + 1, BASE_Z + 1, layout.w - 2, header_band_h - 1, C.header_bg)
    _hline(passes, ox + 1, oy + header_band_h - 1, BASE_Z + 6, layout.w - 2, C.accent_soft)

    local lane_alpha = C.lane_alpha or 9
    local lane_y = oy + header_band_h
    local lane_h = layout.h - header_band_h - 1
    for pi = 1, num_players do
        local color = PLAYER_COLORS[pi] or PLAYER_COLORS[1]
        local col_x = ox + gap + label_w + gap + (pi - 1) * (col_w + gap)
        passes[#passes + 1] = _rect(col_x, lane_y, BASE_Z + 1, col_w, lane_h,
            { lane_alpha, color[2], color[3], color[4] })
    end

    _add_player_header_passes(passes, players, ids, layout, ox, row_y, label_w, col_w, gap, header_h, host, ui_renderer, social_icons)
    row_y = row_y + header_h + _panel_pad()

    local tick_w = math_max(2, _scaled(3))

    for si = 1, #sections do
        local section = sections[si]
        local cat_text = section.category.label_text or mod:localize(section.category.label) or section.category.key
        cat_text = Utf8.upper(cat_text)
        local text_x = ox + tick_w + _scaled(10)
        local section_font_size = _fit_label_font_size(host, ui_renderer, cat_text, "itc_novarese_bold",
            _dim.section_font, layout.w - (text_x - ox) - _scaled(8), _dim.section_h)
        local main_row_index = 0

        passes[#passes + 1] = _rect(ox + 1, row_y, BASE_Z + 3, layout.w - 2, _dim.section_h, C.section_bg)
        passes[#passes + 1] = _rect(ox + 1, row_y, BASE_Z + 4, tick_w, _dim.section_h, C.accent)
        _hline(passes, ox + 1, row_y + _dim.section_h - 1, BASE_Z + 4, layout.w - 2, C.accent_soft)
        passes[#passes + 1] = _txt("section_" .. si, cat_text, text_x, row_y, BASE_Z + 8,
            layout.w - (text_x - ox) - _scaled(8), _dim.section_h,
            "itc_novarese_bold", section_font_size, "left", "center", C.section)
        row_y = row_y + _dim.section_h

        for ri = 1, #section.rows do
            local row = section.rows[ri]
            local row_style = row.style or (row.parent and "sub" or "main")
            local detail_row = row_style == "sub" or row.parent
            local row_background

            if detail_row then
                row_background = C.detail_bg
            else
                main_row_index = main_row_index + 1
                if alternating_row_shading and main_row_index % 2 == 0 then
                    row_background = C.row_alt
                end
            end

            row_y = _add_row_passes(passes, row, si .. "_" .. ri, row_y, layout, label_x, label_w,
                col_w, gap, ox, ids, num_players, row_background, host, ui_renderer)
        end
    end

    return passes
end

local function _with_alpha(color, alpha)
    return { alpha, color[2], color[3], color[4] }
end

local function _title_text(settings)
    return settings and settings.title_text or "Scoreboard"
end

_rect = function(x, y, z, w, h, color)
    return { pass_type = "rect", style = { offset = { x, y, z }, size = { w, h }, color = color } }
end

_txt = function(vid, text, x, y, z, w, h, font, size, halign, valign, color)
    local s = {
        offset = { x, y, z }, size = { w, h },
        font_size = size, font_type = font,
        text_horizontal_alignment = halign or "center",
        text_vertical_alignment   = valign or "center",
        text_color = color,
    }
    return { value_id = vid, value = text, pass_type = "text", style = s }
end

local function _title_passes(x, y, w, h, value_id, title_text, font_size)
    local passes = {}
    local bar_h = math_max(2, _scaled(2))
    _soft_shadow(passes, x, y, w, h)
    passes[#passes + 1] = _rect(x, y, BASE_Z, w, h, C.title_bg)
    _outline(passes, x, y, BASE_Z + 7, w, h, C.border)
    passes[#passes + 1] = _rect(x, y, BASE_Z + 8, w, bar_h, C.accent)
    _fade_line(passes, x + _scaled(40), y + h - bar_h - _scaled(3), BASE_Z + 8, w - _scaled(80), 1, C.accent_soft, 10)

    local title_pass = _txt(value_id, title_text, x + _scaled(12), y + bar_h, BASE_Z + 10, w - _scaled(24), h - bar_h * 2,
        "itc_novarese_bold", font_size, "center", "center", C.title)
    title_pass.style_id = "title"
    table.insert(passes, 1, title_pass)

    return passes
end

local function _footer_passes(x, y, w, h, value_id, text, font_size)
    local passes = {
        _rect(x, y, BASE_Z + 20, w, h, C.history_footer),
        _rect(x, y, BASE_Z + 21, w, 1, C.row_div),
        _rect(x, y + h - 1, BASE_Z + 21, w, 1, C.border),
        _rect(x, y, BASE_Z + 21, 1, h, C.border),
        _rect(x + w - 1, y, BASE_Z + 21, 1, h, C.border),
        _txt(value_id, text, x + _scaled(16), y, BASE_Z + 22, w - _scaled(32), h,
            "proxima_nova_bold", font_size, "center", "center", C.history_hint_text),
    }
    return passes
end

local function _color_markup(color)
    return string_format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
end

-- Returns footer text with highlighted key names, plus the same text without markup for measuring.
local function _style_hint(text)
    if type(text) ~= "string" or text == "" then
        return text, text
    end

    local key_open = _color_markup(C.footer_key)
    local sep_open = _color_markup(C.text_dim)
    local styled, plain = {}, {}

    for part in (text .. "  |  "):gmatch("(.-)%s+|%s+") do
        local key, desc = part:match("^%[(.-)%]%s*(.*)$")
        if not key then
            key, desc = part:match("^(.-)%s+%-%s+(.*)$")
        end

        if key and key ~= "" then
            styled[#styled + 1] = key_open .. key .. "{#reset()}  " .. desc
            plain[#plain + 1] = key .. "  " .. desc
        elseif part ~= "" then
            styled[#styled + 1] = part
            plain[#plain + 1] = part
        end
    end

    if #styled == 0 then
        return text, text
    end

    return table.concat(styled, "   " .. sep_open .. "|{#reset()}   "), table.concat(plain, "   |   ")
end

local Render = {}

function Render.set_theme(theme_id)
    local selected = Themes.by_id[theme_id] or Themes.by_id[Themes.default]
    C = selected.colors
end

function Render.theme_colors()
    return C
end

function Render.style_hint(text)
    return _style_hint(text)
end

function Render.footer_height()
    return SCOREBOARD_FOOTER_H
end

function Render.footer_passes(x, y, w, h, value_id, text, font_size)
    return _footer_passes(x, y, w, h, value_id, text, font_size)
end

function Render.title_font_size(host, ui_renderer, text, max_font_size, max_width, max_height)
    return _fit_label_font_size(host, ui_renderer, text or "", "itc_novarese_bold",
        max_font_size, max_width, max_height)
end

function Render.fit_text_font_size(host, ui_renderer, text, font_type, font_size, max_width, max_height)
    return _fit_label_font_size(host, ui_renderer, text or "", font_type, font_size, max_width, max_height)
end

function Render.fit_title_widget(host, ui_renderer, widget, text, max_font_size, max_width)
    local style = widget and widget.style and widget.style.title
    if not style then
        return
    end

    max_font_size = max_font_size or style.font_size
    max_width = max_width or style.size and style.size[1]
    if type(max_font_size) ~= "number" or type(max_width) ~= "number" then
        return
    end

    style.font_size = Render.title_font_size(host, ui_renderer, text, max_font_size, max_width,
        style.size and style.size[2])
    widget.dirty = true
end

function Render.update_dimensions(scale, text_scale)
    _dim.scale        = scale
    _dim.text_scale   = text_scale or 1
    _dim.panel_w      = math_floor(PANEL_W * scale)
    _dim.col_w        = math_floor(COL_W * scale)
    _dim.label_w      = math_floor(LABEL_W * scale)
    _dim.spacing      = math_floor(SPACING * scale)
    _dim.row_h        = math_floor(ROW_H * scale)
    _dim.header_h     = math_floor(HEADER_H * scale)
    _dim.title_h      = math_floor(TITLE_H * scale)
    _dim.section_h    = math_floor(SECTION_H * scale)
    _dim.icon_font     = math_floor(NAME_FONT * scale) + FONT_INCREASE
    _dim.name_font     = _text_font_size(_dim.icon_font - 3)
    _dim.base_row_font = math_floor(ROW_FONT * scale)
    _dim.row_font      = _text_font_size(_dim.base_row_font + FONT_INCREASE)
    _dim.title_font    = _text_font_size(math_floor(TITLE_FONT * scale) + FONT_INCREASE)
    _dim.section_font  = _text_font_size(math_floor(SECTION_FONT * scale) + FONT_INCREASE)
    _dim.sub_indent   = math_floor(SUB_INDENT * scale)
end

function Render.fit_scoreboard_scale(sections, requested_scale, text_scale, settings)
    local scale = math_max(requested_scale or 1, 0.1)
    local available_height = math_max(SCREEN_H - FIT_MARGIN * 2, 1)

    Render.update_dimensions(scale, text_scale)
    local layout = _combined_panel_layout(sections, settings)
    local content_height = layout.y + layout.h + SCOREBOARD_FOOTER_H

    if content_height > available_height then
        local minimum_scale = math_min(scale, FIT_MIN_SCALE)
        scale = math_max(minimum_scale, scale * available_height / content_height)
        Render.update_dimensions(scale, text_scale)
    end

    layout = _combined_panel_layout(sections, settings)
    content_height = layout.y + layout.h + SCOREBOARD_FOOTER_H

    return scale, content_height
end

function Render.fit_vertical_offset(content_height, content_top)
    local bottom = (content_top or 0) + (content_height or 0)

    return math_max(0, bottom - (SCREEN_H - FIT_MARGIN))
end

function Render.view_vertical_fit_offset(content_height, root_y)
    local root_top = SCREEN_H * 0.5 - VIEW_H * 0.5 + (root_y or 0)

    return Render.fit_vertical_offset(content_height, root_top)
end

function Render.content_height(sections)
    local h = 0
    for _, s in ipairs(sections) do
        h = h + _dim.section_h
        for _, row in ipairs(s.rows) do
            h = h + _row_height(row)
        end
    end
    return h
end

function Render.layout(players, sections)
    local num_players = #players
    local content_h = Render.content_height(sections)
    local bg_h = _dim.header_h + content_h + math_floor(12 * _dim.scale)

    local label_x = -_dim.panel_w * 0.5
    local cols = {}

    for i = 1, num_players do
        cols[i] = label_x + _dim.label_w + ((i - 1) * (_dim.col_w + _dim.spacing) + _dim.spacing)
    end

    return bg_h, cols, label_x
end

function Render.column_passes(width, height, accent_color, origin_x, origin_y)
    local ox = origin_x or 0
    local oy = origin_y or 0
    local bg = { 200, C.panel[2], C.panel[3], C.panel[4] }
    local bot = { 60, accent_color[2], accent_color[3], accent_color[4] }
    local passes = {
        _rect(ox, oy, BASE_Z,     width, height, bg),
        _rect(ox, oy, BASE_Z + 6, width, 2,      accent_color),
        _rect(ox, oy + height - 1, BASE_Z + 6, width, 1, bot),
        _rect(ox - 3, oy - 3, BASE_Z - 1, width + 6, height + 6, C.shadow),
    }
    return passes
end

function Render.build_widgets(host, scenegraph_id, players, sections, settings)
    local num_players = #players
    if num_players == 0 then return nil end

    Render.set_theme(settings and settings.theme)
    local effective_scale, content_height = Render.fit_scoreboard_scale(sections,
        settings and settings.scale or 1, settings and settings.text_scale or 1, settings)

    local result = {
        columns = {},
        sections = {},
        rows = {},
        text_scale = _dim.text_scale,
        scale = effective_scale,
        content_height = content_height,
    }

    local ids = {}
    for i = 1, num_players do
        local aid = players[i]:account_id() or players[i]:name()
        ids[i] = aid
    end

    local panel_x = (VIEW_W - _dim.panel_w) * 0.5
    local title_text = _title_text(settings)
    local title_max_font_size = _dim.title_font
    local title_max_width = _dim.panel_w - _scaled(24)
    local title_font_size = Render.title_font_size(host, nil, title_text, title_max_font_size,
        title_max_width, _dim.title_h)
    local title_def = UIWidget.create_definition(_title_passes(0, 0, _dim.panel_w, _dim.title_h, "title",
        title_text, title_font_size), scenegraph_id, nil, { _dim.panel_w, _dim.title_h })
    result.columns[#result.columns + 1] = { widget = title_def, offset = { panel_x, 0, 0 } }
    result.title_max_font_size = title_max_font_size
    result.title_max_width = title_max_width

    local layout = _combined_panel_layout(sections, settings)
    local def = UIWidget.create_definition(_combined_panel_passes(players, ids, sections, layout, 0, 0,
        settings, host),
        scenegraph_id, nil, { layout.w, layout.h })
    result.sections[#result.sections + 1] = {
        widget = def,
        offset = { layout.x + VIEW_W * 0.5, layout.y, 0 },
    }
    result.panel = {
        x = layout.x + VIEW_W * 0.5,
        y = layout.y,
        w = layout.w,
        h = layout.h,
    }

    return result
end

function Render.build_hud_widgets(hud, ui_renderer, players, sections, settings)
    local num_players = #players
    if num_players == 0 then return nil end

    Render.set_theme(settings and settings.theme)
    local effective_scale, content_height = Render.fit_scoreboard_scale(sections,
        settings and settings.scale or 1, settings and settings.text_scale or 1, settings)

    local base_x = SCREEN_ORIGIN_X + (settings.horizontal_offset or 0)
    local base_y = SCREEN_ORIGIN_Y - (settings.vertical_offset or 0)

    local result = {}

    local ids = {}
    for i = 1, num_players do
        ids[i] = players[i]:account_id() or players[i]:name()
    end

    local layout = _combined_panel_layout(sections, settings)
    local fit_offset = Render.fit_vertical_offset(content_height, base_y)
    base_y = base_y - fit_offset

    local panel_x = (VIEW_W - _dim.panel_w) * 0.5
    local title_text = _title_text(settings)
    local title_max_font_size = _dim.title_font
    local title_max_width = _dim.panel_w - _scaled(24)
    local title_font_size = Render.title_font_size(hud, ui_renderer, title_text, title_max_font_size,
        title_max_width, _dim.title_h)
    local title_widget = hud:_create_widget("as_hud_title", UIWidget.create_definition(
        _title_passes(base_x + panel_x, base_y, _dim.panel_w, _dim.title_h, "t", title_text, title_font_size),
        "canvas", nil, { _dim.panel_w, _dim.title_h }))
    hud._as_title_widget = title_widget
    hud._as_title_max_font_size = title_max_font_size
    hud._as_title_max_width = title_max_width
    result[#result + 1] = title_widget

    local abs_x = base_x + layout.x + VIEW_W * 0.5
    local abs_y = base_y + layout.y

    result[#result + 1] = hud:_create_widget("as_hud_panel_1", UIWidget.create_definition(
        _combined_panel_passes(players, ids, sections, layout, abs_x, abs_y,
            settings, hud, ui_renderer),
        "canvas", nil, { layout.w, layout.h }))

    local hint_styled, hint_plain = _style_hint(mod:localize("scoreboard_hint_temporarily_hide"))
    local hint_font_size = _fit_label_font_size(hud, ui_renderer, hint_plain, "proxima_nova_bold",
        _text_font_size(15), layout.w - _scaled(32), SCOREBOARD_FOOTER_H)
    result[#result + 1] = hud:_create_widget("as_hud_hint", UIWidget.create_definition(
        _footer_passes(abs_x, abs_y + layout.h, layout.w, SCOREBOARD_FOOTER_H, "hint", hint_styled, hint_font_size),
        "canvas", nil, { layout.w, SCOREBOARD_FOOTER_H }))

    return result
end

return Render
