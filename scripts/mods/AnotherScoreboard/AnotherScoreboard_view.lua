local mod = get_mod("AnotherScoreboard")

local pairs              = pairs
local ipairs             = ipairs

local Managers           = Managers
local Keyboard           = Keyboard

local UIWorkspace = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local LoadoutRender = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_loadout_render")

local BASE_Z = 100
local VIEW_W = 900
local VIEW_H = 700
local MOVE_DURATION = 0.75
local HISTORY_FOOTER_H = 42
local HISTORY_VERTICAL_OFFSET = 100

local HISTORY_HINT_TEXT = { 255, 216, 229, 207 }
local HISTORY_FOOTER_COLOR = { 220, 18, 20, 18 }
local Y_KEY = Keyboard.button_index("y")
local Q_KEY = Keyboard.button_index("q")
local U_KEY = Keyboard.button_index("u")
local T_KEY = Keyboard.button_index("t")
local LEFT_KEY = Keyboard.button_index("left")
local RIGHT_KEY = Keyboard.button_index("right")
local PLAYER_KEYS = {
    Keyboard.button_index("1"), Keyboard.button_index("2"),
    Keyboard.button_index("3"), Keyboard.button_index("4"),
}

local function text_pass(value_id, text, x, y, z, w, h, size, color)
    return {
        pass_type = "text",
        value_id = value_id,
        value = text,
        style = {
            offset = { x, y, z },
            size = { w, h },
            font_size = size,
            font_type = "proxima_nova_bold",
            text_horizontal_alignment = "left",
            text_vertical_alignment = "center",
            text_color = color,
        },
    }
end

local function rect_pass(x, y, z, w, h, color)
    return {
        pass_type = "rect",
        style = {
            offset = { x, y, z },
            size = { w, h },
            color = color,
        },
    }
end

local function render_settings_with_title(settings, title_text, end_view)
    return {
        scale = end_view and settings.end_scoreboard_scale or settings.scale,
        text_scale = settings.text_scale,
        alternating_row_shading = settings.alternating_row_shading,
        horizontal_offset = end_view and settings.end_scoreboard_horizontal_offset or settings.horizontal_offset,
        vertical_offset = end_view and settings.end_scoreboard_vertical_offset or settings.vertical_offset,
        title_text = title_text,
        panel_min_h = settings and settings.panel_min_h or nil,
        theme = settings.scoreboard_theme,
    }
end

local ASView = class("AnotherScoreboardView", "BaseView")

ASView.init = function(self, settings, context)
    self._definitions = {
        widget_definitions = {},
        scenegraph_definition = {
            screen          = UIWorkspace.screen,
            scoreboard_root = {
                vertical_alignment   = "center",
                parent               = "screen",
                horizontal_alignment = "center",
                size                 = { VIEW_W, VIEW_H },
                position             = { 0, 50, BASE_Z },
            },
            content_area = {
                vertical_alignment   = "top",
                parent               = "scoreboard_root",
                horizontal_alignment = "center",
                size                 = { VIEW_W, VIEW_H },
                position             = { 0, 0, BASE_Z + 1 },
            },
        },
    }

    self._column_widgets   = {}
    self._section_widgets  = {}
    self._row_widgets      = {}
    self._history_hint_widget = nil
    self._context          = context or {}
    self._show_all_enemy_rows = false
    self._show_all_dot_rows = false
    self._show_boss_details = false
    self._show_survival_details = false
    self._temporarily_hidden = false
    self._scoreboard_hint_text = nil
    self._show_loadout = false
    self._loadout_player = 1
    self._loadout_tree = false
    self._loadout_talent = 1
    self._loadout_talent_count = 0

    self._move_timer   = nil
    self._move_from    = 0
    self._move_to      = 0
    self._scoreboard_offset = 0
    self._scoreboard_fit_offset = 0

    ASView.super.init(self, self._definitions, settings, context)
    self._pass_draw  = true
    self._pass_input = true
end

local function _apply_scoreboard_position(self)
    local scenegraph = self._ui_scenegraph
    local root = scenegraph and scenegraph.scoreboard_root
    if not root then
        return
    end

    if self._show_loadout then
        self:_set_scenegraph_position("scoreboard_root", 0, -11)
        return
    end

    if self._context and self._context.scoreboard_history then
        self:_set_scenegraph_position("scoreboard_root", 0,
            -HISTORY_VERTICAL_OFFSET - (self._scoreboard_fit_offset or 0))

        return
    end

    local settings = mod:get_cached_settings()
    local end_view = self._context and self._context.end_view
    local horizontal_offset = end_view and settings.end_scoreboard_horizontal_offset or settings.horizontal_offset
    local vertical_offset = end_view and settings.end_scoreboard_vertical_offset or settings.vertical_offset
    self:_set_scenegraph_position("scoreboard_root", horizontal_offset or 0,
        50 - (vertical_offset or 0) - (self._scoreboard_fit_offset or 0))
end

ASView.on_enter = function(self)
    ASView.super.on_enter(self)
    self:_build()
end

ASView.on_exit = function(self)
    ASView.super.on_exit(self)
    self:_cleanup()
end

ASView._get_players = function(self)
    local context = self._context
    if context and context.players then
        return context.players
    end

    local list, n = {}, 0
    for _, p in pairs(Managers.player:players()) do
        n = n + 1
        if n <= 4 then list[#list + 1] = p end
    end
    return list
end

ASView._build_hint = function(self, built, hint_text)
    if not self._show_loadout and self._context and (self._context.end_view or self._context.scoreboard_history) then
        hint_text = (hint_text and hint_text .. "  |  " or "") .. mod:localize("loadout_hint_open")
    end
    if not hint_text or hint_text == "" then
        return
    end

    local panel = built.panel
    local footer_x = panel and panel.x or 0
    local footer_y = panel and panel.y + panel.h or VIEW_H - HISTORY_FOOTER_H
    local footer_w = panel and panel.w or VIEW_W
    local Render = mod:get_render()
    local colors = Render and Render.theme_colors and Render.theme_colors()
    local hint_text_color = colors and colors.history_hint_text or HISTORY_HINT_TEXT
    local footer_color = colors and colors.history_footer or HISTORY_FOOTER_COLOR
    local hint_font_size = math.floor(17 * (built.text_scale or 1))
    if Render and Render.fit_text_font_size then
        hint_font_size = Render.fit_text_font_size(self, nil, hint_text, "proxima_nova_bold",
            hint_font_size, footer_w - 32, 24)
    end

    self._scoreboard_hint_text = hint_text
    local displayed_hint = self._context and self._context.end_view and self._temporarily_hidden
        and mod:localize("scoreboard_hint_end_show") or hint_text
    self._history_hint_widget = self:_create_widget("as_scoreboard_hint", UIWidget.create_definition({
        rect_pass(footer_x, footer_y, BASE_Z + 20, footer_w, HISTORY_FOOTER_H, footer_color),
        text_pass("hint", displayed_hint, footer_x + 16, footer_y + 6,
            BASE_Z + 22, footer_w - 32, 24, hint_font_size, hint_text_color),
    }, "content_area", nil, { VIEW_W, VIEW_H }))
end

ASView._build = function(self)
    self:_cleanup()

    local players = self:_get_players()
    if #players == 0 then return end

    local Render  = mod:get_render()
    local context = self._context
    local settings = mod:get_cached_settings()
    players = mod.order_scoreboard_players(players)
    local end_view = context and context.end_view
    local title_text = mod.get_scoreboard_title_text and mod.get_scoreboard_title_text(context and context.snapshot) or nil
    self._last_title_text = title_text
    self._title_update_timer = 1.0

    if self._show_loadout then
        local built = LoadoutRender.build(self, "content_area", players, self._loadout_player,
            self._loadout_tree, self._loadout_talent, settings)
        self._loadout_player_count = #players
        self._loadout_talent_count = built.talent_count
        self._column_widgets = {}
        for i, w in ipairs(built.columns) do
            local registered = self:_create_widget("as_loadout_" .. i, w.widget)
            registered.offset = w.offset
            self._column_widgets[i] = registered
        end
        self:_build_hint(built, mod:localize(self._loadout_tree and "loadout_hint_tree" or "loadout_hint_equipment"))
        _apply_scoreboard_position(self)
        self:_force_update_scenegraph()
        return
    end

    if context and context.scoreboard_history then
        local sections = context.sections or {}
        if mod.filter_scoreboard_sections then
            sections = mod.filter_scoreboard_sections(sections, self._show_all_enemy_rows, self._show_all_dot_rows,
                self._show_boss_details, self._show_survival_details, context.snapshot and context.snapshot.duration)
        end

        local built = Render.build_widgets(self, "content_area", players, sections,
            render_settings_with_title(settings, title_text, false))

        if not built then return end

        self._scoreboard_fit_offset = Render.view_vertical_fit_offset(built.content_height, -HISTORY_VERTICAL_OFFSET)

        self._column_widgets = {}
        self._section_widgets = {}
        self._row_widgets = {}

        for _, w in ipairs(built.columns) do
            local registered = self:_create_widget("as_" .. #self._column_widgets, w.widget)
            self._column_widgets[#self._column_widgets + 1] = registered
            registered.offset = w.offset
        end
        self._title_widget = self._column_widgets[1]
        self._title_max_font_size = built.title_max_font_size
        self._title_max_width = built.title_max_width

        for _, w in ipairs(built.sections) do
            local registered = self:_create_widget("as_sec_" .. #self._section_widgets, w.widget)
            self._section_widgets[#self._section_widgets + 1] = registered
            registered.offset = w.offset
        end

        local hint_text = mod.get_scoreboard_hint_text(self._show_all_enemy_rows,
            self._show_all_dot_rows, self._show_boss_details, self._show_survival_details, true)
        self:_build_hint(built, hint_text)
        _apply_scoreboard_position(self)
        self:_force_update_scenegraph()

        return
    end

    local Stats   = mod:get_stats()

    local ids = {}
    for i = 1, #players do
        ids[players[i]:account_id() or players[i]:name()] = true
    end
    Stats.ensure_entries(ids)

    Stats.validate(ids)

    local sections = Stats.sections()
    if mod.filter_scoreboard_sections then
        sections = mod.filter_scoreboard_sections(sections, self._show_all_enemy_rows, self._show_all_dot_rows,
            self._show_boss_details, self._show_survival_details,
            mod.get_scoreboard_duration and mod.get_scoreboard_duration() or 0)
    end
    local built = Render.build_widgets(self, "content_area", players, sections,
        render_settings_with_title(settings, title_text, end_view))

    if not built then return end

    local root_y = 50 - (end_view and settings.end_scoreboard_vertical_offset or settings.vertical_offset)
    self._scoreboard_fit_offset = Render.view_vertical_fit_offset(built.content_height, root_y)

    self._column_widgets = {}
    self._section_widgets = {}
    self._row_widgets = {}

    for _, w in ipairs(built.columns) do
        local registered = self:_create_widget("as_" .. #self._column_widgets, w.widget)
        self._column_widgets[#self._column_widgets + 1] = registered
        registered.offset = w.offset
    end
    self._title_widget = self._column_widgets[1]
    self._title_max_font_size = built.title_max_font_size
    self._title_max_width = built.title_max_width

    for _, w in ipairs(built.sections) do
        local registered = self:_create_widget("as_sec_" .. #self._section_widgets, w.widget)
        self._section_widgets[#self._section_widgets + 1] = registered
        registered.offset = w.offset
    end

    for _, w in ipairs(built.rows) do
        local registered = self:_create_widget("as_row_" .. #self._row_widgets, w.widget)
        self._row_widgets[#self._row_widgets + 1] = registered
        registered.offset = w.offset
    end


    local hint_text = mod.get_scoreboard_hint_text(self._show_all_enemy_rows,
        self._show_all_dot_rows, self._show_boss_details, self._show_survival_details, false)
    self:_build_hint(built, hint_text)
    _apply_scoreboard_position(self)
    self:_force_update_scenegraph()
end

ASView._cleanup = function(self)
    local cols = self._column_widgets
    if cols then
        for _, w in ipairs(cols) do
            self._widgets_by_name[w.name] = nil
            self:_unregister_widget_name(w.name)
        end
        self._column_widgets = nil
    end
    self._title_widget = nil
    self._title_max_font_size = nil
    self._title_max_width = nil
    self._scoreboard_fit_offset = 0
    local secs = self._section_widgets
    if secs then
        for _, w in ipairs(secs) do
            self._widgets_by_name[w.name] = nil
            self:_unregister_widget_name(w.name)
        end
        self._section_widgets = nil
    end
    local rows = self._row_widgets
    if rows then
        for _, w in ipairs(rows) do
            self._widgets_by_name[w.name] = nil
            self:_unregister_widget_name(w.name)
        end
        self._row_widgets = nil
    end

    if self._history_hint_widget then
        self._widgets_by_name[self._history_hint_widget.name] = nil
        self:_unregister_widget_name(self._history_hint_widget.name)
        self._history_hint_widget = nil
    end
end

ASView.move_scoreboard = function(self, from_x, to_x)
    self._move_timer = MOVE_DURATION
    self._move_from  = from_x
    self._move_to    = to_x
end

ASView._update_move = function(self, dt)
    if not self._move_timer then return end
    if self._move_timer <= 0 then
        self._scoreboard_offset = self._move_to
        self._move_timer = nil
    else
        local pct = self._move_timer * (1 / MOVE_DURATION)
        local t_ease = math.ease_sine(pct)
        local range = math.abs(self._move_to) + math.abs(self._move_from)
        if self._move_to > self._move_from then
            self._scoreboard_offset = self._move_to - range * t_ease
        else
            self._scoreboard_offset = self._move_to + range * t_ease
        end
        self._move_timer = self._move_timer - dt
    end
end

ASView.update = function(self, dt, t, input_service)
    local scoreboard_history = self._context and self._context.scoreboard_history
    local end_view = self._context and self._context.end_view

    if self._input_disabled or not input_service or input_service:is_null_service() then
        self:_update_move(dt)
        return ASView.super.update(self, dt, t, input_service)
    end

    if (scoreboard_history or end_view) and (Keyboard.pressed(U_KEY)
            or self._show_loadout and input_service:get("back")) then
        self._show_loadout = not self._show_loadout
        self._pass_input = not self._show_loadout
        self._temporarily_hidden = false
        self:_build()
        ASView.super.update(self, dt, t, input_service)
        -- Consume the closing key too, so Escape does not also leave the underlying screen.
        return false, true
    end

    if self._show_loadout then
        local rebuild = false
        for i = 1, math.min(self._loadout_player_count or 0, #PLAYER_KEYS) do
            if Keyboard.pressed(PLAYER_KEYS[i]) and self._loadout_player ~= i then
                self._loadout_player = i
                self._loadout_talent = 1
                rebuild = true
            end
        end
        if Keyboard.pressed(T_KEY) then
            self._loadout_tree = not self._loadout_tree
            rebuild = true
        end
        local scroll_axis = input_service:get("scroll_axis")
        local scroll = scroll_axis and scroll_axis[2] or 0
        if not self._loadout_tree and not rebuild and scroll ~= 0 then
            local player_count = self._loadout_player_count or 0
            if player_count > 1 then
                local direction = scroll > 0 and -1 or 1
                self._loadout_player = (self._loadout_player - 1 + direction) % player_count + 1
                self._loadout_talent = 1
                rebuild = true
            end
        elseif self._loadout_tree and not rebuild and self._loadout_talent_count > 0 then
            local direction = Keyboard.pressed(RIGHT_KEY) and 1
                or Keyboard.pressed(LEFT_KEY) and -1
                or scroll > 0 and -1
                or scroll < 0 and 1
                or 0
            if direction ~= 0 then
                self._loadout_talent = (self._loadout_talent - 1 + direction) % self._loadout_talent_count + 1
                rebuild = true
            end
        end
        if rebuild then self:_build() end
        self:_update_move(dt)
        return ASView.super.update(self, dt, t, input_service)
    end

    if scoreboard_history and input_service and input_service:get("back") then
        Managers.ui:close_view(self.view_name)

        return
    end

    if end_view and Keyboard.pressed(Q_KEY) then
        self._temporarily_hidden = not self._temporarily_hidden
        if self._history_hint_widget then
            self._history_hint_widget.content.hint = self._temporarily_hidden
                and mod:localize("scoreboard_hint_end_show") or self._scoreboard_hint_text
            self._history_hint_widget.dirty = true
        end
    end

    if self._temporarily_hidden then
        _apply_scoreboard_position(self)
        self:_update_move(dt)
        return ASView.super.update(self, dt, t, input_service)
    end

    if input_service and input_service:get("hotkey_menu_special_1") and mod.scoreboard_detail_available("enemy") then
        self._show_all_enemy_rows = not self._show_all_enemy_rows
        self._show_all_dot_rows = false
        self._show_boss_details = false
        self._show_survival_details = false
        self:_build()

        return
    end

    if input_service and input_service:get("group_finder_refresh_groups") and mod.scoreboard_detail_available("dot") then
        self._show_all_dot_rows = not self._show_all_dot_rows
        self._show_all_enemy_rows = false
        self._show_boss_details = false
        self._show_survival_details = false
        self:_build()

        return
    end

    if input_service and input_service:get("toggle_filter") and mod.scoreboard_detail_available("boss") then
        self._show_boss_details = not self._show_boss_details
        self._show_all_enemy_rows = false
        self._show_all_dot_rows = false
        self._show_survival_details = false
        self:_build()

        return
    end

    if input_service and Keyboard.pressed(Y_KEY) and mod.scoreboard_detail_available("survival") then
        self._show_survival_details = not self._show_survival_details
        self._show_all_enemy_rows = false
        self._show_all_dot_rows = false
        self._show_boss_details = false
        self:_build()

        return
    end

    _apply_scoreboard_position(self)

    if not (self._context and self._context.scoreboard_history) and self._title_widget then
        self._title_update_timer = (self._title_update_timer or 0) - dt
        if self._title_update_timer <= 0 then
            self._title_update_timer = 1.0
            local title_text = mod.get_scoreboard_title_text and mod.get_scoreboard_title_text() or nil
            if title_text and title_text ~= self._last_title_text then
                self._last_title_text = title_text
                self._title_widget.content.title = title_text
                local Render = mod:get_render()
                Render.fit_title_widget(self, nil, self._title_widget, title_text,
                    self._title_max_font_size, self._title_max_width)
            end
        end
    end

    self:_update_move(dt)

    return ASView.super.update(self, dt, t, input_service)
end

ASView.draw = function(self, dt, t, input_service, layer)
    ASView.super.draw(self, dt, t, input_service, layer)
end

ASView._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
    local alpha = self._alpha_multiplier or render_settings.alpha_multiplier or 1
    if not self._show_loadout and not (self._context and self._context.scoreboard_history) then
        local settings = mod:get_cached_settings()
        local opacity = self._context and self._context.end_view and settings.end_scoreboard_opacity
            or settings.scoreboard_opacity
        alpha = alpha * ((opacity or 206) / 255)
    end
    if self._temporarily_hidden then
        if self._history_hint_widget then
            self._history_hint_widget.alpha_multiplier = alpha
            UIWidget.draw(self._history_hint_widget, ui_renderer)
        end
        return
    end
    local cols = self._column_widgets
    if cols then
        for i = 1, #cols do
            cols[i].alpha_multiplier = alpha
            UIWidget.draw(cols[i], ui_renderer)
        end
    end
    local secs = self._section_widgets
    if secs then
        for i = 1, #secs do
            secs[i].alpha_multiplier = alpha
            UIWidget.draw(secs[i], ui_renderer)
        end
    end
    local rows = self._row_widgets
    if rows then
        for i = 1, #rows do
            rows[i].alpha_multiplier = alpha
            UIWidget.draw(rows[i], ui_renderer)
        end
    end
    if self._history_hint_widget then
        self._history_hint_widget.alpha_multiplier = alpha
        UIWidget.draw(self._history_hint_widget, ui_renderer)
    end
end

return ASView
