# AnotherScoreboard offline tests

Run from the workspace root with LuaJIT (`tools/luajit/luajit`, or `tools\luajit\luajit.exe` on Windows):

```
tools/luajit/luajit mods/active/AnotherScoreboard/tests/<name>.lua
```

These are offline results with mocked engine natives, not in-game results.

| Test | Covers | Last result (2026-09-29, LuaJIT) |
|---|---|---|
| `boss_finalize_test.lua` | A boss killed once counts once and gives one popup, whether the death or the killing blow's attack report arrives first; the count is kills, so a boss that is only damaged or leaves adds no count but keeps its damage, and such a row survives export/import; since 1.13.3 the Prophet of Decay (scripted death sequence, killing blow reported as damaged, no set_dead) counts its kill from zero health once, for the last player who dealt damage, with one popup | 33 checks passed (2026-10-22); the scripted-death section fails on the pre-fix `AnotherScoreboard_stats.lua` |
| `kill_damage_test.lua` | Damage beside enemy kills: off records nothing; on records category and enemy-type damage (survivors included, overkill capped, bosses and unknown breeds excluded); saved in history rows and rejoin data; older runs import | 19 checks passed (2026-09-30) |
| `companion_damage_test.lua` | Skitarii servo skull shots and flamer hits (reported as ranged) and dog attacks count as Other damage > Companion and companion damage, not as ranged damage or melee/ranged hits; skull killing blows count as companion kills; the player's own hits are unchanged | 20 checks passed (2026-10-13); fails on the pre-fix `AnotherScoreboard_stats.lua` (check 2, skull shot counted as ranged) |
| `fun_facts_test.lua` | Fun Facts (Beta): hits that cost HP count only direct hits with health or corruption damage (no toughness-only hits, no ticks without an attack type or with `buff`); teammates hurt counts health or toughness damage on another player (not `friendly_fire`, self or ticks); highest single hit keeps the largest melee/ranged hit on an enemy, overkill included, without companion, explosion or push hits; the section, row order, saved rows, rejoin merge (max for highest hit) and older runs import; the rows use the detail row size; the three rows are Live Stats choices and every Live Stats catalog stat exists | 74 checks passed (2026-10-16) |
| `external_stats_test.lua` | External stats API | 132 checks passed |
| `external_integration_test.lua` | External provider integration; the real section filter shows saved Fun Facts rows at detail size and drops a saved Ranged misses row; the scoreboard view loads only the shown players' class talent packages, and every class when a class is unknown or no players are given; loading the main chunk also catches the 200-local limit | 47 checks passed (2026-10-22); the Fun Facts check fails without the filter fix (check 6) |
| `history_filter_test.lua` | History class filter: the local player's class from the stored `local_archetype`, the loadout snapshot or the class icon (all seven icons), by account id or name; teammates' classes, a missing local player and entries without players never match; filtering keeps the source list; `History.save` stores the class in the mission file and the index. Takes an optional scratch directory for the save check | 28 checks passed (2026-10-22) |
| `forced_assist_test.lua` | Forced assist detection | 9 checks passed |
| `curios_test.lua` | Curio snapshots and hover | passed |
| `sourceless_test.lua` | Debuffs the game adds without a source player (Zealot Fire and Fury burn, Skitarii skull hack and burn): attributed whether the debuff or the attack report arrives first, only within 0.5 s, only to the listed class with the required talent, past another class's hit; a stack keeps the instance owner, a new instance clears it; burn ticks go to the attributed Zealot | 34 checks passed (2026-10-03) |
