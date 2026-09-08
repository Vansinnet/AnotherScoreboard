local mod = get_mod("AnotherScoreboard")
local live_stats = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_live_stats")
local archetypes = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_archetypes")
local scoreboard_stats = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_scoreboard_stats")
local themes = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_themes")

local function live_stat_options()
    local options = {}

    for i = 1, #live_stats do
        local stat = live_stats[i]
        options[i] = { text = stat.option, value = stat.key }
    end

    table.sort(options, function(a, b)
        local a_text = string.lower(mod:localize(a.text))
        local b_text = string.lower(mod:localize(b.text))

        if a_text == b_text then
            return a.value < b.value
        end

        return a_text < b_text
    end)

    return options
end

local function archetype_options()
    local options = { localize = false }

    for i = 1, #archetypes do
        local archetype = archetypes[i]
        local ok, display_name = pcall(Localize, archetype.localization_key)
        options[i] = {
            text = ok and type(display_name) == "string" and display_name ~= "" and display_name or archetype.fallback_name,
            value = archetype.id,
        }
    end

    return options
end

local function scoreboard_stat_widgets(section)
    local widgets = {}

    for i = 1, #scoreboard_stats do
        local stat = scoreboard_stats[i]
        if stat.section == section then
            widgets[#widgets + 1] = {
                setting_id = "show_scoreboard_stat_" .. stat.id,
                type = "checkbox",
                default_value = stat.id ~= "lesser_enemies_killed",
                title = stat.label,
                tooltip = "scoreboard_stat_visibility_tooltip",
            }
            if stat.id == "headshots" then
                widgets[#widgets + 1] = {
                    setting_id = "show_scoreboard_weakspot_percentage",
                    type = "checkbox",
                    default_value = true,
                    title = "show_scoreboard_weakspot_percentage",
                    tooltip = "scoreboard_hit_percentage_tooltip",
                }
            elseif stat.id == "critical_hits" then
                widgets[#widgets + 1] = {
                    setting_id = "show_scoreboard_critical_percentage",
                    type = "checkbox",
                    default_value = true,
                    title = "show_scoreboard_critical_percentage",
                    tooltip = "scoreboard_hit_percentage_tooltip",
                }
            end
        end
    end

    return widgets
end

local function theme_options()
    local options = {}

    for i = 1, #themes.order do
        local theme_id = themes.order[i]
        options[i] = { text = themes.by_id[theme_id].label, value = theme_id }
    end

    return options
end

return {
    name             = mod:localize("mod_name"),
    description      = mod:localize("mod_description"),
    is_togglable     = true,
    allow_rehooking  = true,
    options = { widgets = {
        { setting_id = "open_scoreboard_history", type = "keybind", default_value = { "f5" },
          title = "open_scoreboard_history", tooltip = "open_scoreboard_history_tooltip",
          keybind_trigger = "pressed", keybind_type = "function_call", function_name = "open_scoreboard_history" },
        { setting_id = "scoreboard_theme_header", type = "group",
          title = "scoreboard_theme_header", tooltip = "scoreboard_theme_header_tooltip",
           sub_widgets = {
               { setting_id = "scoreboard_theme", type = "dropdown", default_value = themes.default,
                 title = "scoreboard_theme", tooltip = "scoreboard_theme_tooltip", options = theme_options() },
                { setting_id = "scoreboard_text_scale", type = "numeric", default_value = 115,
                  title = "scoreboard_text_scale", tooltip = "scoreboard_text_scale_tooltip",
                  range = { 100, 130 } },
                { setting_id = "local_player_first", type = "checkbox", default_value = true,
                  title = "local_player_first", tooltip = "local_player_first_tooltip" },
                { setting_id = "alternating_row_shading", type = "checkbox", default_value = true,
                  title = "alternating_row_shading", tooltip = "alternating_row_shading_tooltip" },
           },
        },
        { setting_id = "tab_scoreboard_header", type = "group",
          title = "tab_scoreboard_header", tooltip = "tab_scoreboard_header_tooltip",
          sub_widgets = {
              { setting_id = "show_in_mission",      type = "checkbox", default_value = true,
                title = "show_in_mission", tooltip = "show_in_mission_tooltip" },
              { setting_id = "scoreboard_scale",     type = "numeric",  default_value = 100,
                title = "scoreboard_scale", tooltip = "scoreboard_scale_tooltip",
                range = { 50, 150 } },
              { setting_id = "scoreboard_opacity",   type = "numeric",  default_value = 206,
                title = "scoreboard_opacity", tooltip = "scoreboard_opacity_tooltip",
                range = { 0, 255 } },
              { setting_id = "vertical_offset",      type = "numeric",  default_value = 0,
                title = "vertical_offset", tooltip = "vertical_offset_tooltip",
                range = { -300, 300 } },
              { setting_id = "horizontal_offset",    type = "numeric",  default_value = 0,
                title = "horizontal_offset", tooltip = "horizontal_offset_tooltip",
                range = { -300, 300 } },
          },
        },
        { setting_id = "end_scoreboard_header", type = "group",
          title = "end_scoreboard_header", tooltip = "end_scoreboard_header_tooltip",
          sub_widgets = {
              { setting_id = "show_at_end",          type = "checkbox", default_value = true,
                title = "show_at_end", tooltip = "show_at_end_tooltip" },
              { setting_id = "end_scoreboard_scale", type = "numeric", default_value = 100,
                title = "end_scoreboard_scale", tooltip = "end_scoreboard_scale_tooltip",
                range = { 50, 150 } },
              { setting_id = "end_scoreboard_opacity", type = "numeric", default_value = 206,
                title = "end_scoreboard_opacity", tooltip = "end_scoreboard_opacity_tooltip",
                range = { 0, 255 } },
              { setting_id = "end_scoreboard_vertical_offset", type = "numeric", default_value = 180,
                title = "end_scoreboard_vertical_offset", tooltip = "end_scoreboard_vertical_offset_tooltip",
                range = { -300, 300 } },
              { setting_id = "end_scoreboard_horizontal_offset", type = "numeric", default_value = 0,
                title = "end_scoreboard_horizontal_offset", tooltip = "end_scoreboard_horizontal_offset_tooltip",
                range = { -300, 300 } },
          },
        },
        { setting_id = "live_scoreboard_header", type = "group",
          title = "live_scoreboard_header", tooltip = "live_scoreboard_header_tooltip",
          sub_widgets = {
              { setting_id = "show_live_scoreboard",       type = "checkbox", default_value = true,
                title = "show_live_scoreboard", tooltip = "show_live_scoreboard_tooltip" },
               { setting_id = "live_scoreboard_archetype", type = "dropdown", default_value = "veteran",
                 title = "live_scoreboard_archetype", tooltip = "live_scoreboard_archetype_tooltip", options = archetype_options() },
               { setting_id = "live_scoreboard_stat_count", type = "dropdown", default_value = 3,
                 title = "live_scoreboard_stat_count", tooltip = "live_scoreboard_stat_count_tooltip",
                 options = {
                     { text = "live_scoreboard_stat_count_1", value = 1, show_widgets = { 1 } },
                     { text = "live_scoreboard_stat_count_2", value = 2, show_widgets = { 1, 2 } },
                     { text = "live_scoreboard_stat_count_3", value = 3, show_widgets = { 1, 2, 3 } },
                 },
                 sub_widgets = {
                     { setting_id = "live_scoreboard_stat_1", type = "dropdown", default_value = "damage",
                       title = "live_scoreboard_stat_1", tooltip = "live_scoreboard_stat_tooltip", options = live_stat_options() },
                     { setting_id = "live_scoreboard_stat_2", type = "dropdown", default_value = "kills",
                       title = "live_scoreboard_stat_2", tooltip = "live_scoreboard_stat_tooltip", options = live_stat_options() },
                     { setting_id = "live_scoreboard_stat_3", type = "dropdown", default_value = "hp_lost",
                       title = "live_scoreboard_stat_3", tooltip = "live_scoreboard_stat_tooltip", options = live_stat_options() },
                 },
               },
              { setting_id = "live_scoreboard_scale",      type = "numeric",  default_value = 100,
                title = "live_scoreboard_scale", tooltip = "live_scoreboard_scale_tooltip",
                range = { 50, 300 } },
              { setting_id = "live_scoreboard_x_offset",   type = "numeric",  default_value = 0,
                title = "live_scoreboard_x_offset", tooltip = "live_scoreboard_x_offset_tooltip",
                range = { -1000, 1000 } },
              { setting_id = "live_scoreboard_y_offset",   type = "numeric",  default_value = -455,
                title = "live_scoreboard_y_offset", tooltip = "live_scoreboard_y_offset_tooltip",
                range = { -1000, 1000 } },
              { setting_id = "live_scoreboard_bg_opacity", type = "numeric",  default_value = 0,
                title = "live_scoreboard_bg_opacity", tooltip = "live_scoreboard_bg_opacity_tooltip",
                range = { 0, 255 } },
          },
        },
        { setting_id = "boss_popup_header",     type = "group",
          title = "boss_popup_header", tooltip = "boss_popup_header_tooltip",
          sub_widgets = {
              { setting_id = "show_boss_popup",       type = "checkbox", default_value = true,
                title = "show_boss_popup", tooltip = "show_boss_popup_tooltip" },
              { setting_id = "show_boss_popup_damage", type = "checkbox", default_value = true,
                title = "show_boss_popup_damage", tooltip = "show_boss_popup_damage_tooltip" },
              { setting_id = "show_boss_popup_percent", type = "checkbox", default_value = true,
                title = "show_boss_popup_percent", tooltip = "show_boss_popup_percent_tooltip" },
              { setting_id = "show_boss_popup_total_damage", type = "checkbox", default_value = false,
                title = "show_boss_popup_total_damage", tooltip = "show_boss_popup_total_damage_tooltip" },
              { setting_id = "boss_popup_scale",      type = "numeric",  default_value = 70,
                title = "boss_popup_scale", tooltip = "boss_popup_scale_tooltip",
                range = { 50, 300 } },
              { setting_id = "boss_popup_duration",   type = "numeric",  default_value = 10,
                title = "boss_popup_duration", tooltip = "boss_popup_duration_tooltip",
                range = { 1, 15 } },
              { setting_id = "boss_popup_x_offset",   type = "numeric",  default_value = 0,
                title = "boss_popup_x_offset", tooltip = "boss_popup_x_offset_tooltip",
                range = { -500, 500 } },
              { setting_id = "boss_popup_y_offset",   type = "numeric",  default_value = -310,
                title = "boss_popup_y_offset", tooltip = "boss_popup_y_offset_tooltip",
                range = { -500, 500 } },
              { setting_id = "boss_popup_bg_opacity", type = "numeric",  default_value = 0,
                title = "boss_popup_bg_opacity", tooltip = "boss_popup_bg_opacity_tooltip",
                range = { 0, 255 } },
          },
        },
        { setting_id = "scoreboard_stats_header", type = "group",
          title = "scoreboard_stats_header", tooltip = "scoreboard_stats_header_tooltip",
          sub_widgets = {
              { setting_id = "scoreboard_stats_combat_header", type = "group",
                title = "scoreboard_stats_combat_header", tooltip = "scoreboard_stats_group_tooltip",
                sub_widgets = scoreboard_stat_widgets("combat") },
              { setting_id = "scoreboard_stats_survival_header", type = "group",
                title = "scoreboard_stats_survival_header", tooltip = "scoreboard_stats_group_tooltip",
                sub_widgets = scoreboard_stat_widgets("survival") },
          },
        },
    }},
}
