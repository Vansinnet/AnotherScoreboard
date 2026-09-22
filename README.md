# AnotherScoreboard

A detailed, performance-focused scoreboard for Warhammer 40,000: Darktide. Track the mission while you play, review end-of-mission results, monitor a configurable Live Stats HUD, see boss-damage summaries, and keep a persistent local history of completed missions.

## Installation

Install Darktide Mod Framework (DMF), place the `AnotherScoreboard` folder in Darktide's mods directory, and add `AnotherScoreboard` to `mod_load_order.txt`.

Download `AnotherScoreboard.zip` from the [latest GitHub release](../../releases/latest). Do not install GitHub's source-code archives.

## Main Features

### Full Scoreboard During Missions

Hold **Tab** to open Darktide's tactical overlay and see the full scoreboard while the mission is still in progress. Each player has a class icon and a color-coded column. Ranked rows highlight the best and worst values; lower values are correctly treated as better for statistics such as HP Lost, Downs & Deaths, and Disabled.

The scoreboard tracks:

- Total, Special, Elite, ranged Elite, melee Elite, and companion kills
- Total, melee, ranged, other, damage-over-time, companion, and boss damage
- Bleeding, Soulblaze, Burning, and Toxin damage
- Weakspot hits and ratio, critical hits and ratio, staggers, and debuffs
- HP Lost, Downs & Deaths, Revives & Rescues, Disabled, and Disabled helped
- Medicae uses, ammo pickups, ammo gained, ability uses, aggro, and coherency

Accumulated statistics remain associated with a player's account when that player disconnects and rejoins during the same mission. Same-session recovery also preserves eligible in-process active-run checkpoints across a local reconnect, hot reload, or mid-mission disable.

### Expandable Detail Rows

Use the full scoreboard without permanently filling it with every breakdown:

- **E:** Special and Elite kill details
- **R:** Damage-over-time type details
- **T:** Boss-type damage details
- **Y:** Survival details, including Downs, Deaths, ability-use rate, and average time between uses

Only one built-in detail group is expanded at a time. The enemy breakdown covers Pox Hounds, Mutants, Trappers, Poxbursters, Bombers, Snipers, Flamers, Ragers, Maulers, Bulwarks, Crushers, Gunners, Shotgunners, Reapers, and Plasma Gunners.

Boss details cover Beast of Nurgle, Daemonhost, Chaos Spawn, Plague Ogryn, Captains, Twins, Hexbound Daemonhost, and Pack Master encounters when present.

### End-of-Mission Scoreboard

AnotherScoreboard can automatically open when the mission ends. It has independent scale, opacity, and position settings, so a large end-screen result does not change the in-mission Tab layout. The same detail controls are available on the end screen.

Players who leave within 30 seconds of the confirmed mission outcome remain in the final scoreboard and history with a **Left near match end** label. If someone left earlier and the squad completed the mission with a bot, the bot remains in that slot and is labeled **Bot**. A current human replacement or reconnected player always takes priority.

### Configurable Live Stats HUD

The Live Stats HUD shows all human players and one to three selected statistics while you play. It is designed for quick comparisons without opening the full scoreboard.

- Choose from 36 supported statistics, including damage, kills, survival, accuracy, boss damage, DoT, ammo, ability, aggro, and coherency values
- The first Live Stat controls player sorting
- Lower-is-better statistics sort in the correct direction
- Duplicate selections swap columns instead of producing repeated values
- Save separate Live Stats choices for each player class
- Adjust scale, position, and background opacity

### Boss Damage Popup

When a tracked boss dies, a compact popup summarizes each player's contribution to that encounter.

- Player names and class icons
- Damage values and percentage share of tracked player damage
- Optional total damage
- Up to four players, sorted by damage
- Multiple boss deaths are queued and shown in sequence

Damage, percentage, total, scale, duration, position, and background opacity are individually configurable. Changing presentation settings also shows a preview.

### Persistent Scoreboard History

AnotherScoreboard saves completed missions that reach the ending screen. **Recent history capacity**, next to the history keybind in Mod Options, selects 10–100 entries in steps of 10 (default: 10).

Reopen history after changing the capacity to refresh the list; the next completed mission save also uses the new limit. Changing the setting or reopening history does not delete excess Recent files. They are pruned on the next completed mission save. Increasing the limit cannot restore missions already deleted. Use the mouse wheel to scroll Recent or Saved; each tab remembers its own position while history is open.

Open Scoreboard History with **F5** by default while in the Mourningstar or Psykanium. The keybind can be changed in Mod Options.

History entries include mission, game type, difficulty, completion time and date, players, outcome, mission conditions, Havoc rank and modifiers, and the complete recorded scoreboard. History recognizes standard missions, Auric and Maelstrom missions, Havoc, Expeditions, and Mortis Trials.

Click the Social icon beside a player in Scoreboard History to open Darktide's native Social menu and player popup. Bots and history entries without a valid account ID have no Social action.

Copy a Recent mission to the separate, unlimited **Saved** collection to keep it permanently. Saved missions can have custom names, can be renamed later, and can be removed individually. Clearing Recent history or reducing its capacity does not remove Saved missions.

History files are stored locally under:

```text
%APPDATA%\Fatshark\Darktide\AnotherScoreboard_history\
```

### Squad Loadouts and Talent Trees

On an end-of-mission or history scoreboard, press **U** to open Squad Loadouts. Player cards show class icons, weapons, and recorded signature talents. Hover a signature talent for its description; long descriptions can be paged with the mouse wheel.

Press **T** inside Squad Loadouts to show that player's full talent tree using the game's native node, connection, icon, and tooltip styling. Use the mouse wheel to zoom, left-drag to pan, and hover a node for details. Press **1-4**, click anywhere on a player card, or use the wheel in the loadout view to change player. This view is read-only: it cannot spend or remove talent points.

Talent trees come from the saved mission build. If the current game tree no longer matches the saved layout or selections, AnotherScoreboard displays a notice instead of an inaccurate tree.

### External Provider Stats

Other mods can add local-only, collapsible stat groups to the full scoreboard. External rows can show numeric or text values, can appear under a built-in category or their own category, and are retained in mission history even if the provider mod is later disabled or removed.

In the Tab scoreboard, the configurable **External stat details** key defaults to **J** and toggles all collapsible external groups. End screens and history use clickable group headings. This does not affect the compact Live Stats HUD.

Mod authors should use the separate [External Stats API v1](EXTERNAL_STATS_API.md) documentation for registration, values, lifecycle rules, and examples.

## Mod Options

Settings are organized by feature:

- **Scoreboard Appearance:** theme, text scale, local-player-first ordering, and row shading
- **In-Mission Scoreboard (Tab):** enable, scale, opacity, and position
- **End-of-Mission Scoreboard:** automatic display, scale, opacity, and position
- **Live Stats HUD:** enable, class-specific columns, scale, position, and background opacity
- **Boss Damage Popup:** enable, displayed columns, scale, duration, position, and background opacity
- **Toggle Stats in Scoreboard:** visibility of individual built-in combat and survival rows
- **Keybinds:** Scoreboard History and External stat details

Hiding a built-in row affects only its display. The mod continues to track and save that statistic.

## Controls

| Control | Action |
| --- | --- |
| Tab | Open the in-mission tactical overlay scoreboard |
| E | Show or hide Special and Elite kill details |
| R | Show or hide damage-over-time details |
| T | Show or hide boss-type damage details; toggle the talent tree in Squad Loadouts |
| Y | Show or hide survival details |
| U | Open or close Squad Loadouts on end-of-mission and history scoreboards |
| J | Toggle collapsible external stat groups while Tab is held; configurable |
| F5 | Open Scoreboard History by default in the Mourningstar or Psykanium; configurable |
| Q | Hide or show the end-of-mission scoreboard |
| Esc | Close history or return from Squad Loadouts |
| Space | Clear the Recent history list |
| Mouse wheel | Scroll Recent or Saved history; change loadout player; zoom/paginate in the talent-tree view where applicable |

## Requirements

- Warhammer 40,000: Darktide
- Darktide Mod Framework (DMF)

No other mod is required. Havoc modifier colors used by Scoreboard History are included directly in AnotherScoreboard.

## Important Notes

- Statistics are collected client-side from events visible to the mod. They are not official Fatshark or server-authoritative statistics.
- Live Stats shows human players and supports Darktide's four-player team size.
- Scoreboard History is available from the Mourningstar or Psykanium, not during a regular mission.
- Recent history retains 10–100 missions (default: 10). The unlimited Saved collection is not cleared with Recent history.
- User-facing text is available in English and Simplified Chinese.

## How Statistics Are Calculated

The formulas below are simplified. A *count* is the number of matching events detected by the mod; a *sum* adds all matching values.

### Damage

AnotherScoreboard uses actual enemy health removed rather than unlimited reported hit damage:

```text
Actual damage for a hit = minimum(reported damage, enemy health remaining)
Total damage = sum of actual damage from all hits
```

This limits overkill damage when the final hit is larger than the enemy's remaining health.

| Statistic | Simplified calculation |
| --- | --- |
| Total Damage / Live Damage | Sum of actual damage credited to the player |
| Melee Damage | Sum of actual damage from attacks classified as melee |
| Ranged Damage | Sum of actual damage from attacks classified as ranged |
| Other Damage | Total Damage minus Melee Damage minus Ranged Damage |
| Damage over Time | Sum of actual damage from recognized DoT profiles |
| Bleeding / Soulblaze / Burning / Toxin | Sum of matching DoT damage |
| Companion Damage | Sum of actual damage caused by the player's companion attacks |
| Boss Damage | Sum of actual damage dealt to tracked bosses |
| Boss Type Damage | Boss Damage grouped by individual boss type or encounter |
| Boss Popup Percentage | Player Boss Damage / Total Tracked Player Boss Damage x 100 |

DoT, companion, and boss damage are detail categories inside Total Damage. Do not add them to Total Damage a second time.

### Kills

| Statistic | Simplified calculation |
| --- | --- |
| Total Kills | Count of enemies where the player or attributed attack delivered the killing blow |
| Specials Killed | Count of Total Kills classified as Specials |
| Elites Killed | Count of Total Kills classified as Elites |
| Ranged Elites / Melee Elites | Elite kills grouped by ranged or melee breed |
| Individual Enemy Kills | Special or Elite kills grouped by enemy breed |
| Companion Kills | Count of killing blows caused by the player's companion attacks |

The same defeated enemy is deduplicated so separate damage and death reports do not count it twice.

### Accuracy and Utility

| Statistic | Simplified calculation |
| --- | --- |
| Weakspot Hits | Count of attacks reported as hitting a weakspot |
| Weakspot Hit Ratio | Weakspot melee/ranged hits / all valid melee/ranged hits x 100 |
| Critical Hits | Count of critical attacks that dealt more than zero damage |
| Critical Hit Ratio | Critical melee/ranged hits / all valid melee/ranged hits x 100 |
| Enemies Staggered | Count of qualifying stagger events credited to the player |
| Debuffs Applied | Count of newly activated tracked debuff groups applied to enemies |

An enemy can contribute more than one stagger if it is staggered by multiple qualifying attacks.

### Survival

| Statistic | Simplified calculation |
| --- | --- |
| HP Lost | Sum of positive increases in the player's accumulated health damage |
| Downs & Deaths | Number of transitions into knocked-down or dead states |
| Revives & Rescues | Count of successful revives and rescues credited to the player |
| Disabled | Number of new disabling states such as nets, pounces, grabs, or being consumed |
| Disabled Helped | Count of credited assists that free a disabled teammate |
| Medicae Uses | Count of successful health-station interactions |

Healing does not subtract from HP Lost. Lower values are treated as better for HP Lost, Downs & Deaths, Disabled, and Medicae Uses.

### Ammo, Abilities, Aggro, and Coherency

| Statistic | Simplified calculation |
| --- | --- |
| Ammo Pickups | Count of recognized ammo pickups collected |
| Ammo Gained | Sum of positive magazine plus reserve-ammo changes after pickups |
| Ability Uses | Count of detected decreases in combat-ability charges |
| Enemies Aggroed | Count of unique enemy-to-player aggro credits detected during target sequences |
| Coherency | Time near at least one teammate / eligible alive time x 100 |

Ammo Pickups measures how many pickups were taken, while Ammo Gained estimates how much ammunition they restored. An enemy can credit more than one player if it clearly switches targets during its lifetime, but is counted at most once per player. Dead or hogtied time is excluded from Coherency eligible time.

### Display and Ranking

- Counts display as whole numbers.
- Large damage values use `K` or `M` where needed.
- Ratios and coherency display as rounded whole percentages.
- Green marks the best value and red marks the worst value on ranked rows.
- For negative statistics such as HP Lost and Disabled, the lowest value is ranked best.

## License

Licensed under the [MIT License](LICENSE).
