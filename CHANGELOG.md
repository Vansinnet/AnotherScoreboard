# Changelog

## 1.2.5

- Kept players who leave within 30 seconds of the confirmed mission outcome on the end-of-mission scoreboard and in Scoreboard History.
- Marked retained late departures as **Left near match end** so the result does not imply that they remained connected.
- Kept bots on the final scoreboard when a player left earlier in the mission, preserving runs completed with a bot.
- Marked bot columns as **Bot** and prioritized current human replacements and reconnected players over departed players.
- Removed weapon Rank from Squad Loadouts and used the space for native weapon thumbnails rendered from Darktide's item assets.
- New mission snapshots retain the weapon model identifier needed for thumbnails; older history entries remain compatible but do not gain images retroactively.

## 1.2.4

- Preserved accumulated native and external statistics when a teammate disconnects and rejoins with the same account.
- Rebased unit-bound damage, state, disable, ability, ammo, and player caches when a player or unit is replaced, preventing false events and stale baselines after reconnecting.
- Merged same-session active-run checkpoints with statistics recorded after a local reconnect, hot reload, or mid-mission disable instead of replacing either side.
- Added a Social icon to player headings in saved Scoreboard History entries.
- The icon opens Darktide's native Social menu and player popup after loading current player information.
- Added Social actions to compatible history entries saved by earlier versions; bots and entries without a valid account ID remain non-interactive.

## 1.2.3

- Removed the Social menu action from player headings and loadout cards.
- Click anywhere on a player card in Squad Loadouts or the talent-tree view to select that player.
- The **1-4** keyboard shortcuts remain available for player selection.

## 1.2.2

- Added Simplified Chinese localization for mod options, scoreboards, history, loadouts, and enemy-detail rows.
- Added the **Recent history capacity** option with limits from 10 to 100 missions in steps of 10; the default remains 10.
- Added mouse-wheel scrolling, range indicators, and independent scroll positions for Recent and Saved history lists.
- Saved history remains unlimited.
- Corrected Simplified Chinese percentage formatting and a damage-over-time detail hint.

### Credits

- Simplified Chinese localization contributed by [Keaun (@liukangcc)](https://github.com/liukangcc) in [PR #1](https://github.com/Vansinnet/AnotherScoreboard/pull/1).
