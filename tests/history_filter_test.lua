-- Run from the workspace root: tools/luajit/luajit mods/active/AnotherScoreboard/tests/history_filter_test.lua [scratch dir]
-- Offline test: the History class filter finds the local player's class in new and old entries,
-- filters lists by it, and History.save stores it in the mission file and the index.
local root = "mods/active/AnotherScoreboard/scripts/mods/AnotherScoreboard/"
local scratch = arg and arg[1] or os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"

-- Distinct placeholders for UISettings.archetype_font_icon (scripts/settings/ui/ui_settings.lua:560-568).
local ICONS = { veteran = "V", zealot = "Z", psyker = "P", ogryn = "O", adamant = "A", broker = "B", cryptic = "C" }

local real_os = os
Mods = {
    lua = {
        io = io,
        os = setmetatable({
            getenv = function(name)
                if name == "APPDATA" then return scratch end
                return real_os.getenv(name)
            end,
        }, { __index = real_os }),
    },
}
function Localize(key) return "L:" .. key end

local settings = {}
local history_mod = {}
function history_mod:get(id) return settings[id] end
function history_mod:localize(id) return id end
function history_mod:original_require(path)
    if path == "scripts/settings/ui/ui_settings" then
        return { archetype_font_icon = ICONS }
    end
    return {}
end
function get_mod() return history_mod end

local local_player = { id = "acc-me", player_name = "Me" }
function local_player:account_id() return self.id end
function local_player:name() return self.player_name end
Managers = {
    player = { local_player_safe = function(_, index) return index == 1 and local_player or nil end },
}

local History = dofile(root .. "AnotherScoreboard_history.lua")

local checks = 0
local function eq(actual, expected, what)
    checks = checks + 1
    assert(actual == expected, string.format("check %d (%s): expected %s, got %s",
        checks, what, tostring(expected), tostring(actual)))
end

local function player(account_id, archetype, with_loadout)
    return {
        account_id = account_id,
        name = account_id,
        archetype_icon = ICONS[archetype],
        loadout_snapshot = with_loadout and { archetype = archetype } or nil,
    }
end

-- Index entries saved before local_archetype existed keep only the icon.
local old_zealot = { id = "1", players = { player("acc-other", "psyker"), player("acc-me", "zealot") } }
local old_broker = { id = "2", players = { player("acc-me", "broker") } }
-- Mission files keep the loadout snapshot with the class name.
local file_ogryn = { id = "3", players = { player("acc-me", "ogryn", true) } }
-- New entries carry the stored class, whoever the local player is now.
local stored_veteran = { id = "4", local_archetype = "veteran", players = { player("acc-someone", "psyker") } }
local without_me = { id = "5", players = { player("acc-other", "zealot") } }
local no_players = { id = "6" }

eq(History.entry_local_archetype(old_zealot, "acc-me"), "zealot", "old entry: class from icon")
eq(History.entry_local_archetype(old_broker, "acc-me"), "broker", "old entry: DLC class from icon")
eq(History.entry_local_archetype(file_ogryn, "acc-me"), "ogryn", "mission file: class from loadout")
eq(History.entry_local_archetype(stored_veteran, "acc-me"), "veteran", "stored class wins")
eq(History.entry_local_archetype(stored_veteran, nil), "veteran", "stored class without local player")
eq(History.entry_local_archetype(without_me, "acc-me"), nil, "local player missing")
eq(History.entry_local_archetype(no_players, "acc-me"), nil, "entry without players")
eq(History.entry_local_archetype(old_zealot, nil), nil, "old entry without local player")

-- Each distinct icon maps back to its own class.
for archetype_name in pairs(ICONS) do
    eq(History.entry_local_archetype({ players = { player("acc-me", archetype_name) } }, "acc-me"),
        archetype_name, "icon for " .. archetype_name)
end

local entries = { old_zealot, old_broker, file_ogryn, stored_veteran, without_me, no_players }
eq(History.filter_by_archetype(entries, nil), entries, "no filter returns the same list")

local zealots = History.filter_by_archetype(entries, "zealot")
eq(#zealots, 1, "zealot filter count")
eq(zealots[1], old_zealot, "zealot filter keeps the local player's zealot, not the teammate's")

local psykers = History.filter_by_archetype(entries, "psyker")
eq(#psykers, 0, "teammate classes do not match")

local veterans = History.filter_by_archetype(entries, "veteran")
eq(#veterans, 1, "stored class filter count")
eq(veterans[1], stored_veteran, "stored class filter entry")

eq(#History.filter_by_archetype(entries, "cryptic"), 0, "owned class with no matches is empty")
eq(#entries, 6, "filtering leaves the source list unchanged")

-- The name stands in for the account id when there is none, as in the scoreboard's _account_id.
local_player.id = nil
local by_name = { players = { { account_id = "Me", archetype_icon = ICONS.psyker } } }
eq(#History.filter_by_archetype({ by_name }, "psyker"), 1, "name fallback matches")
local_player.id = "acc-me"

-- History.save stores local_archetype in the mission file and the index entry.
local history_dir = scratch .. "/Fatshark/Darktide/AnotherScoreboard_history/"
if package.config:sub(1, 1) == "\\" then
    os.execute('if not exist "' .. history_dir:gsub("/", "\\") .. '" mkdir "' .. history_dir:gsub("/", "\\") .. '"')
else
    os.execute('mkdir -p "' .. history_dir .. '"')
end
local ok, file_path = History.save({
    duration = 600,
    mission = {},
    players = { player("acc-other", "zealot", true), player("acc-me", "adamant", true) },
    sections = {},
})
eq(ok, true, "save succeeds")
eq(History.list()[1].local_archetype, "adamant", "index entry keeps local_archetype")
eq(History.load(file_path).local_archetype, "adamant", "mission file keeps local_archetype")
eq(#History.filter_by_archetype(History.list(), "adamant"), 1, "saved entry filters by class")

os.remove(file_path)
os.remove(history_dir .. "index.lua")

print(string.format("history_filter_test: %d checks passed", checks))
