# Changelog

## 2.0.1

- The number after a boss name on its boss damage row, for example Daemonhost (2), now counts bosses killed. Before, a boss that was only hit also counted, such as a Daemonhost that was shot but left or was never killed. Damage to such a boss still shows on the row.
- New option "Show damage beside enemy kills" at the top of Toggle Stats in Scoreboard, off by default. It shows each player's damage beside the kills for Lesser Enemies, Specials, Elites, and each enemy type, for example 12 (3.4K), also in Scoreboard History. The damage includes enemies that survived or that another player killed, and it is only recorded while the option is on.

## 2.0.0

- Game update 1.13.0: Scoreboard History again shows Damnation and Auric instead of "Difficulty 5"; older history entries are fixed as well.
- Game update 1.13.0: the new bosses from the Torment event (Daemonhost) and the Spillway missions now count as bosses. The Spillway boss is listed as Prophet of Decay on its boss damage row; the Torment Daemonhost uses its in-game name.
- Fixed a boss sometimes being counted twice on its boss damage row, for example Prophet of Decay (2) after one kill, and a possible second Boss Popup. This happened when the game reported the death before the killing blow.
- Game update 1.13.0: Squad Loadouts again lists the player's talents and fills Signature talents from them when the tree has no pick for a category. Saved scoreboards from before 1.13.0 for Cryptic, Ogryn, Psyker, Veteran and Zealot show that the talent tree has changed, because those trees were reworked.
- The R hotkey is now "Damage Details". It still shows the DoT types and now also splits Other damage into Damage over time, Explosions, Arc lightning, Companion, Electrocution, and Unclassified. Scoreboards saved before this change have no Other damage breakdown.
- Live Stats can now show Other damage, Explosion damage, Arc lightning damage, and Electrocution damage.
- Removed the separate Companion damage row from the full scoreboard; companion damage is shown under Other damage with R and remains available in Live Stats.
- New Damage per second: Total damage divided by the mission time, shown under Damage dealt with R (also for saved history entries) and selectable in Live Stats.
- Squad Loadouts now shows the icon for combat abilities whose talent definition has no icon of its own, such as the Skitarii's Voltaic Expander.
- New visual design for the full scoreboard on the Tab overlay, end screen, and Scoreboard History: a title card, player header cards with class-colored bars, subtle player columns, left-aligned section headings with an accent marker, zebra and detail-row shading, and a green marker behind the best value in each ranked row.
- The scoreboard footer highlights hotkeys in the theme's accent color.
- New palettes for all six themes. Theme names and saved theme choices are unchanged, so existing users see the new look automatically. Live Stats and the Boss Popup keep their previous colors.
- Redesigned Squad Loadouts (U): player tabs with 1-4 key badges, a clickable Weapons & Signature Talents / Talent Tree switch, sectioned layout, weapon cards with stat bars and tier markers for perks and blessings, weapon hover cards with full perk and blessing descriptions, curio cards colored by type, and signature talent cards with category labels.
- Squad Loadouts keeps the same window size in both views and for players without a recorded loadout; the talent tree uses the larger area.
- Revives and rescues by the Skitarii medicae servo skull now count toward the Skitarii's Revives & Rescues, and net releases by the skull toward Disabled helped. Revives by a Veteran shout with the revive talent count toward the Veteran. They are detected client-side from the skull's heal effect, the forced assist, and the player's state change; player interactions are never counted twice.
- Live Stats shortens long player names with "..." so they fit on one line instead of wrapping.

## 1.2.8

- Increased Squad Loadouts weapon thumbnail render resolution to 600×216 while preserving their existing display size.

## 1.2.7

- Enlarged weapon thumbnails in Squad Loadouts and removed the Expertise and Base Rating labels to make room while keeping weapon stats, perks, and blessings.
- Preloaded weapon thumbnails when opening a saved mission scoreboard, so they can appear immediately on switching to Squad Loadouts; released the preloaded images on leaving that mission.
- Added three curio cards to Squad Loadouts, labeled by their main Health, Toughness, Stamina, or Wounds bonus. Hover a curio to see up to three additional perks.
- Captured curios in new mission snapshots. Older history entries remain compatible and show when curio data was not recorded; empty slots are distinguished from missing snapshot data.

## 1.2.6

- Repackaged v1.2.5 with an updated version label for installation testing; no runtime code changes.

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
