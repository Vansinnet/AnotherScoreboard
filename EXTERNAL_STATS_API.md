# External stats API — version 1

AnotherScoreboard provides a **local-only** registration and publication API. It does not install provider hooks, collect gameplay events for providers, or send network messages. Providers are responsible for the accuracy and authority of their measurements.

Check `get_mod("AnotherScoreboard").external_stats_api_version == 1` before using it. All public methods below use **colon syntax**. Pass your actual DMF mod object as `owner`, not a name or a wrapper table. The API verifies `get_mod(owner:get_name()) == owner` and checks `owner:is_enabled()` before publication or collection.

## Registration

```lua
local provider = get_mod("MyMod")
---@type AnotherScoreboardMod?
local scoreboard = get_mod("AnotherScoreboard")

local group_key, stat_key, status_key
local function register_stats()
    scoreboard = get_mod("AnotherScoreboard")
    if not scoreboard or scoreboard.external_stats_api_version ~= 1 then return end

    group_key = assert(scoreboard:register_external_group(provider, {
        id = "support",
        label = "My Mod: Support", -- Already-resolved text; provider:localize(...) is also valid.
        placement = "survival_utility",
        collapsible = true,
        collapsed_by_default = true,
    }))
    stat_key = assert(scoreboard:register_external_stat(provider, {
        id = "seconds_saved",
        label = "Time saved",
        group = group_key,
        value_type = "number",
        accumulation = "add",
        ranking = "higher_better",
        decimals = 1,
        suffix = " s",
    }))
    status_key = assert(scoreboard:register_external_stat(provider, {
        id = "status", label = "Status", group = group_key,
        value_type = "text", accumulation = "set",
    }))
end

-- Merge these calls into your existing lifecycle handlers.
function provider.on_all_mods_loaded() register_stats() end
function provider.on_enabled() register_stats() end
```

The API is installed at the beginning of AnotherScoreboard's main entry, before its `on_all_mods_loaded` callback. A provider loaded after that entry can register immediately, even before Stats initializes. A provider loaded earlier should retry in `on_all_mods_loaded`. Registration and repeated identical definitions preserve values; native `Stats.init()` does not clear external registrations or values.

Provider-local identifiers are case-sensitive, 1–128 bytes, and contain only ASCII letters, digits, `_` or `-`. Actual DMF owner names may contain spaces, punctuation or UTF-8 (1–256 bytes without control characters); their namespace component is percent-encoded to prevent collisions with separators. For example, `My Mod` becomes `My%20Mod`. Keys are opaque strings for consumers:

- Group: `external:MyMod:group:support`
- Stat: `external:MyMod:stat:seconds_saved`

Group and stat identifiers have separate namespaces. The same stat ID under another provider cannot collide. A stat's group must belong to the same owner. Exact repeated registrations return the existing key without creating duplicate rows. Reusing an ID with a different normalized definition returns `definition_conflict`; unregister the provider before replacing its schema. Unregistration discards live values.

### Group definition

| Field | Contract |
|---|---|
| `id` | Required provider-local identifier. |
| `label` | Required resolved display text, 1–256 bytes, no control characters. |
| `placement` | `survivability`, `combat_utility`, `survival_utility`, or `own` (default). `own` creates a separate category whose heading displays the group's label in uppercase; the collapsible group row preserves the label exactly as supplied. |
| `collapsible` | Boolean, default `true`. |
| `collapsed_by_default` | Boolean, default `true` for collapsible groups and `false` otherwise. Cannot be `true` when `collapsible = false`. |

### Stat definition

| Field | Contract |
|---|---|
| `id`, `label` | Same identifier/display-text rules as groups. |
| `group` | Required returned group key owned by this provider. |
| `value_type` | `number` (default) or `text`. |
| `accumulation` | `set` (default) or `add`. Text supports only `set`. |
| `ranking` | `none` (default), `higher_better`, or `lower_better`. Text supports only `none`. |
| `decimals` | Integer 0–6, default 0. Text requires 0. |
| `suffix` | String of up to 32 bytes, no control characters; default empty. Include any desired leading space. Text requires empty. |

Unknown fields and incorrect types are rejected rather than ignored. Groups and rows are ordered deterministically by their namespaced keys. Providers cannot modify built-in definitions through this API.

## Publication and reading

```lua
-- Use the same ID as the scoreboard: player:account_id() or player:name().
local player_id = player:account_id() or player:name()
local ok, err = scoreboard:update_external_stat(stat_key, player_id, 2.5)
if not ok then provider:warning("External stat rejected: %s", err) end
scoreboard:update_external_stat(status_key, player_id, "Complete")

local value, read_error = scoreboard:get_external_stat(stat_key, player_id)
local all_players = scoreboard:get_external_stat(stat_key) -- Independent player-ID -> scalar map.
```

Player IDs must be nonempty strings of at most 256 bytes without control characters. All finite numbers, including zero and negatives, are accepted. NaN, infinities, numeric strings and overflowing additions are rejected. `add` treats the first valid update as an addition to zero; `set` replaces the scalar. Text permits 0–512 bytes without control characters. An empty string is published text, not a missing value.

Missing values remain absent and display **—**. An explicitly published zero displays its numeric format, such as `0.0 s`. Built-in zero initialization never fills external rows. Ranking ignores missing players and non-displayed player IDs; ties at the high/low extremes share the highlight, and equal values produce no best/worst highlight. `none` never ranks.

`get_external_stat(key, player_id)` returns the scalar or `nil` with no error when the player has no value. Omitting `player_id` returns a copy of the entire value map. Modifying that copy cannot change the scoreboard. Getters remain available while a provider is disabled, until unregistration.

### Return codes

Registration returns `key` on success, otherwise `nil, error_code`. Update, collector registration, and unregistration return `true` on success, otherwise `nil, error_code`. Getters return the value/copy, otherwise `nil, error_code` (except missing-player reads described above).

| Code | Meaning |
|---|---|
| `invalid_owner` | Not the current DMF mod object, invalid name, or missing required DMF methods. |
| `owner_conflict` | An existing registration belongs to a different DMF object with that name; the old instance must unregister before replacement. |
| `invalid_definition` | Missing/invalid ID or label, unknown field, invalid optional type, or contradictory collapse settings. |
| `invalid_placement` | Unsupported group placement. |
| `invalid_group` | Missing group or another provider's group. |
| `invalid_value_type` | Unsupported stat value type. |
| `invalid_accumulation` | Unsupported accumulator. |
| `invalid_ranking` | Unsupported ranking direction. |
| `invalid_format` | Invalid decimals/suffix or unsupported text accumulator/ranking/format. |
| `definition_conflict` | The ID already has a different normalized definition. |
| `unknown_stat` | No registered stat for the supplied key. |
| `invalid_player_id` | Invalid player ID. |
| `invalid_value` | Invalid scalar type/content, nonfinite number or addition overflow. |
| `provider_disabled` | Owner is disabled or is no longer the current registered DMF object. |
| `scoreboard_disabled` | AnotherScoreboard is disabled; publication is rejected. |
| `invalid_collector` | Collector is neither a function nor nil. |

## Optional final collection

```lua
-- A collector is useful when your provider maintains its own mission totals.
-- Register this stat with accumulation = "set" so capture retries cannot double-count.
scoreboard:set_external_stat_collector(provider, function(owner, api)
    for player_id, total in pairs(my_mission_totals) do
        local ok, err = api:update_external_stat(my_set_stat_key, player_id, total)
        if not ok then owner:warning("Final stat rejected: %s", err) end
    end
end)
```

There is at most one collector per provider. Replacing it is supported; pass nil to remove it. Callback arguments are `(owner, scoreboard)`; no implicit third receiver is supplied. It must return promptly, must not yield, and should publish idempotent `set` totals. Return values are ignored.

Collection occurs synchronously immediately before AnotherScoreboard builds the history snapshot in its existing `EndView.on_enter` capture path, after native `on_enter`. Each enabled provider's callback runs through a separate `pcall`, in provider-name order. A failure is logged and other providers continue. Updates made before an error remain published. Disabled/stale providers are skipped; no collection runs while AnotherScoreboard is disabled. A successfully saved result is not collected again on repeated end-view entry. A failed save may retry collection. Collectors are not invoked for active-run backup, view refresh, history browsing, or every gameplay event.

## Reset, unregistration and reload

```lua
local function unregister_stats()
    local api = get_mod("AnotherScoreboard")
    if api and api.external_stats_api_version == 1 then
        api:unregister_external_provider(provider)
    end
    group_key, stat_key, status_key = nil, nil, nil
end

-- Merge into existing handlers; do not overwrite your own cleanup.
function provider.on_disabled() unregister_stats() end
function provider.on_unload() unregister_stats() end
```

- Mission reset clears external values and pending restored data, retaining definitions and collectors. Providers must also reset their own mission totals on the appropriate lifecycle edge.
- AnotherScoreboard's existing disable/unload reset clears live values. Updates are rejected while it is disabled. Re-enable can restore an eligible active run using its existing matching rules.
- Active-run export includes external scalar maps, including explicit zero and text. Restore validates external data before changing Stats. During same-session reconnect recovery, saved numeric `add` values are added to values published after reconnect; present live `set` and text values win. Values for unknown providers/rows remain pending until the matching stat registers. A saved value-type mismatch is discarded. Importing an old active run without external data yields empty external values.
- `unregister_external_provider(owner)` removes that provider's definitions, values, collector and pending restore data. It is idempotent for the current valid owner. Saved history is unaffected.
- Providers must unregister on disable/unload and register again on enable/reload. Unregistration is the supported immediate removal path; no native provider-toggle hooks are installed. If AnotherScoreboard itself is hot-reloaded, consumers must reacquire the API and register again (for example through their own reload/enable path). Registry objects are not persisted across a source reload; eligible mission values use active-run restore.
- Only scalar maps and metadata are saved. No engine player/unit/world/extension references or functions enter a snapshot.

## Display and history

In the in-mission **Tab scoreboard**, the configurable **External stat details** key defaults to **J**. While Tab is active it switches all collapsible groups between expanded and their registered default state. Noncollapsible groups stay open. This state resets with the mission. It affects the full Tab scoreboard, not the separate compact live-summary HUD.

In end screens and history, click the `+`/`−` group heading to expand/collapse that group. Choices are local to the open view and are not written into history. External updates/registration/unregistration increment a rendering revision; an already-open live scoreboard processes external refreshes at most once per 0.25 seconds. Click rebuilds are deferred to the view update, not performed inside a native hotspot callback. History remains immutable while providers continue publishing.

Native utility/survivability headings remain visible when external children exist, even if all their built-in child rows are disabled in settings. Snapshot creation uses complete uncollapsed sections. History stores group placement, collapse defaults, resolved group/category/row labels, numeric formatting, ranking direction/flags and all published values, including values for IDs not on the final displayed roster. Historical labels and rows remain readable after the provider is disabled, removed, renamed or changed. Existing history with no external fields still displays normally. Only players on that result's roster have visible columns.

## Offline verification and manual checks

Run from the workspace root:

```powershell
& "lua-5.5.0_Win64_bin\lua55.exe" "mods\active\AnotherScoreboard\tests\external_stats_test.lua"
& "lua-5.5.0_Win64_bin\lua55.exe" "mods\active\AnotherScoreboard\tests\external_integration_test.lua"
```

The tests exercise the real registry/Stats/main entry, end capture, renderer pass construction, and view update/click handlers with mocked engine boundaries. They cover namespace validation, accumulators, formatting, missing/zero, ranking, idempotence, reset, active restore, collector isolation, old history, provider removal, native-heading visibility, Tab refresh coalescing and immutable history. Tests are development files, never runtime-loaded.

Remaining in-game checks: register from a consumer loaded on each side of AnotherScoreboard; show numeric/text/missing rows in Tab; rebind J; click end/history groups; hide all native utility children; publish a burst while the scoreboard is open; disable/re-enable the provider; finish a mission with a collector; reopen that history without the provider; reconnect/hot-reload into an eligible active run and register late; start a fresh mission and verify reset. Check both Psykanium display and a regular dedicated-server mission. Offline checks establish neither GPU/input behavior nor measurement authority on a dedicated server.

### Implementation verification — 2026-09-10

- `external_stats_test.lua`: **120 checks passed** (including percent-encoded DMF names and late restore).
- `external_integration_test.lua`: **33 checks passed**.
- Canonical `tools/validate.ps1` checked the seven changed runtime Lua files and `types/dmf/identity.lua`. External, Stats, render, data, localization and identity annotations have **zero selected-file LuaLS diagnostics**.
- The canonical LuaLS run remains **non-clean: 25 existing diagnostics**, compared with the 77-diagnostic pre-edit baseline for main/Stats/render/view/data. `AnotherScoreboard.lua` has 23: two HUD registration missing-fields warnings, four nullable-use warnings, one `Keyboard` global warning, fourteen undefined-field warnings in existing Stats/stagger/render call sites, and two type mismatches. `AnotherScoreboard_view.lua` has two: `Keyboard` and `math.ease_sine`. None is reported in the external API code. The mod-local class exposes the existing API to LuaLS and removes many prior injected/undefined-field diagnostics; nullable view-module availability is now checked.
- Separate canonical `-SkipLuaLS` validation runs `luac55.exe -p` over the seven changed runtime files, both offline tests and the new identity type file. Lua 5.5 parser success is not proof of LuaJIT/native runtime behavior.
- Source review confirms the existing generic history serializer recursively stores complete snapshot tables, including new external metadata, without a field allowlist. No history serializer change was required.
- No game build/process/session was used. There is no observed in-game result, deployment, release or network test for this implementation.
