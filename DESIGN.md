# AnotherScoreboard: design

This file starts with the History class filter. Older features are described in `README.md`, `EXTERNAL_STATS_API.md` and `types/CONTRACTS.md` (workspace root); add them here when they are next changed.

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
