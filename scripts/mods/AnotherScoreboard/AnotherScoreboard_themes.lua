local function shifted(color, amount)
    return {
        math.min(color[1] + amount, 255),
        math.min(color[2] + amount, 255),
        math.min(color[3] + amount, 255),
    }
end

local function theme(panel, section, accent)
    local hover = shifted(section, 18)
    local selected = shifted(section, 30)

    return {
        title = { 255, accent[1], accent[2], accent[3] },
        best = { 255, 114, 224, 122 },
        worst = { 255, 255, 143, 143 },
        normal = { 255, 242, 244, 243 },
        sub = { 255, 199, 208, 204 },
        label = { 255, 242, 244, 243 },
        label_sub = { 255, 199, 208, 204 },
        label_nested = { 255, 184, 197, 202 },
        section = { 255, accent[1], accent[2], accent[3] },
        section_bg = { 255, section[1], section[2], section[3] },
        section_col = { 255, section[1], section[2], section[3] },
        row_alt = { 48, section[1], section[2], section[3] },
        panel = { 255, panel[1], panel[2], panel[3] },
        panel_label = { 255, panel[1], panel[2], panel[3] },
        shadow = { 230, 5, 5, 5 },
        accent = { 255, accent[1], accent[2], accent[3] },
        row_div = { 90, accent[1], accent[2], accent[3] },
        total = { 255, 255, 215, 94 },
        panel_total = { 255, section[1], section[2], section[3] },
        history_hint_text = { 255, 242, 244, 243 },
        history_footer = { 255, panel[1], panel[2], panel[3] },
        history = {
            title = { 255, accent[1], accent[2], accent[3] },
            text = { 255, 242, 244, 243 },
            sub = { 255, 199, 208, 204 },
            panel = { 255, panel[1], panel[2], panel[3] },
            footer = { 255, panel[1], panel[2], panel[3] },
            entry = { 255, section[1], section[2], section[3] },
            entry_hover = { 220, hover[1], hover[2], hover[3] },
            button = { 255, section[1], section[2], section[3] },
            button_hover = { 255, hover[1], hover[2], hover[3] },
            button_selected = { 255, selected[1], selected[2], selected[3] },
            empty = { 255, 199, 208, 204 },
            won = { 255, 114, 224, 122 },
            lost = { 255, 255, 143, 143 },
        },
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

local function default_theme()
    return {
        title = { 255, 239, 193, 82 },
        best = { 255, 74, 199, 60 },
        worst = { 255, 88, 99, 80 },
        normal = { 255, 204, 204, 204 },
        sub = { 255, 152, 152, 152 },
        label = { 255, 216, 229, 207 },
        label_sub = { 255, 169, 191, 153 },
        label_nested = { 255, 151, 174, 182 },
        section = { 255, 239, 193, 82 },
        section_bg = { 60, 49, 56, 49 },
        section_col = { 40, 35, 40, 35 },
        row_alt = { 48, 49, 56, 49 },
        panel = { 220, 30, 35, 30 },
        panel_label = { 240, 12, 15, 12 },
        shadow = { 200, 5, 5, 5 },
        accent = { 255, 60, 78, 57 },
        row_div = { 40, 60, 78, 57 },
        total = { 255, 250, 189, 73 },
        panel_total = { 220, 40, 45, 40 },
        history_hint_text = { 255, 216, 229, 207 },
        history_footer = { 220, 18, 20, 18 },
        history = {
            title = { 255, 239, 193, 82 },
            text = { 255, 216, 229, 207 },
            sub = { 255, 169, 191, 153 },
            panel = { 230, 30, 35, 30 },
            footer = { 220, 18, 20, 18 },
            entry = { 180, 35, 40, 35 },
            entry_hover = { 220, 49, 56, 49 },
            button = { 220, 54, 62, 54 },
            button_hover = { 255, 76, 88, 76 },
            button_selected = { 255, 104, 78, 32 },
            empty = { 255, 152, 152, 152 },
            won = { 255, 74, 199, 60 },
            lost = { 255, 220, 80, 70 },
        },
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
            colors = default_theme(),
        },
        reject_olive = {
            label = "scoreboard_theme_reject_olive",
            colors = theme({ 21, 26, 22 }, { 32, 42, 33 }, { 217, 189, 99 }),
        },
        inquisition_navy = {
            label = "scoreboard_theme_inquisition_navy",
            colors = theme({ 16, 24, 33 }, { 24, 39, 53 }, { 120, 197, 242 }),
        },
        manufactorum_slate = {
            label = "scoreboard_theme_manufactorum_slate",
            colors = theme({ 23, 25, 29 }, { 40, 43, 49 }, { 228, 154, 104 }),
        },
        void_purple = {
            label = "scoreboard_theme_void_purple",
            colors = theme({ 24, 21, 34 }, { 42, 34, 56 }, { 195, 167, 242 }),
        },
        high_contrast_obsidian = {
            label = "scoreboard_theme_high_contrast_obsidian",
            colors = theme({ 9, 10, 11 }, { 23, 25, 27 }, { 255, 215, 94 }),
        },
    },
}
