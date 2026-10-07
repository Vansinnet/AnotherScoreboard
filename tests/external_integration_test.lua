-- Engine boundaries are stubbed; the main entry, Stats and external module are real.
local root = "mods/active/AnotherScoreboard/scripts/mods/AnotherScoreboard/"
local hooks, settings, mods = {}, { show_at_end = false }, {}
local noop = function() end
local mod = { enabled = true }
mods.AnotherScoreboard = mod
function get_mod(name) return mods[name] end
function mod:get_name() return "AnotherScoreboard" end
function mod:is_enabled() return self.enabled end
function mod:get(key) return settings[key] end
function mod:set(key, value) settings[key] = value end
function mod:persistent_table(_, default) return default end
function mod:localize(key) return key end
function mod:warning() self.warnings = (self.warnings or 0) + 1 end
function mod:hook(target, method, callback)
    hooks[(type(target) == "table" and target.name or target) .. "." .. method] = callback
end
mod.hook_safe = mod.hook
mod.hook_require = noop
mod.command = noop
mod.get_require_store = noop
mod.register_hud_element = noop
mod.add_require_path = noop
mod.register_view = noop
table.clear = function(t) for k in pairs(t) do t[k] = nil end end
CLASS = setmetatable({}, { __index = function(t, key) local v = { name = key }; t[key] = v; return v end })
Keyboard = { button_index = function(key) return key end, pressed = function() return false end }
local player = { player_unit = nil }
function player:account_id() return "p1" end
function player:name() return "Player" end
function player:profile() return {} end
Managers = {
    player = { players = function() return { player } end, human_players = function() return { player } end,
        local_player_safe = function() return player end },
    state = { game_mode = { game_mode_name = function() return "hub" end } },
    ui = { view_active = function() return false end, get_hud = function() return nil end },
}
local saved, builds = nil, 0
local history = { save = function(snapshot) saved = snapshot; return true end }
local render = {
    update_dimensions = noop,
    build_hud_widgets = function(_, _, _, sections) builds = builds + 1; return { { sections = sections } } end,
}
function mod:original_require(path)
    if path:find("interaction_settings", 1, true) then return { results = {} } end
    if path:find("ui_widget", 1, true) then return { destroy = noop } end
    if path:find("ui_renderer", 1, true) then return { clear_scenegraph_queue = noop, clear_render_pass_queue = noop } end
    return {}
end
function mod:io_dofile(path)
    local name = path:match("([^/]+)$")
    if name == "AnotherScoreboard_history" then return history end
    if name == "AnotherScoreboard_render" then return render end
    if name == "AnotherScoreboard_loadout" then return { capture = function() return {} end } end
    if name == "AnotherScoreboard_stagger" or name == "AnotherScoreboard_view" or name == "AnotherScoreboard_history_view" then return {} end
    return dofile(root .. name .. ".lua")
end
dofile(root .. "AnotherScoreboard.lua")
local checks = 0
local function eq(actual, expected)
    checks = checks + 1
    assert(actual == expected, "check " .. checks .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function find(sections, key)
    for _, section in ipairs(sections) do
        for _, row in ipairs(section.rows) do if row.id == key then return row end end
    end
end
local owner = { get_name = function() return "Consumer" end, is_enabled = function() return true end }
mods.Consumer = owner
eq(mod.external_stats_api_version, 1)
local group = assert(mod:register_external_group(owner, { id = "group", label = "Consumer", placement = "combat_utility" }))
local key = assert(mod:register_external_stat(owner, { id = "stat", label = "Published", group = group }))
eq(mod:update_external_stat(key, "p1", 5), true)
mod.on_all_mods_loaded()
eq(mod:get_external_stat(key, "p1"), 5)
local visibility = mod.get_cached_settings().scoreboard_stat_visibility
visibility.headshots, visibility.critical_hits, visibility.enemies_staggered, visibility.debuffs_applied = false, false, false, false
local sections = mod.filter_scoreboard_sections(mod.get_stats().sections())
eq(find(sections, "combat_utility") ~= nil, true)
eq(find(sections, key) ~= nil, true)
local calls = 0
assert(mod:set_external_stat_collector(owner, function(_, api)
    calls = calls + 1
    assert(api:update_external_stat(key, "p1", 99))
end))
hooks["EndView.on_enter"](noop, {})
eq(calls, 1)
eq(find(saved.sections, key).values.p1.score, 99)
eq(find(saved.sections, group).collapsed_by_default, true)
eq(find(saved.sections, key).label_text, "Published")
hooks["EndView.on_enter"](noop, {})
eq(calls, 1)
mod.enabled = false
local value, err = mod:update_external_stat(key, "p1", 0)
eq(value, nil)
eq(err, "scoreboard_disabled")
mod.enabled = true
mod.on_game_state_changed("enter", "StateGameplay")
eq(mod:get_external_stat(key, "p1"), nil)
assert(mod:update_external_stat(key, "p1", 0))
local roster_builds = 0
local roster_view = { _context = {}, _build = function() roster_builds = roster_builds + 1 end }
Managers.ui.view_instance = function(_, name) return name == "another_scoreboard_view" and roster_view or nil end
Managers.ui.is_view_closing = function() return false end
mod.get_stats().record("total_kills", "p1", 4)
mod._sync_player_roster({ player })
mod._sync_player_roster({})
local rejoined_player = { player_unit = nil }
function rejoined_player:account_id() return "p1" end
function rejoined_player:name() return "Player" end
mod._sync_player_roster({ rejoined_player })
eq(mod.get_stats().data_for("total_kills").p1.score, 4)
eq(roster_builds, 3)
Managers.ui.view_instance = function() return nil end
local hud = { _active = true }
Managers.ui.get_hud = function() return { element = function() return hud end } end
hooks["HudElementTacticalOverlay.update"](noop, hud, 0.01, 0, {}, {}, {})
eq(builds, 1)
eq(find(hud._as_widgets[1].sections, key), nil)
mod.toggle_external_details()
for i = 1, 20 do
    assert(mod:update_external_stat(key, "p1", i))
    hooks["HudElementTacticalOverlay.update"](noop, hud, 0.01, i * 0.01, {}, {}, {})
end
eq(builds, 1)
hooks["HudElementTacticalOverlay.update"](noop, hud, 0.05, 0.25, {}, {}, {})
eq(builds, 2)
eq(find(hud._as_widgets[1].sections, key).values.p1.score, 20)
eq(mod:unregister_external_provider(owner), true)
eq(find(mod.get_stats().sections(), key), nil)
eq(find(mod.external_stats.filter(saved.sections, { [group] = false }), key).values.p1.score, 99)
-- Real render pass construction and view interaction with a stubbed native widget factory.
Utf8 = { string_length = string.len, sub_string = string.sub, upper = string.upper }
local original_require = mod.original_require
function mod:original_require(path)
    if path:find("ui_workspace_settings", 1, true) then return { screen = { size = { 1920, 1080 } } } end
    if path:find("ui_widget", 1, true) then return { create_definition = function(passes) return passes end } end
    return original_require(self, path)
end
local real_render = dofile(root .. "AnotherScoreboard_render.lua")
local missing_player = { account_id = function() return "missing" end, name = function() return "Missing" end }
local p2 = { account_id = function() return "p2" end, name = function() return "Zero" end }
find(saved.sections, key).values.p2 = { score = 0 }
find(saved.sections, key).decimals = 1
find(saved.sections, key).suffix = "s"
local called_key, called_closed
local host = { _toggle_external_group = function(_, k, closed) called_key, called_closed = k, closed end }
local displayed = mod.external_stats.filter(saved.sections, { [group] = false })
displayed[#displayed + 1] = {
    category = { key = "own", label_text = "Overflow Meter", uppercase = true },
    rows = {},
}
local built = real_render.build_widgets(host, "content", { player, p2, missing_player }, displayed, { scale = 1, text_scale = 1 })
local value_texts, hotspot = {}, nil
for _, pass in ipairs(built.sections[1].widget) do
    if pass.pass_type == "text" then value_texts[pass.value] = true end
    if pass.content_id and pass.content_id:find("external_hotspot_", 1, true) then hotspot = pass end
end
eq(value_texts["99.0s"], true)
eq(value_texts["0.0s"], true)
eq(value_texts["—"], true)
eq(value_texts["OVERFLOW METER"], true)
assert(hotspot).content.pressed_callback()
eq(called_key, group)
eq(called_closed, false)
local io_dofile = mod.io_dofile
function mod:io_dofile(path)
    if path:find("AnotherScoreboard_loadout_render", 1, true) or path:find("AnotherScoreboard_talent_tree", 1, true) then return {} end
    return io_dofile(self, path)
end
function class() return { super = { update = noop } } end
local View = dofile(root .. "AnotherScoreboard_view.lua")
local view_builds = 0
local view = setmetatable({ _context = { end_view = true }, _external_revision = mod.external_stats.revision,
    _external_refresh_timer = 0.25 }, { __index = View })
view._update_social_request, view._update_move = noop, noop
view._build = function(self)
    view_builds = view_builds + 1
    self._external_revision = mod.external_stats.revision
    self._external_refresh_timer = 0.25
end
local input = { get = function() return false end, is_null_service = function() return false end }
view:_toggle_external_group(group, false)
eq(view._external_collapsed[group], true)
eq(view_builds, 0)
view:update(0.01, 0, input)
eq(view_builds, 1)
for i = 1, 20 do
    mod.external_stats.revision = mod.external_stats.revision + 1
    view:update(0.01, i * 0.01, input)
end
eq(view_builds, 1)
view:update(0.06, 0.26, input)
eq(view_builds, 2)
view._context = { scoreboard_history = true }
mod.external_stats.revision = mod.external_stats.revision + 1
view:update(1, 1, input)
eq(view_builds, 2)
view:_toggle_external_group(group, true)
view:update(0.01, 1.01, input)
eq(view_builds, 3)
print("external_integration_test: " .. checks .. " checks passed")
