local mod = get_mod("AnotherScoreboard")
local enemies = mod:io_dofile("AnotherScoreboard/scripts/mods/AnotherScoreboard/AnotherScoreboard_enemies")

local localization = {
    player_bot = {
        en = "Bot",
        ["zh-cn"] = "机器人",
    },
    player_left_near_end = {
        en = "Left near match end",
        ["zh-cn"] = "临近结束时离开",
    },
    external_details_key = {
		en = "External stat details (Tab scoreboard)",
		["zh-cn"] = "外部统计详情（Tab 记分板）",
	},
    external_details_key_description = {
		en = "Toggle all collapsible external stat groups in the in-mission Tab scoreboard. End screens and history use clickable group headings.",
		["zh-cn"] = "切换任务中 Tab 记分板内所有可折叠的外部统计分组。结算界面和历史记录可点击分组标题。",
	},
    loadout_title = {
		en = "Squad Loadouts",
		["zh-cn"] = "小队配装",
	},
    loadout_equipment = {
        en = "Weapons & Signature Talents",
        ["zh-cn"] = "武器与标志性天赋",
    },
    loadout_tree = {
        en = "Talent Tree",
        ["zh-cn"] = "天赋树",
    },
    loadout_readonly = {
        en = "MISSION SNAPSHOT  /  READ ONLY",
        ["zh-cn"] = "任务快照 / 只读",
    },
    loadout_missing = {
        en = "No loadout was recorded for this player.\nLoadouts are saved with new mission results.",
        ["zh-cn"] = "未记录该玩家的配装。\n新的任务结果保存后才会记录配装。",
    },
    loadout_no_weapon = {
        en = "Weapon not recorded",
        ["zh-cn"] = "未记录武器",
    },
    loadout_no_selection = {
        en = "None recorded",
        ["zh-cn"] = "未记录",
    },
    loadout_no_description = {
        en = "No description available.",
        ["zh-cn"] = "暂无描述。",
    },
    loadout_curios = {
        en = "Curios",
        ["zh-cn"] = "珍品",
    },
    loadout_curio_hover = {
        en = "Hover over a curio to see its bonuses",
        ["zh-cn"] = "悬停珍品查看附加属性",
    },
    loadout_curios_unrecorded = {
        en = "Curios were not recorded for this mission.",
        ["zh-cn"] = "本次任务未记录珍品。",
    },
    loadout_curio_empty = {
        en = "Empty slot",
        ["zh-cn"] = "空栏位",
    },
    loadout_curio_health = {
        en = "Health",
        ["zh-cn"] = "生命值",
    },
    loadout_curio_toughness = {
        en = "Toughness",
        ["zh-cn"] = "韧性",
    },
    loadout_curio_stamina = {
        en = "Stamina",
        ["zh-cn"] = "体力",
    },
    loadout_curio_wounds = {
        en = "Wounds",
        ["zh-cn"] = "伤口",
    },
    loadout_curio_unknown = {
        en = "Curio",
        ["zh-cn"] = "珍品",
    },
    loadout_perks = {
        en = "PERKS",
        ["zh-cn"] = "专长",
    },
    loadout_blessings = {
        en = "BLESSINGS",
        ["zh-cn"] = "祝福",
    },
    loadout_stats = {
        en = "BASE RATING",
        ["zh-cn"] = "基础评级",
    },
    loadout_expertise = {
        en = "EXPERTISE",
        ["zh-cn"] = "专精",
    },
    loadout_blitz = {
        en = "Blitz",
        ["zh-cn"] = "闪击",
    },
    loadout_aura = {
        en = "Aura",
        ["zh-cn"] = "光环",
    },
    loadout_ability = {
        en = "Combat Ability",
        ["zh-cn"] = "战斗能力",
    },
    loadout_keystone = {
        en = "Keystone",
        ["zh-cn"] = "核心天赋",
    },
    loadout_tree_missing = {
        en = "No compatible talent tree was recorded for this player.",
        ["zh-cn"] = "未记录到该玩家的天赋树。",
    },
    loadout_tree_changed = {
        en = "The game's talent tree has changed since this mission.\nThe saved build cannot be displayed on the current tree.",
        ["zh-cn"] = "自本次任务以来，游戏天赋树已发生变化。\n无法在当前天赋树上显示已保存的配置。",
    },
    loadout_rank = {
        en = "RANK",
        ["zh-cn"] = "等级",
    },
    loadout_specialization = {
        en = "Specialization",
        ["zh-cn"] = "专精方向",
    },
    loadout_hint_open = {
        en = "[U] Loadouts",
        ["zh-cn"] = "[U] 配装",
    },
    loadout_hint_open_history = {
        en = "[U] Loadouts  |  [Click social icon] Social",
        ["zh-cn"] = "[U] 配装  |  [点击社交图标] 社交",
    },
    loadout_hover_scroll = {
        en = "Mouse wheel: previous / next description page",
        ["zh-cn"] = "鼠标滚轮：上一页 / 下一页描述",
    },
    loadout_hint_equipment = {
        en = "[U / Esc] Back  |  [1-4 / Wheel / Click player] Player  |  [T] Tree  |  [Hover curio / talent] Details",
        ["zh-cn"] = "[U / Esc] 返回  |  [1-4 / 滚轮 / 点击玩家] 玩家  |  [T] 天赋树  |  [悬停珍品/天赋] 详情",
    },
    loadout_hint_tree = {
        en = "[U / Esc] Back  |  [1-4 / Click player] Player  |  [T] Weapons  |  [Wheel] Zoom  |  [Left drag] Pan  |  [Hover talent] Details",
        ["zh-cn"] = "[U / Esc] 返回  |  [1-4 / 点击玩家] 玩家  |  [T] 武器  |  [滚轮] 缩放  |  [左键拖动] 平移  |  [悬停天赋] 详情",
    },
	mod_name = {
	    en = "Another Scoreboard",
	    ["zh-cn"] = "另一个记分板",
	},
	mod_description = {
	    en = "Performance-focused end-of-mission and in-mission scoreboard.",
	    ["zh-cn"] = "专注性能的任务内与任务结束记分板。",
	},
	open_scoreboard_history = {
	    en = "Open Scoreboard History",
	    ["zh-cn"] = "打开记分板历史",
	},
	open_scoreboard_history_tooltip = {
	    en = "Open the latest saved Another Scoreboard results.",
	    ["zh-cn"] = "打开最近保存的记分板结果。",
	},
	scoreboard_theme_header = {
	    en = "Scoreboard Appearance",
	    ["zh-cn"] = "记分板外观",
	},
	scoreboard_theme_header_tooltip = {
	    en = "Customize the full scoreboard's theme, text scale, and row shading.",
	    ["zh-cn"] = "自定义完整记分板的主题、文字大小和行底色。",
	},
	scoreboard_theme = {
	    en = "Theme",
	    ["zh-cn"] = "主题",
	},
	scoreboard_theme_tooltip = {
	    en = "Applies to the full scoreboard, Scoreboard History, Live Stats, and Boss Popup.",
	    ["zh-cn"] = "应用于完整记分板、记分板历史、实时统计和首领弹窗。",
	},
	scoreboard_theme_default = {
	    en = "Default",
	    ["zh-cn"] = "默认",
	},
	scoreboard_theme_reject_olive = {
	    en = "Reject Olive",
	    ["zh-cn"] = "橄榄绿",
	},
	scoreboard_theme_inquisition_navy = {
	    en = "Inquisition Navy",
	    ["zh-cn"] = "海军蓝",
	},
	scoreboard_theme_manufactorum_slate = {
	    en = "Manufactorum Slate",
	    ["zh-cn"] = "暗灰蓝",
	},
	scoreboard_theme_void_purple = {
	    en = "Void Purple",
	    ["zh-cn"] = "虚空紫",
	},
	scoreboard_theme_high_contrast_obsidian = {
	    en = "High Contrast Obsidian",
	    ["zh-cn"] = "高对比黑曜石",
	},

	show_at_end = {
	    en = "Show at Mission End",
	    ["zh-cn"] = "任务结束时显示",
	},
	show_at_end_tooltip = {
	    en = "Open automatically when the mission ends.",
	    ["zh-cn"] = "任务结束时自动打开。",
	},
	show_in_mission = {
	    en = "Show In Mission",
	    ["zh-cn"] = "任务中显示",
	},
	show_in_mission_tooltip = {
	    en = "Show in the tactical overlay during missions.",
	    ["zh-cn"] = "在任务中的战术覆盖层显示。",
	},
	tab_scoreboard_header = {
	    en = "In-Mission Scoreboard (Tab)",
	    ["zh-cn"] = "任务内记分板（Tab）",
	},
	tab_scoreboard_header_tooltip = {
	    en = "Settings for the full scoreboard shown with Tab during a mission.",
	    ["zh-cn"] = "设置任务中按 Tab 显示的完整记分板。",
	},
	scoreboard_scale = {
	    en = "Scale",
	    ["zh-cn"] = "缩放",
	},
	scoreboard_scale_tooltip = {
	    en = "In-mission Tab scoreboard size in percent.",
	    ["zh-cn"] = "任务内 Tab 记分板大小（百分比）。",
	},
	scoreboard_text_scale = {
	    en = "Text Scale",
	    ["zh-cn"] = "文字缩放",
	},
	scoreboard_text_scale_tooltip = {
	    en = "Text size for full Tab, end-of-mission, and opened History scoreboards. Text is reduced locally when needed to keep it on one line.",
	    ["zh-cn"] = "完整 Tab、任务结束和打开的历史记分板的文字大小。必要时会在本地缩小文字以保持单行显示。",
	},
	local_player_first = {
	    en = "Always Show Your Stats to the Left",
	    ["zh-cn"] = "始终将你的统计放在左侧",
	},
	local_player_first_tooltip = {
	    en = "Show your player column first in full scoreboards.",
	    ["zh-cn"] = "在完整记分板中优先显示你的玩家列。",
	},
	alternating_row_shading = {
	    en = "Alternating Row Shading",
	    ["zh-cn"] = "交替行底色",
	},
	alternating_row_shading_tooltip = {
	    en = "Use fixed shading for headings and alternating shading for detail rows in full scoreboards.",
	    ["zh-cn"] = "完整记分板的标题使用固定底色，详情行使用交替底色。",
	},
	scoreboard_opacity = {
	    en = "Opacity",
	    ["zh-cn"] = "不透明度",
	},
	scoreboard_opacity_tooltip = {
	    en = "In-mission Tab scoreboard opacity. 0 = transparent, 255 = opaque.",
	    ["zh-cn"] = "任务内 Tab 记分板不透明度。0 = 透明，255 = 不透明。",
	},
	vertical_offset = {
	    en = "Vertical Offset",
	    ["zh-cn"] = "垂直偏移",
	},
	vertical_offset_tooltip = {
	    en = "Move the in-mission Tab scoreboard vertically. Positive values move it up.",
	    ["zh-cn"] = "垂直移动任务内 Tab 记分板。正值向上移动。",
	},
	horizontal_offset = {
	    en = "Horizontal Offset",
	    ["zh-cn"] = "水平偏移",
	},
	horizontal_offset_tooltip = {
	    en = "Move the in-mission Tab scoreboard horizontally. Positive values move it right.",
	    ["zh-cn"] = "水平移动任务内 Tab 记分板。正值向右移动。",
	},
	end_scoreboard_header = {
	    en = "End-of-Mission Scoreboard",
	    ["zh-cn"] = "任务结束记分板",
	},
	end_scoreboard_header_tooltip = {
	    en = "Settings for the scoreboard shown on the mission ending screen.",
	    ["zh-cn"] = "设置任务结束界面显示的记分板。",
	},
	end_scoreboard_scale = {
	    en = "Scale",
	    ["zh-cn"] = "缩放",
	},
	end_scoreboard_scale_tooltip = {
	    en = "End-of-mission scoreboard size in percent.",
	    ["zh-cn"] = "任务结束记分板大小（百分比）。",
	},
	end_scoreboard_opacity = {
	    en = "Opacity",
	    ["zh-cn"] = "不透明度",
	},
	end_scoreboard_opacity_tooltip = {
	    en = "End-of-mission scoreboard opacity. 0 = transparent, 255 = opaque.",
	    ["zh-cn"] = "任务结束记分板不透明度。0 = 透明，255 = 不透明。",
	},
	end_scoreboard_vertical_offset = {
	    en = "Vertical Offset",
	    ["zh-cn"] = "垂直偏移",
	},
	end_scoreboard_vertical_offset_tooltip = {
	    en = "Move the end-of-mission scoreboard vertically. Positive values move it up.",
	    ["zh-cn"] = "垂直移动任务结束记分板。正值向上移动。",
	},
	end_scoreboard_horizontal_offset = {
	    en = "Horizontal Offset",
	    ["zh-cn"] = "水平偏移",
	},
	end_scoreboard_horizontal_offset_tooltip = {
	    en = "Move the end-of-mission scoreboard horizontally. Positive values move it right.",
	    ["zh-cn"] = "水平移动任务结束记分板。正值向右移动。",
	},
	live_scoreboard_header = {
	    en = "Live Stats HUD",
	    ["zh-cn"] = "实时统计 HUD",
	},
	live_scoreboard_header_tooltip = {
	    en = "Settings for the live mission HUD scoreboard.",
	    ["zh-cn"] = "设置任务中的实时 HUD 记分板。",
	},
	show_live_scoreboard = {
	    en = "Show Live Scoreboard",
	    ["zh-cn"] = "显示实时记分板",
	},
	show_live_scoreboard_tooltip = {
	    en = "Show a live HUD box with selected mission stats.",
	    ["zh-cn"] = "显示包含所选任务统计的实时 HUD 面板。",
	},
	live_scoreboard_archetype = {
	    en = "Class",
	    ["zh-cn"] = "职业",
	},
	live_scoreboard_archetype_tooltip = {
	    en = "Choose which class's Live Stats settings to edit.",
	    ["zh-cn"] = "选择要编辑实时统计设置的职业。",
	},
	live_scoreboard_stat_count = {
	    en = "Number of Live Stats",
	    ["zh-cn"] = "实时统计数量",
	},
	live_scoreboard_stat_count_tooltip = {
	    en = "Choose how many Live Stats columns to show for this class.",
	    ["zh-cn"] = "选择该职业要显示的实时统计列数。",
	},
	live_scoreboard_stat_count_1 = {
	    en = "1",
	    ["zh-cn"] = "1",
	},
	live_scoreboard_stat_count_2 = {
	    en = "2",
	    ["zh-cn"] = "2",
	},
	live_scoreboard_stat_count_3 = {
	    en = "3",
	    ["zh-cn"] = "3",
	},
	live_scoreboard_stat_1 = {
	    en = "Live Stat 1 (Sort Players By)",
	    ["zh-cn"] = "实时统计 1（排序依据）",
	},
	live_scoreboard_stat_2 = {
	    en = "Live Stat 2",
	    ["zh-cn"] = "实时统计 2",
	},
	live_scoreboard_stat_3 = {
	    en = "Live Stat 3",
	    ["zh-cn"] = "实时统计 3",
	},
	live_scoreboard_stat_tooltip = {
	    en = "Choose this Live Stats column. Selecting a stat already in use swaps the two columns.",
	    ["zh-cn"] = "选择此实时统计列。选择已在使用的统计项会交换两列。",
	},
	live_stat_damage = {
	    en = "Damage",
	    ["zh-cn"] = "伤害",
	},
	live_stat_kills = {
	    en = "Kills",
	    ["zh-cn"] = "击杀",
	},
	live_stat_hp_lost = {
	    en = "HP Lost",
	    ["zh-cn"] = "生命值损失",
	},
	live_stat_specials = {
	    en = "Specials killed",
	    ["zh-cn"] = "特殊敌人击杀",
	},
	live_stat_elites = {
	    en = "Elites killed",
	    ["zh-cn"] = "精英击杀",
	},
	live_stat_ranged_elites = {
	    en = "Ranged Elites killed",
	    ["zh-cn"] = "远程精英击杀",
	},
	live_stat_melee_elites = {
	    en = "Melee Elites killed",
	    ["zh-cn"] = "近战精英击杀",
	},
	live_stat_companion_kills = {
	    en = "Companion kills",
	    ["zh-cn"] = "同伴击杀",
	},
	live_stat_critical_hits = {
	    en = "Critical hits",
	    ["zh-cn"] = "暴击命中",
	},
	live_stat_critical_ratio = {
	    en = "Critical hit ratio",
	    ["zh-cn"] = "暴击命中率",
	},
	live_stat_weakspots = {
	    en = "Weakspots",
	    ["zh-cn"] = "弱点命中",
	},
	live_stat_weakspot_ratio = {
	    en = "Weakspot hit ratio",
	    ["zh-cn"] = "弱点命中率",
	},
	live_stat_boss_damage = {
	    en = "Boss Damage",
	    ["zh-cn"] = "首领伤害",
	},
	live_stat_coherency = {
	    en = "Coherency",
	    ["zh-cn"] = "协同",
	},
	live_stat_melee_damage = {
	    en = "Melee damage",
	    ["zh-cn"] = "近战伤害",
	},
	live_stat_ranged_damage = {
	    en = "Ranged damage",
	    ["zh-cn"] = "远程伤害",
	},
	live_stat_dot_damage = {
	    en = "Damage over time",
	    ["zh-cn"] = "持续伤害",
	},
	live_stat_bleeding_damage = {
	    en = "Bleeding damage",
	    ["zh-cn"] = "流血伤害",
	},
	live_stat_soulblaze_damage = {
	    en = "Soulblaze damage",
	    ["zh-cn"] = "灵魂之火伤害",
	},
	live_stat_burning_damage = {
	    en = "Burning damage",
	    ["zh-cn"] = "燃烧伤害",
	},
	live_stat_toxin_damage = {
	    en = "Toxin damage",
	    ["zh-cn"] = "毒素伤害",
	},
	live_stat_companion_damage = {
	    en = "Companion damage",
	    ["zh-cn"] = "同伴伤害",
	},
	live_stat_enemies_staggered = {
	    en = "Enemies staggered",
	    ["zh-cn"] = "使敌人失衡",
	},
	live_stat_debuffs_applied = {
	    en = "Debuffs applied",
	    ["zh-cn"] = "施加减益",
	},
	live_stat_downs_deaths = {
	    en = "Downs & Deaths",
	    ["zh-cn"] = "倒地与死亡",
	},
	live_stat_downs = {
	    en = "Downs",
	    ["zh-cn"] = "倒地",
	},
	live_stat_deaths = {
	    en = "Deaths",
	    ["zh-cn"] = "死亡",
	},
	live_stat_revives_rescues = {
	    en = "Revives & Rescues",
	    ["zh-cn"] = "复活与救援",
	},
	live_stat_disabled = {
	    en = "Disabled",
	    ["zh-cn"] = "被控",
	},
	live_stat_disabled_helped = {
	    en = "Disabled helped",
	    ["zh-cn"] = "协助解除控制",
	},
	live_stat_medicae_uses = {
	    en = "Medicae uses",
	    ["zh-cn"] = "医疗站使用",
	},
	live_stat_ammo_pickups = {
	    en = "Ammo pickups",
	    ["zh-cn"] = "拾取弹药",
	},
	live_stat_ammo_gained = {
	    en = "Ammo gained",
	    ["zh-cn"] = "获得弹药",
	},
	live_stat_ability_uses = {
	    en = "Ability uses",
	    ["zh-cn"] = "能力使用",
	},
	live_stat_enemies_aggroed = {
	    en = "Enemies Aggro'd",
	    ["zh-cn"] = "吸引仇恨的敌人",
	},
	live_scoreboard_scale = {
	    en = "Scale",
	    ["zh-cn"] = "缩放",
	},
	live_scoreboard_scale_tooltip = {
	    en = "Live scoreboard size in percent.",
	    ["zh-cn"] = "实时记分板大小（百分比）。",
	},
	live_scoreboard_x_offset = {
	    en = "Horizontal Offset",
	    ["zh-cn"] = "水平偏移",
	},
	live_scoreboard_x_offset_tooltip = {
	    en = "Move the live scoreboard horizontally. Positive values move it right.",
	    ["zh-cn"] = "水平移动实时记分板。正值向右移动。",
	},
	live_scoreboard_y_offset = {
	    en = "Vertical Offset",
	    ["zh-cn"] = "垂直偏移",
	},
	live_scoreboard_y_offset_tooltip = {
	    en = "Move the live scoreboard vertically. Positive values move it up.",
	    ["zh-cn"] = "垂直移动实时记分板。正值向上移动。",
	},
	live_scoreboard_bg_opacity = {
	    en = "Background Opacity",
	    ["zh-cn"] = "背景不透明度",
	},
	live_scoreboard_bg_opacity_tooltip = {
	    en = "Live scoreboard background opacity. 0 = transparent, 255 = opaque.",
	    ["zh-cn"] = "实时记分板背景不透明度。0 = 透明，255 = 不透明。",
	},
	live_scoreboard_title = {
	    en = "Live Stats",
	    ["zh-cn"] = "实时统计",
	},
	live_scoreboard_player = {
	    en = "Player",
	    ["zh-cn"] = "玩家",
	},
	live_header_damage = {
	    en = "Damage",
	    ["zh-cn"] = "伤害",
	},
	live_header_kills = {
	    en = "Kills",
	    ["zh-cn"] = "击杀",
	},
	live_header_hp_lost = {
	    en = "HP Lost",
	    ["zh-cn"] = "生命损失",
	},
	live_header_specials = {
	    en = "Specials",
	    ["zh-cn"] = "特殊",
	},
	live_header_elites = {
	    en = "Elites",
	    ["zh-cn"] = "精英",
	},
	live_header_ranged_elites = {
	    en = "Rng Elites",
	    ["zh-cn"] = "远程精英",
	},
	live_header_melee_elites = {
	    en = "Melee Elites",
	    ["zh-cn"] = "近战精英",
	},
	live_header_companion_kills = {
	    en = "Comp Kills",
	    ["zh-cn"] = "同伴击杀",
	},
	live_header_critical_hits = {
	    en = "Crits",
	    ["zh-cn"] = "暴击",
	},
	live_header_critical_ratio = {
	    en = "Critical %%",
	    ["zh-cn"] = "暴击 %%",
	},
	live_header_weakspots = {
	    en = "Weakspots",
	    ["zh-cn"] = "弱点",
	},
	live_header_weakspot_ratio = {
	    en = "Weakspot %%",
	    ["zh-cn"] = "弱点 %%",
	},
	live_header_boss_damage = {
	    en = "Boss Dmg",
	    ["zh-cn"] = "首领伤害",
	},
	live_header_coherency = {
	    en = "Coherency",
	    ["zh-cn"] = "协同",
	},
	live_header_melee_damage = {
	    en = "Melee Dmg",
	    ["zh-cn"] = "近战伤害",
	},
	live_header_ranged_damage = {
	    en = "Ranged Dmg",
	    ["zh-cn"] = "远程伤害",
	},
	live_header_dot_damage = {
	    en = "DoT Dmg",
	    ["zh-cn"] = "持续伤害",
	},
	live_header_bleeding_damage = {
	    en = "Bleeding",
	    ["zh-cn"] = "流血",
	},
	live_header_soulblaze_damage = {
	    en = "Soulblaze",
	    ["zh-cn"] = "灵魂之火",
	},
	live_header_burning_damage = {
	    en = "Burning",
	    ["zh-cn"] = "燃烧",
	},
	live_header_toxin_damage = {
	    en = "Toxin",
	    ["zh-cn"] = "毒素",
	},
	live_header_companion_damage = {
	    en = "Comp Dmg",
	    ["zh-cn"] = "同伴伤害",
	},
	live_header_enemies_staggered = {
	    en = "Staggered",
	    ["zh-cn"] = "失衡",
	},
	live_header_debuffs_applied = {
	    en = "Debuffs",
	    ["zh-cn"] = "减益",
	},
	live_header_downs_deaths = {
	    en = "Downs",
	    ["zh-cn"] = "倒地",
	},
	live_header_downs = {
	    en = "Downs",
	    ["zh-cn"] = "倒地",
	},
	live_header_deaths = {
	    en = "Deaths",
	    ["zh-cn"] = "死亡",
	},
	live_header_revives_rescues = {
	    en = "Rev/Resc",
	    ["zh-cn"] = "复活/救援",
	},
	live_header_disabled = {
	    en = "Disabled",
	    ["zh-cn"] = "被控",
	},
	live_header_disabled_helped = {
	    en = "Dis. Help",
	    ["zh-cn"] = "协助解控",
	},
	live_header_medicae_uses = {
	    en = "Medicae",
	    ["zh-cn"] = "医疗站",
	},
	live_header_ammo_pickups = {
	    en = "Ammo P/U",
	    ["zh-cn"] = "拾弹",
	},
	live_header_ammo_gained = {
	    en = "Ammo Gain",
	    ["zh-cn"] = "获得弹药",
	},
	live_header_ability_uses = {
	    en = "Ability Uses",
	    ["zh-cn"] = "能力使用",
	},
	live_header_enemies_aggroed = {
	    en = "Aggro'd",
	    ["zh-cn"] = "吸引仇恨",
	},
	show_boss_popup = {
	    en = "Show Boss Damage Popup",
	    ["zh-cn"] = "显示首领伤害弹窗",
	},
	show_boss_popup_tooltip = {
	    en = "Show a per-player boss damage popup when a boss dies.",
	    ["zh-cn"] = "首领死亡时显示每名玩家的首领伤害弹窗。",
	},
	show_boss_popup_damage = {
	    en = "Show Popup Damage",
	    ["zh-cn"] = "显示弹窗伤害",
	},
	show_boss_popup_damage_tooltip = {
	    en = "Show each player's boss damage number in the boss popup.",
	    ["zh-cn"] = "在首领弹窗中显示每名玩家的首领伤害数值。",
	},
	show_boss_popup_percent = {
	    en = "Show Popup Percent",
	    ["zh-cn"] = "显示弹窗百分比",
	},
	show_boss_popup_percent_tooltip = {
	    en = "Show each player's boss damage percentage in the boss popup.",
	    ["zh-cn"] = "在首领弹窗中显示每名玩家的首领伤害百分比。",
	},
	show_boss_popup_total_damage = {
	    en = "Show Total Boss Damage",
	    ["zh-cn"] = "显示首领总伤害",
	},
	show_boss_popup_total_damage_tooltip = {
	    en = "Show the total boss damage area at the bottom of the boss popup.",
	    ["zh-cn"] = "在首领弹窗底部显示首领总伤害区域。",
	},
	boss_popup_header = {
	    en = "Boss Damage Popup",
	    ["zh-cn"] = "首领伤害弹窗",
	},
	boss_popup_header_tooltip = {
	    en = "Settings for the boss damage popup.",
	    ["zh-cn"] = "设置首领伤害弹窗。",
	},
	boss_popup_scale = {
	    en = "Scale",
	    ["zh-cn"] = "缩放",
	},
	boss_popup_scale_tooltip = {
	    en = "Boss popup size in percent.",
	    ["zh-cn"] = "首领弹窗大小（百分比）。",
	},
	boss_popup_duration = {
	    en = "Duration (seconds)",
	    ["zh-cn"] = "持续时间（秒）",
	},
	boss_popup_duration_tooltip = {
	    en = "How long the boss popup stays visible, in seconds.",
	    ["zh-cn"] = "首领弹窗保持显示的时间（秒）。",
	},
	boss_popup_x_offset = {
	    en = "Horizontal Offset",
	    ["zh-cn"] = "水平偏移",
	},
	boss_popup_x_offset_tooltip = {
	    en = "Move the boss popup horizontally. Positive values move it right.",
	    ["zh-cn"] = "水平移动首领弹窗。正值向右移动。",
	},
	boss_popup_y_offset = {
	    en = "Vertical Offset",
	    ["zh-cn"] = "垂直偏移",
	},
	boss_popup_y_offset_tooltip = {
	    en = "Move the boss popup vertically. Positive values move it up.",
	    ["zh-cn"] = "垂直移动首领弹窗。正值向上移动。",
	},
	boss_popup_bg_opacity = {
	    en = "Background Opacity",
	    ["zh-cn"] = "背景不透明度",
	},
	boss_popup_bg_opacity_tooltip = {
	    en = "Boss popup background opacity. 0 = transparent, 255 = opaque.",
	    ["zh-cn"] = "首领弹窗背景不透明度。0 = 透明，255 = 不透明。",
	},
	scoreboard_stats_header = {
	    en = "Toggle Stats in Scoreboard",
	    ["zh-cn"] = "记分板统计项开关",
	},
	scoreboard_stats_header_tooltip = {
	    en = "Choose which tracked stats are visible in the full scoreboard views.",
	    ["zh-cn"] = "选择完整记分板视图中显示的统计项。",
	},
	scoreboard_stats_combat_header = {
	    en = "Combat Stats",
	    ["zh-cn"] = "战斗统计",
	},
	scoreboard_stats_survival_header = {
	    en = "Survival Stats",
	    ["zh-cn"] = "生存统计",
	},
	scoreboard_stats_group_tooltip = {
	    en = "Visibility settings only. All stats continue to be tracked and saved.",
	    ["zh-cn"] = "这里只控制显示。所有统计仍会继续追踪和保存。",
	},
	scoreboard_stat_visibility_tooltip = {
	    en = "Show this stat in the Tab, end-of-mission, and Scoreboard History views. Tracking and saved data are unaffected.",
	    ["zh-cn"] = "在 Tab、任务结束和记分板历史视图中显示此统计项。追踪和保存的数据不受影响。",
	},
	show_scoreboard_weakspot_percentage = {
	    en = "Show Weakspot hit percentage",
	    ["zh-cn"] = "显示弱点命中率",
	},
	show_scoreboard_critical_percentage = {
	    en = "Show Critical hit percentage",
	    ["zh-cn"] = "显示暴击命中率",
	},
	scoreboard_hit_percentage_tooltip = {
	    en = "Show the percentage of valid melee and ranged hits beside each player's hit count.",
	    ["zh-cn"] = "在每名玩家的命中数旁显示有效近战和远程命中百分比。",
	},

	cat_combat = {
	    en = "COMBAT",
	    ["zh-cn"] = "战斗",
	},
	cat_damage = {
	    en = "DAMAGE",
	    ["zh-cn"] = "伤害",
	},
	cat_boss = {
	    en = "BOSS",
	    ["zh-cn"] = "首领",
	},
	cat_survival = {
	    en = "SURVIVAL",
	    ["zh-cn"] = "生存",
	},
	cat_performance = {
	    en = "PERFORMANCE",
	    ["zh-cn"] = "表现",
	},

	row_total_kills = {
	    en = "Total kills",
	    ["zh-cn"] = "击杀总数",
	},
	row_lesser_enemies_killed = {
	    en = "Lesser Enemies",
	    ["zh-cn"] = "普通敌人",
	},
	row_ranged_lesser_enemies_killed = {
	    en = "Ranged Lesser Enemies",
	    ["zh-cn"] = "远程普通敌人",
	},
	row_melee_lesser_enemies_killed = {
	    en = "Melee Lesser Enemies",
	    ["zh-cn"] = "近战普通敌人",
	},
	row_specials_killed = {
	    en = "Specials",
	    ["zh-cn"] = "特殊敌人",
	},
	row_elites_killed = {
	    en = "Elites",
	    ["zh-cn"] = "精英敌人",
	},
	row_ranged_elites_killed = {
	    en = "Ranged Elites",
	    ["zh-cn"] = "远程精英",
	},
	row_melee_elites_killed = {
	    en = "Melee Elites",
	    ["zh-cn"] = "近战精英",
	},
	row_companion_kills = {
	    en = "Companion kills",
	    ["zh-cn"] = "同伴击杀",
	},

	row_damage_dealt = {
	    en = "Total damage",
	    ["zh-cn"] = "总伤害",
	},
	row_melee_damage = {
	    en = "Melee damage",
	    ["zh-cn"] = "近战伤害",
	},
	row_ranged_damage = {
	    en = "Ranged damage",
	    ["zh-cn"] = "远程伤害",
	},
	row_other_damage = {
	    en = "Other damage",
	    ["zh-cn"] = "其他伤害",
	},
	row_damage_details = {
	    en = "Damage details",
	    ["zh-cn"] = "伤害详情",
	},
	row_dot_damage = {
	    en = "Damage over time",
	    ["zh-cn"] = "持续伤害",
	},
	row_dot_bleeding_damage = {
	    en = "Bleeding",
	    ["zh-cn"] = "流血",
	},
	row_dot_soulblaze_damage = {
	    en = "Soulblaze",
	    ["zh-cn"] = "灵魂之火",
	},
	row_dot_burning_damage = {
	    en = "Burning",
	    ["zh-cn"] = "燃烧",
	},
	row_dot_toxin_damage = {
	    en = "Toxin",
	    ["zh-cn"] = "毒素",
	},
	row_companion_damage = {
	    en = "Companion damage",
	    ["zh-cn"] = "同伴伤害",
	},
	row_damage_to_bosses = {
	    en = "Boss damage",
	    ["zh-cn"] = "首领伤害",
	},
	row_boss_beast_of_nurgle = {
	    en = "Beast of Nurgle",
	    ["zh-cn"] = "纳垢兽",
	},
	row_boss_daemonhost = {
	    en = "Daemonhost",
	    ["zh-cn"] = "恶魔宿主",
	},
	row_boss_chaos_spawn = {
	    en = "Chaos Spawn",
	    ["zh-cn"] = "混沌魔物",
	},
	row_boss_plague_ogryn = {
	    en = "Plague Ogryn",
	    ["zh-cn"] = "瘟疫欧格林",
	},
	row_boss_captain = {
	    en = "Captain",
	    ["zh-cn"] = "连长",
	},
	row_boss_scab_captain = {
	    en = "Scab Captain",
	    ["zh-cn"] = "血痂连长",
	},
	row_boss_dreg_captain = {
	    en = "Dreg Captain",
	    ["zh-cn"] = "渣滓连长",
	},
	row_boss_hexbound_daemonhost = {
	    en = "Hexbound Daemonhost",
	    ["zh-cn"] = "缚咒恶魔宿主",
	},
	row_boss_ogryn_houndmaster = {
	    en = "Pack Master",
	    ["zh-cn"] = "猎群大师",
	},
	row_boss_twins = {
	    en = "Twins",
	    ["zh-cn"] = "双子",
	},
	row_utility = {
	    en = "Utility",
	    ["zh-cn"] = "辅助",
	},

	row_headshots = {
	    en = "Weakspot hits",
	    ["zh-cn"] = "弱点命中",
	},
	row_critical_hits = {
	    en = "Critical hits",
	    ["zh-cn"] = "暴击命中",
	},
	row_enemies_staggered = {
	    en = "Enemies staggered",
	    ["zh-cn"] = "使敌人失衡",
	},
	row_debuffs_applied = {
	    en = "Debuffs applied",
	    ["zh-cn"] = "施加减益",
	},
	row_weighted_stagger = {
	    en = "Weighted stagger",
	    ["zh-cn"] = "加权失衡",
	},
	row_combat_ability_uses = {
	    en = "Ability uses",
	    ["zh-cn"] = "能力使用次数",
	},
	row_enemies_aggroed = {
	    en = "Enemies Aggro'd",
	    ["zh-cn"] = "吸引仇恨的敌人",
	},
	row_coherency_uptime = {
	    en = "Coherency",
	    ["zh-cn"] = "协同覆盖",
	},

	row_survivability = {
	    en = "Survivability",
	    ["zh-cn"] = "生存能力",
	},
	row_damage_taken = {
	    en = "HP Lost",
	    ["zh-cn"] = "生命值损失",
	},
	row_downs_and_deaths = {
	    en = "Downs & Deaths",
	    ["zh-cn"] = "倒地与死亡",
	},
	row_downs = {
	    en = "Downs",
	    ["zh-cn"] = "倒地",
	},
	row_deaths = {
	    en = "Deaths",
	    ["zh-cn"] = "死亡",
	},
	row_revives_and_rescues = {
	    en = "Revives & Rescues",
	    ["zh-cn"] = "复活与救援",
	},
	row_times_disabled = {
	    en = "Disabled",
	    ["zh-cn"] = "被控次数",
	},
	row_disabled_helped = {
	    en = "Disabled helped",
	    ["zh-cn"] = "协助解除控制",
	},
	row_healthstation_uses = {
	    en = "Medicae uses",
	    ["zh-cn"] = "医疗站使用",
	},
	row_combat_ability_uses_per_minute = {
	    en = "Uses per minute",
	    ["zh-cn"] = "每分钟使用次数",
	},
	row_combat_ability_average_time = {
	    en = "Avg between uses",
	    ["zh-cn"] = "平均使用间隔",
	},
	row_ammo_pickups = {
	    en = "Ammo pickups",
	    ["zh-cn"] = "拾取弹药",
	},
	row_ammo_collected = {
	    en = "Ammo gained",
	    ["zh-cn"] = "获得弹药",
	},

	loc_another_scoreboard_view_display_name = {
	    en = "Scoreboard",
	    ["zh-cn"] = "记分板",
	},
	scoreboard_mission_time = {
	    en = "Mission time",
	    ["zh-cn"] = "任务时间",
	},
	loc_another_scoreboard_history_view_display_name = {
	    en = "Scoreboard History",
	    ["zh-cn"] = "记分板历史",
	},
	history_view_title = {
	    en = "Scoreboard History",
	    ["zh-cn"] = "记分板历史",
	},
	history_recent_capacity = {
	    en = "Recent history capacity",
	    ["zh-cn"] = "最近历史记录容量",
	},
	history_recent_capacity_tooltip = {
	    en = "Keep the latest 10–100 completed missions, in steps of 10 (default: 10). Reopen history to update the list. Excess Recent files are deleted on the next completed mission save, not when changing this setting. Saved missions are unlimited. Increasing the limit cannot restore deleted missions.",
	    ["zh-cn"] = "保留最近完成的 10–100 个任务，每次递增 10 个（默认 10 个）。重新打开历史记录即可更新列表。超出容量的最近记录文件会在下次保存已完成任务时删除，修改设置时不会删除。已保存任务数量不限。提高容量无法恢复已删除的任务。",
	},
	history_view_subtitle = {
	    en = "Latest %d completed missions",
	    ["zh-cn"] = "最近完成的 %d 个任务",
	},
	history_saved_subtitle = {
	    en = "Missions saved for later",
	    ["zh-cn"] = "保存以便稍后查看的任务",
	},
	history_tab_recent = {
	    en = "Recent",
	    ["zh-cn"] = "最近",
	},
	history_tab_saved = {
	    en = "Saved",
	    ["zh-cn"] = "已保存",
	},
	history_save = {
	    en = "SAVE",
	    ["zh-cn"] = "保存",
	},
	history_saved = {
	    en = "SAVED",
	    ["zh-cn"] = "已保存",
	},
	history_manage = {
	    en = "MANAGE",
	    ["zh-cn"] = "管理",
	},
	history_name_popup_title = {
	    en = "Name Saved Game",
	    ["zh-cn"] = "命名已保存游戏",
	},
	history_name_popup_description = {
	    en = "Enter an optional name. Leave it blank to use the generated mission title.",
	    ["zh-cn"] = "输入可选名称。留空则使用自动生成的任务标题。",
	},
	history_manage_popup_title = {
	    en = "Manage Saved Game",
	    ["zh-cn"] = "管理已保存游戏",
	},
	history_manage_current_name = {
	    en = "Current name",
	    ["zh-cn"] = "当前名称",
	},
	history_manage_generated_name = {
	    en = "Generated mission title",
	    ["zh-cn"] = "自动生成的任务标题",
	},
	history_save_name = {
	    en = "SAVE NAME",
	    ["zh-cn"] = "保存名称",
	},
	history_remove = {
	    en = "REMOVE",
	    ["zh-cn"] = "移除",
	},
	history_cancel = {
	    en = "CANCEL",
	    ["zh-cn"] = "取消",
	},
	history_no_saved_entries = {
	    en = "No saved games yet.",
	    ["zh-cn"] = "还没有已保存的游戏。",
	},
	history_loading = {
	    en = "Loading saved scoreboards...",
	    ["zh-cn"] = "正在加载已保存的记分板……",
	},
	history_no_entries = {
	    en = "No saved scoreboards yet.",
	    ["zh-cn"] = "还没有保存的记分板。",
	},
	history_game_type_expedition = {
	    en = "Expedition",
	    ["zh-cn"] = "远征",
	},
	history_game_type_mortis_trials = {
	    en = "Mortis Trials",
	    ["zh-cn"] = "死者试炼",
	},
	history_game_type_maelstrom = {
	    en = "Maelstrom",
	    ["zh-cn"] = "漩涡",
	},
	history_game_type_auric_maelstrom = {
	    en = "Auric Maelstrom",
	    ["zh-cn"] = "奥瑞克漩涡",
	},
	history_unknown_mission = {
	    en = "Unknown Mission",
	    ["zh-cn"] = "未知任务",
	},
	history_unknown_difficulty = {
	    en = "Unknown Difficulty",
	    ["zh-cn"] = "未知难度",
	},
	history_escape_hint = {
	    en = "ESC - Exit  |  Mouse wheel - Scroll  |  SPACE - Clear Recent",
	    ["zh-cn"] = "ESC - 退出  |  鼠标滚轮 - 滚动  |  SPACE - 清除最近记录",
	},
	history_saved_hint = {
	    en = "ESC - Exit  |  Mouse wheel - Scroll  |  Manage saved games individually",
	    ["zh-cn"] = "ESC - 退出  |  鼠标滚轮 - 滚动  |  单独管理已保存游戏",
	},
	history_scoreboard_back_hint = {
	    en = "ESC - Back to Mission History",
	    ["zh-cn"] = "ESC - 返回任务历史",
	},
	scoreboard_default_hint = {
	    en = "E - Specials/Elites  |  R - DoT types  |  T - Boss types",
	    ["zh-cn"] = "E - 特殊/精英  |  R - 持续伤害类型  |  T - 首领类型",
	},
	scoreboard_enemy_hint = {
	    en = "E - Hide Specials/Elite kills  |  R - DoT types  |  T - Boss types",
	    ["zh-cn"] = "E - 隐藏特殊/精英击杀  |  R - 持续伤害类型  |  T - 首领类型",
	},
	scoreboard_dot_hint = {
	    en = "E - Specials/Elites  |  R - Hide DoT types  |  T - Boss types",
	    ["zh-cn"] = "E - 特殊/精英  |  R - 隐藏持续伤害类型  |  T - 首领类型",
	},
	scoreboard_boss_hint = {
	    en = "E - Specials/Elites  |  R - DoT types  |  T - Hide boss types",
	    ["zh-cn"] = "E - 特殊/精英  |  R - 持续伤害类型  |  T - 隐藏首领类型",
	},
	history_scoreboard_default_hint = {
	    en = "ESC - Back  |  E - Specials/Elites  |  R - DoT types  |  T - Boss types",
	    ["zh-cn"] = "ESC - 返回  |  E - 特殊/精英  |  R - 持续伤害类型  |  T - 首领类型",
	},
	history_scoreboard_enemy_hint = {
	    en = "ESC - Back  |  E - Hide Specials/Elite kills  |  R - DoT types  |  T - Boss types",
	    ["zh-cn"] = "ESC - 返回  |  E - 隐藏特殊/精英击杀  |  R - 持续伤害类型  |  T - 首领类型",
	},
	history_scoreboard_dot_hint = {
	    en = "ESC - Back  |  E - Specials/Elites  |  R - Hide DoT types  |  T - Boss types",
	    ["zh-cn"] = "ESC - 返回  |  E - 特殊/精英  |  R - 隐藏持续伤害类型  |  T - 首领类型",
	},
	history_scoreboard_boss_hint = {
	    en = "ESC - Back  |  E - Specials/Elites  |  R - DoT types  |  T - Hide boss types",
	    ["zh-cn"] = "ESC - 返回  |  E - 特殊/精英  |  R - 持续伤害类型  |  T - 隐藏首领类型",
	},
	scoreboard_hint_back = {
	    en = "ESC - Back",
	    ["zh-cn"] = "ESC - 返回",
	},
	scoreboard_hint_specials_elites = {
	    en = "E - Specials/Elites",
	    ["zh-cn"] = "E - 特殊/精英",
	},
	scoreboard_hint_hide_specials_elites = {
	    en = "E - Hide Specials/Elites",
	    ["zh-cn"] = "E - 隐藏特殊/精英",
	},
	scoreboard_hint_enemy_details = {
	    en = "E - Enemy Details",
	    ["zh-cn"] = "E - 敌人详情",
	},
	scoreboard_hint_hide_enemy_details = {
	    en = "E - Hide Enemy Details",
	    ["zh-cn"] = "E - 隐藏敌人详情",
	},
	scoreboard_hint_specials = {
	    en = "E - Specials",
	    ["zh-cn"] = "E - 特殊敌人",
	},
	scoreboard_hint_hide_specials = {
	    en = "E - Hide Specials",
	    ["zh-cn"] = "E - 隐藏特殊敌人",
	},
	scoreboard_hint_elites = {
	    en = "E - Elites",
	    ["zh-cn"] = "E - 精英敌人",
	},
	scoreboard_hint_hide_elites = {
	    en = "E - Hide Elites",
	    ["zh-cn"] = "E - 隐藏精英敌人",
	},
	scoreboard_hint_dot = {
	    en = "R - DoT types",
	    ["zh-cn"] = "R - 持续伤害类型",
	},
	scoreboard_hint_hide_dot = {
	    en = "R - Hide DoT types",
	    ["zh-cn"] = "R - 隐藏持续伤害类型",
	},
	scoreboard_hint_boss = {
	    en = "T - Boss types",
	    ["zh-cn"] = "T - 首领类型",
	},
	scoreboard_hint_hide_boss = {
	    en = "T - Hide boss types",
	    ["zh-cn"] = "T - 隐藏首领类型",
	},
	scoreboard_hint_survival_details = {
	    en = "Y - Survival details",
	    ["zh-cn"] = "Y - 生存详情",
	},
	scoreboard_hint_hide_survival_details = {
	    en = "Y - Hide Survival details",
	    ["zh-cn"] = "Y - 隐藏生存详情",
	},
	scoreboard_hint_downs_deaths = {
	    en = "Y - Survival details",
	    ["zh-cn"] = "Y - 生存详情",
	},
	scoreboard_hint_hide_downs_deaths = {
	    en = "Y - Hide Survival details",
	    ["zh-cn"] = "Y - 隐藏生存详情",
	},
	scoreboard_hint_ability_rate = {
	    en = "Y - Survival details",
	    ["zh-cn"] = "Y - 生存详情",
	},
	scoreboard_hint_hide_ability_rate = {
	    en = "Y - Hide Survival details",
	    ["zh-cn"] = "Y - 隐藏生存详情",
	},
	scoreboard_hint_temporarily_hide = {
	    en = "TAB + Q - Hide Scoreboard",
	    ["zh-cn"] = "TAB + Q - 隐藏记分板",
	},
	scoreboard_hint_end_hide = {
	    en = "Q - Hide Scoreboard",
	    ["zh-cn"] = "Q - 隐藏记分板",
	},
	scoreboard_hint_end_show = {
	    en = "Q - Show Scoreboard",
	    ["zh-cn"] = "Q - 显示记分板",
	},
}

for _, category in ipairs({ "specials", "elites" }) do
	for _, enemy in ipairs(enemies[category]) do
		localization[enemy.label] = {
			en = enemy.name.en,
			["zh-cn"] = enemy.name["zh-cn"],
		}
	end
end

return localization
