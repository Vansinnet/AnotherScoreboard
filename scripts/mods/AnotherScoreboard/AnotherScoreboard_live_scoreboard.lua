local mod = get_mod("AnotherScoreboard")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local Themes = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_themes")

local math_floor = math.floor
local math_max = math.max
local table_sort = table.sort
local string_format = string.format
local utf8_string_length = Utf8.string_length
local utf8_sub_string = Utf8.sub_string

local BASE_Z = 990
local BASE_W = 301
local BASE_H = 106
local BASE_X = 28
local BASE_Y = 112
local MIN_VISIBLE_Y = 0
local BASE_TITLE_FONT = 13
local BASE_TEXT_FONT = 11
local ROW_H = 15

local PADDING_X = 8
local TITLE_Y = 6
local HEADER_Y = 25
local ROWS_Y = 41
local COLUMN_GAP = 6
local PLAYER_COL_W = 102
local PLAYER_ICON_W = 14
local PLAYER_ICON_GAP = 3
local STAT_COL_W = 64
local MEASURE_SIZE = { 10000, 1000 }

local ROW_WIDGET_NAMES = {
    "live_scoreboard_row_1",
    "live_scoreboard_row_2",
    "live_scoreboard_row_3",
    "live_scoreboard_row_4",
}

local C = Themes.by_id[Themes.default].colors.live

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    live_scoreboard = {
        parent = "screen",
        horizontal_alignment = "left",
        vertical_alignment = "top",
        size = { BASE_W, BASE_H },
        position = { BASE_X, BASE_Y, BASE_Z },
    },
}

local function live_scoreboard_definition()
    return UIWidget.create_definition({
        {
            style_id = "background",
            pass_type = "rect",
            style = {
                offset = { 0, 0, 0 },
                size = { BASE_W, BASE_H },
                color = C.bg,
            },
        },
        {
            value_id = "title",
            style_id = "title",
            pass_type = "text",
            value = "",
            style = {
                offset = { PADDING_X, TITLE_Y, 2 },
                size = { BASE_W - PADDING_X * 2, 24 },
                font_size = BASE_TITLE_FONT,
                font_type = "machine_medium",
                text_horizontal_alignment = "left",
                text_vertical_alignment = "top",
                text_color = C.title,
            },
        },
        {
            value_id = "header_player",
            style_id = "header_player",
            pass_type = "text",
            value = "",
            style = {
                offset = { PADDING_X, HEADER_Y, 2 },
                size = { PLAYER_COL_W, 20 },
                font_size = BASE_TEXT_FONT,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "top",
                text_color = C.header,
            },
        },
        {
            value_id = "header_stat_1",
            style_id = "header_stat_1",
            pass_type = "text",
            value = "",
            style = {
                offset = { PADDING_X + PLAYER_COL_W + COLUMN_GAP, HEADER_Y, 2 },
                size = { STAT_COL_W, 20 },
                font_size = BASE_TEXT_FONT,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "top",
                text_color = C.header,
            },
        },
        {
            value_id = "header_stat_2",
            style_id = "header_stat_2",
            pass_type = "text",
            value = "",
            style = {
                offset = { PADDING_X + PLAYER_COL_W + COLUMN_GAP + STAT_COL_W + COLUMN_GAP, HEADER_Y, 2 },
                size = { STAT_COL_W, 20 },
                font_size = BASE_TEXT_FONT,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "top",
                text_color = C.header,
            },
        },
        {
            value_id = "header_stat_3",
            style_id = "header_stat_3",
            pass_type = "text",
            value = "",
            style = {
                offset = { PADDING_X + PLAYER_COL_W + COLUMN_GAP + STAT_COL_W + COLUMN_GAP + STAT_COL_W + COLUMN_GAP, HEADER_Y, 2 },
                size = { STAT_COL_W, 20 },
                font_size = BASE_TEXT_FONT,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "top",
                text_color = C.header,
            },
        },
    }, "live_scoreboard", nil, { BASE_W, BASE_H })
end

local function live_scoreboard_row_definition()
    return UIWidget.create_definition({
        {
            value_id = "player_icon",
            style_id = "player_icon",
            pass_type = "text",
            value = "",
            style = {
                offset = { PADDING_X, 0, 2 },
                size = { PLAYER_ICON_W, ROW_H },
                font_size = BASE_TEXT_FONT,
                font_type = "itc_novarese_bold",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = C.text,
            },
        },
        {
            value_id = "player",
            style_id = "player",
            pass_type = "text",
            value = "",
            style = {
                offset = { PADDING_X, 0, 2 },
                size = { PLAYER_COL_W, ROW_H },
                font_size = BASE_TEXT_FONT,
                font_type = "proxima_nova_bold",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = C.text,
            },
        },
        {
            value_id = "stat_1",
            style_id = "stat_1",
            pass_type = "text",
            value = "",
            style = {
                offset = { PADDING_X + PLAYER_COL_W + COLUMN_GAP, 0, 2 },
                size = { STAT_COL_W, ROW_H },
                font_size = BASE_TEXT_FONT,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = C.text,
            },
        },
        {
            value_id = "stat_2",
            style_id = "stat_2",
            pass_type = "text",
            value = "",
            style = {
                offset = { PADDING_X + PLAYER_COL_W + COLUMN_GAP + STAT_COL_W + COLUMN_GAP, 0, 2 },
                size = { STAT_COL_W, ROW_H },
                font_size = BASE_TEXT_FONT,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = C.text,
            },
        },
        {
            value_id = "stat_3",
            style_id = "stat_3",
            pass_type = "text",
            value = "",
            style = {
                offset = { PADDING_X + PLAYER_COL_W + COLUMN_GAP + STAT_COL_W + COLUMN_GAP + STAT_COL_W + COLUMN_GAP, 0, 2 },
                size = { STAT_COL_W, ROW_H },
                font_size = BASE_TEXT_FONT,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = C.text,
            },
        },
    }, "live_scoreboard", nil, { BASE_W, ROW_H })
end

local widget_definitions = {
    live_scoreboard = live_scoreboard_definition(),
    live_scoreboard_row_1 = live_scoreboard_row_definition(),
    live_scoreboard_row_2 = live_scoreboard_row_definition(),
    live_scoreboard_row_3 = live_scoreboard_row_definition(),
    live_scoreboard_row_4 = live_scoreboard_row_definition(),
}

local HudElementLiveScoreboard = class("HudElementLiveScoreboard", "HudElementBase")

local function shorten(v)
    if v >= 1000000 then
        return string_format("%.1fM", v * 0.000001)
    elseif v >= 1000 then
        return string_format("%.1fK", v * 0.001)
    end

    return string_format("%d", math_floor(v + 0.5))
end

local function format_value(value, format)
    if format == "percent" then
        return string_format("%d%%", math_floor(value + 0.5))
    elseif format == "count" then
        return string_format("%d", math_floor(value + 0.5))
    end

    return shorten(value)
end

local function short_name(name)
    if not name then
        return "?"
    end

    if utf8_string_length(name) > 24 then
        return utf8_sub_string(name, 1, 24)
    end

    return name
end

-- Shortens a name with "..." so it fits on one line; results are cached per name, font size and width.
local function fitted_name(self, ui_renderer, name, style, max_width)
    name = short_name(name)
    if not ui_renderer or type(self._text_size) ~= "function" or max_width <= 0 then
        return name
    end

    local key = name .. "\0" .. style.font_size .. "\0" .. max_width
    local cache = self._as_name_fit_cache
    if not cache or self._as_name_fit_count > 64 then
        cache = {}
        self._as_name_fit_cache = cache
        self._as_name_fit_count = 0
    end
    if cache[key] then
        return cache[key]
    end

    -- An explicit large area stops the measurement from wrapping inside the style's own size.
    local function fits(candidate)
        return self:_text_size(ui_renderer, candidate, style, MEASURE_SIZE) <= max_width
    end

    local result = name
    if not fits(name) then
        local low, high, best = 1, utf8_string_length(name) - 1, "..."
        while low <= high do
            local middle = math_floor((low + high) / 2)
            local candidate = utf8_sub_string(name, 1, middle) .. "..."
            if fits(candidate) then
                best, low = candidate, middle + 1
            else
                high = middle - 1
            end
        end
        result = best
    end

    cache[key] = result
    self._as_name_fit_count = self._as_name_fit_count + 1

    return result
end

local function set_size(style, width, height)
    style.size[1] = width
    style.size[2] = height
end

local function set_text_style(style, x, y, width, height, font_size, horizontal_alignment, vertical_alignment, color)
    style.offset[1] = x
    style.offset[2] = y
    style.size[1] = width
    style.size[2] = height
    style.font_size = font_size
    style.text_horizontal_alignment = horizontal_alignment
    style.text_vertical_alignment = vertical_alignment
    style.text_color = color
end

local function set_hidden_text_style(style)
    style.offset[1] = 0
    style.offset[2] = 0
    style.size[1] = 0
    style.size[2] = 0
end

local function color_copy(color)
    return { color[1], color[2], color[3], color[4] }
end

local function apply_theme(self, theme_id)
    local selected = Themes.by_id[theme_id] or Themes.by_id[Themes.default]
    if self._theme_id == theme_id then
        return
    end

    self._theme_id = theme_id
    C = selected.colors.live

    local widget = self._widgets_by_name.live_scoreboard
    if widget then
        local style = widget.style
        style.background.color = color_copy(C.bg)
        style.title.text_color = C.title
        style.header_player.text_color = C.header
        for i = 1, 3 do
            style["header_stat_" .. i].text_color = C.header
        end
        widget.dirty = true
    end

    for i = 1, 4 do
        local row_widget = self._widgets_by_name[ROW_WIDGET_NAMES[i]]
        if row_widget then
            local style = row_widget.style
            style.player_icon.text_color = C.text
            style.player.text_color = C.text
            for j = 1, 3 do
                style["stat_" .. j].text_color = C.text
            end
            row_widget.dirty = true
        end
    end
end

local function visible_stat_columns(scale)
    local columns = mod.get_live_scoreboard_columns()
    local count = mod.get_live_scoreboard_stat_count()

    for i = 1, count do
        columns[i].width = math_max(math_floor(STAT_COL_W * scale), 1)
    end

    return columns, count
end

function HudElementLiveScoreboard:init(parent, draw_layer, start_scale)
    HudElementLiveScoreboard.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })

    self._title_text = mod:localize("live_scoreboard_title")
    self._header_player_text = mod:localize("live_scoreboard_player")

    self._widgets = {
        self._widgets_by_name.live_scoreboard,
        self._widgets_by_name[ROW_WIDGET_NAMES[1]],
        self._widgets_by_name[ROW_WIDGET_NAMES[2]],
        self._widgets_by_name[ROW_WIDGET_NAMES[3]],
        self._widgets_by_name[ROW_WIDGET_NAMES[4]],
    }

    for i = 1, 4 do
        local row_widget = self._widgets_by_name[ROW_WIDGET_NAMES[i]]
        if row_widget then
            row_widget.visible = false
        end
    end

    if self._widgets_by_name.live_scoreboard then
        self._widgets_by_name.live_scoreboard.visible = false
    end
end

function HudElementLiveScoreboard:update(dt, t, ui_renderer, render_settings, input_service)
    local widget = self._widgets_by_name.live_scoreboard
    if not mod.is_live_scoreboard_visible() then
        widget.visible = false
        for i = 1, 4 do
            local row_widget = self._widgets_by_name[ROW_WIDGET_NAMES[i]]
            if row_widget then
                row_widget.visible = false
            end
        end
        return
    end

    local settings = mod.get_cached_settings()
    apply_theme(self, settings.scoreboard_theme)
    local rows = mod.get_live_scoreboard_rows()
    if not rows or #rows == 0 then
        widget.visible = false
        for i = 1, 4 do
            local row_widget = self._widgets_by_name[ROW_WIDGET_NAMES[i]]
            if row_widget then
                row_widget.visible = false
            end
        end
        return
    end

    local scale = math_max(settings.live_scoreboard_scale or 1, 0.1)
    local stat_columns, stat_count = visible_stat_columns(scale)
    if stat_count == 0 then
        widget.visible = false
        for i = 1, 4 do
            local row_widget = self._widgets_by_name[ROW_WIDGET_NAMES[i]]
            if row_widget then
                row_widget.visible = false
            end
        end
        return
    end

    table_sort(rows, function(a, b)
        local a_value = a.values[1] or 0
        local b_value = b.values[1] or 0

        if a_value == b_value then
            return (a.name or "") < (b.name or "")
        end

        if stat_columns[1].lower_better then
            return a_value < b_value
        end

        return a_value > b_value
    end)

    local pad_x = math_max(math_floor(PADDING_X * scale), 1)
    local row_h = math_max(math_floor(ROW_H * scale), 1)
    local title_y = math_floor(TITLE_Y * scale)
    local header_y = math_floor(HEADER_Y * scale)
    local rows_y = math_floor(ROWS_Y * scale)
    local gap = math_max(math_floor(COLUMN_GAP * scale), 1)
    local player_w = math_max(math_floor(PLAYER_COL_W * scale), 1)
    local player_icon_w = math_max(math_floor(PLAYER_ICON_W * scale), 1)
    local player_icon_gap = math_max(math_floor(PLAYER_ICON_GAP * scale), 1)
    local player_name_w = math_max(player_w - player_icon_w - player_icon_gap, 1)
    local stats_w = 0
    for i = 1, stat_count do
        stats_w = stats_w + stat_columns[i].width
    end
    local width = pad_x * 2 + player_w + gap * stat_count + stats_w
    local height = rows_y + #rows * row_h + pad_x
    local font = math_max(math_floor(BASE_TEXT_FONT * scale), 1)
    local title_font = math_max(math_floor(BASE_TITLE_FONT * scale), 1)

    local y = math_max(BASE_Y - (settings.live_scoreboard_y or 0), MIN_VISIBLE_Y)

    self:_set_scenegraph_size("live_scoreboard", width, height)
    self:set_scenegraph_position("live_scoreboard", BASE_X + (settings.live_scoreboard_x or 0), y)

    local style = widget.style
    set_size(style.background, width, height)
    style.background.color[1] = settings.live_scoreboard_bg_opacity or 0
    set_text_style(style.title, pad_x, title_y, width - pad_x * 2, math_floor(24 * scale), title_font, "left", "top", C.title)
    set_text_style(style.header_player, pad_x, header_y, player_w, math_floor(20 * scale), font, "center", "top", C.header)
    for i = 1, 3 do
        set_hidden_text_style(style["header_stat_" .. i])
    end

    local column_x = pad_x + player_w + gap
    for i = 1, stat_count do
        local column = stat_columns[i]
        set_text_style(style["header_stat_" .. i], column_x, header_y, column.width, math_floor(20 * scale), font, "center", "top", C.header)
        column.x = column_x
        column_x = column_x + column.width + gap
    end

    widget.content.title = self._title_text
    widget.content.header_player = self._header_player_text
    for i = 1, stat_count do
        widget.content["header_stat_" .. i] = stat_columns[i].label
    end

    for i = 1, #rows do
        local row = rows[i]
        local row_widget = self._widgets_by_name[ROW_WIDGET_NAMES[i]]

        if row_widget then
            local row_style = row_widget.style
            local row_y = rows_y + (i - 1) * row_h
            local row_color = row.is_self and C.title or C.text

            set_text_style(row_style.player_icon, pad_x, row_y, player_icon_w, row_h, font, "center", "center", row_color)
            set_text_style(row_style.player, pad_x + player_icon_w + player_icon_gap, row_y,
                player_name_w, row_h, font, "left", "center", row_color)
            for j = 1, 3 do
                set_hidden_text_style(row_style["stat_" .. j])
            end

            for j = 1, stat_count do
                local column = stat_columns[j]
                set_text_style(row_style["stat_" .. j], column.x, row_y, column.width, row_h, font, "center", "center", row_color)
            end

            row_widget.content.player_icon = row.archetype_icon or ""
            row_widget.content.player = fitted_name(self, ui_renderer, row.name, row_style.player, player_name_w - 2)
            for j = 1, stat_count do
                row_widget.content["stat_" .. j] = format_value(row.values[j] or 0, stat_columns[j].format)
            end
            row_widget.visible = true
            row_widget.dirty = true
        end
    end

    for i = #rows + 1, 4 do
        local row_widget = self._widgets_by_name[ROW_WIDGET_NAMES[i]]
        if row_widget then
            row_widget.visible = false
            row_widget.dirty = true
        end
    end

    widget.visible = true
    widget.dirty = true

    HudElementLiveScoreboard.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

function HudElementLiveScoreboard:draw(dt, t, ui_renderer, render_settings, input_service)
    local widget = self._widgets_by_name.live_scoreboard
    if not widget or not widget.visible then
        return
    end

    HudElementLiveScoreboard.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

function HudElementLiveScoreboard:destroy(ui_renderer)
    local widget = self._widgets_by_name and self._widgets_by_name.live_scoreboard
    if widget then
        widget.visible = false
        widget.content.title = ""
        widget.content.header_player = ""
        for i = 1, 3 do
            widget.content["header_stat_" .. i] = ""
        end
    end

    for i = 1, 4 do
        local row_widget = self._widgets_by_name and self._widgets_by_name[ROW_WIDGET_NAMES[i]]
        if row_widget then
            row_widget.visible = false
            row_widget.content.player_icon = ""
            row_widget.content.player = ""
            for j = 1, 3 do
                row_widget.content["stat_" .. j] = ""
            end
        end
    end

    HudElementLiveScoreboard.super.destroy(self, ui_renderer)

    if ui_renderer then
        UIRenderer.clear_scenegraph_queue(ui_renderer)
        UIRenderer.clear_render_pass_queue(ui_renderer)
    end
end

return HudElementLiveScoreboard
