local mod = get_mod("AnotherScoreboard")
local _io = Mods.lua.io
local _os = Mods.lua.os

local Missions = mod:original_require("scripts/settings/mission/mission_templates")
local DangerSettings = mod:original_require("scripts/settings/difficulty/danger_settings")
local Havoc = mod:original_require("scripts/utilities/havoc")
local CircumstanceTemplates = mod:original_require("scripts/settings/circumstance/circumstance_templates")

local History = {}

local DEFAULT_CAPACITY = 10
local VERSION = 1
local INDEX_FILE = "index.lua"
local SAVED_INDEX_FILE = "saved_index.lua"
local SAVED_MARKER_FILE = "saved_storage_v1"
local SAVED_FILE_PREFIX = "saved_"
local LEGACY_SAVED_DIRECTORY = "saved/"

local cached_entries = {}
local cached_saved_entries = {}
local cache_ready = false
local cached_capacity = DEFAULT_CAPACITY
local pending_clear_paths = {}

local HIDDEN_HAVOC_CIRCUMSTANCES = {
    mutator_increased_difficulty = true,
    mutator_highest_difficulty = true,
}

local HAVOC_MODIFIER_COLORS = {
    loc_havoc_increased_difficulty_name = { 255, 255, 255 },
    loc_havoc_highest_difficulty_name = { 255, 255, 255 },
    loc_havoc_bolstering_enemies_name = { 208, 136, 48 },
    loc_havoc_encroaching_garden_name = { 138, 43, 226 },
    loc_havoc_mutator_enraged_name = { 255, 54, 36 },
    loc_havoc_chaos_ritual_name = { 0, 255, 0 },
    loc_havoc_armored_infected_name = { 70, 130, 180 },
    loc_havoc_enemies_corrupted_name = { 128, 128, 0 },
    loc_havoc_enemies_parasite_headshot_name = { 255, 160, 122 },
    loc_havoc_tougher_skin_name = { 157, 169, 75 },
    loc_havoc_rotten_armor_name = { 132, 156, 99 },
    loc_havoc_stimmed_minions_name = { 255, 242, 0 },
    loc_circumstance_ember_title = { 160, 82, 45 },
    loc_circumstance_toxic_gas_title = { 154, 205, 50 },
    loc_circumstance_toxic_gas_cultist_grenadier_title = { 154, 205, 50 },
    loc_circumstance_ventilation_purge_title = { 255, 240, 245 },
    loc_circumstance_ventilation_purge_with_snipers_title = { 255, 240, 245 },
    loc_circumstance_darkness_title = { 67, 97, 116 },
    loc_circumstance_darkness_hunting_grounds_title = { 67, 97, 116 },
}

local function strip_formatting_tags(text)
    return type(text) == "string" and text:gsub("{#[^}]*}", "") or text
end

local function colored_modifier_name(text, localization_key)
    text = strip_formatting_tags(text)

    local color = HAVOC_MODIFIER_COLORS[localization_key]
    if not color then
        return text
    end

    return string.format("{#color(%d,%d,%d)}%s{#reset()}", color[1], color[2], color[3], text)
end

local function appdata_path()
    local appdata = _os.getenv("APPDATA")
    if not appdata or appdata == "" then
        return nil
    end

    return appdata .. "/Fatshark/Darktide/AnotherScoreboard_history/"
end

local function file_exists(path)
    local file = _io.open(path, "r")
    if file then
        file:close()
        return true
    end

    return false
end

local function recover_backup(path)
    local backup_path = path .. ".bak"

    if not file_exists(path) and file_exists(backup_path) then
        return _os.rename(backup_path, path) ~= nil
    end

    return file_exists(path)
end

local function directory_exists(path)
    local ok, _, code = _os.rename(path, path)
    if ok or code == 13 then
        return true
    end

    return false
end

local function ensure_directory()
    local path = appdata_path()
    if not path then
        return nil
    end

    if not directory_exists(path) then
        _os.execute('mkdir "' .. path .. '"')
    end

    return path
end

local function legacy_saved_path(path)
    return path and path .. LEGACY_SAVED_DIRECTORY or nil
end

local function sorted_keys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    return keys
end

local function serialize_value(value, indent)
    indent = indent or 0
    local value_type = type(value)

    if value_type == "number" or value_type == "boolean" then
        return tostring(value)
    elseif value_type == "string" then
        return string.format("%q", value)
    elseif value_type ~= "table" then
        return "nil"
    end

    local next_indent = indent + 4
    local pad = string.rep(" ", indent)
    local next_pad = string.rep(" ", next_indent)
    local parts = { "{" }

    for _, key in ipairs(sorted_keys(value)) do
        local entry = value[key]
        local key_text

        if type(key) == "number" then
            key_text = "[" .. tostring(key) .. "]"
        else
            key_text = "[" .. string.format("%q", tostring(key)) .. "]"
        end

        parts[#parts + 1] = next_pad .. key_text .. " = " .. serialize_value(entry, next_indent) .. ","
    end

    parts[#parts + 1] = pad .. "}"

    return table.concat(parts, "\n")
end

local function date_text(timestamp)
    return _os.date("%Y-%m-%d %H:%M:%S", timestamp)
end

local function read_file(path)
    recover_backup(path)

    local file = _io.open(path, "r")
    if not file then
        return nil
    end

    local text = file:read("*a")
    file:close()

    return text
end

local load_file

local function decode_string(text)
    local result = {}
    local i = 2
    local last = #text - 1

    while i <= last do
        local c = text:sub(i, i)
        if c == "\\" then
            local next_char = text:sub(i + 1, i + 1)
            if next_char == "n" then
                result[#result + 1] = "\n"
                i = i + 2
            elseif next_char == "r" then
                result[#result + 1] = "\r"
                i = i + 2
            elseif next_char == "t" then
                result[#result + 1] = "\t"
                i = i + 2
            elseif next_char == "\\" or next_char == "\"" then
                result[#result + 1] = next_char
                i = i + 2
            else
                local digits = text:match("^%d%d?%d?", i + 1)
                if digits then
                    local byte = math.floor(tonumber(digits) or 0)
                    result[#result + 1] = string.char(byte)
                    i = i + 1 + #digits
                else
                    result[#result + 1] = next_char
                    i = i + 2
                end
            end
        else
            result[#result + 1] = c
            i = i + 1
        end
    end

    return table.concat(result)
end

local function parse_saved_table(text)
    if type(text) ~= "string" then
        return nil
    end

    local pos = text:match("^%s*return%s+()") or text:match("^%s*()")

    local function skip_ws()
        local next_pos = text:match("^%s*()", pos)
        pos = next_pos or pos
    end

    local parse_value

    local function parse_string()
        if text:sub(pos, pos) ~= '"' then
            return nil
        end

        local start_pos = pos
        pos = pos + 1

        while pos <= #text do
            local c = text:sub(pos, pos)

            if c == "\\" then
                pos = pos + 2
            elseif c == '"' then
                local full = text:sub(start_pos, pos)
                pos = pos + 1

                return decode_string(full)
            else
                pos = pos + 1
            end
        end

        return nil
    end

    local function parse_key()
        skip_ws()
        if text:sub(pos, pos) ~= "[" then
            return nil
        end

        pos = pos + 1
        skip_ws()

        local key
        if text:sub(pos, pos) == '"' then
            key = parse_string()
        else
            local number_text = text:match("^[%-]?%d+", pos)
            if not number_text then
                return nil
            end
            key = tonumber(number_text)
            pos = pos + #number_text
        end

        skip_ws()
        if text:sub(pos, pos) ~= "]" then
            return nil
        end
        pos = pos + 1

        return key
    end

    local function parse_table()
        if text:sub(pos, pos) ~= "{" then
            return nil
        end

        pos = pos + 1
        local tbl = {}

        while true do
            skip_ws()
            if text:sub(pos, pos) == "}" then
                pos = pos + 1
                return tbl
            end

            local key = parse_key()
            if key == nil then
                return nil
            end

            skip_ws()
            if text:sub(pos, pos) ~= "=" then
                return nil
            end
            pos = pos + 1

            tbl[key] = parse_value()
            skip_ws()

            if text:sub(pos, pos) == "," then
                pos = pos + 1
            elseif text:sub(pos, pos) ~= "}" then
                return nil
            end
        end
    end

    parse_value = function()
        skip_ws()
        local c = text:sub(pos, pos)

        if c == "{" then
            return parse_table()
        elseif c == '"' then
            return parse_string()
        end

        local literal = text:match("^%a+", pos)
        if literal == "true" then
            pos = pos + 4
            return true
        elseif literal == "false" then
            pos = pos + 5
            return false
        elseif literal == "nil" then
            pos = pos + 3
            return nil
        end

        local number_text = text:match("^[%-]?%d+%.?%d*", pos)
        if number_text then
            pos = pos + #number_text
            return tonumber(number_text)
        end

        return nil
    end

    local data = parse_value()
    skip_ws()

    if text:sub(pos):match("%S") then
        return nil
    end

    return data
end

local function history_file_info(file_name)
    local timestamp, suffix = file_name:match("^(%d+)_?(%d*)%.lua$")
    if not timestamp then
        return nil
    end

    return tonumber(timestamp), tonumber(suffix) or 1
end

local function history_file_id(file_name)
    return file_name:match("^(%d+_?%d*)%.lua$")
end

local function saved_history_file_info(file_name)
    local saved_name = file_name:match("^" .. SAVED_FILE_PREFIX .. "(.+)$")
    if not saved_name then
        return nil
    end

    return history_file_info(saved_name)
end

local function saved_history_file_id(file_name)
    return file_name:match("^" .. SAVED_FILE_PREFIX .. "(%d+_?%d*)%.lua$")
end

local function sorted_history_files(path, file_info)
    local files = {}
    file_info = file_info or history_file_info
    local pipe = _io.popen('dir "' .. path .. '" /b')
    if not pipe then
        return files
    end

    for file_name in pipe:lines() do
        local timestamp, suffix = file_info(file_name)
        if timestamp then
            files[#files + 1] = {
                file_name = file_name,
                file_path = path .. file_name,
                timestamp = timestamp,
                suffix = suffix,
            }
        end
    end

    pipe:close()

    table.sort(files, function(a, b)
        if a.timestamp == b.timestamp then
            return a.suffix > b.suffix
        end

        return a.timestamp > b.timestamp
    end)

    return files
end

local function index_path(path, index_file)
    return path .. (index_file or INDEX_FILE)
end

local function summary_sort(a, b)
    if (a.timestamp or 0) == (b.timestamp or 0) then
        return (a.suffix or 1) > (b.suffix or 1)
    end

    return (a.timestamp or 0) > (b.timestamp or 0)
end

local entry_title_display

local function mission_template(metadata)
    metadata = metadata or {}
    local mission_id = metadata.mission_name or metadata.map_id

    return mission_id and Missions[mission_id]
end

local function mission_type(metadata)
    local mission = mission_template(metadata)

    return metadata and metadata.mission_type or mission and mission.mission_type
end

local function game_mode_name(metadata)
    local mission = mission_template(metadata)

    return metadata and metadata.game_mode_name or mission and mission.game_mode_name
end

local function is_expedition(metadata)
    local mode_name = game_mode_name(metadata)

    return metadata and metadata.is_expedition or mode_name == "expedition"
end

local function is_mortis_trials(metadata)
    local mission_type_name = mission_type(metadata)
    local mode_name = game_mode_name(metadata)

    return mode_name == "survival" or mission_type_name == "horde"
end

local function localized_circumstance_name(circumstance_name)
    local template = CircumstanceTemplates[circumstance_name]
    local display_name = template and template.ui and template.ui.display_name

    if display_name then
        local ok, localized = pcall(Localize, display_name)
        if ok and localized and localized ~= "" then
            return colored_modifier_name(localized, display_name)
        end
    end

    return circumstance_name
end

local function split_modifier_lines(names)
    local count = #names
    if count == 0 then
        return nil
    end

    if count == 1 then
        return { names[1] }
    end

    local total_length = 0
    for i = 1, count do
        total_length = total_length + #strip_formatting_tags(names[i])
    end

    total_length = total_length + (count - 1) * 2

    local split_at = 1
    local line_length = 0

    for i = 1, count - 1 do
        line_length = line_length + #strip_formatting_tags(names[i])
        if i > 1 then
            line_length = line_length + 2
        end

        split_at = i
        if line_length >= total_length / 2 then
            break
        end
    end

    local first = {}
    local second = {}

    for i = 1, split_at do
        first[#first + 1] = names[i]
    end

    for i = split_at + 1, count do
        second[#second + 1] = names[i]
    end

    return {
        table.concat(first, ", "),
        table.concat(second, ", "),
    }
end

local function havoc_modifier_lines(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local metadata = entry.mission or entry
    local havoc_data = metadata and metadata.havoc_data

    if type(havoc_data) == "string" and havoc_data ~= "" then
        local ok, parsed = pcall(Havoc.parse_data, havoc_data)
        local circumstances = ok and parsed and parsed.circumstances

        if type(circumstances) == "table" then
            local names = {}
            for i = 1, #circumstances do
                local circumstance_name = circumstances[i]
                if circumstance_name and circumstance_name ~= "" and not HIDDEN_HAVOC_CIRCUMSTANCES[circumstance_name] then
                    names[#names + 1] = localized_circumstance_name(circumstance_name)
                end
            end

            if #names > 0 then
                return split_modifier_lines(names)
            end
        end
    end

    local existing = entry.havoc_modifiers_display
    if type(existing) == "table" then
        return existing
    elseif type(existing) == "string" and existing ~= "" then
        return { existing }
    end

    return nil
end

local function mission_condition_lines(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local metadata = entry.mission or entry
    local havoc_data = metadata and metadata.havoc_data

    if metadata and (metadata.havoc_rank or type(havoc_data) == "string" and havoc_data ~= "") then
        return havoc_modifier_lines(entry)
    end

    local circumstance_name = metadata and metadata.circumstance_name
    if not circumstance_name or circumstance_name == "default" or circumstance_name == "none" then
        return nil
    end

    if metadata.category == "story" or is_mortis_trials(metadata) or circumstance_name:match("^player_journey_") then
        return nil
    end

    local template = CircumstanceTemplates[circumstance_name]
    local display_name = template and template.ui and template.ui.display_name
    if not display_name then
        return nil
    end

    return { localized_circumstance_name(circumstance_name) }
end

local function entry_summary(entry, file_name, file_path)
    local _, suffix = history_file_info(file_name)
    if not suffix then
        _, suffix = saved_history_file_info(file_name)
    end

    -- Keep full loadouts in the mission file, not duplicated in both history indexes.
    local players = {}
    for i, player in ipairs(entry.players or {}) do
        players[i] = {
            account_id = player.account_id,
            name = player.name,
            archetype_icon = player.archetype_icon,
            slot = player.slot,
        }
    end

    return {
        version = VERSION,
        id = entry.id,
        file_name = file_name,
        file_path = file_path,
        timestamp = entry.timestamp,
        suffix = suffix or 1,
        date = entry.date,
        date_display = entry.date or date_text(entry.timestamp or 0),
        duration_display = entry.duration_display,
        difficulty_display = entry.difficulty_display,
        game_type_display = entry.game_type_display,
        custom_name = entry.custom_name,
        history_title_display = entry_title_display(entry),
        havoc_modifiers_display = havoc_modifier_lines(entry),
        mission_display = entry.mission_display,
        outcome = entry.outcome or entry.mission and entry.mission.outcome,
        mission = entry.mission,
        players = players,
    }
end

local function load_index(path, max_entries, index_file, file_info, file_id)
    local data = parse_saved_table(read_file(index_path(path, index_file)))
    if type(data) ~= "table" or data.version ~= VERSION or type(data.entries) ~= "table" then
        return nil
    end

    local entries = {}
    file_info = file_info or history_file_info
    file_id = file_id or history_file_id
    local seen_ids = {}
    local count = max_entries and math.min(#data.entries, max_entries) or #data.entries
    for i = 1, count do
        local entry = data.entries[i]
        local expected_id = type(entry) == "table" and type(entry.file_name) == "string" and file_id(entry.file_name)
        if expected_id and entry.id == expected_id and not seen_ids[entry.id] and file_info(entry.file_name) then
            entry.file_path = path .. entry.file_name
            if file_exists(entry.file_path) then
                entries[#entries + 1] = entry
                seen_ids[entry.id] = true
            end
        end
    end

    table.sort(entries, summary_sort)

    return entries
end

local function write_serialized(path, value)
    local ok, serialized = pcall(serialize_value, value, 0)
    if not ok then
        return false
    end

    local temporary_path = path .. ".tmp"
    local backup_path = path .. ".bak"
    local file = _io.open(temporary_path, "w+")
    if not file then
        return false
    end

    local wrote = file:write("return ", serialized, "\n")
    local closed = file:close()
    if not wrote or closed == nil then
        _os.remove(temporary_path)
        return false
    end

    recover_backup(path)
    _os.remove(backup_path)
    local had_original = file_exists(path)
    if had_original and not _os.rename(path, backup_path) then
        _os.remove(temporary_path)
        return false
    end

    if not _os.rename(temporary_path, path) then
        if had_original then
            _os.rename(backup_path, path)
        end
        _os.remove(temporary_path)
        return false
    end

    if had_original then
        _os.remove(backup_path)
    end

    return true
end

local function write_index(path, entries, index_file)
    return write_serialized(index_path(path, index_file), { version = VERSION, entries = entries })
end

local function build_index_from_files(path, max_entries, index_file, file_info, file_id)
    local entries = {}
    local files = sorted_history_files(path, file_info)
    file_id = file_id or history_file_id
    local count = max_entries and math.min(#files, max_entries) or #files

    for i = 1, count do
        local history_file = files[i]
        local entry = load_file(history_file.file_path)

        if entry and entry.id == file_id(history_file.file_name) then
            entries[#entries + 1] = entry_summary(entry, history_file.file_name, history_file.file_path)
        end
    end

    table.sort(entries, summary_sort)
    write_index(path, entries, index_file)

    return entries
end

local function write_snapshot(path, snapshot)
    return write_serialized(path, snapshot)
end

local function saved_marker_path(path)
    return path .. SAVED_MARKER_FILE
end

local function write_saved_marker(path)
    local file = _io.open(saved_marker_path(path), "w+")
    if not file then
        return false
    end

    file:write("1\n")
    file:close()

    return true
end

local function migrate_legacy_saved_entries(path, entries)
    local legacy_path = legacy_saved_path(path)
    if not legacy_path or not directory_exists(legacy_path) then
        return entries
    end

    local legacy_entries = load_index(legacy_path) or build_index_from_files(legacy_path)
    local id_lookup = {}
    local changed = false

    for i = 1, #entries do
        id_lookup[entries[i].id] = true
    end

    for i = 1, #legacy_entries do
        local legacy_entry = legacy_entries[i]
        if not id_lookup[legacy_entry.id] then
            local snapshot = load_file(legacy_entry.file_path)
            local file_name = SAVED_FILE_PREFIX .. legacy_entry.id .. ".lua"
            local file_path = path .. file_name
            local existing_snapshot = file_exists(file_path) and load_file(file_path)

            if snapshot and (existing_snapshot and existing_snapshot.id == legacy_entry.id or write_snapshot(file_path, snapshot)) then
                local saved_snapshot = existing_snapshot and existing_snapshot.id == legacy_entry.id and existing_snapshot or snapshot
                entries[#entries + 1] = entry_summary(saved_snapshot, file_name, file_path)
                id_lookup[legacy_entry.id] = true
                changed = true
            end
        end
    end

    if changed then
        table.sort(entries, summary_sort)
        write_index(path, entries, SAVED_INDEX_FILE)
    end

    return entries
end

function History.format_duration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    end

    return string.format("%02d:%02d", minutes, secs)
end

function History.difficulty_display(metadata)
    metadata = metadata or {}
    local havoc_rank = metadata.havoc_rank

    if havoc_rank then
        return "Havoc " .. tostring(havoc_rank)
    end

    local challenge = tonumber(metadata.challenge)
    local resistance = tonumber(metadata.resistance)

    for _, danger in ipairs(DangerSettings) do
        if danger.challenge == challenge and danger.resistance == resistance then
            local ok, localized = pcall(Localize, danger.display_name)
            return ok and localized or danger.name
        end
    end

    if challenge then
        return "Difficulty " .. tostring(challenge)
    end

    return mod:localize("history_unknown_difficulty")
end

function History.game_type_display(metadata)
    metadata = metadata or {}

    if metadata.havoc_rank then
        return "Havoc " .. tostring(metadata.havoc_rank)
    end

    if metadata.category == "maelstrom" then
        if metadata.resistance == 5 then
            return mod:localize("history_game_type_auric_maelstrom")
        end

        return mod:localize("history_game_type_maelstrom")
    end

    if is_expedition(metadata) then
        return mod:localize("history_game_type_expedition")
    end

    if is_mortis_trials(metadata) then
        return mod:localize("history_game_type_mortis_trials")
    end

    return History.difficulty_display(metadata)
end

function History.mission_display(metadata)
    metadata = metadata or {}
    local mission_id = metadata.mission_name or metadata.map_id or mod:localize("history_unknown_mission")
    local mission = mission_template(metadata)

    if mission and mission.mission_name then
        local ok, localized = pcall(Localize, mission.mission_name)
        if ok and localized and localized ~= "" then
            return localized
        end
    end

    return mission_id
end

local function generated_entry_title(entry)
    entry = entry or {}

    if entry.history_title_display and not entry.mission then
        return entry.history_title_display
    end

    local metadata = entry.mission
    local map = entry.mission_display or metadata and History.mission_display(metadata)
    local difficulty = metadata and History.game_type_display(metadata) or entry.game_type_display or entry.difficulty_display

    local duration = entry.duration_display
    if not duration and entry.duration then
        duration = History.format_duration(entry.duration)
    end

    map = map or mod:localize("history_unknown_mission")
    difficulty = difficulty or entry.difficulty_display or mod:localize("history_unknown_difficulty")
    duration = duration or "--:--"

    return string.format("%s | %s | %s", map, difficulty, duration)
end

entry_title_display = function(entry)
    entry = entry or {}

    local generated_title = generated_entry_title(entry)
    if type(entry.custom_name) == "string" and entry.custom_name ~= "" then
        if generated_title == entry.custom_name then
            return entry.custom_name
        end

        return string.format("%s | %s", entry.custom_name, generated_title)
    end

    return generated_title
end

function History.entry_title_display(entry)
    return entry_title_display(entry)
end

function History.entry_outcome(entry)
    entry = entry or {}

    return entry.outcome or entry.mission and entry.mission.outcome
end

function History.havoc_modifiers_display(entry)
    return havoc_modifier_lines(entry)
end

function History.mission_conditions_display(entry)
    return mission_condition_lines(entry)
end

load_file = function(path)
    local data = parse_saved_table(read_file(path))
    if type(data) ~= "table" or data.version ~= VERSION then
        return nil
    end

    return data
end

function History.recent_capacity()
    local capacity = mod:get("history_recent_capacity")
    if type(capacity) == "number" and capacity >= 10 and capacity <= 100 and capacity % 10 == 0 then
        return capacity
    end

    return DEFAULT_CAPACITY
end

function History.list()
    if cache_ready and cached_capacity ~= History.recent_capacity() and #pending_clear_paths == 0 then
        History.refresh_cache(true)
    end

    return cached_entries
end

function History.saved_list()
    return cached_saved_entries
end

function History.is_saved(id)
    if not id then
        return false
    end

    for i = 1, #cached_saved_entries do
        if cached_saved_entries[i].id == id then
            return true
        end
    end

    return false
end

function History.cache_ready()
    return cache_ready
end

function History.refresh_cache(rebuild_from_files)
    local path = appdata_path()
    local capacity = History.recent_capacity()
    local entries
    local saved_entries

    if path and directory_exists(path) then
        entries = load_index(path)

        if not entries and rebuild_from_files then
            entries = build_index_from_files(path)
        end

        saved_entries = load_index(path, nil, SAVED_INDEX_FILE, saved_history_file_info, saved_history_file_id)
        if not saved_entries then
            if file_exists(saved_marker_path(path)) then
                saved_entries = build_index_from_files(path, nil, SAVED_INDEX_FILE, saved_history_file_info, saved_history_file_id)
            else
                saved_entries = migrate_legacy_saved_entries(path, {})
                write_index(path, saved_entries, SAVED_INDEX_FILE)
                write_saved_marker(path)
            end
        end
    end

    cached_entries = entries or {}
    for i = #cached_entries, capacity + 1, -1 do
        cached_entries[i] = nil
    end
    cached_capacity = capacity
    cached_saved_entries = saved_entries or {}
    cache_ready = true

    return cached_entries
end

function History.prune()
    local path = ensure_directory()
    if not path then
        return
    end

    local files = sorted_history_files(path)
    for i = History.recent_capacity() + 1, #files do
        local file_path = files[i].file_path
        if file_path and file_exists(file_path) then
            _os.remove(file_path)
        end
    end
end

function History.clear()
    local path = appdata_path()
    local paths = {}

    if path and directory_exists(path) then
        local files = sorted_history_files(path)
        for i = 1, #files do
            paths[#paths + 1] = files[i].file_path
        end

        paths[#paths + 1] = index_path(path)
    end

    cached_entries = {}
    cache_ready = true

    for i = 1, #paths do
        pending_clear_paths[#pending_clear_paths + 1] = paths[i]
    end

    return true
end

function History.update(dt)
    local path = pending_clear_paths[1]
    if not path then
        return
    end

    table.remove(pending_clear_paths, 1)

    if file_exists(path) then
        _os.remove(path)
    end
end

function History.load(path)
    return load_file(path)
end

local function normalized_custom_name(custom_name)
    if custom_name == nil then
        return nil
    elseif type(custom_name) ~= "string" then
        return false
    end

    custom_name = custom_name:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s%s+", " ")
    if custom_name == "" then
        return nil
    elseif #custom_name > 192 then
        return false
    end

    return custom_name
end

function History.save_entry(entry, custom_name)
    if type(entry) ~= "table" or type(entry.id) ~= "string" or not entry.id:match("^%d+_?%d*$") then
        return false
    end

    custom_name = normalized_custom_name(custom_name)
    if custom_name == false then
        return false
    end

    if History.is_saved(entry.id) then
        return true
    end

    local snapshot = entry.file_path and load_file(entry.file_path) or entry.sections and entry
    if type(snapshot) ~= "table" or snapshot.id ~= entry.id then
        return false
    end

    snapshot.custom_name = custom_name

    local path = ensure_directory()
    if not path then
        return false
    end

    local file_name = SAVED_FILE_PREFIX .. entry.id .. ".lua"
    local file_path = path .. file_name
    local source_entries = load_index(path, nil, SAVED_INDEX_FILE, saved_history_file_info, saved_history_file_id)
    if not source_entries and not file_exists(saved_marker_path(path)) then
        source_entries = migrate_legacy_saved_entries(path, {})
    end
    source_entries = source_entries or cached_saved_entries or {}
    local entries = {}

    for i = 1, #source_entries do
        entries[i] = source_entries[i]
    end

    for i = 1, #entries do
        if entries[i].id == entry.id then
            cached_saved_entries = entries
            return true
        end
    end

    if file_exists(file_path) then
        local existing_snapshot = load_file(file_path)
        if not existing_snapshot or existing_snapshot.id ~= entry.id then
            return false
        end

        existing_snapshot.custom_name = custom_name
        if not write_snapshot(file_path, existing_snapshot) then
            return false
        end

        entries[#entries + 1] = entry_summary(existing_snapshot, file_name, file_path)
        table.sort(entries, summary_sort)

        if not write_index(path, entries, SAVED_INDEX_FILE) then
            return false
        end

        cached_saved_entries = entries
        write_saved_marker(path)
        return true
    end

    if not write_snapshot(file_path, snapshot) then
        return false
    end

    entries[#entries + 1] = entry_summary(snapshot, file_name, file_path)
    table.sort(entries, summary_sort)

    if not write_index(path, entries, SAVED_INDEX_FILE) then
        _os.remove(file_path)
        return false
    end

    cached_saved_entries = entries
    write_saved_marker(path)

    return true
end

function History.rename_saved(id, custom_name)
    if type(id) ~= "string" or not id:match("^%d+_?%d*$") then
        return false
    end

    custom_name = normalized_custom_name(custom_name)
    if custom_name == false then
        return false
    end

    local path = appdata_path()
    if not path or not directory_exists(path) then
        return false
    end

    local saved_entry
    local entry_index
    for i = 1, #cached_saved_entries do
        if cached_saved_entries[i].id == id then
            saved_entry = cached_saved_entries[i]
            entry_index = i
            break
        end
    end

    if not saved_entry or not saved_entry.file_path then
        return false
    end

    local snapshot = load_file(saved_entry.file_path)
    if not snapshot or snapshot.id ~= id then
        return false
    end

    local previous_name = snapshot.custom_name
    snapshot.custom_name = custom_name
    if not write_snapshot(saved_entry.file_path, snapshot) then
        return false
    end

    local entries = {}
    for i = 1, #cached_saved_entries do
        entries[i] = cached_saved_entries[i]
    end
    entries[entry_index] = entry_summary(snapshot, saved_entry.file_name, saved_entry.file_path)

    if not write_index(path, entries, SAVED_INDEX_FILE) then
        snapshot.custom_name = previous_name
        write_snapshot(saved_entry.file_path, snapshot)
        return false
    end

    cached_saved_entries = entries
    return true
end

function History.remove_saved(id)
    if not id then
        return false
    end

    local path = appdata_path()
    if not path or not directory_exists(path) then
        return false
    end

    local entries = {}
    local removed_entry

    for i = 1, #cached_saved_entries do
        local entry = cached_saved_entries[i]
        if entry.id == id then
            removed_entry = entry
        else
            entries[#entries + 1] = entry
        end
    end

    if not removed_entry then
        return false
    end

    if not write_index(path, entries, SAVED_INDEX_FILE) then
        return false
    end

    if removed_entry.file_path and file_exists(removed_entry.file_path) then
        local removed = _os.remove(removed_entry.file_path)
        if not removed then
            if write_index(path, cached_saved_entries, SAVED_INDEX_FILE) then
                return false
            end

            cached_saved_entries = entries
            return true
        end
    end

    cached_saved_entries = entries
    return true
end

function History.save(snapshot)
    local path = ensure_directory()
    if not path or type(snapshot) ~= "table" then
        return false
    end

    local timestamp = _os.time()
    local id = tostring(timestamp)
    local file_name = id .. ".lua"
    local file_path = path .. file_name
    local suffix = 1

    while file_exists(file_path) do
        suffix = suffix + 1
        id = tostring(timestamp) .. "_" .. tostring(suffix)
        file_name = id .. ".lua"
        file_path = path .. file_name
    end

    snapshot.version = VERSION
    snapshot.id = id
    snapshot.timestamp = timestamp
    snapshot.date = date_text(timestamp)
    snapshot.duration_display = History.format_duration(snapshot.duration or 0)
    snapshot.difficulty_display = History.difficulty_display(snapshot.mission)
    snapshot.mission_display = History.mission_display(snapshot.mission)
    snapshot.game_type_display = History.game_type_display(snapshot.mission)
    snapshot.havoc_modifiers_display = havoc_modifier_lines(snapshot)
    snapshot.history_title_display = History.entry_title_display(snapshot)

    if not write_snapshot(file_path, snapshot) then
        return false
    end

    local capacity = History.recent_capacity()
    local source_entries = load_index(path) or cached_entries or {}
    local entries = {}
    for i = 1, #source_entries do
        entries[i] = source_entries[i]
    end
    entries[#entries + 1] = entry_summary(snapshot, file_name, file_path)
    table.sort(entries, summary_sort)

    local pruned_paths = {}
    for i = #entries, capacity + 1, -1 do
        local old_path = entries[i].file_path
        pruned_paths[#pruned_paths + 1] = old_path
        entries[i] = nil
    end

    if not write_index(path, entries) then
        _os.remove(file_path)
        return false
    end

    for i = 1, #pruned_paths do
        local old_path = pruned_paths[i]
        if old_path and old_path ~= file_path and file_exists(old_path) then
            _os.remove(old_path)
        end
    end

    cached_entries = entries
    cached_capacity = capacity
    cache_ready = true
    History.prune()

    return true, file_path
end

function History.player_adapters(players)
    local adapters = {}

    for i = 1, math.min(#(players or {}), 4) do
        local player = players[i]
        local social_account_id = player.social_account_id
        if not social_account_id and math.is_uuid(player.account_id) then
            social_account_id = player.account_id
        end

        adapters[#adapters + 1] = {
            _account_id = player.account_id,
            _name = player.name,
            string_symbol = player.archetype_icon or player.string_symbol,
            loadout_snapshot = player.loadout_snapshot,
            social_account_id = social_account_id,
            account_id = function(self)
                return self._account_id
            end,
            name = function(self)
                return self._name
            end,
        }
    end

    return adapters
end

return History
