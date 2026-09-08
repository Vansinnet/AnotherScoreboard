return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`AnotherScoreboard` failed loading DMF.")
		new_mod("AnotherScoreboard", {
			mod_script       = "AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard",
			mod_data         = "AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_data",
			mod_localization = "AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_localization",
		})
	end,
	packages = {},
}
