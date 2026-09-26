local function shifted(color, amount)
    return {
        math.max(0, math.min(color[1] + amount, 255)),
        math.max(0, math.min(color[2] + amount, 255)),
        math.max(0, math.min(color[3] + amount, 255)),
    }
end

local function argb(alpha, color)
    return { alpha, color[1], color[2], color[3] }
end

-- Live Stats and Boss Popup keep the original AnotherScoreboard palettes unchanged.
local function legacy_hud_colors(panel, section, accent)
    return {
        live = {
            bg = { 210, panel[1], panel[2], panel[3] },
            accent = { 220, accent[1], accent[2], accent[3] },
            title = { 255, accent[1], accent[2], accent[3] },
            header = { 255, 199, 208, 204 },
            text = { 255, 242, 244, 243 },
        },
        boss = {
            bg = { 210, panel[1], panel[2], panel[3] },
            accent = { 220, accent[1], accent[2], accent[3] },
            accent_soft = { 90, accent[1], accent[2], accent[3] },
            title = { 255, accent[1], accent[2], accent[3] },
            header = { 255, 199, 208, 204 },
            text = { 255, 242, 244, 243 },
            damage = { 255, 255, 215, 94 },
            section_bg = { 255, section[1], section[2], section[3] },
            footer_bg = { 255, section[1], section[2], section[3] },
            row_divider = { 90, accent[1], accent[2], accent[3] },
        },
    }
end

local function legacy_default_hud_colors()
    return {
        live = {
            bg = { 210, 18, 22, 18 },
            accent = { 220, 60, 78, 57 },
            title = { 255, 239, 193, 82 },
            header = { 255, 169, 191, 153 },
            text = { 255, 204, 204, 204 },
        },
        boss = {
            bg = { 210, 18, 22, 18 },
            accent = { 220, 60, 78, 57 },
            accent_soft = { 70, 60, 78, 57 },
            title = { 255, 239, 193, 82 },
            header = { 255, 169, 191, 153 },
            text = { 255, 204, 204, 204 },
            damage = { 255, 250, 189, 73 },
            section_bg = { 55, 49, 56, 49 },
            footer_bg = { 220, 40, 45, 40 },
            row_divider = { 35, 60, 78, 57 },
        },
    }
end

-- base: darkest surface, accent: signature color, text: primary text color.
local function theme(base, accent, hud, options)
    options = options or {}
    local text = options.text or { 232, 234, 238 }
    local text_sub = options.text_sub or { 158, 165, 176 }
    local text_dim = options.text_dim or { 118, 126, 139 }
    local best = options.best or { 104, 226, 148 }
    local worst = options.worst or { 255, 120, 112 }
    local line_alpha = options.line_alpha or 16

    local surface = shifted(base, 6)
    local raised = shifted(base, 13)
    local border = shifted(base, options.border_shift or 30)
    local hover = shifted(base, 22)
    local selected = shifted(base, 32)

    return {
        -- Text
        title = argb(255, text),
        normal = argb(255, text),
        sub = argb(255, text_sub),
        label = argb(255, text),
        label_sub = argb(255, text_sub),
        label_nested = argb(255, text_dim),
        text_dim = argb(255, text_dim),
        best = argb(255, best),
        worst = argb(255, worst),
        total = { 255, 255, 215, 94 },

        -- Surfaces
        panel = argb(242, base),
        panel_label = argb(255, surface),
        panel_total = argb(255, raised),
        title_bg = argb(250, surface),
        header_bg = argb(255, surface),
        section_bg = argb(255, raised),
        section_col = argb(255, surface),
        detail_bg = { 70, 0, 0, 0 },
        row_alt = { 9, 255, 255, 255 },
        border = argb(255, border),
        shadow = { 70, 0, 0, 0 },

        -- Accents
        accent = argb(255, accent),
        accent_soft = argb(70, accent),
        section = argb(255, accent),
        row_div = { line_alpha, 255, 255, 255 },
        best_bg = argb(34, best),
        worst_bg = argb(26, worst),
        lane_alpha = options.lane_alpha or 9,
        header_tint_alpha = options.header_tint_alpha or 26,

        -- Footer
        history_hint_text = argb(255, text_sub),
        history_footer = argb(250, surface),
        footer_key = argb(255, accent),

        history = {
            title = argb(255, accent),
            text = argb(255, text),
            sub = argb(255, text_sub),
            panel = argb(245, base),
            footer = argb(250, surface),
            entry = argb(255, surface),
            entry_hover = argb(255, hover),
            button = argb(255, raised),
            button_hover = argb(255, hover),
            button_selected = argb(255, selected),
            empty = argb(255, text_dim),
            won = argb(255, best),
            lost = argb(255, worst),
        },
        live = hud.live,
        boss = hud.boss,
    }
end

local order = {
    "default",
    "reject_olive",
    "inquisition_navy",
    "manufactorum_slate",
    "void_purple",
    "high_contrast_obsidian",
}

return {
    default = "default",
    order = order,
    by_id = {
        default = {
            label = "scoreboard_theme_default",
            colors = theme({ 13, 15, 19 }, { 226, 180, 98 }, legacy_default_hud_colors()),
        },
        reject_olive = {
            label = "scoreboard_theme_reject_olive",
            colors = theme({ 14, 18, 14 }, { 214, 196, 112 },
                legacy_hud_colors({ 21, 26, 22 }, { 32, 42, 33 }, { 217, 189, 99 }),
                { text = { 228, 234, 222 }, text_sub = { 160, 172, 152 }, text_dim = { 120, 134, 114 } }),
        },
        inquisition_navy = {
            label = "scoreboard_theme_inquisition_navy",
            colors = theme({ 10, 15, 24 }, { 116, 192, 246 },
                legacy_hud_colors({ 16, 24, 33 }, { 24, 39, 53 }, { 120, 197, 242 }),
                { text = { 228, 236, 245 }, text_sub = { 150, 168, 190 }, text_dim = { 110, 128, 152 } }),
        },
        manufactorum_slate = {
            label = "scoreboard_theme_manufactorum_slate",
            colors = theme({ 17, 18, 21 }, { 236, 146, 88 },
                legacy_hud_colors({ 23, 25, 29 }, { 40, 43, 49 }, { 228, 154, 104 })),
        },
        void_purple = {
            label = "scoreboard_theme_void_purple",
            colors = theme({ 15, 12, 23 }, { 194, 164, 250 },
                legacy_hud_colors({ 24, 21, 34 }, { 42, 34, 56 }, { 195, 167, 242 }),
                { text = { 236, 232, 246 }, text_sub = { 168, 158, 190 }, text_dim = { 128, 118, 152 } }),
        },
        high_contrast_obsidian = {
            label = "scoreboard_theme_high_contrast_obsidian",
            colors = theme({ 4, 4, 5 }, { 255, 215, 94 },
                legacy_hud_colors({ 9, 10, 11 }, { 23, 25, 27 }, { 255, 215, 94 }),
                {
                    text = { 255, 255, 255 }, text_sub = { 206, 210, 216 }, text_dim = { 170, 176, 186 },
                    best = { 96, 255, 140 }, worst = { 255, 104, 96 },
                    line_alpha = 34, border_shift = 48, lane_alpha = 14, header_tint_alpha = 40,
                }),
        },
    },
}
