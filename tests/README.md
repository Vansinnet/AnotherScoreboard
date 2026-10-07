# AnotherScoreboard offline tests

Run from the workspace root with LuaJIT (`tools/luajit/luajit`, or `tools\luajit\luajit.exe` on Windows):

```
tools/luajit/luajit mods/active/AnotherScoreboard/tests/<name>.lua
```

These are offline results with mocked engine natives, not in-game results.

| Test | Covers | Last result (2026-09-29, LuaJIT) |
|---|---|---|
| `boss_finalize_test.lua` | A boss killed once counts once and gives one popup, whether the death or the killing blow's attack report arrives first; the count is kills, so a boss that is only damaged or leaves adds no count but keeps its damage, and such a row survives export/import | 15 checks passed (2026-09-30); fails on the pre-fix `AnotherScoreboard_stats.lua` (check 9, damaged boss counted) |
| `kill_damage_test.lua` | Damage beside enemy kills: off records nothing; on records category and enemy-type damage (survivors included, overkill capped, bosses and unknown breeds excluded); saved in history rows and rejoin data; older runs import | 19 checks passed (2026-09-30) |
| `external_stats_test.lua` | External stats API | 132 checks passed |
| `external_integration_test.lua` | External provider integration | 36 checks passed |
| `forced_assist_test.lua` | Forced assist detection | 9 checks passed |
| `curios_test.lua` | Curio snapshots and hover | passed |
| `sourceless_test.lua` | Debuffs the game adds without a source player (Zealot Fire and Fury burn, Skitarii skull hack and burn): attributed whether the debuff or the attack report arrives first, only within 0.5 s, only to the listed class with the required talent, past another class's hit; a stack keeps the instance owner, a new instance clears it; burn ticks go to the attributed Zealot | 34 checks passed (2026-10-03) |
