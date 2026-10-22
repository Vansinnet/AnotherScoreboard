# AnotherScoreboard: design

This file starts with the History class filter, the scripted-death boss kill, the best/worst highlight settings and the scoreboard view packages. Older features are described in `README.md`, `EXTERNAL_STATS_API.md` and `types/CONTRACTS.md` (workspace root); add them here when they are next changed.

## History class filter

### Decisions

- The History view (`AnotherScoreboard_history_view.lua`) filters both Recent and Saved by the class the local player played in each mission. "All" shows everything and is the default each time the view opens.
- A filter button is shown for every class the player owns, including classes with no matches yet. Base classes (`requires_dlc == nil`) are always owned. A DLC class is shown only after `Managers.dlc:is_owner_of(archetype.requires_dlc)` resolves true, the same check `DLCUtils.is_archetype_available` uses on the class selection screen. A failed or negative check hides the button.
- The classes come from `scripts/settings/archetype/archetypes`, sorted by `ui_selection_order` like the cosmetics vendor tabs, so a new class gets a button without a mod change. Buttons show the class icon (`UISettings.archetype_font_icon`, font `itc_novarese_bold`, as in the live scoreboard).
- Clearing Recent (SPACE) is disabled while a class filter is active, so it never looks like it clears only one class.

### How it works

- `History.save` stores `local_archetype` in the mission file and the index entry.
- `History.entry_local_archetype(entry, account_id)` returns `local_archetype` when present. Older entries are matched by the local player's account id (`account_id()` or `name()`, the same id the scoreboard stores per player); the class comes from the player's `loadout_snapshot.archetype` (mission files) or from the class icon (index entries), and all seven icons are distinct.
- An entry whose local player cannot be found has no class and is shown only under "All".
- The ownership promise can resolve after the view closes; `on_exit` sets `_closed` and the callback then does nothing. On resolve the view rebuilds through `_rebuild_requested`.

### Source contracts

- `DLCManager.is_owner_of(self, dlc_id, force_refresh)` returns a promise that resolves to a boolean; platform errors resolve to false (`darktide-source/scripts/managers/dlc/dlc_manager.lua:80-110`). `Managers.dlc` exists on every client (`scripts/game_states/state_game.lua:289-291`). Steam answers through `Steam.is_subscribed` (`scripts/managers/account/account_manager_steam.lua:71-75`); PSN and Xbox answer later.
- `requires_dlc` on archetype templates: `adamant`, `broker`, `cryptic`; base classes have none (`scripts/settings/archetype/archetypes/*_archetype.lua`).
- `Archetypes[name].name` and `.ui_selection_order` (`scripts/settings/archetype/archetypes.lua:6-18`).

### Tests

- `tests/history_filter_test.lua`: stored and derived classes, missing local player, filtering and the saved field.

### Runtime status

- Not yet tested in game.

### Open items

- A player who loses access to a DLC class (refund, Family Sharing) loses its button; those missions stay under "All".

## Scripted-death boss kills (Prophet of Decay)

### Decision

Since Darktide 1.13.3 the Prophet of Decay (`renegade_wizard`) has `has_scripted_death_sequence`. Its killing blow reports `"damaged"`, and it never reaches `MinionDeathManager.set_dead`, so neither the attack-report kill nor the `set_dead` fallback ran: no kill, no boss row count and no boss popup. The kill is now read from its health, the same way Logis does it (Logis `f5ea4d1`).

### How it works

- `Stats.handle_attack` remembers the last account that dealt damage > 0 to a breed with `has_scripted_death_sequence`, unless the unit is already in `_killed_units` (weak-keyed `_scripted_death_hitters`).
- `mod.update` calls `Stats.update_scripted_deaths(_record_enemy_death)` every frame. It returns at once when nothing is watched. A watched unit whose `current_health_percent()` is `<= 0` is reported once and dropped. A unit that is no longer alive, or is already in `_killed_units`, is dropped without a kill.
- `_record_enemy_death` is the body of the `set_dead` hook: aggro finalize, `record_kill_from_death` (total kills, deduplicated through `_killed_units`), `finalize_boss_encounter` (boss row count and popup data, once per boss), and the popup queue. A later `"died"` report or `set_dead` therefore adds nothing.
- The watch is cleared with the rest of the kill tracking: `Stats.clear` (mission start, disable, unload), `Stats.clear_kill_tracking`, and `_clear_unit_runtime_caches` on mission exit.
- The killing blow's damage was already recorded: the mod hooks `AttackReportManager.add_attack_result`, before `_process_attack_result` drops reports on such a breed at zero health.

### Source contracts

- `renegade_wizard_breed.lua:47` sets `has_scripted_death_sequence = true` (new in 1.13.3, replacing `skip_kill_feed_announcement`).
- `attack.lua:539-541` turns `"died"` into `"damaged"` for such a breed inside `_handle_attack`; the server's report (`attack.lua:387`) and the clients' RPC carry the converted result (`attack_report_manager.lua:147-158`).
- `attack_report_manager.lua:175-177` drops buffered reports on such a breed at zero health; `add_attack_result` (line 101) runs before that.
- `bt_wizard_die_action.lua` never calls `MinionDeath.set_dead`; `spillway_wizard.lua:600-640` (`_kill_all_enemies`) skips the boss.
- Health: minions get `HealthExtension` on the server and `HuskHealthExtension` on clients (`minion_unit_template.lua:449`); both have `current_health_percent()` (`health_extension.lua:65-73`, `husk_health_extension.lua:47-55`). The game uses the same `<= 0` test for this breed (`attack_report_manager.lua:175`).

### Tests

- `tests/boss_finalize_test.lua` section 5: the kill fires once at zero health for the last player who dealt damage, with one popup and one boss row count; a later `set_dead` or hit adds nothing; a `"died"` report still counts once; a despawned unit, a cleared watch and a boss without the flag give no kill.

### Runtime status

- Not yet tested in game.

## Best and worst highlight settings

- `highlight_best` and `highlight_worst` (Scoreboard Appearance, both on by default, so existing users see no change) turn off the green best value with its marker and the red worst value in full scoreboards: Tab overlay, scoreboard view, end screen and history. When off, the value keeps the row's normal colour. Ranking itself is unchanged.
- `_combined_panel_passes` sets the render module's `_highlight_best` and `_highlight_worst` from the render settings, the same way the theme is set per build; `_row_player_data` reads them. A change rebuilds an open scoreboard like the other appearance settings.
- No offline harness covers the rendering; tested only by validation.

## Scoreboard view packages

### Decision

Players reported a pause before the end-of-mission scoreboard. Console logs (`[Profiler] [main] Stall`) showed a 5.4 s `Lua->update` stall at every mission end up to v2.0.2, from `History.prune`'s `io.popen('dir')`; v2.0.3 removed it, and the save itself costs about 14 ms (measured offline on real 380 KB history files). What remains on the developer's PC is about 0.3-0.8 s, mostly GPU resource upload while the end screen and the scoreboard view load. The view loaded the talent packages of all seven classes every time it opened, and released them when it closed. It now loads only the classes of the players it shows. The gain is not measured.

### How it works

- `mod.scoreboard_view_packages(archetypes)` returns the three base packages (options view, training grounds options view for the weapon icon frame, talent builder) plus `packages/ui/views/talent_builder_view/<class>` for each class in the set, or for every class in `AnotherScoreboard_archetypes.lua` when the set is nil. Registration uses the full list.
- `mod.prepare_scoreboard_view_packages(players)` runs right before every open (end screen and history entry). It uses each player's `loadout_snapshot.archetype`, the same field the loadout panel and talent tree draw from. If there are no players, or any player has no snapshot or an unknown class, it loads every class, as before.
- These are module functions, not locals: the main chunk is at Lua's 200-local limit.

### Source contracts

- `UIManager.load_view` reads `Views[view_name].package` (a string or an array) each time a view is created (`darktide-source/scripts/managers/ui/ui_manager.lua:1152-1196`), from `BaseView.init` (`ui/views/base_view.lua:45`). `UIViewHandler._open` creates the instance synchronously (`managers/ui/ui_view_handler.lua:741-800`); `settings_override` clones the settings only for the instance.
- `Views` is the view handler's `_view_list` (`ui_manager.lua:23,79`, `ui_view_handler.lua:17-18`), and DMF stores the registered `view_settings` there (`dmf-source/scripts/mods/dmf/modules/gui/custom_views.lua:94`).
- `UIManager.unload_view` releases the packages stored at load (`ui_manager.lua:1304-1324`), so changing the list for the next open does not affect an open view.
- `PackageManager._bring_in` calls `ResourcePackage.flush` on the main thread when a package finishes loading (`foundation/managers/package/package_manager.lua:140-158`).
- `load_always` and `load_in_hub` in the registration are not read by the game or DMF; nothing is preloaded.

### Tests

- `tests/external_integration_test.lua`: package lists for known classes, a player without a snapshot, an unknown class, no players and an empty list.

### Runtime status

- Not yet tested in game. The pause is unchanged when the four players have four different classes, and the remaining cost of the end screen itself is not measured.
