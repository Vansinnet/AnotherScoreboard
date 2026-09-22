local mod = get_mod("AnotherScoreboard")
local MasterItems = mod:original_require("scripts/backend/master_items")

local Icons = {}

local function clear(entry)
    entry.style.color[1] = 0
    entry.style.material_values.use_placeholder_texture = 1
    entry.style.material_values.texture_icon = nil
    entry.widget.dirty = true
end

function Icons.load(widget, requests)
    if not requests or #requests == 0 then return nil end

    local ui = Managers.ui
    local backend = Managers.backend
    local definitions = backend and backend.interfaces and backend.interfaces.master_data and MasterItems.get_cached()
    if not ui or not definitions then return nil end

    local owner = { ui = ui, entries = {}, active = true }
    for _, request in ipairs(requests) do
        local item = definitions[request.master_item_name]
        if item and (item.item_type == "WEAPON_MELEE" or item.item_type == "WEAPON_RANGED") then
            local entry = { widget = widget, style = widget.style[request.style_id] }
            owner.entries[#owner.entries + 1] = entry
            local function loaded(grid_index, rows, columns, render_target)
                if not owner.active then return end
                local values = entry.style.material_values
                values.use_placeholder_texture = 0
                values.rows = rows
                values.columns = columns
                values.grid_index = grid_index - 1
                values.texture_icon = render_target
                entry.style.color[1] = 255
                widget.dirty = true
            end
            local function unloaded()
                if owner.active then clear(entry) end
            end
            -- Cached icons can invoke loaded before load_item_icon returns.
            entry.id = ui:load_item_icon(item, loaded, {
                camera_focus_slot_name = request.slot,
                size = request.size,
            }, nil, nil, unloaded)
        end
    end
    return owner
end

function Icons.destroy(owner)
    if not owner or not owner.active then return end
    owner.active = false
    for _, entry in ipairs(owner.entries) do
        clear(entry)
        if entry.id then
            owner.ui:unload_item_icon(entry.id)
            entry.id = nil
        end
    end
    owner.entries = {}
    owner.ui = nil
end

return Icons
