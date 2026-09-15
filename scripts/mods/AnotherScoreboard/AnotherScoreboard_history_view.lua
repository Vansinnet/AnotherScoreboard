local mod = get_mod("AnotherScoreboard")

local Managers = Managers
local UIWorkspace = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local Themes = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_themes")

local HistoryView = class("AnotherScoreboardHistoryView", "BaseView")

local BASE_Z = 100
local VIEW_W = 900
local VIEW_H = 640
local ENTRY_W = 820
local ENTRY_H = 46
local ENTRY_GAP = 4
local LIST_TOP = 86
local FOOTER_H = 42
local LIST_BOTTOM_PADDING = 14
local MODIFIER_X = 500
local SAVE_BUTTON_W = 76
local SAVE_BUTTON_X = ENTRY_W - SAVE_BUTTON_W - 8
local MODIFIER_W = SAVE_BUTTON_X - MODIFIER_X - 8
local MAIN_TEXT_W = MODIFIER_X - 32
local MODIFIER_FONT_SIZE = 13
local MAX_VISIBLE_ENTRIES = math.floor((VIEW_H - FOOTER_H - LIST_BOTTOM_PADDING - LIST_TOP + ENTRY_GAP) / (ENTRY_H + ENTRY_GAP))

local COLORS = Themes.by_id[Themes.default].colors.history

local function refresh_theme()
    local settings = mod:get_cached_settings()
    local theme_id = settings and settings.scoreboard_theme
    local selected = Themes.by_id[theme_id] or Themes.by_id[Themes.default]
    COLORS = selected.colors.history
end

local function text_pass(value_id, text, x, y, z, w, h, size, color, valign, halign)
    return {
        pass_type = "text",
        value_id = value_id,
        value = text,
        style = {
            offset = { x, y, z },
            size = { w, h },
            font_size = size,
            font_type = "proxima_nova_bold",
            text_horizontal_alignment = halign or "left",
            text_vertical_alignment = valign or "center",
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

local function button_definition(text, x, y, w, h, selected)
    local color = selected and COLORS.button_selected or COLORS.button

    return UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            style = {
                offset = { x, y, BASE_Z + 5 },
                size = { w, h },
            },
        },
        {
            pass_type = "rect",
            style_id = "background",
            style = {
                offset = { x, y, BASE_Z + 4 },
                size = { w, h },
                color = { color[1], color[2], color[3], color[4] },
            },
            change_function = function(content, style)
                local target = content.hotspot.is_hover and COLORS.button_hover or color
                style.color[1] = target[1]
                style.color[2] = target[2]
                style.color[3] = target[3]
                style.color[4] = target[4]
            end,
        },
        text_pass("text", text, x, y, BASE_Z + 6, w, h, 14, COLORS.text, "center", "center"),
    }, "content", nil, { VIEW_W, VIEW_H })
end

local function player_names(entry)
    local names = {}

    for i = 1, #(entry.players or {}) do
        names[#names + 1] = entry.players[i].name or "?"
    end

    return table.concat(names, ", ")
end

local function entry_title(entry, History)
    if History and History.entry_title_display then
        return History.entry_title_display(entry)
    end

    local mission = entry.mission_display or mod:localize("history_unknown_mission")
    local difficulty = entry.difficulty_display or mod:localize("history_unknown_difficulty")
    local duration = entry.duration_display or "--:--"

    return string.format("%s | %s | %s", mission, difficulty, duration)
end

local function entry_title_color(entry, History)
    local outcome = History and History.entry_outcome and History.entry_outcome(entry) or entry.outcome or entry.mission and entry.mission.outcome

    if outcome == "won" then
        return COLORS.won
    elseif outcome == "lost" then
        return COLORS.lost
    end

    return COLORS.text
end

local function mission_condition_lines(entry, History)
    if History and History.mission_conditions_display then
        return History.mission_conditions_display(entry)
    end

    return entry.havoc_modifiers_display
end

local function strip_formatting_tags(text)
    return type(text) == "string" and text:gsub("{#[^}]*}", "") or text
end

local function modifier_font_size(view, lines)
    local style = {
        font_size = MODIFIER_FONT_SIZE,
        font_type = "proxima_nova_bold",
    }
    local max_width = 0

    for i = 1, math.min(#lines, 2) do
        local width = view:_text_size(strip_formatting_tags(lines[i]), style)
        max_width = math.max(max_width, width)
    end

    if max_width <= MODIFIER_W then
        return MODIFIER_FONT_SIZE
    end

    return math.max(1, math.floor(MODIFIER_FONT_SIZE * MODIFIER_W / max_width))
end

local function entry_title_font_size(view, title)
    local font_size = 16
    local style = {
        font_size = font_size,
        font_type = "proxima_nova_bold",
    }
    local max_width = MAIN_TEXT_W - 8
    local width = view:_text_size(title, style)

    if width <= max_width then
        return font_size
    end

    return math.max(1, math.floor(font_size * max_width / width))
end

function HistoryView:init(settings, context)
    self._definitions = {
        widget_definitions = {},
        scenegraph_definition = {
            screen = UIWorkspace.screen,
            root = {
                vertical_alignment = "center",
                parent = "screen",
                horizontal_alignment = "center",
                size = { VIEW_W, VIEW_H },
                position = { 0, 0, BASE_Z },
            },
            content = {
                vertical_alignment = "top",
                parent = "root",
                horizontal_alignment = "center",
                size = { VIEW_W, VIEW_H },
                position = { 0, 0, BASE_Z + 1 },
            },
        },
    }

    self._entry_widgets = {}
    self._tab_widgets = {}
    self._active_tab = "recent"
    self._first_entries = { recent = 1, saved = 1 }
    self._max_first_entries = { recent = 1, saved = 1 }
    self._popup_id = nil
    HistoryView.super.init(self, self._definitions, settings, context or {})
    self._pass_draw = true
    self._pass_input = false
end

function HistoryView:on_enter()
    HistoryView.super.on_enter(self)
    self:_build()
end

function HistoryView:on_exit()
    if self._popup_id and Managers.event then
        Managers.event:trigger("event_remove_ui_popup", self._popup_id)
        self._popup_id = nil
    end

    self:_cleanup()
    HistoryView.super.on_exit(self)
end

function HistoryView:update(dt, t, input_service)
    if self._showing_entry then
        local ui = Managers.ui
        if ui:view_active("another_scoreboard_view") and not ui:is_view_closing("another_scoreboard_view") then
            return false, false
        end

        self._showing_entry = false
    end

    if self._pending_saved_action then
        local action = self._pending_saved_action
        self._pending_saved_action = nil
        self:_apply_saved_action(action)
    end

    if self._rebuild_requested then
        self._rebuild_requested = nil
        self:_build()
    end

    if self._history_cache_ready == false then
        local History = self:_history()
        if History.cache_ready and History.cache_ready() then
            self:_build()
        end
    end

    if input_service then
        local scroll_axis = input_service:get("scroll_axis")
        local scroll = scroll_axis and scroll_axis[2] or 0
        if scroll ~= 0 then
            self:_change_scroll(scroll > 0 and -1 or 1)
        end
    end

    if self._active_tab == "recent" and input_service and input_service:get("next") then
        local History = self:_history()
        if History.clear then
            History.clear()
            self:_build()
        end

        return
    end

    if input_service and input_service:get("back") then
        Managers.ui:close_view(self.view_name)

        return
    end

    return HistoryView.super.update(self, dt, t, input_service)
end

function HistoryView:_history()
    return mod.get_history and mod:get_history() or mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_history")
end

function HistoryView:_open_entry(entry)
    local History = self:_history()
    local loaded = entry.file_path and History.load(entry.file_path) or entry
    if not loaded then
        return
    end

    local ui = Managers.ui
    if ui:view_active("another_scoreboard_view") and not ui:is_view_closing("another_scoreboard_view") then
        ui:close_view("another_scoreboard_view", true)
    end

    self._showing_entry = true

    ui:open_view("another_scoreboard_view", nil, false, false, nil, {
        scoreboard_history = true,
        players = History.player_adapters(loaded.players),
        sections = loaded.sections or {},
        snapshot = loaded,
    }, { use_transition_ui = false })
end

function HistoryView:_entry_definition(entry, index, History)
    local y = LIST_TOP + (index - 1) * (ENTRY_H + ENTRY_GAP)
    local title = entry_title(entry, History)
    local title_size = entry_title_font_size(self, title)
    local title_color = entry_title_color(entry, History)
    local subtitle = string.format("%s  |  %s", entry.date_display or entry.date or "", player_names(entry))
    local modifier_lines = mission_condition_lines(entry, History) or {}
    local modifier_text = table.concat(modifier_lines, "\n", 1, math.min(#modifier_lines, 2))
    local modifier_size = modifier_font_size(self, modifier_lines)
    local is_saved = History.is_saved and History.is_saved(entry.id)
    local save_text = is_saved and mod:localize("history_manage")
        or mod:localize("history_save")

    return UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "entry_hotspot",
            style = {
                offset = { 0, 0, BASE_Z + 2 },
                size = { SAVE_BUTTON_X - 4, ENTRY_H },
            },
        },
        {
            pass_type = "hotspot",
            content_id = "save_hotspot",
            style = {
                offset = { SAVE_BUTTON_X, 5, BASE_Z + 3 },
                size = { SAVE_BUTTON_W, ENTRY_H - 10 },
            },
        },
        rect_pass(0, 0, BASE_Z, ENTRY_W, ENTRY_H, COLORS.entry),
        {
            pass_type = "rect",
            style_id = "hover",
            style = {
                offset = { 0, 0, BASE_Z + 1 },
                size = { ENTRY_W, ENTRY_H },
                color = { 0, COLORS.entry_hover[2], COLORS.entry_hover[3], COLORS.entry_hover[4] },
            },
            change_function = function(content, style)
                style.color[1] = content.entry_hotspot.is_hover and COLORS.entry_hover[1] or 0
            end,
        },
        {
            pass_type = "rect",
            style_id = "save_background",
            style = {
                offset = { SAVE_BUTTON_X, 5, BASE_Z + 2 },
                size = { SAVE_BUTTON_W, ENTRY_H - 10 },
                color = { COLORS.button[1], COLORS.button[2], COLORS.button[3], COLORS.button[4] },
            },
            change_function = function(content, style)
                local color = content.save_hotspot.is_hover and COLORS.button_hover
                    or is_saved and COLORS.button_selected
                    or COLORS.button
                style.color[1] = color[1]
                style.color[2] = color[2]
                style.color[3] = color[3]
                style.color[4] = color[4]
            end,
        },
        text_pass("title", title, 16, 2, BASE_Z + 3, MAIN_TEXT_W, 23, title_size, title_color),
        text_pass("subtitle", subtitle, 16, 24, BASE_Z + 3, MAIN_TEXT_W, 18, 13, COLORS.sub),
        text_pass("modifiers", modifier_text, MODIFIER_X, 0, BASE_Z + 3, MODIFIER_W, ENTRY_H, modifier_size, COLORS.text),
        text_pass("save_text", save_text, SAVE_BUTTON_X, 5, BASE_Z + 4, SAVE_BUTTON_W, ENTRY_H - 10, 12, COLORS.text, "center", "center"),
    }, "content", nil, { ENTRY_W, ENTRY_H }), { 40, y, 0 }
end

function HistoryView:_set_tab(tab)
    if tab == self._active_tab then
        return
    end

    self._active_tab = tab
    self._rebuild_requested = true
end

function HistoryView:_popup_closed()
    self._popup_id = nil
end

function HistoryView:_show_save_popup(entry)
    if self._popup_id or not Managers.event then
        return
    end

    local context = {
        title_text_unlocalized = mod:localize("history_name_popup_title"),
        description_text_unlocalized = mod:localize("history_name_popup_description"),
        options = {
            {
                keyboard_title = "loc_rename_account_virtual_keyboard_label",
                max_length = 48,
                template_type = "terminal_input_field",
                width = 512,
            },
            {
                close_on_pressed = true,
                no_localization = true,
                template_type = "terminal_button_small",
                text = mod:localize("history_save"),
                callback = function(custom_name)
                    self._pending_saved_action = { kind = "save", entry = entry, custom_name = custom_name }
                    self:_popup_closed()
                end,
            },
            {
                close_on_pressed = true,
                force_same_row = true,
                no_localization = true,
                template_type = "terminal_button_small",
                text = mod:localize("history_cancel"),
                callback = function()
                    self:_popup_closed()
                end,
            },
        },
    }

    Managers.event:trigger("event_show_ui_popup", context, function(popup_id)
        self._popup_id = popup_id
    end)
end

function HistoryView:_show_manage_popup(entry)
    if self._popup_id or not Managers.event then
        return
    end

    local History = self:_history()
    local name_label = entry.custom_name and mod:localize("history_manage_current_name")
        or mod:localize("history_manage_generated_name")
    local description = string.format("%s: %s", name_label, entry_title(entry, History))
    local context = {
        title_text_unlocalized = mod:localize("history_manage_popup_title"),
        description_text_unlocalized = description,
        options = {
            {
                keyboard_title = "loc_rename_account_virtual_keyboard_label",
                max_length = 48,
                template_type = "terminal_input_field",
                width = 512,
            },
            {
                close_on_pressed = true,
                no_localization = true,
                template_type = "terminal_button_small",
                text = mod:localize("history_save_name"),
                callback = function(custom_name)
                    self._pending_saved_action = { kind = "rename", entry = entry, custom_name = custom_name }
                    self:_popup_closed()
                end,
            },
            {
                close_on_pressed = true,
                force_same_row = true,
                no_localization = true,
                template_type = "terminal_button_small",
                text = mod:localize("history_remove"),
                callback = function()
                    self._pending_saved_action = { kind = "remove", entry = entry }
                    self:_popup_closed()
                end,
            },
            {
                close_on_pressed = true,
                force_same_row = true,
                no_localization = true,
                template_type = "terminal_button_small",
                text = mod:localize("history_cancel"),
                callback = function()
                    self:_popup_closed()
                end,
            },
        },
    }

    Managers.event:trigger("event_show_ui_popup", context, function(popup_id)
        self._popup_id = popup_id
    end)
end

function HistoryView:_handle_saved_button(entry)
    local History = self:_history()

    if History.is_saved and History.is_saved(entry.id) then
        local saved_entry = entry
        for _, candidate in ipairs(History.saved_list and History.saved_list() or {}) do
            if candidate.id == entry.id then
                saved_entry = candidate
                break
            end
        end
        self:_show_manage_popup(saved_entry)
    else
        self:_show_save_popup(entry)
    end
end

function HistoryView:_apply_saved_action(action)
    local History = self:_history()
    local changed

    if action.kind == "save" then
        changed = History.save_entry and History.save_entry(action.entry, action.custom_name)
    elseif action.kind == "rename" then
        changed = History.rename_saved and History.rename_saved(action.entry.id, action.custom_name)
    elseif action.kind == "remove" then
        changed = History.remove_saved and History.remove_saved(action.entry.id)
    end

    if changed then
        self._rebuild_requested = true
    end
end

function HistoryView:_change_scroll(delta)
    local tab = self._active_tab
    local first_entry = math.max(1, math.min(self._first_entries[tab] + delta, self._max_first_entries[tab]))

    if first_entry ~= self._first_entries[tab] then
        self._first_entries[tab] = first_entry
        self._rebuild_requested = true
    end
end

function HistoryView:_build()
    refresh_theme()
    self:_cleanup()

    local History = self:_history()
    if not History then
        return
    end

    local recent_entries = History.list()
    local saved_entries = History.saved_list and History.saved_list() or {}
    local entries = self._active_tab == "saved" and saved_entries or recent_entries
    local cache_ready = not History.cache_ready or History.cache_ready()
    self._history_cache_ready = cache_ready
    local tab = self._active_tab
    local max_first_entry = math.max(1, #entries - MAX_VISIBLE_ENTRIES + 1)
    self._max_first_entries[tab] = max_first_entry
    self._first_entries[tab] = math.min(self._first_entries[tab], max_first_entry)
    local first_entry = self._first_entries[tab]
    local subtitle = tab == "saved" and mod:localize("history_saved_subtitle")
        or mod:localize("history_view_subtitle", History.recent_capacity())
    local hint_id = self._active_tab == "saved" and "history_saved_hint" or "history_escape_hint"
    local last_entry = math.min(#entries, first_entry + MAX_VISIBLE_ENTRIES - 1)

    local background_passes = {
        rect_pass(0, 0, BASE_Z - 1, VIEW_W, VIEW_H, COLORS.panel),
        text_pass("title", mod:localize("history_view_title"), 36, 18, BASE_Z + 4, VIEW_W - 72, 42, 30, COLORS.title),
        text_pass("subtitle", subtitle, 38, 56, BASE_Z + 4, VIEW_W - 76, 24, 16, COLORS.sub),
        rect_pass(0, VIEW_H - FOOTER_H, BASE_Z + 2, VIEW_W, FOOTER_H, COLORS.footer),
        text_pass("hint", mod:localize(hint_id), 16, VIEW_H - 36, BASE_Z + 4, 560, 24, 15, COLORS.text),
    }

    if #entries > MAX_VISIBLE_ENTRIES then
        local range_text = string.format("%d-%d / %d", first_entry, last_entry, #entries)
        background_passes[#background_passes + 1] = text_pass("range", range_text, 700, VIEW_H - 36, BASE_Z + 4, 164, 24, 15, COLORS.text, "center", "right")
    end

    local background = UIWidget.create_definition(background_passes, "content", nil, { VIEW_W, VIEW_H })

    self._background_widget = self:_create_widget("as_history_background", background)

    local recent_text = string.format("%s (%d)", mod:localize("history_tab_recent"), #recent_entries)
    local saved_text = string.format("%s (%d)", mod:localize("history_tab_saved"), #saved_entries)
    local recent_widget = self:_create_widget("as_history_tab_recent", button_definition(recent_text, 570, 24, 140, 34, self._active_tab == "recent"))
    recent_widget.content.hotspot.pressed_callback = function()
        self:_set_tab("recent")
    end
    self._tab_widgets[#self._tab_widgets + 1] = recent_widget

    local saved_widget = self:_create_widget("as_history_tab_saved", button_definition(saved_text, 718, 24, 146, 34, self._active_tab == "saved"))
    saved_widget.content.hotspot.pressed_callback = function()
        self:_set_tab("saved")
    end
    self._tab_widgets[#self._tab_widgets + 1] = saved_widget

    if #entries == 0 then
        local empty_id = self._active_tab == "saved" and "history_no_saved_entries"
            or cache_ready and "history_no_entries"
            or "history_loading"
        local empty = UIWidget.create_definition({
            text_pass("empty", mod:localize(empty_id), 40, 120, BASE_Z + 4, VIEW_W - 80, 40, 20, COLORS.empty),
        }, "content", nil, { VIEW_W, 180 })

        self._empty_widget = self:_create_widget("as_history_empty", empty)
        return
    end

    local visible_index = 0
    for entry_index = first_entry, last_entry do
        visible_index = visible_index + 1
        local definition, offset = self:_entry_definition(entries[entry_index], visible_index, History)
        local widget = self:_create_widget("as_history_entry_" .. visible_index, definition)
        widget.offset = offset
        widget.content.entry = entries[entry_index]
        widget.content.entry_hotspot.pressed_callback = function()
            self:_open_entry(widget.content.entry)
        end
        widget.content.save_hotspot.pressed_callback = function()
            self:_handle_saved_button(widget.content.entry)
        end
        self._entry_widgets[#self._entry_widgets + 1] = widget
    end
end

function HistoryView:_cleanup()
    if self._background_widget then
        self._widgets_by_name[self._background_widget.name] = nil
        self:_unregister_widget_name(self._background_widget.name)
        self._background_widget = nil
    end

    if self._empty_widget then
        self._widgets_by_name[self._empty_widget.name] = nil
        self:_unregister_widget_name(self._empty_widget.name)
        self._empty_widget = nil
    end

    if self._entry_widgets then
        for _, widget in ipairs(self._entry_widgets) do
            self._widgets_by_name[widget.name] = nil
            self:_unregister_widget_name(widget.name)
        end
    end

    if self._tab_widgets then
        for _, widget in ipairs(self._tab_widgets) do
            self._widgets_by_name[widget.name] = nil
            self:_unregister_widget_name(widget.name)
        end
    end

    self._entry_widgets = {}
    self._tab_widgets = {}
end

function HistoryView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    if self._showing_entry then
        return
    end

    local alpha = self._alpha_multiplier or render_settings.alpha_multiplier or 1

    if self._background_widget then
        self._background_widget.alpha_multiplier = alpha
        UIWidget.draw(self._background_widget, ui_renderer)
    end

    if self._empty_widget then
        self._empty_widget.alpha_multiplier = alpha
        UIWidget.draw(self._empty_widget, ui_renderer)
    end

    for i = 1, #self._entry_widgets do
        local widget = self._entry_widgets[i]
        widget.alpha_multiplier = alpha
        UIWidget.draw(widget, ui_renderer)
    end

    for i = 1, #self._tab_widgets do
        local widget = self._tab_widgets[i]
        widget.alpha_multiplier = alpha
        UIWidget.draw(widget, ui_renderer)
    end

end

function HistoryView:dialogue_system()
    return nil
end

return HistoryView
