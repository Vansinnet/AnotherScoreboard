# AnotherScoreboard

A Darktide Mod Framework scoreboard with live mission statistics, end-of-mission results, boss damage popups, and persistent mission history with loadout snapshots.

## Installation

Install DMF, place the `AnotherScoreboard` folder in Darktide's mods directory, and add `AnotherScoreboard` to `mod_load_order.txt`.

## Download

Download `AnotherScoreboard.zip` from the [latest GitHub release](../../releases/latest). Do not use GitHub's source-code archives for installation.

## Loadouts and player actions

On the post-mission or history scoreboard, press **U** for Squad Loadouts. Player cards show class icons; signature talents show icons and names. Hover a signature card to read its description. Long descriptions have pages: use the mouse wheel while hovering the card.

Press **T** to show the full talent tree inside the loadout panel, using the game's native talent nodes, connections, icons and tooltip design. Selected nodes come from the saved mission build. Use the **mouse wheel** to zoom, **left-drag** to pan and **hover** for details. Long tooltip descriptions can be paged with the wheel over the tooltip. Press **1–4**, or click a player's number, to switch players. This view cannot spend or remove talent points. Snapshots whose layout or selected nodes no longer match the current game show a notice instead of an inaccurate tree.

Click a player heading or loadout player card to open the native Social menu with that player's popup selected. Bots have no social action. **Inspect** is available when supplied by the installed **InspectFromSocial** mod. The in-mission held-Tab scoreboard keeps its existing controls.

## External provider stats

AnotherScoreboard exposes a versioned, local-only external stats API. Providers can register collapsible groups, publish numeric or text rows, and optionally collect final totals before history capture. Saved rows remain readable without their provider installed.

See [External stats API v1](EXTERNAL_STATS_API.md) for definitions, examples, return codes, lifecycle/reset rules and verification instructions. In the Tab scoreboard, the configurable external-details key defaults to **J**; end screens and history use clickable group headings.

## License

Licensed under the [MIT License](LICENSE).
