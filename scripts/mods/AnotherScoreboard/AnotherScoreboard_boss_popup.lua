local mod = get_mod("AnotherScoreboard")

local orig_require = Mods and Mods.original_require or require
local UIWorkspaceSettings = orig_require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = orig_require("scripts/managers/ui/ui_widget")
local UIScenegraph = orig_require("scripts/managers/ui/ui_scenegraph")
local UIRenderer = orig_require("scripts/managers/ui/ui_renderer")
local UISettings = orig_require("scripts/settings/ui/ui_settings")
local Themes = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_themes")

local math_max = math.max
local string_format = string.format
local utf8_string_length = Utf8.string_length
local utf8_sub_string = Utf8.sub_string

local BASE_Z = 100
local POPUP_MARGIN = 30
local POPUP_W_BOTH = 520
local POPUP_W_DAMAGE = 440
local POPUP_W_PERCENT = 390
local POPUP_W_NAMES = 320
local POPUP_H = 286
local PADDING_X = 20
local TITLE_Y = 14
local TITLE_H = 34
local TITLE_FONT = 26
local ROWS_Y = 55
local ROW_H = 36
local ROW_FONT = 21
local PLAYER_ICON_W = 24
local PLAYER_ICON_GAP = 8
local DAMAGE_W = 104
local PERCENT_W = 62
local COLUMN_GAP = 14
local FOOTER_GAP = 8
local FOOTER_H = 52
local MAX_PLAYERS = 4

local C = Themes.by_id[Themes.default].colors.boss

local PLAYER_COLORS = {
    { 255, 106, 224, 216 },
    { 255, 244, 115, 171 },
    { 255, 255, 139, 82 },
    { 255, 139, 164, 255 },
}

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    popup = {
        parent = "screen",
        horizontal_alignment = "right",
        vertical_alignment = "top",
        size = { POPUP_W_BOTH, POPUP_H },
        position = { -POPUP_MARGIN, 120, BASE_Z },
    },
}

local function _set_size(style, width, height)
    if not style then
        return
    end

    style.size = style.size or { 0, 0 }
    style.size[1] = width
    style.size[2] = height
end

local function _set_offset(style, x, y, z)
    if not style then
        return
    end

    style.offset = style.offset or { 0, 0, 0 }
    style.offset[1] = x
    style.offset[2] = y
    style.offset[3] = z
end

local function _set_rect_style(style, x, y, width, height, scale, z)
    _set_size(style, width * scale, height * scale)
    _set_offset(style, x * scale, y * scale, z)
end

local function _set_text_style(style, x, y, width, height, font_size, scale, alignment, vertical_alignment)
    _set_size(style, width * scale, height * scale)
    _set_offset(style, x * scale, y * scale, BASE_Z + 5)

    if style then
        style.font_size = font_size * scale
        style.text_horizontal_alignment = alignment or "left"
        style.text_vertical_alignment = vertical_alignment or "center"
    end
end

local function _hide_style(style)
    _set_size(style, 0, 0)
    _set_offset(style, 0, 0, BASE_Z + 5)
end

local function _popup_width(settings)
    local show_damage = settings.show_boss_popup_damage
    local show_percent = settings.show_boss_popup_percent

    if show_damage and show_percent then
        return POPUP_W_BOTH
    elseif show_damage then
        return POPUP_W_DAMAGE
    elseif show_percent then
        return POPUP_W_PERCENT
    end

    return POPUP_W_NAMES
end

local function _apply_popup_layout(self, scale, settings, player_count)
    local widget = self._widget
    if not widget then
        return
    end

    scale = math_max(tonumber(scale) or 1, 0.1)
    player_count = math_max(math.min(player_count or 0, MAX_PLAYERS), 1)

    local popup_w = _popup_width(settings)
    local rows_bottom = ROWS_Y + player_count * ROW_H
    local footer_y = rows_bottom + FOOTER_GAP
    local popup_h = settings.show_boss_popup_total_damage and footer_y + FOOTER_H or rows_bottom
    local popup_scenegraph = self._ui_scenegraph and self._ui_scenegraph.popup

    if popup_scenegraph and popup_scenegraph.size then
        popup_scenegraph.size[1] = popup_w * scale
        popup_scenegraph.size[2] = popup_h * scale
        self._update_scenegraph = true
    end

    local style = widget.style
    _set_rect_style(style.background, 0, 0, popup_w, popup_h, scale, BASE_Z)

    _set_text_style(style.title, PADDING_X, TITLE_Y, popup_w - PADDING_X * 2,
        TITLE_H, TITLE_FONT, scale, "left", "center")

    local right_x = popup_w - PADDING_X
    local percent_x = right_x
    local damage_x = right_x
    local player_x = PADDING_X + PLAYER_ICON_W + PLAYER_ICON_GAP

    if settings.show_boss_popup_percent then
        percent_x = right_x - PERCENT_W
        right_x = percent_x - COLUMN_GAP
    end

    if settings.show_boss_popup_damage then
        damage_x = right_x - DAMAGE_W
        right_x = damage_x - COLUMN_GAP
    end

    for i = 1, MAX_PLAYERS do
        local row_y = ROWS_Y + (i - 1) * ROW_H
        local player_icon_style = style["player_icon_" .. i]
        local player_style = style["player_" .. i]
        local damage_style = style["damage_" .. i]
        local percent_style = style["percent_" .. i]
        local divider_style = style["divider_" .. i]

        if i <= player_count then
            _set_text_style(player_icon_style, PADDING_X, row_y, PLAYER_ICON_W, ROW_H,
                ROW_FONT - 2, scale, "center", "center")
            _set_text_style(player_style, player_x, row_y, right_x - player_x, ROW_H,
                ROW_FONT, scale, "left", "center")

            if settings.show_boss_popup_damage then
                _set_text_style(damage_style, damage_x, row_y, DAMAGE_W, ROW_H,
                    ROW_FONT, scale, "right", "center")
            else
                _hide_style(damage_style)
            end

            if settings.show_boss_popup_percent then
                _set_text_style(percent_style, percent_x, row_y, PERCENT_W, ROW_H,
                    ROW_FONT - 2, scale, "right", "center")
            else
                _hide_style(percent_style)
            end

            if i < player_count then
                _set_rect_style(divider_style, PADDING_X, row_y + ROW_H - 1,
                    popup_w - PADDING_X * 2, 1, scale, BASE_Z + 2)
            else
                _hide_style(divider_style)
            end
        else
            _hide_style(player_icon_style)
            _hide_style(player_style)
            _hide_style(damage_style)
            _hide_style(percent_style)
            _hide_style(divider_style)
        end
    end

    if settings.show_boss_popup_total_damage then
        _set_rect_style(style.footer_bg, 0, footer_y, popup_w, FOOTER_H, scale, BASE_Z + 1)
        _set_rect_style(style.footer_border, 0, footer_y, popup_w, 2, scale, BASE_Z + 2)

        local total_label_w = math.min(160, popup_w * 0.42)
        _set_text_style(style.total_label, PADDING_X, footer_y, total_label_w, FOOTER_H,
            15, scale, "left", "center")
        _set_text_style(style.total_value, PADDING_X + total_label_w, footer_y,
            popup_w - PADDING_X * 2 - total_label_w, FOOTER_H, 18, scale, "right", "center")
    else
        _hide_style(style.footer_bg)
        _hide_style(style.footer_border)
        _hide_style(style.total_label)
        _hide_style(style.total_value)
    end

    widget.dirty = true
end

local function _shorten(value)
    if value >= 1e6 then
        return string_format("%.1fM", value * 1e-6)
    elseif value >= 1e3 then
        return string_format("%.1fK", value * 1e-3)
    end

    return string_format("%.0f", value)
end

local function _player_display(aid, fallback_index)
    local player_manager = Managers.player
    local players = player_manager and player_manager:players()

    if players then
        for _, player in pairs(players) do
            local player_aid = player:account_id() or player:name()
            if player_aid == aid then
                local character_name = player.character_name and player:character_name()
                local name = character_name or player:name() or aid
                local slot = player.slot and player:slot()
                local color = slot and PLAYER_COLORS[slot] or PLAYER_COLORS[fallback_index]
                local profile = type(player.profile) == "function" and player:profile()
                local archetype_name = profile and profile.archetype and profile.archetype.name
                local archetype_icon = archetype_name and UISettings.archetype_font_icon[archetype_name]

                return name, color or C.text, archetype_icon
            end
        end
    end

    return aid, PLAYER_COLORS[fallback_index] or C.text, nil
end

local function _set_popup_content(widget, data, settings)
    widget.content.title = data.display_name or data.breed_name or "Boss"

    local players = data.players or {}
    for i = 1, MAX_PLAYERS do
        local player_data = players[i]
        local player_icon_style = widget.style["player_icon_" .. i]
        local player_style = widget.style["player_" .. i]

        if player_data then
            local name, color, archetype_icon = _player_display(player_data.aid, i)
            if utf8_string_length(name) > 14 then
                name = utf8_sub_string(name, 1, 14)
            end

            widget.content["player_icon_" .. i] = archetype_icon or ""
            widget.content["player_" .. i] = name
            widget.content["damage_" .. i] = settings.show_boss_popup_damage
                and _shorten(player_data.damage or 0) or ""
            widget.content["percent_" .. i] = settings.show_boss_popup_percent
                and string_format("%d%%", player_data.pct or 0) or ""
            player_icon_style.text_color = color
            player_style.text_color = color
        else
            widget.content["player_icon_" .. i] = ""
            widget.content["player_" .. i] = ""
            widget.content["damage_" .. i] = ""
            widget.content["percent_" .. i] = ""
            player_icon_style.text_color = C.text
            player_style.text_color = C.text
        end
    end

    local total_damage = _shorten(data.total_damage or 0)
    widget.content.total_label = "TOTAL DAMAGE"
    widget.content.total_value = string_format("{#color(%d,%d,%d)}%s HP{#reset()}",
        C.damage[2], C.damage[3], C.damage[4], total_damage)
end

-- class() is not available in every loading context.
local HudElementBossPopup = nil

if not HudElementBossPopup and type(class) == "function" then
    local ok, result = pcall(class, "HudElementBossPopup", "HudElementBase")
    if ok and result then
        HudElementBossPopup = result
    end
end

if not HudElementBossPopup then
    local ok, Base = pcall(orig_require, "scripts/ui/hud/elements/hud_element_base")
    if ok and Base then
        HudElementBossPopup = setmetatable({}, { __index = Base })
        HudElementBossPopup.__index = HudElementBossPopup
        HudElementBossPopup.super = Base

        function HudElementBossPopup:new(host, draw_layer, scale, context)
            local instance = setmetatable({}, self)
            if instance.init then
                instance:init(host, draw_layer, scale, context)
            end
            return instance
        end
    end
end

if not HudElementBossPopup then
    return {}
end

local function _rect_pass(style_id, x, y, z, width, height, color)
    return {
        style_id = style_id,
        pass_type = "rect",
        style = {
            offset = { x, y, z },
            size = { width, height },
            color = color,
        },
    }
end

local function _text_pass(style_id, value, x, y, width, height, font_size, color, alignment, font_type)
    return {
        style_id = style_id,
        value_id = style_id,
        pass_type = "text",
        value = value or "",
        style = {
            offset = { x, y, BASE_Z + 5 },
            size = { width, height },
            font_size = font_size,
            font_type = font_type or "machine_medium",
            text_horizontal_alignment = alignment or "left",
            text_vertical_alignment = "center",
            text_color = color,
        },
    }
end

local function _color_copy(color)
    return { color[1], color[2], color[3], color[4] }
end

local function _apply_theme(self, theme_id)
    local selected = Themes.by_id[theme_id] or Themes.by_id[Themes.default]
    if self._theme_id == theme_id then
        return false
    end

    self._theme_id = theme_id
    C = selected.colors.boss

    local widget = self._widget
    if not widget then
        return true
    end

    local style = widget.style
    style.background.color = _color_copy(C.bg)
    style.footer_bg.color = _color_copy(C.footer_bg)
    style.footer_border.color = _color_copy(C.accent)
    style.title.text_color = C.title
    style.total_label.text_color = C.header
    style.total_value.text_color = C.text

    for i = 1, MAX_PLAYERS do
        style["damage_" .. i].text_color = C.damage
        style["percent_" .. i].text_color = C.text
        style["divider_" .. i].color = _color_copy(C.row_divider)
    end

    widget.dirty = true
    return true
end

HudElementBossPopup.init = function(self, parent, draw_layer, start_scale, definitions)
    self._draw_layer = math.max(draw_layer or 0, 990)
    self._render_scale = start_scale or 1
    self._widgets = {}
    self._widgets_by_name = {}
    self._event_list = {}

    local scale = self._render_scale
    self._definitions = { widget_definitions = {}, scenegraph_definition = scenegraph_definition }
    self._ui_scenegraph = UIScenegraph.init_scenegraph(scenegraph_definition, scale)

    local passes = {
        _rect_pass("background", 0, 0, BASE_Z, POPUP_W_BOTH, POPUP_H, C.bg),
        _rect_pass("footer_bg", 0, POPUP_H - FOOTER_H, BASE_Z + 1, POPUP_W_BOTH, FOOTER_H, C.footer_bg),
        _rect_pass("footer_border", 0, POPUP_H - FOOTER_H, BASE_Z + 2, POPUP_W_BOTH, 2, C.accent),
        _text_pass("title", "", PADDING_X, TITLE_Y, POPUP_W_BOTH - PADDING_X * 2,
            TITLE_H, TITLE_FONT, C.title, "left"),
        _text_pass("total_label", "", PADDING_X, POPUP_H - FOOTER_H, 160, FOOTER_H,
            15, C.header, "left"),
        _text_pass("total_value", "", 180, POPUP_H - FOOTER_H, 320, FOOTER_H,
            18, C.text, "right"),
    }

    for i = 1, MAX_PLAYERS do
        local row_y = ROWS_Y + (i - 1) * ROW_H
        passes[#passes + 1] = _text_pass("player_icon_" .. i, "", PADDING_X, row_y,
            PLAYER_ICON_W, ROW_H, ROW_FONT - 2, PLAYER_COLORS[i], "center", "itc_novarese_bold")
        passes[#passes + 1] = _text_pass("player_" .. i, "", PADDING_X, row_y,
            260, ROW_H, ROW_FONT, PLAYER_COLORS[i], "left", "proxima_nova_bold")
        passes[#passes + 1] = _text_pass("damage_" .. i, "", 330, row_y,
            DAMAGE_W, ROW_H, ROW_FONT, C.damage, "right")
        passes[#passes + 1] = _text_pass("percent_" .. i, "", 438, row_y,
            PERCENT_W, ROW_H, ROW_FONT - 2, C.text, "right")
        passes[#passes + 1] = _rect_pass("divider_" .. i, PADDING_X, row_y + ROW_H - 1,
            BASE_Z + 2, POPUP_W_BOTH - PADDING_X * 2, 1, C.row_divider)
    end

    local widget_definition = UIWidget.create_definition(passes, "popup")
    self._widget = self:_create_widget("boss_popup", widget_definition)
    self._widget.visible = false

    self._popup_data = nil
    self._popup_visible = false
    self._widget.offset[1] = 0
    self._widget.offset[2] = 0
end

HudElementBossPopup.show = function(self, data, x_offset, y_offset, scale)
    self._popup_data = data
    self._popup_visible = true

    local settings = mod.get_cached_settings and mod.get_cached_settings() or {}
    local player_count = data and data.players and #data.players or 0

    _apply_theme(self, settings.scoreboard_theme)
    _apply_popup_layout(self, scale, settings, player_count)

    self._widget.offset[1] = x_offset or 0
    self._widget.offset[2] = -(y_offset or 0)
    self._widget.style.background.color[1] = settings.boss_popup_bg_opacity or 0

    _set_popup_content(self._widget, data or {}, settings)
    self._widget.visible = true
    self._widget.dirty = true
end

HudElementBossPopup.hide = function(self)
    self._popup_visible = false
    self._popup_data = nil

    if self._widget then
        for key in pairs(self._widget.content) do
            if key ~= "size" then
                self._widget.content[key] = ""
            end
        end
        self._widget.visible = false
    end
end

HudElementBossPopup.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    local settings = mod.get_cached_settings and mod.get_cached_settings() or {}
    if _apply_theme(self, settings.scoreboard_theme) and self._popup_data then
        _set_popup_content(self._widget, self._popup_data, settings)
    end

    if HudElementBossPopup.super and HudElementBossPopup.super.update then
        HudElementBossPopup.super.update(self, dt, t, ui_renderer, render_settings, input_service)
    end
end

HudElementBossPopup.destroy = function(self, ui_renderer)
    if self._widget then
        self._widget.visible = false
    end

    if self._widget and ui_renderer then
        UIWidget.destroy(ui_renderer, self._widget)
    end

    if ui_renderer then
        UIRenderer.clear_scenegraph_queue(ui_renderer)
        UIRenderer.clear_render_pass_queue(ui_renderer)
    end

    self._widget = nil
    self._ui_scenegraph = nil
    self._widgets = nil
    self._widgets_by_name = nil
end

HudElementBossPopup.draw = function(self, dt, t, ui_renderer, render_settings, input_service)
    if self._popup_visible then
        render_settings.start_layer = self._draw_layer
        UIRenderer.begin_pass(ui_renderer, self._ui_scenegraph, input_service, dt, render_settings)

        if self._widget and self._widget.visible then
            UIWidget.draw(self._widget, ui_renderer)
        end

        UIRenderer.end_pass(ui_renderer)
    end
end

return HudElementBossPopup
