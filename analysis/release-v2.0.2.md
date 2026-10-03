# AnotherScoreboard v2.0.2 release record

Date: 2026-10-03. Repository: https://github.com/Vansinnet/AnotherScoreboard.

## Source and package

- Authoritative source: `mods/active/AnotherScoreboard/`, based on `a96675e` (v2.0.1), with the local sourceless-debuff attribution and phosphor classification changes.
- Version: v2.0.2 in README, changelog, and GitHub release/tag. The DMF manifest does not declare a version field.
- ModID and installed folder: `AnotherScoreboard`; all self `get_mod()` calls and the three manifest script paths agree. DMF is required; the manifest declares no resource packages.
- Standard-profile artifact: `releases/AnotherScoreboard/v2.0.2/AnotherScoreboard.zip`.
- ZIP SHA-256: `50D6AB8462EBE165A1F9B9578F67D21FB686034257DB1E8737DBD80069E47780`.
- Source-file manifest: `releases/AnotherScoreboard/v2.0.2/AnotherScoreboard.source.sha256` (29 files).
- Archive checksum record: `releases/AnotherScoreboard/v2.0.2/AnotherScoreboard.zip.sha256`.
- Inspected all 29 ZIP entries: one `AnotherScoreboard/` root, `.mod`, README, LICENSE, and 26 runtime Lua files. Paths use `/`; no duplicate mod root, tools, tests, archives, secrets, or development companions are included. The wrapper rejects prohibited files and reparse points.
- Excluded development/repository files: `.git/`, `tests/`, `analysis/`, `CHANGELOG.md`, and `EXTERNAL_STATS_API.md`. Forced-assist diagnostics are intentionally gated by its existing `DEBUG` flag; no new probes or debug commands were added.
- No settings or localization keys changed.

## Source review

Reviewed against `darktide-source/Darktide-Source-Code-1.13.0/`:

- `scripts/settings/buff/archetype_buff_templates/zealot_buff_templates.lua:5020-5058`: Fire and Fury is a server-only on-hit proc and adds `flamer_assault` without `owner_unit`.
- `scripts/settings/buff/weapon_buff_templates.lua:50-76`: `flamer_assault` ticks use the `burning` damage profile and the server-side owner, which can be absent. Lines 2440-2471 establish `phosphor_burning` as burning damage.
- `scripts/extension_systems/buff/buff_extension_base.lua:434-510`: `_add_buff(self, template, t, from_server_correction, ...)` returns the local index; stacks reuse the existing instance. Lines 1388-1415 resolve replicated owners and call `_add_buff` on the instance, supporting the hook on `MinionBuffExtension` rather than only its base class.
- `scripts/extension_systems/buff/minion_buff_extension.lua:343-374`: buff owner replication and `_add_buff` call/return path.
- `scripts/managers/attack_report/attack_report_manager.lua:100-157`: attack-report hook signature and nullable network-resolved units. Both hooks preserve the original call and return.
- `scripts/managers/player/human_player.lua:127-129`: `profile()` returns the player's current profile; the new helper guards missing profile/talents.
- The new unit-bound tables have weak keys and reset through `_clear_unit_runtime_caches`, reached on disable, unload, gameplay exit, and runtime reset. No predicted gameplay components are written.
- Existing require-hook registration can attempt rehooking on repeated require; DMF `scripts/mods/dmf/modules/core/hooks.lua:227-254` deduplicates the same mod/function and warns or replaces its handler. This pre-existing registration pattern is unchanged; reload remains an untested context.
- No engine signature declaration was changed by this release review. A future narrow LuaCATS addition could declare the currently undeclared `_add_buff(template, t, from_server_correction, ...): integer` and `has_buff_using_buff_template(buff_template_name): boolean` contracts from `buff_extension_base.lua:434-510,764-777`, with entries in `types/SOURCES.md`; metadata is not packaged.

## Validation and disposition

1. `powershell -NoProfile -ExecutionPolicy Bypass -File tools\release-mod.ps1 -Mod AnotherScoreboard -OutputDirectory releases\AnotherScoreboard\v2.0.2`
   - Initial attempt exceeded the 120-second command timeout; rerun with a 600-second timeout completed the checks.
   - LuaJIT and Lua 5.5 syntax checks completed for all 27 Lua/manifest files.
   - LuaLS reported 63 warnings in 8 files, so the wrapper returned failure and did not build an archive.
2. `tools\validate.ps1 -Path <temporary v2.0.1 worktree>\scripts`
   - Rechecked tag v2.0.1 using the same workspace configuration and tools.
   - The same 63 diagnostics appeared, matching file, message, diagnostic code, and unchanged source location after accounting for line shifts. No new diagnostics in v2.0.2; the new sourceless module and changed stats module had none.
   - Existing diagnostics include undeclared dynamic mod fields/globals, injected fields, optional HUD settings, a table/string inference mismatch, and nil-check warnings in unchanged code. These remain unresolved; this release does not claim a clean LuaLS pass or establish that every existing warning is harmless.
   - The temporary baseline worktree was removed.
3. `powershell -NoProfile -ExecutionPolicy Bypass -File tools\release-mod.ps1 -Mod AnotherScoreboard -OutputDirectory releases\AnotherScoreboard\v2.0.2 -SkipLuaLS`
   - Explicit disposition: carried forward the reviewed, unchanged LuaLS baseline from v2.0.1. LuaLS was already run above; only its repeat during artifact construction was skipped.
   - LuaJIT parse and `luac55.exe -p` passed for all 27 runtime files; the wrapper built the ZIP, inspected every entry, and generated both checksum records.
4. LuaJIT offline tests from the workspace root:
   - `tools\luajit\luajit.exe mods\active\AnotherScoreboard\tests\sourceless_test.lua`: 34 checks passed.
   - `tools\luajit\luajit.exe mods\active\AnotherScoreboard\tests\boss_finalize_test.lua`: 15 checks passed.
   - `tools\luajit\luajit.exe mods\active\AnotherScoreboard\tests\kill_damage_test.lua`: 19 checks passed.
5. `git diff --check`: passed.

## Runtime coverage and rollback

No deployment, live LuaExec query, or in-game verification was performed for this release. Source evidence is for Darktide 1.13.0; offline tests are not dedicated-server evidence.

Remaining manual checks: Fire and Fury damage/debuff/kill credit and phosphor burning classification in Psykanium and a real dedicated-server mission; Skitarii skull credit with interleaved players and both event orders; enable/disable, reload, mission exit, and the next mission. Actual network ordering and attribution in multiplayer remain unverified. The 0.5-second source-player match is heuristic when several qualifying players hit the same enemy.

Rollback: reinstall the v2.0.1 release ZIP from GitHub. The previous source is retained at tag `v2.0.1` / commit `a96675e`; v2.0.2 settings retain the same ModID.
