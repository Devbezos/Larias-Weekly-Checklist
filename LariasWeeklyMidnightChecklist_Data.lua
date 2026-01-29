-- Data file for Larias Weekly Midnight Checklist
-- Edit this file to change the checklist.

local addonName = ...

-- WoW loads addon Lua files in a sandbox; you generally cannot read arbitrary files from disk.
-- Instead, we "read" from this Lua file by loading it via the .toc.

_G[addonName .. "_LIST_DATA"] = {
    {
        id = "early_access",
        title = "Early Access - Feb 27 through Mar 2",
        items = {
            { id = "level_characters", text = "Level all the characters you're wanting to use for professions, splits etc." },
            { id = "no_side_quests_until_sun", text = "Do not do side quests until Sunday - get Darkmoon Faire buff" },
            { id = "farm_gold_world_quests", text = "Farm gold and do random ass world quests and stuff" },
        },
    },
    {
        id = "pre_season_1",
        title = "Pre-Season 1 - Mar 3 through Mar 16",
        items = {
            { id = "hold_crests", text = "Hold crests" },
            { id = "dmf_buff_sidequests_renown", text = "Grab Darkmoon Faire buff while doing sidequests for Renown" },
            { id = "unlock_delves", text = "Unlock Delves through tier 8 (11 if available)" },
            { id = "wq_gear_upgrades", text = "Do world quests that give gear upgrades" },
            { id = "progress_vault", text = "Progress Vault (details to come, wowhead says it'll be available)" },
            { id = "queue_heroic_dungeons", text = "Queue for Heroic Dungeons for remaining slots" },
        },
    },
    {
        id = "season_1_week_1",
        title = "Season 1 Week 1 – Mar 17 – Heroic Week",
        items = {
            { id = "hold_crests", text = "Hold crests" },
            { id = "lfr_tier_pieces", text = "Do LFR for tier pieces (check guide for why)" },
            { id = "mythic0_world_tour", text = "Complete a world tour of mythic 0's" },
            { id = "kill_world_boss", text = "Kill World Boss" },
            { id = "weekly_prey_quest", text = "Complete weekly prey quest for 1x heroic piece (tentative)" },
            { id = "pvp_quest_neck_ring", text = "Complete pvp quest for guaranteed hero neck/ring" },
            { id = "bountiful_delves_keys", text = "Do high level bountiful delves with coffer keys, use map if possible" },
            { id = "craft_246_embellishments", text = "Before raid, craft a ton of 246 ilvl pieces, include 2x embellishments on weak slots" },
            { id = "craft_233_fill_slots", text = "Craft 233 ilvl pieces to fill out any remaining slots" },
            { id = "spend_normal_below_crests", text = "Spend any remaining normal difficulty or below crests" },
            { id = "complete_raids", text = "Complete your raids" },
            { id = "track_crests", text = "Track crests: 0/100 Heroic" },
        },
    },
    {
        id = "season_1_week_2",
        title = "Week 2 – Mar 24 – Mythic Week, M+ Opens",
        items = {
            { id = "hold_crests", text = "Hold crests" },
            { id = "lfr_tier_pieces", text = "Do LFR for tier pieces (check guide for why)" },
            { id = "kill_world_boss", text = "Kill World Boss" },
            { id = "weekly_prey_quest", text = "Complete weekly prey quest for 1x heroic piece (tentative)" },
            { id = "bountiful_delves_keys", text = "Do high level bountiful delves with coffer keys (if they award heroic pieces, will update)" },
            { id = "spend_normal_below_crests", text = "Spend Normal and below crests on temporary upgrades, prefer trinkets" },
            { id = "farm_10s_266", text = "Farm +10s for 266 gear in every slot" },
            { id = "mythic_time_full_clear", text = "Mythic raid time! Full clear normal and heroic for tier and trinkets" },
            { id = "upgrade_mythic_item_twice", text = "If lucky, upgrade mythic item twice. Adjust the advice below until it sorts out again." },
            { id = "track_crests", text = "Track crests: 0/200 Heroic, 0/100 Gilded" },
            { id = "ending_ilvl", text = "Ending item level: 15x266, finished farming heroic pieces" },
        },
    },
    {
        id = "season_1_week_3",
        title = "Week 3 – Mar 31 – Final Raid Opens",
        items = {
            { id = "hold_crests", text = "Hold crests" },
            { id = "open_vault", text = "Open vault (272+ myth item) - upgrade after crafting" },
            { id = "craft_2h_mythic_weapon", text = "Craft 2H mythic weapon (5/6 285) - see note in text guide" },
            { id = "lfr_if_no_4p", text = "If no 4p, do LFR for tier pieces (check guide for why)" },
            { id = "farm_12s", text = "Farm +12s for vault + crests" },
            { id = "full_reclear", text = "Do full Reclear" },
            { id = "upgrade_heroic_items_4_6", text = "Before Mythic Progression, upgrade heroic items to 4/6 269 (300 Heroic crests)" },
            { id = "upgrade_vault_item_4_6", text = "Upgrade vault item to 4/6 282 (60 Mythic crests)" },
            { id = "track_crests", text = "Track crests: 300/300 Heroic, 160/200 Gilded" },
            { id = "ending_ilvl", text = "Ending item level: 3x266, 10x 269, 1x 282, 1x285 (crafted)" },
        },
    },
    {
        id = "season_1_week_4",
        title = "Week 4 – Apr 7",
        items = {
            { id = "open_vault", text = "Open vault (272+ myth item)" },
            { id = "farm_12s", text = "Farm +12s for vault + crests" },
            { id = "upgrade_266_269", text = "Upgrade 266→269 (60 crests)" },
            { id = "upgrade_269_272", text = "Upgrade 269→272 (40 crests)" },
            { id = "upgrade_myth_items_4_6", text = "Upgrade myth items to 4/6 282" },
            { id = "track_crests", text = "Track crests: 400/400 Heroic, 270/300 Gilded" },
            { id = "ending_ilvl", text = "Ending item level: 1x266, 10x 269, 3x 282, 1x285 (crafted)" },
        },
    },
    {
        id = "season_1_week_5",
        title = "Week 5 – Apr 14",
        items = {
            { id = "open_vault", text = "Open vault (272+ myth item)" },
            { id = "farm_12s", text = "Farm +12s for vault + crests" },
            { id = "craft_second_myth_item", text = "Craft second mythic item (5/6 285)" },
            { id = "upgrade_269_272", text = "Upgrade 269→272 (80 crests)" },
            { id = "upgrade_myth_item_3_6", text = "Upgrade myth item to 3/6 279" },
            { id = "track_crests", text = "Track crests: 480/500 Heroic, 400/400 Gilded" },
            { id = "ending_ilvl", text = "Ending item level: 7x 269, 2x 272h, 1x 279, 3x 282, 2x285 (crafted)" },
        },
    },
    {
        id = "season_1_week_6",
        title = "Week 6 – Apr 21",
        items = {
            { id = "open_vault", text = "Open vault (272+ myth item)" },
            { id = "farm_12s", text = "Farm +12s for vault + crests" },
            { id = "upgrade_269_272", text = "Upgrade 269→272 (120 crests)" },
            { id = "upgrade_myth_items", text = "Upgrade myth items to 279 / 282" },
            { id = "track_crests", text = "Track crests: 600/600 Heroic, 490/500 Gilded" },
            { id = "ending_ilvl", text = "Ending item level: 2x 269, 5x 272h, 1x 279, 5x 282, 2x285 (crafted)" },
        },
    },
    {
        id = "season_1_week_7",
        title = "Week 7 – Apr 28",
        items = {
            { id = "open_vault", text = "Open vault (272+ myth item)" },
            { id = "farm_12s", text = "Farm +12s for vault + crests" },
            { id = "craft_third_myth_item", text = "Craft third mythic item if appropriate" },
            { id = "upgrade_remaining_heroic", text = "Upgrade remaining heroic items" },
            { id = "track_crests", text = "Track crests: 680/700 Heroic, 600/600 Gilded" },
            { id = "ending_ilvl", text = "Ending item level: 5x 272h, 1x 276m, 1x 279, 5x 282, 3x285 (crafted)" },
        },
    },
    {
        id = "season_1_week_8",
        title = "Week 8 – May 5 – Done with Heroic Crests",
        items = {
            { id = "open_vault", text = "Open vault (272+ myth item)" },
            { id = "farm_12s", text = "Farm +12s for vault + crests" },
            { id = "finish_heroic_upgrades", text = "Finish heroic upgrades" },
            { id = "upgrade_multiple_myth_items", text = "Upgrade multiple myth track items" },
            { id = "track_crests", text = "Track crests: 780/800 Heroic (Done), 700/700 Gilded" },
            { id = "ending_ilvl", text = "Ending item level: 2x 276h, 4x 279, 6x 282, 3x285 (crafted)" },
        },
    },
    {
        id = "weeks_9_plus",
        title = "Weeks 9+ – May 12+",
        items = {
            { id = "all_items_4_6_282", text = "Get all items to 4/6 282" },
            { id = "upgrade_2_items_week", text = "Upgrade 2 items per week to 6/6 289" },
            { id = "sim_weekly", text = "Sim weekly before spending crests" },
            { id = "plan_1h_oh_swap", text = "Plan for possible 1H + crafted OH swap" },
            { id = "prepare_7_8_8_8", text = "Prepare for 7/8 and 8/8 upgrades if turbo exists" },
        },
    },
}
