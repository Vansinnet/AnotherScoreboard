local mod = get_mod("AnotherScoreboard")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local Archetypes = mod:original_require("scripts/settings/archetype/archetypes")
local Parser = mod:original_require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
local Settings = mod:original_require("scripts/ui/views/talent_builder_view/talent_builder_view_settings")
local Definitions = mod:original_require("scripts/ui/views/talent_builder_view/talent_builder_view_definitions")
local Colors = mod:original_require("scripts/utilities/ui/colors")

local Tree = {}
Tree.__index = Tree
-- Must match the tree frame in AnotherScoreboard_loadout_render (panel content area).
local X, Y, W, H = -86, 168, 1072, 639
local serial = 0

-- Snapshot IDs are evidence of selection only when the entire layout contract matches.
function Tree.resolve(snapshot)
    local archetype = snapshot and Archetypes[snapshot.archetype]
    if not archetype or type(snapshot.layouts) ~= "table" or #snapshot.layouts == 0 then
        return nil, mod:localize("loadout_tree_missing")
    end
    local current, result, seen = Parser.archetype_layouts(archetype), {}, {}
    if #current ~= #snapshot.layouts then return nil, mod:localize("loadout_tree_changed") end
    for _, saved in ipairs(snapshot.layouts) do
        local layout
        for _, candidate in ipairs(current) do
            if candidate.name == saved.name then layout = candidate break end
        end
        if not layout or seen[saved.name] or layout.version ~= saved.version then
            return nil, mod:localize("loadout_tree_changed")
        end
        seen[saved.name] = true
        if type(saved.nodes) ~= "table" then return nil, mod:localize("loadout_tree_missing") end
        local by_id, selected = {}, {}
        for _, node in ipairs(layout.nodes) do by_id[node.widget_name] = node end
        for _, record in ipairs(saved.nodes) do
            local node = by_id[record.id]
            local tier = record.tier
            if not node or selected[record.id] or node.talent ~= record.talent_id
                or type(tier) ~= "number" or tier <= 0 or tier % 1 ~= 0 or tier > (node.max_points or 1)
                or node.cost ~= record.cost or node.type ~= record.type then
                return nil, mod:localize("loadout_tree_changed")
            end
            selected[record.id] = record
        end
        result[#result + 1] = { layout = layout, selected = selected }
    end
    return result, nil, archetype
end

local function widget(definition, name, size)
    local result = UIWidget.init(name, definition)
    result.scenegraph_id = "content_area"
    result.content.size = size
    return result
end

local function node_definition(definition)
    local copy = table.clone(definition)
    for _, pass in ipairs(copy.passes) do
        if pass.pass_type == "texture" then
            pass.pass_type = "texture_uv"
            copy.style[pass.style_id].uvs = { { 0, 0 }, { 1, 1 } }
        end
    end
    return copy
end

local function clip_node(entry, tree)
    local w = entry.widget
    for _, pass in ipairs(w.passes) do
        if pass.pass_type == "texture_uv" then
            local original = entry.styles[pass.style_id]
            local change, visibility = pass.change_function, pass.visibility_function
            local size, offset, addition = {}, {}, {}
            local clipped_size, clipped_offset, uvs = {}, {}, { {}, {} }
            local function restore(style)
                for axis = 1, 2 do
                    size[axis] = (original.size and original.size[axis] or entry.config.size[axis]) * tree.zoom
                    offset[axis] = (original.offset and original.offset[axis] or 0) * tree.zoom
                    addition[axis] = (original.size_addition and original.size_addition[axis] or 0) * tree.zoom
                end
                offset[3] = original.offset and original.offset[3] or 0
                style.size, style.offset, style.size_addition = size, offset, addition
                style.horizontal_alignment = original.horizontal_alignment
                style.vertical_alignment = original.vertical_alignment
                style.uvs = original.uvs
            end
            pass.visibility_function = function(content, style)
                restore(style)
                return not visibility or visibility(content, style)
            end
            pass.change_function = function(content, style, animations, dt)
                restore(style)
                if change then change(content, style, animations, dt) end
                local width = style.size[1] + style.size_addition[1]
                local height = style.size[2] + style.size_addition[2]
                local x, y = w.offset[1] + style.offset[1], w.offset[2] + style.offset[2]
                if style.horizontal_alignment == "center" then x = x + (w.content.size[1] - width) / 2
                elseif style.horizontal_alignment == "right" then x = x + w.content.size[1] - width end
                if style.vertical_alignment == "center" then y = y + (w.content.size[2] - height) / 2
                elseif style.vertical_alignment == "bottom" then y = y + w.content.size[2] - height end
                local left, top = math.max(X, x), math.max(Y, y)
                local right, bottom = math.min(X + W, x + width), math.min(Y + H, y + height)
                clipped_size[1], clipped_size[2] = math.max(0, right - left), math.max(0, bottom - top)
                clipped_offset[1], clipped_offset[2], clipped_offset[3] = left - w.offset[1], top - w.offset[2], style.offset[3]
                -- Crop in top-left UI coordinates, as in the native player-assistance texture_uv fill.
                local source_uvs = style.uvs
                local u, v = source_uvs[1][1], source_uvs[1][2]
                local du, dv = source_uvs[2][1] - u, source_uvs[2][2] - v
                uvs[1][1] = u + du * math.clamp((left - x) / width, 0, 1)
                uvs[1][2] = v + dv * math.clamp((top - y) / height, 0, 1)
                uvs[2][1] = u + du * math.clamp((right - x) / width, 0, 1)
                uvs[2][2] = v + dv * math.clamp((bottom - y) / height, 0, 1)
                style.size, style.offset, style.uvs = clipped_size, clipped_offset, uvs
                style.size_addition = nil
                style.horizontal_alignment, style.vertical_alignment = "left", "top"
            end
        end
    end
end

local function clip_line(ax, ay, bx, by, inset)
    local dx, dy, first, last = bx - ax, by - ay, 0, 1
    local function boundary(p, q)
        if p == 0 then return q >= 0 end
        local ratio = q / p
        if p < 0 then first = math.max(first, ratio)
        else last = math.min(last, ratio) end
        return first <= last
    end
    if not boundary(-dx, ax - X - inset) or not boundary(dx, X + W - inset - ax)
        or not boundary(-dy, ay - Y - inset) or not boundary(dy, Y + H - inset - ay)
        or first == last or dx == 0 and dy == 0 then return nil end
    return ax + first * dx, ay + first * dy, ax + last * dx, ay + last * dy
end

function Tree.new(host, snapshot)
    local layouts, reason, archetype = Tree.resolve(snapshot)
    if not layouts then return nil, reason end
    serial = serial + 1
    local self = setmetatable({ host = host, archetype = archetype, nodes = {}, edges = {},
        widgets = {}, pan_x = 0, pan_y = 0, name = "as_talent_tree_" .. serial }, Tree)
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    local lane_x = 0
    for _, group in ipairs(layouts) do
        local by_id, linked = {}, {}
        local lane_min, lane_max = math.huge, -math.huge
        for _, node in ipairs(group.layout.nodes) do
            lane_min, lane_max = math.min(lane_min, node.x), math.max(lane_max, node.x)
        end
        for _, source in ipairs(group.layout.nodes) do
            local node = table.clone(source)
            local config = Settings.settings_by_node_type[node.type] or Settings.settings_by_node_type.default
            local size = config.size
            local w = widget(node_definition(config.node_definition), self.name .. "_" .. #self.nodes, { size[1], size[2] })
            local selected = group.selected[node.widget_name]
            w.content.node_data = node
            w.content.player_mode = true
            w.content.has_points_spent = selected ~= nil
            w.content.highlighted = selected ~= nil
            w.content.alpha_anim_progress = selected and 1 or 0
            w.content.locked = selected == nil and node.type ~= "start"
            if w.style.icon and w.style.icon.material_values then
                w.style.icon.material_values.gradient_map = config.gradient_map
            end
            local glow = Settings.archetype_glow_colors[snapshot.archetype]
            if glow and w.style.frame_selected then
                w.style.frame_selected.material_values.fill_color = Colors.format_color_to_material(glow.line_chosen.fill_color)
                w.style.frame_selected.material_values.blur_color = Colors.format_color_to_material(glow.line_chosen.blur_color)
            end
            local entry = { node = node, widget = w, selected = selected, config = config,
                styles = table.clone(w.style), x = lane_x + node.x - lane_min, y = node.y }
            clip_node(entry, self)
            self.nodes[#self.nodes + 1] = entry
            self.widgets[#self.widgets + 1] = w
            by_id[node.widget_name] = entry
            min_x, max_x = math.min(min_x, entry.x), math.max(max_x, entry.x + size[1])
            min_y, max_y = math.min(min_y, entry.y), math.max(max_y, entry.y + size[2])
        end
        for _, entry in pairs(by_id) do
            for _, id in ipairs(entry.node.children or {}) do
                local child = by_id[id]
                if child then
                    local a, b = entry.node.widget_name, id
                    local key = a < b and a .. b or b .. a
                    if not linked[key] then
                        linked[key] = true
                        self.edges[#self.edges + 1] = { entry, child }
                    end
                end
            end
        end
        lane_x = lane_x + lane_max - lane_min + 300
    end
    if #self.nodes == 0 then return nil, mod:localize("loadout_tree_missing") end
    self.center_x, self.center_y = (min_x + max_x) / 2, (min_y + max_y) / 2
    self.width, self.height = max_x - min_x + 160, max_y - min_y + 160
    self.fit = math.min((W - 32) / self.width, (H - 32) / self.height)
    self.zoom = self.fit
    self.connection = widget(Definitions.node_connection_definition, self.name .. "_connection", { 0, 0 })
    self.widgets[#self.widgets + 1] = self.connection
    local glow = Settings.archetype_glow_colors[snapshot.archetype]
    if glow then
        self.connection.style.line.material_values.fill_color = Colors.format_color_to_material(glow.line_chosen.fill_color)
        self.connection.style.line.material_values.blur_color = Colors.format_color_to_material(glow.line_chosen.blur_color)
    end
    self.tooltip = widget(Definitions.widget_definitions.tooltip, self.name .. "_tooltip", { 420, 440 })
    self.widgets[#self.widgets + 1] = self.tooltip
    for _, pass in ipairs(self.tooltip.passes) do
        if pass.pass_type == "text" then self.tooltip.content[pass.value_id] = "" end
    end
    self.renderer = host._ui_renderer
    self:_position()
    return self
end

function Tree:_position()
    local zoom = self.zoom
    self.pan_x = math.clamp(self.pan_x, -math.max(0, (self.width * zoom - W) / 2), math.max(0, (self.width * zoom - W) / 2))
    self.pan_y = math.clamp(self.pan_y, -math.max(0, (self.height * zoom - H) / 2), math.max(0, (self.height * zoom - H) / 2))
    for _, entry in ipairs(self.nodes) do
        local w = entry.widget
        w.offset[1] = X + W / 2 + (entry.x - self.center_x) * zoom + self.pan_x
        w.offset[2] = Y + H / 2 + (entry.y - self.center_y) * zoom + self.pan_y
        w.offset[3] = 120
        w.content.size[1], w.content.size[2] = entry.config.size[1] * zoom, entry.config.size[2] * zoom
        for key, original in pairs(entry.styles) do
            local style = w.style[key]
            for _, field in ipairs({ "size", "size_addition", "offset", "pivot" }) do
                if original[field] then
                    style[field] = style[field] or {}
                    for axis = 1, 2 do
                        if original[field][axis] then style[field][axis] = original[field][axis] * zoom end
                    end
                end
            end
        end
    end
end

function Tree:update(input)
    if not input or input:is_null_service() or self.host._input_disabled then
        self.drag_x, self.hovered, self.inside, self.over_tooltip = nil, nil, false, false
        return
    end
    local cursor = input:get("cursor")
    if not cursor then
        self.drag_x, self.hovered, self.inside, self.over_tooltip = nil, nil, false, false
        return
    end
    local scale = self.host._render_scale or 1
    local origin = self.host:_scenegraph_world_position("content_area", scale)
    local x, y = (cursor[1] - origin[1]) / scale, (cursor[2] - origin[2]) / scale
    self.inside = x >= X and x <= X + W and y >= Y and y <= Y + H
    local tip = self.tooltip
    self.over_tooltip = self.hovered ~= nil and x >= tip.offset[1] and x <= tip.offset[1] + tip.content.size[1]
        and y >= tip.offset[2] and y <= tip.offset[2] + tip.content.size[2]
    if self.inside and not self.over_tooltip and input:get("left_pressed") then self.drag_x, self.drag_y = x, y end
    local moved = false
    if self.drag_x then
        if input:get("left_hold") and self.inside then
            self.pan_x, self.pan_y = self.pan_x + x - self.drag_x, self.pan_y + y - self.drag_y
            moved = x ~= self.drag_x or y ~= self.drag_y
            self.drag_x, self.drag_y = x, y
        else
            self.drag_x = nil
        end
    end
    local axis = input:get("scroll_axis")
    local scroll = axis and axis[2] or 0
    if self.over_tooltip and scroll ~= 0 and self.pages then
        self.page = math.clamp(self.page + (scroll > 0 and -1 or 1), 1, #self.pages)
        self.tooltip.content.description = self.pages[self.page]
        self.tooltip.content.input_text = string.format("%d / %d  %s", self.page, #self.pages,
            mod:localize("loadout_hover_scroll"))
    elseif self.inside and scroll ~= 0 then
        local old = self.zoom
        self.zoom = math.clamp(old * (scroll > 0 and 1.15 or 1 / 1.15), self.fit, math.max(1, self.fit * 4))
        local ratio = self.zoom / old
        self.pan_x = (self.pan_x - (x - X - W / 2)) * ratio + x - X - W / 2
        self.pan_y = (self.pan_y - (y - Y - H / 2)) * ratio + y - Y - H / 2
        moved = true
    end
    if moved then self:_position() end
    if not self.inside or moved or self.drag_x then self.hovered, self.over_tooltip = nil, false end
end

function Tree:_tooltip(entry)
    local w = self.tooltip
    if self.tooltip_entry == entry then return end
    self.tooltip_entry = entry
    local node, saved = entry.node, entry.selected
    local definition = self.archetype.talents[node.talent]
    local points = math.max(1, saved and saved.points_spent or node.cost or 1)
    w.content.title = saved and saved.name or definition and Parser.talent_title(definition, points) or node.talent or "-"
    w.content.description = saved and saved.description or definition and definition.description
        and Parser.talent_description(definition, points) or mod:localize("loadout_no_description")
    w.content.talent_type_title = entry.config.display_name and Localize(entry.config.display_name) or ""
    w.content.level_counter = string.format("%d / %d", saved and saved.tier or 0, node.max_points or 1)
    local y = 16
    for _, key in ipairs({ "talent_type_title", "title" }) do
        local style = w.style[key]
        style.font_size = key == "title" and 24 or 16
        local _, height = self.host:_text_size(w.content[key], style, { 380, 100000 }, true)
        style.size[2], style.offset[2] = height + 6, y
        y = y + height + 14
    end
    w.style.level_counter.size[2], w.style.level_counter.offset[2] = 24, 16
    local style = w.style.description
    style.font_size = 18
    style.offset[2], style.size[2] = y, math.max(60, H - 100 - y)
    local remaining = w.content.description:gsub("{#[^}]*}", "")
    self.pages, self.page = {}, 1
    while remaining ~= "" do
        local low, high, best = 1, Utf8.string_length(remaining), 1
        while low <= high do
            local middle = math.floor((low + high) / 2)
            local _, height = self.host:_text_size(Utf8.sub_string(remaining, 1, middle), style, { 380, 100000 }, true)
            if height <= style.size[2] - 6 then best, low = middle, middle + 1 else high = middle - 1 end
        end
        self.pages[#self.pages + 1] = Utf8.sub_string(remaining, 1, best)
        remaining = Utf8.sub_string(remaining, best + 1)
    end
    if #self.pages == 0 then self.pages[1] = "" end
    w.content.description = self.pages[1]
    w.content.input_text = #self.pages > 1 and string.format("1 / %d  %s", #self.pages, mod:localize("loadout_hover_scroll")) or ""
    w.style.input_text.size[2], w.style.input_text.offset[2] = 30, H - 72
    w.style.input_text.text_color = w.style.title.text_color
    w.content.size[2] = H - 24
end

function Tree:draw(dt, input, layer)
    local host, renderer = self.host, self.renderer
    local enabled = input and not input:is_null_service() and not host._input_disabled
    if input and not enabled then input = input:null_service() end
    local scale = host._render_scale or 1
    local settings = { scale = scale, inverse_scale = 1 / scale, start_layer = layer,
        alpha_multiplier = host._alpha_multiplier or 1 }
    UIRenderer.begin_pass(renderer, host._ui_scenegraph, input, dt, settings)
    local line, zoom = self.connection, self.zoom
    for _, edge in ipairs(self.edges) do
        local a, b = edge[1], edge[2]
        local ao, bo = a.node.connector_offset or { 0, 0 }, b.node.connector_offset or { 0, 0 }
        local ax = a.widget.offset[1] + (a.config.size[1] / 2 + ao[1]) * zoom
        local ay = a.widget.offset[2] + (a.config.size[2] / 2 + ao[2]) * zoom
        local bx = b.widget.offset[1] + (b.config.size[1] / 2 + bo[1]) * zoom
        local by = b.widget.offset[2] + (b.config.size[2] / 2 + bo[2]) * zoom
        ax, ay, bx, by = clip_line(ax, ay, bx, by, 9 * zoom)
        if ax then
            ---@cast ay number
            ---@cast bx number
            ---@cast by number
            local distance = math.sqrt((bx - ax)^2 + (by - ay)^2)
            line.offset[1], line.offset[2], line.offset[3] = ax, ay, 105
            line.content.has_progressed = (a.selected ~= nil or a.node.type == "start") and b.selected ~= nil
            for key, style in pairs(line.style) do
                local thickness = Definitions.node_connection_definition.style[key].size[2] * zoom
                style.size[1], style.size[2] = distance, thickness
                style.pivot[1], style.pivot[2] = 0, thickness / 2
                style.offset[1], style.offset[2] = 0, 0
                style.angle = math.pi - math.angle(bx, by, ax, ay)
            end
            UIWidget.draw(line, renderer)
        end
    end
    local hovered = enabled and self.over_tooltip and self.hovered or nil
    for _, entry in ipairs(self.nodes) do
        local w = entry.widget
        local hotspot = w.content.hotspot
        if hotspot then hotspot.force_disabled = not enabled or not self.inside or self.over_tooltip or self.drag_x ~= nil end
        UIWidget.draw(w, renderer)
        if hotspot and not hotspot.force_disabled and hotspot.is_hover then hovered = entry end
    end
    self.hovered = hovered
    if hovered then
        self:_tooltip(hovered)
        local tip = self.tooltip
        tip.offset[1] = hovered.widget.offset[1] > X + W / 2 and X + 12 or X + W - 432
        tip.offset[2], tip.offset[3] = Y + 12, 180
        UIWidget.draw(tip, renderer)
    end
    UIRenderer.end_pass(renderer)
end

function Tree:destroy()
    for _, w in ipairs(self.widgets) do
        UIWidget.destroy(self.renderer, w)
    end
    self.widgets, self.nodes, self.edges = {}, {}, {}
    self.host, self.renderer, self.hovered, self.drag_x, self.tooltip_entry = nil, nil, nil, nil, nil
    self.connection, self.tooltip, self.pages = nil, nil, nil
end

return Tree
