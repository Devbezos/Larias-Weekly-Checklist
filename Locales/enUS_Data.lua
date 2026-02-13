--[[
Localization (checklist data)

This file provides the default (enUS) checklist data.
To add a new language:
1) Copy Locales\\enUS.lua -> Locales\\<locale>.lua (example: Locales\\deDE.lua)
2) Copy Locales\\enUS_Data.lua -> Locales\\<locale>_Data.lua (example: Locales\\deDE_Data.lua)
3) In both copies, change the locale string ("enUS") to your locale ("deDE")
4) Translate section titles and item text in the _Data file
5) Add BOTH files to LariasWeeklyMidnightChecklist.toc AFTER the enUS entries

Common locale codes: enUS, enGB, frFR, deDE, esES, esMX, itIT, ptBR, ruRU, koKR, zhCN, zhTW
]]

local addonName = ...
local locale = (GetLocale and GetLocale()) or nil
local LOCALE = "enUS"
local listKey = addonName .. "_LIST_DATA"

if locale == LOCALE or type(_G[listKey]) ~= "table" then
_G[listKey] = {

    {
        id = "early_access_feb_26_through_mar_2_pay_to_win",
        title = "Early Access - Feb 26 through Mar 2 - Pay to Win",
        items = {
            { id = "do_not_spend_any_crests_until_told_to_do_so", text = "Do not spend any Crests until told to do so" },
            { id = "level_characters_to_90_dmf_opens_sunday_for_10_more_exp", text = "Level characters to 90 - DMF opens Sunday for 10% more exp" },
            { id = "if_you_want_renown_wait_until_sunday_for_dmf_renown_buff_to_do_side_quests", text = "If you want Renown, wait until Sunday for DMF renown buff to do side quests" },
            { id = "complete_weekly_events_if_available_tbd_will_add_as_we_get_them", text = "Complete weekly events if available. (TBD, will add as we get them)" },
            { id = "if_prey_gives_any_useful_rewards_do_prey", text = "If Prey gives any useful rewards, do Prey" },
        },
    },
    {
        id = "pre_season_week_1_march_3_m0_s",
        title = "Pre-Season Week 1 - March 3 - M0's",
        items = {
            { id = "do_not_spend_any_crests_until_told_to_do_so", text = "Do not spend any Crests until told to do so" },
            { id = "grab_darkmoon_faire_buff_for_renown_loremaster_if_a_crafter", text = "Grab Darkmoon Faire buff for Renown Loremaster if a crafter" },
            { id = "unlock_delves_through_tier_8_11_if_available", text = "Unlock Delves through tier 8 (11 if available)" },
            { id = "complete_weekly_events_if_available_tbd_will_add_as_we_get_them", text = "Complete weekly events if available. (TBD, will add as we get them)" },
            { id = "if_prey_gives_any_useful_rewards_do_prey", text = "If Prey gives any useful rewards, do Prey" },
            { id = "do_world_quests_that_give_gear_upgrades", text = "Do world quests that give gear upgrades" },
            { id = "complete_a_world_tour_of_m0_dungeons_rewards_vet_ilvl_do_not_upgrade", text = "Complete a World Tour of M0 dungeons - rewards vet ilvl - do not upgrade" },
            { id = "queue_for_heroic_dungeons_for_remaining_slots", text = "Queue for Heroic Dungeons for remaining slots" },
        },
    },
    {
        id = "pre_season_week_2_march_10_m0_s",
        title = "Pre-Season Week 2 - March 10 - M0's",
        items = {
            { id = "do_not_spend_any_crests_until_told_to_do_so", text = "Do not spend any Crests until told to do so" },
            { id = "grab_darkmoon_faire_buff_for_renown_loremaster_if_a_crafter", text = "Grab Darkmoon Faire buff for Renown Loremaster if a crafter" },
            { id = "unlock_delves_through_tier_8_11_if_available", text = "Unlock Delves through tier 8 (11 if available)" },
            { id = "complete_weekly_events_if_available_tbd_will_add_as_we_get_them", text = "Complete weekly events if available. (TBD, will add as we get them)" },
            { id = "if_prey_gives_any_useful_rewards_do_prey", text = "If Prey gives any useful rewards, do Prey" },
            { id = "do_world_quests_that_give_gear_upgrades", text = "Do world quests that give gear upgrades" },
            { id = "complete_a_world_tour_of_m0_dungeons_rewards_vet_ilvl_do_not_upgrade", text = "Complete a World Tour of M0 dungeons - rewards vet ilvl - do not upgrade" },
            { id = "queue_for_heroic_dungeons_for_remaining_slots", text = "Queue for Heroic Dungeons for remaining slots" },
            { id = "if_you_raid_tuesday_the_17th_craft_see_doc_for_more_info", text = "If you raid Tuesday the 17th, craft. See doc for more info." },
        },
    },
    {
        id = "season_1_week_1_mar_17_heroic_week",
        title = "Season 1 Week 1 - Mar 17 - Heroic Week",
        items = {
            { id = "do_not_spend_heroic_or_mythic_crests", text = "Do NOT spend Heroic or Mythic crests" },
            { id = "do_lfr_for_tier_pieces_check_guide_for_why", text = "Do LFR for tier pieces (check guide for why)" },
            { id = "complete_a_world_tour_of_m0_dungeons_rewards_champ_ilvl", text = "Complete a World Tour of M0 dungeons - rewards champ ilvl" },
            { id = "kill_world_boss_for_champ_ilvl", text = "Kill World Boss for champ ilvl" },
            { id = "do_high_level_bountiful_delves_with_coffer_keys_use_map_if_possible", text = "Do high level bountiful delves with coffer keys, use map if possible" },
            { id = "if_prey_gives_any_useful_rewards_do_prey", text = "If Prey gives any useful rewards, do Prey" },
            { id = "complete_pvp_quest_for_guaranteed_hero_neck_ring", text = "Complete pvp quest for guaranteed hero neck/ring" },
            { id = "before_raid_craft_5x_246_ilvl_pieces_include_2x_embellishments_on_weak_slots_use_60_vet_crests", text = "Before raid, craft 5x 246 ilvl pieces, include 2x embellishments on weak slots, use 60 Vet Crests" },
            { id = "before_raid_craft_233_ilvl_pieces_to_fill_out_any_remaining_slots", text = "Before raid, craft 233 ilvl pieces to fill out any remaining slots" },
            { id = "spend_any_remaining_normal_difficulty_or_below_crests", text = "Spend any remaining normal difficulty or below crests" },
            { id = "complete_your_raids", text = "Complete your raids" },
            { id = "track_crests_0_100_heroic", text = "Track crests: 0/100 Heroic" },
        },
    },
    {
        id = "week_2_mar_24_mythic_week_m_opens_take_off_work_giganerds",
        title = "Week 2 - Mar 24 - Mythic Week, M+ Opens, take off work giganerds",
        items = {
            { id = "do_not_spend_heroic_or_mythic_crests", text = "Do NOT spend Heroic or Mythic Crests" },
            { id = "do_lfr_for_tier_pieces_check_guide_for_why", text = "Do LFR for tier pieces (check guide for why)" },
            { id = "kill_world_boss_for_champ_ilvl", text = "Kill World Boss for champ ilvl" },
            { id = "do_high_level_bountiful_delves_with_coffer_keys_use_map_if_possible", text = "Do high level bountiful delves with coffer keys, use map if possible" },
            { id = "if_prey_gives_any_useful_rewards_do_prey", text = "If Prey gives any useful rewards, do Prey" },
            { id = "spend_normal_and_below_crests_on_temporary_upgrades", text = "Spend Normal and below crests on temporary upgrades" },
            { id = "farm_10s_for_266_gear_in_every_slot", text = "Farm +10s for 266 gear in every slot" },
            { id = "full_clear_normal_heroic_and_do_as_much_of_mythic_as_you_can", text = "Full Clear Normal, Heroic, and do as much of Mythic as you can" },
            { id = "if_lucky_upgrade_mythic_item_twice_adjust_the_advice_below_until_it_sorts_out_again", text = "If lucky, upgrade mythic item twice. Adjust the advice below until it sorts out again." },
            { id = "track_crests_0_200_heroic_0_100_gilded", text = "Track crests: 0/200 Heroic, 0/100 Gilded" },
            { id = "ending_item_level_15x266_finished_farming_heroic_pieces", text = "Ending item level: 15x266, finished farming heroic pieces" },
        },
    },
    {
        id = "week_3_mar_31_final_raid_opens",
        title = "Week 3 - Mar 31 - Final Raid Opens",
        items = {
            { id = "do_not_spend_heroic_crests_until_after_reclear", text = "Do NOT spend Heroic crests until after reclear" },
            { id = "open_vault_272_myth_item_upgrade_after_crafting", text = "Open vault (272+ myth item) - upgrade after crafting" },
            { id = "craft_2h_mythic_weapon_5_6_285_see_note_in_text_guide", text = "Craft 2H mythic weapon (5/6 285) - see note in text guide" },
            { id = "if_no_4p_do_lfr_for_tier_pieces_check_guide_for_why", text = "If no 4p, do LFR for tier pieces (check guide for why)" },
            { id = "farm_12s_for_vault_crests", text = "Farm +12s for vault + crests" },
            { id = "before_mythic_progression_upgrade_heroic_items_to_4_6_269_300_heroic_crests_see_guide", text = "Before Mythic Progression, upgrade heroic items to 4/6 269 (300 Heroic crests) (see guide)" },
            { id = "full_clear_normal_heroic_and_do_as_much_of_mythic_as_you_can", text = "Full Clear Normal, Heroic, and do as much of Mythic as you can" },
            { id = "upgrade_vault_item_to_4_6_282_60_mythic_crests", text = "Upgrade vault item to 4/6 282 (60 Mythic crests)" },
            { id = "track_crests_300_300_heroic_120_200_gilded", text = "Track crests: 300/300 Heroic, 120/200 Gilded" },
            { id = "ending_item_level_3x266_10x_269_1x_282_1x285_crafted", text = "Ending item level: 3x266, 10x 269, 1x 282, 1x285(crafted)" },
        },
    },
    {
        id = "week_4_apr_7",
        title = "Week 4 - Apr 7",
        items = {
            { id = "open_vault_272_myth_item", text = "Open vault (272+ myth item)" },
            { id = "farm_12s_for_vault_crests", text = "Farm +12s for vault + crests" },
            { id = "heroic_upgrade_266_269_60_crests", text = "Heroic: Upgrade 266->269 (60 crests)" },
            { id = "heroic_upgrade_269_272_40_crests", text = "Heroic: Upgrade 269->272 (40 crests)" },
            { id = "upgrade_myth_items_to_4_6_282", text = "Upgrade myth items to 4/6 282" },
            { id = "upgrade_1_myth_item_to_5_6_282_only_if_you_dont_have_other_items_to_upgrade", text = "Upgrade 1 myth item to 5/6 282 (only if you dont have other items to upgrade)" },
            { id = "track_crests_400_400_heroic_280_300_gilded", text = "Track crests: 400/400 Heroic, 280/300 Gilded" },
            { id = "ending_item_level_1x266_10x_269_2x_282_1x285_1x285_crafted", text = "Ending item level: 1x266, 10x 269, 2x 282, 1x285, 1x285(crafted)" },
        },
    },
    {
        id = "week_5_apr_14",
        title = "Week 5 - Apr 14",
        items = {
            { id = "open_vault_272_myth_item", text = "Open vault (272+ myth item)" },
            { id = "farm_12s_for_vault_crests", text = "Farm +12s for vault + crests" },
            { id = "heroic_upgrade_269_272_80_crests", text = "Heroic: Upgrade 269->272 (80 crests)" },
            { id = "upgrade_myth_item_to_4_6_282", text = "Upgrade myth item to 4/6 282" },
            { id = "track_crests_480_500_heroic_400_400_gilded", text = "Track crests: 480/500 Heroic, 400/400 Gilded" },
            { id = "ending_item_level_7x_269_2x_272h_3x_282_1x285_2x285_crafted", text = "Ending item level:  7x 269, 2x 272h, 3x 282, 1x285, 2x285(crafted)" },
        },
    },
    {
        id = "week_6_apr_21",
        title = "Week 6 - Apr 21",
        items = {
            { id = "open_vault_272_myth_item", text = "Open vault (272+ myth item)" },
            { id = "farm_12s_for_vault_crests", text = "Farm +12s for vault + crests" },
            { id = "heroic_upgrade_269_272_120_crests", text = "Heroic: Upgrade 269->272 (120 crests)" },
            { id = "upgrade_myth_items_to_282", text = "Upgrade myth items to 282" },
            { id = "track_crests_600_600_heroic_490_500_gilded", text = "Track crests: 600/600 Heroic, 490/500 Gilded" },
            { id = "ending_item_level_2x_269_5x_272h_6x_282_2x285_crafted", text = "Ending item level:  2x 269, 5x 272h, 6x 282, 2x285(crafted)" },
        },
    },
    {
        id = "week_7_apr_28",
        title = "Week 7 - Apr 28",
        items = {
            { id = "open_vault_272_myth_item", text = "Open vault (272+ myth item)" },
            { id = "farm_12s_for_vault_crests", text = "Farm +12s for vault + crests" },
            { id = "craft_third_mythic_item_5_6_285", text = "Craft third mythic item (5/6 285)" },
            { id = "upgrade_remaining_heroic_items", text = "Upgrade remaining heroic items" },
            { id = "upgrade_myth_item_to_279", text = "Upgrade myth item to 279" },
            { id = "track_crests_680_700_heroic_580_600_gilded", text = "Track crests: 680/700 Heroic, 580/600 Gilded" },
            { id = "ending_item_level_5x_272h_1x_279_6x_282_3x285_crafted", text = "Ending item level:  5x 272h, 1x 279, 6x 282, 3x285(crafted)" },
        },
    },
    {
        id = "week_8_may_5_done_with_heroic_crests",
        title = "Week 8 - May 5 - Done with Heroic Crests",
        items = {
            { id = "open_vault_272_myth_item", text = "Open vault (272+ myth item)" },
            { id = "farm_12s_for_vault_crests", text = "Farm +12s for vault + crests" },
            { id = "finish_heroic_upgrades", text = "Finish heroic upgrades" },
            { id = "upgrade_multiple_myth_track_items", text = "Upgrade multiple myth track items" },
            { id = "track_crests_780_800_heroic_done_680_700_gilded", text = "Track crests: 780/800 Heroic (Done), 680/700 Gilded" },
        },
    },
    {
        id = "weeks_9_may_12",
        title = "Weeks 9+ - May 12+",
        items = {
            { id = "craft_at_5_6_every_other_week_if_a_crest_save", text = "Craft at 5/6 every other week if a crest save" },
            { id = "get_item_slots_to_4_6_282_that_you_aren_t_crafting_in_leave_others_at_2_6_or_3_6", text = "Get item slots to 4/6 282 that you aren't crafting in, leave others at 2/6 or 3/6" },
            { id = "upgrade_1_item_per_week_to_6_6_289", text = "Upgrade 1 item per week to 6/6 289" },
            { id = "sim_weekly_before_spending_crests", text = "Sim weekly before spending crests" },
            { id = "plan_for_possible_1h_crafted_oh_swap", text = "Plan for possible 1H + crafted OH swap" },
            { id = "prepare_for_7_8_and_8_8_upgrades_if_turbo_exists", text = "Prepare for 7/8 and 8/8 upgrades if turbo exists" },
        },
    },
}
end
