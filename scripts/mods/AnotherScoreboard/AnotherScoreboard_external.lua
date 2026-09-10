---@class ASExternalGroupDefinition
---@field id string Provider-local identifier: letters, digits, underscore or hyphen.
---@field label string Resolved display text, stored in history.
---@field placement? 'survivability'|'combat_utility'|'survival_utility'|'own'
---@field collapsible? boolean Default true.
---@field collapsed_by_default? boolean Default true when collapsible.
---@class ASExternalStatDefinition
---@field id string
---@field label string
---@field group string Returned group key belonging to the same provider.
---@field value_type? 'number'|'text'
---@field accumulation? 'add'|'set'
---@field ranking? 'higher_better'|'lower_better'|'none'
---@field decimals? integer 0..6, default 0.
---@field suffix? string

local External = { revision = 0, details_expanded = false }
local providers, groups, stats, pending = {}, {}, {}, {}
local ranked_accounts
local placements = { survivability = "survival", combat_utility = "combat", survival_utility = "survival" }

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function text(value, max_length)
    return type(value) == "string" and #value > 0 and #value <= max_length and not value:find("[%c]")
end

local function identifier(value)
    return text(value, 128) and value:match("^[%w_%-]+$") ~= nil
end

local function text_value(value)
    return type(value) == "string" and #value <= 512 and not value:find("[%c]")
end

local function namespace(name)
    return (name:gsub("[^%w_%-]", function(char) return string.format("%%%02X", string.byte(char)) end))
end

local function changed()
    External.revision = External.revision + 1
end

local function owner_name(owner)
    if type(owner) ~= "table" or type(owner.get_name) ~= "function" or type(owner.is_enabled) ~= "function" then
        return nil, "invalid_owner"
    end
    local ok, name = pcall(owner.get_name, owner)
    if not ok or not text(name, 256) or get_mod(name) ~= owner then return nil, "invalid_owner" end
    return name
end

local function enabled(provider)
    if get_mod(provider.name) ~= provider.owner then return false end
    local ok, result = pcall(provider.owner.is_enabled, provider.owner)
    return ok and result == true
end

local function provider_for(owner)
    local name, err = owner_name(owner)
    if not name then return nil, err end
    local provider = providers[name]
    if provider and provider.owner ~= owner then return nil, "owner_conflict" end
    if not provider then
        provider = { name = name, namespace = namespace(name), owner = owner }
        providers[name] = provider
    end
    return provider
end

local function fields_valid(definition, allowed)
    if type(definition) ~= "table" then return false end
    for key in pairs(definition) do
        if not allowed[key] then return false end
    end
    return identifier(definition.id) and text(definition.label, 256)
end

local group_fields = { id = true, label = true, placement = true, collapsible = true, collapsed_by_default = true }
local stat_fields = { id = true, label = true, group = true, value_type = true, accumulation = true,
    ranking = true, decimals = true, suffix = true }

local function same(a, b)
    for key, value in pairs(a) do if b[key] ~= value then return false end end
    for key, value in pairs(b) do if a[key] ~= value then return false end end
    return true
end

function External.register_group(owner, definition)
    if not fields_valid(definition, group_fields) then return nil, "invalid_definition" end
    if definition.placement ~= nil and type(definition.placement) ~= "string" then return nil, "invalid_placement" end
    local placement = definition.placement or "own"
    if placement ~= "own" and not placements[placement] then return nil, "invalid_placement" end
    for _, key in ipairs({ "collapsible", "collapsed_by_default" }) do
        if definition[key] ~= nil and type(definition[key]) ~= "boolean" then return nil, "invalid_definition" end
    end
    local collapsible = definition.collapsible ~= false
    if not collapsible and definition.collapsed_by_default == true then return nil, "invalid_definition" end
    local provider, err = provider_for(owner)
    if not provider then return nil, err end
    local key = "external:" .. provider.namespace .. ":group:" .. definition.id
    local def = { id = key, label_text = definition.label, placement = placement, collapsible = collapsible,
        collapsed_by_default = collapsible and definition.collapsed_by_default ~= false }
    if groups[key] then
        if not same(groups[key].definition, def) then return nil, "definition_conflict" end
        return key
    end
    groups[key] = { provider = provider, definition = def }
    changed()
    return key
end

function External.register_stat(owner, definition)
    if not fields_valid(definition, stat_fields) then return nil, "invalid_definition" end
    for _, field in ipairs({ "value_type", "accumulation", "ranking", "suffix" }) do
        if definition[field] ~= nil and type(definition[field]) ~= "string" then return nil, "invalid_definition" end
    end
    if definition.decimals ~= nil and type(definition.decimals) ~= "number" then return nil, "invalid_format" end
    local value_type = definition.value_type or "number"
    local accumulation = definition.accumulation or "set"
    local ranking = definition.ranking or "none"
    local decimals = definition.decimals or 0
    local suffix = definition.suffix or ""
    if value_type ~= "number" and value_type ~= "text" then return nil, "invalid_value_type" end
    if accumulation ~= "add" and accumulation ~= "set" then return nil, "invalid_accumulation" end
    if ranking ~= "none" and ranking ~= "higher_better" and ranking ~= "lower_better" then return nil, "invalid_ranking" end
    if not finite(decimals) or decimals < 0 or decimals > 6 or decimals % 1 ~= 0
        or type(suffix) ~= "string" or #suffix > 32 or suffix:find("[%c]") then return nil, "invalid_format" end
    if value_type == "text" and (accumulation ~= "set" or ranking ~= "none" or decimals ~= 0 or suffix ~= "") then
        return nil, "invalid_format"
    end
    local provider, err = provider_for(owner)
    if not provider then return nil, err end
    local group = type(definition.group) == "string" and groups[definition.group]
    if not group or group.provider ~= provider then return nil, "invalid_group" end
    local key = "external:" .. provider.namespace .. ":stat:" .. definition.id
    local def = { id = key, label_text = definition.label, group = definition.group, value_type = value_type,
        accumulation = accumulation, ranking = ranking, decimals = decimals, suffix = suffix }
    if stats[key] then
        if not same(stats[key].definition, def) then return nil, "definition_conflict" end
        return key
    end
    local values = {}
    local saved = pending[key]
    if saved and saved.value_type == value_type then values = copy(saved.values) end
    pending[key] = nil
    stats[key] = { provider = provider, definition = def, values = values }
    changed()
    return key
end

function External.update(key, player_id, value)
    local stat = type(key) == "string" and stats[key]
    if not stat then return nil, "unknown_stat" end
    if not enabled(stat.provider) then return nil, "provider_disabled" end
    if not text(player_id, 256) then return nil, "invalid_player_id" end
    local def = stat.definition
    if def.value_type == "number" then
        if not finite(value) then return nil, "invalid_value" end
        if def.accumulation == "add" then value = (stat.values[player_id] or 0) + value end
        if not finite(value) then return nil, "invalid_value" end
    elseif not text_value(value) then
        return nil, "invalid_value"
    end
    if stat.values[player_id] ~= value then
        stat.values[player_id] = value
        changed()
    end
    return true
end

function External.get(key, player_id)
    local stat = type(key) == "string" and stats[key]
    if not stat then return nil, "unknown_stat" end
    if player_id == nil then return copy(stat.values) end
    if not text(player_id, 256) then return nil, "invalid_player_id" end
    return stat.values[player_id]
end

function External.set_collector(owner, callback)
    if callback ~= nil and type(callback) ~= "function" then return nil, "invalid_collector" end
    local provider, err = provider_for(owner)
    if not provider then return nil, err end
    provider.collector = callback
    return true
end

local collecting = false
function External.collect(api)
    if collecting then return { api = "collection_in_progress" } end
    collecting = true
    local errors, list = {}, {}
    for _, provider in pairs(providers) do list[#list + 1] = provider end
    table.sort(list, function(a, b) return a.name < b.name end)
    for _, provider in ipairs(list) do
        if providers[provider.name] == provider and provider.collector and enabled(provider) then
            local ok, err = pcall(provider.collector, provider.owner, api)
            if not ok then errors[provider.name] = type(err) == "string" and err or "collector raised a non-string error" end
        end
    end
    collecting = false
    return errors
end

function External.unregister(owner)
    local name, err = owner_name(owner)
    if not name then return nil, err end
    local provider = providers[name]
    if provider and provider.owner ~= owner then return nil, "owner_conflict" end
    for key, stat in pairs(stats) do
        if stat.provider == provider then stats[key] = nil end
    end
    for key, group in pairs(groups) do
        if group.provider == provider then groups[key] = nil end
    end
    local prefix = "external:" .. namespace(name) .. ":stat:"
    for key in pairs(pending) do if key:sub(1, #prefix) == prefix then pending[key] = nil end end
    providers[name] = nil
    changed()
    return true
end

function External.reset()
    External.details_expanded = false
    ranked_accounts = nil
    pending = {}
    for _, stat in pairs(stats) do stat.values = {} end
    changed()
end

function External.has_data()
    for _, saved in pairs(pending) do if next(saved.values) then return true end end
    for _, stat in pairs(stats) do if next(stat.values) then return true end end
    return false
end

function External.export()
    local result = copy(pending)
    for key, stat in pairs(stats) do
        result[key] = { value_type = stat.definition.value_type, values = copy(stat.values) }
    end
    return { version = 1, stats = result }
end

function External.validate_snapshot(snapshot)
    if snapshot == nil then return true end
    if type(snapshot) ~= "table" or snapshot.version ~= 1 or type(snapshot.stats) ~= "table" then return false end
    for key, stat in pairs(snapshot.stats) do
        local encoded, id
        if type(key) == "string" then encoded, id = key:match("^external:([^:]+):stat:([%w_%-]+)$") end
        if not encoded or not identifier(id) then return false end
        local name = encoded:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
        if not text(name, 256) or namespace(name) ~= encoded
            or type(stat) ~= "table" or type(stat.values) ~= "table"
            or (stat.value_type ~= "number" and stat.value_type ~= "text") then return false end
        for aid, value in pairs(stat.values) do
            if not text(aid, 256) or (stat.value_type == "number" and not finite(value))
                or (stat.value_type == "text" and not text_value(value)) then return false end
        end
    end
    return true
end

function External.restore(snapshot)
    if not External.validate_snapshot(snapshot) then return false end
    External.reset()
    pending = snapshot and copy(snapshot.stats) or {}
    for key, stat in pairs(stats) do
        local saved = pending[key]
        if saved and saved.value_type == stat.definition.value_type then stat.values = copy(saved.values) end
        pending[key] = nil
    end
    return true
end

function External.validate(accounts)
    ranked_accounts = accounts
end

local function ranked_values(stat)
    local values, low, high = {}, nil, nil
    local def = stat.definition
    for aid, value in pairs(stat.values) do
        values[aid] = { score = value, best = false, worst = false }
        if def.ranking ~= "none" and (not ranked_accounts or ranked_accounts[aid]) then
            low = low and math.min(low, value) or value
            high = high and math.max(high, value) or value
        end
    end
    if low ~= high then
        for aid, entry in pairs(values) do
            if not ranked_accounts or ranked_accounts[aid] then
                entry.best = entry.score == (def.ranking == "higher_better" and high or low)
                entry.worst = entry.score == (def.ranking == "higher_better" and low or high)
            end
        end
    end
    return values
end

function External.inject(sections)
    local ordered = {}
    for key, group in pairs(groups) do if enabled(group.provider) then ordered[#ordered + 1] = key end end
    table.sort(ordered)
    for _, key in ipairs(ordered) do
        local group = groups[key].definition
        local rows, keys = {}, {}
        for stat_key, stat in pairs(stats) do if stat.definition.group == key then keys[#keys + 1] = stat_key end end
        table.sort(keys)
        if #keys > 0 then
            rows[1] = { id = key, label_text = group.label_text, external = true, external_group = true,
                placement = group.placement, parent = placements[group.placement] and group.placement or nil,
                style = "main", depth = 0, no_values = true, collapsible = group.collapsible,
                collapsed_by_default = group.collapsed_by_default }
            for _, stat_key in ipairs(keys) do
                local stat = stats[stat_key]
                local row = copy(stat.definition)
                row.external, row.parent, row.depth, row.style = true, key, 1, "sub"
                row.ranked = row.ranking ~= "none"
                row.values = ranked_values(stat)
                rows[#rows + 1] = row
            end
            local category = placements[group.placement]
            if category then
                for _, section in ipairs(sections) do
                    if section.category.key == category then
                        local index = #section.rows + 1
                        for i, row in ipairs(section.rows) do
                            if row.id == group.placement then
                                index = i + 1
                                break
                            end
                        end
                        for i = #rows, 1, -1 do table.insert(section.rows, index, rows[i]) end
                        break
                    end
                end
            else
                sections[#sections + 1] = { category = { key = key, label_text = group.label_text }, rows = rows }
            end
        end
    end
    return sections
end

function External.filter(sections, collapsed, expand_all)
    local result = {}
    for _, section in ipairs(sections) do
        local rows, hidden = {}, {}
        for _, row in ipairs(section.rows) do
            if row.external_group then
                local closed = collapsed and collapsed[row.id]
                if closed == nil then closed = row.collapsed_by_default end
                hidden[row.id] = row.collapsible and not expand_all and closed
                local heading = copy(row)
                heading.external_collapsed = hidden[row.id]
                rows[#rows + 1] = heading
            elseif not (row.external and hidden[row.parent]) then
                rows[#rows + 1] = row
            end
        end
        result[#result + 1] = { category = section.category, rows = rows }
    end
    return result
end

function External.format(row, value)
    if value == nil then return "—" end
    if row.value_type == "text" then return tostring(value) end
    return string.format("%." .. (row.decimals or 0) .. "f", value) .. (row.suffix or "")
end

return External
