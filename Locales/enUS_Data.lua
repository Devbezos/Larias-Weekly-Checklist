--[[
English (enUS) checklist data for Larias's Weekly Checklist

NOTE: This is the canonical enUS dataset; other locales must keep IDs identical
so completion tracking stays consistent across locales.
]]

local LOCALE = "enUS"

local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"

local reg = _G[LOCALE_REGISTRY_KEY]
if type(reg) ~= "table" then
    reg = {}
    _G[LOCALE_REGISTRY_KEY] = reg
end
if type(reg.data) ~= "table" then reg.data = {} end

local DATASET = {

    {
        id = "early_access_feb_26_through_mar_2_pay_to_win",
        title = "Early Access - Feb 26 through Mar 2 - Pay to Win",
        items = {
            { id = "do_not_spend_any_crests_until_told_to_do_so", text = "Do not spend any Crests until told to do so" },
            { id = "level_characters_warmode_on_to_90_dmf_opens_sunday_for_10_more_exp", text = "Level characters warmode on to 90 - DMF opens Sunday for 10% more exp" },
            { id = "if_available_complete_the_weekly_saltheril_s_soiree_in_eversong_woods_with_the_dmf_buff", text = "If available, complete the weekly Saltheril's Soiree in Eversong Woods with the DMF buff." },
            { id = "if_available_complete_the_weekly_abundance_event_in_zul_aman_with_the_dmf_buff", text = "If available, complete the weekly Abundance Event in Zul'aman with the DMF buff." },
            { id = "if_available_complete_the_weekly_legends_of_the_haranir_event_in_harandar_with_the_dmf_buff", text = "If available, complete the weekly Legends of the Haranir event in Harandar with the DMF buff." },
            { id = "if_available_complete_the_weekly_stormarion_assault_in_the_voidstorm_with_the_dmf_buff", text = "If available, complete the weekly Stormarion Assault in the Voidstorm with the DMF buff." },
            { id = "optional_kill_each_rare_once_in_each_zone_for_renown_these_are_a_weekly_lockout_for_each_rare", text = "(Optional) Kill each rare once in each zone for renown. These are a weekly lockout for each rare." },
            { id = "complete_4x_prey_on_normal_difficulty_for_veteran_gear", text = "Complete 4x Prey on normal difficulty for veteran gear." },
            { id = "once_dmf_opens_complete_side_quest_chains_for_renown_can_be_done_on_alts_to_level_at_same_time", text = "Once DMF opens, complete side quest chains for renown. (can be done on alts to level at same time)" },
            { id = "unlikely_see_doc_for_info_complete_a_world_tour_of_m0_s_after_full_release_but_before_your_region_s_reset", text = "(Unlikely, see doc for info) Complete a world tour of M0's after full release but before your region's reset" },
        },
    },
    {
        id = "pre_season_week_1_march_3_m0_s",
        title = "Pre-Season Week 1 - March 3 - M0's",
        items = {
            { id = "do_not_spend_any_crests_until_told_to_do_so", text = "Do not spend any Crests until told to do so" },
            { id = "raise_the_singularity_renown_to_rank_7_for_1_6_champion_trinket", text = "Raise The Singularity renown to rank 7 for 1/6 champion trinket" },
            { id = "raise_hara_ti_renown_to_rank_8_for_1_6_champion_belt", text = "Raise Hara'ti renown to rank 8 for 1/6 champion belt" },
            { id = "raise_silvermoon_renown_to_rank_9_for_1_6_champion_helm", text = "Raise Silvermoon renown to rank 9 for 1/6 champion helm" },
            { id = "raise_amani_tribe_renown_to_rank_9_for_1_6_champion_necklace", text = "Raise Amani Tribe renown to rank 9 for 1/6 champion necklace" },
            { id = "complete_the_weekly_saltheril_s_soiree_in_eversong_woods_with_the_dmf_buff", text = "Complete the weekly Saltheril's Soiree in Eversong Woods with the DMF buff." },
            { id = "complete_the_weekly_abundance_event_in_zul_aman_with_the_dmf_buff", text = "Complete the weekly Abundance Event in Zul'aman with the DMF buff." },
            { id = "complete_the_weekly_legends_of_the_haranir_event_in_harandar_with_the_dmf_buff", text = "Complete the weekly Legends of the Haranir event in Harandar with the DMF buff." },
            { id = "complete_the_weekly_stormarion_assault_in_the_voidstorm_with_the_dmf_buff", text = "Complete the weekly Stormarion Assault in the Voidstorm with the DMF buff." },
            { id = "optional_kill_each_rare_once_in_each_zone_for_renown_these_are_a_weekly_lockout_for_each_rare", text = "(Optional) Kill each rare once in each zone for renown. These are a weekly lockout for each rare." },
            { id = "unlock_delves_through_tier_8_11_if_available", text = "Unlock Delves through tier 8 (11 if available)" },
            { id = "optional_complete_4x_normal_prey_for_adventurer_gear_and_renown", text = "(Optional) Complete 4x Normal Prey for adventurer gear and renown." },
            { id = "complete_4x_hard_prey_for_veteran_gear_and_renown", text = "Complete 4x Hard Prey for Veteran gear and renown." },
            { id = "complete_a_world_tour_of_m0_dungeons_rewards_vet_ilvl_do_not_upgrade_yet", text = "Complete a World Tour of M0 dungeons - rewards vet ilvl - do not upgrade yet" },
        },
    },
    {
        id = "pre_season_week_2_march_10_m0_s",
        title = "Pre-Season Week 2 - March 10 - M0's",
        items = {
            { id = "do_not_spend_any_crests_until_told_to_do_so", text = "Do not spend any Crests until told to do so" },
            { id = "if_not_completed_continue_to_raise_renown_for_champion_pieces", text = "If not completed, continue to raise renown for Champion Pieces" },
            { id = "complete_the_weekly_saltheril_s_soiree_in_eversong_woods", text = "Complete the weekly Saltheril's Soiree in Eversong Woods." },
            { id = "complete_the_weekly_abundance_event_in_zul_aman", text = "Complete the weekly Abundance Event in Zul'aman." },
            { id = "complete_the_weekly_legends_of_the_haranir_event_in_harandar", text = "Complete the weekly Legends of the Haranir event in Harandar." },
            { id = "complete_the_weekly_stormarion_assault_in_the_voidstorm", text = "Complete the weekly Stormarion Assault in the Voidstorm." },
            { id = "optional_kill_each_rare_once_in_each_zone_for_renown_these_are_a_weekly_lockout_for_each_rare", text = "(Optional) Kill each rare once in each zone for renown. These are a weekly lockout for each rare." },
            { id = "unlock_delves_through_tier_8_11_if_available_if_not_done_yet", text = "Unlock Delves through tier 8 (11 if available) if not done yet" },
            { id = "optional_complete_4x_normal_prey_for_adventurer_gear_and_renown", text = "(Optional) Complete 4x Normal Prey for adventurer gear and renown." },
            { id = "complete_4x_hard_prey_for_veteran_gear_and_renown", text = "Complete 4x Hard Prey for Veteran gear and renown." },
            { id = "complete_a_world_tour_of_m0_dungeons_rewards_vet_ilvl_do_not_upgrade_yet", text = "Complete a World Tour of M0 dungeons - rewards vet ilvl - do not upgrade yet" },
            { id = "if_you_raid_tuesday_the_17th_craft_see_doc_for_more_info", text = "If you raid Tuesday the 17th, craft. See doc for more info." },
        },
    },
    {
        id = "season_1_week_1_mar_17_heroic_week",
        title = "Season 1 Week 1 - Mar 17 - Heroic Week",
        items = {
            { id = "do_not_spend_any_crests_until_told_to_do_so", text = "Do not spend any Crests until told to do so" },
            { id = "do_lfr_for_tier_pieces_check_guide_for_why", text = "Do LFR for tier pieces (check guide for why)" },
            { id = "complete_a_world_tour_of_m0_dungeons_rewards_champ_ilvl", text = "Complete a World Tour of M0 dungeons - rewards champ ilvl" },
            { id = "complete_4x_nightmare_prey_for_champion_gear_and_renown", text = "Complete 4x Nightmare Prey for Champion gear and renown." },
            { id = "kill_world_boss_for_champ_2_6_250_ilvl_item", text = "Kill World Boss for champ 2/6 250 ilvl item" },
            { id = "if_available_complete_pvp_quest_for_guaranteed_hero_neck_ring", text = "If available, complete pvp quest for guaranteed hero neck/ring" },
            { id = "do_t8_bountiful_delves_with_coffer_keys_use_map_on_t8_delve", text = "Do t8 bountiful delves with coffer keys, use map on t8+ delve" },
            { id = "before_raid_craft_2x_246_ilvl_pieces_2x_embellishments_on_weak_slots_use_160_vet_crests", text = "Before raid, craft 2x 246 ilvl pieces, 2x embellishments on weak slots, use 160 Vet Crests" },
            { id = "before_raid_spend_all_adventurer_veteran_and_champion_crests_upgrading_anything", text = "Before raid, spend all Adventurer, Veteran and Champion Crests upgrading anything" },
            { id = "track_crests_0_100_heroic_0_100_mythic", text = "Track crests: 0/100 Heroic, 0/100 Mythic" },
        },
    },
    {
        id = "week_2_mar_24_mythic_week_m_opens_take_off_work_giganerds",
        title = "Week 2 - Mar 24 - Mythic Week, M+ Opens, take off work giganerds",
        items = {
            { id = "do_not_spend_any_crests_until_told_to_do_so", text = "Do not spend any Crests until told to do so" },
            { id = "1h_crafted_note_check_guide_check_craft_path_info_very_important", text = "1h crafted note, check guide, check craft path info(VERY IMPORTANT!)" },
            { id = "do_lfr_for_tier_pieces_check_guide_for_why", text = "Do LFR for tier pieces (check guide for why)" },
            { id = "optional_kill_world_boss_for_champ_2_6_250_ilvl_item", text = "(Optional) Kill World Boss for champ 2/6 250 ilvl item" },
            { id = "optional_complete_4x_nightmare_prey_for_champion_gear_and_renown", text = "(Optional) Complete 4x Nightmare Prey for Champion gear and renown." },
            { id = "do_at_least_one_t11_bountiful_delve_to_get_cracked_keystone_quest", text = "Do at least one t11 bountiful delve to get Cracked Keystone Quest" },
            { id = "continue_to_spend_all_adventurer_veteran_and_champion_crests_upgrading_anything", text = "Continue to spend all Adventurer, Veteran and Champion Crests upgrading anything" },
            { id = "farm_10s_for_266_gear_in_every_slot", text = "Farm +10s for 266 gear in every slot" },
            { id = "before_mythic_raid_upgrade_11x_3_6_hero_items_once_each", text = "Before Mythic raid, Upgrade 11x 3/6 hero items once each" },
            { id = "mythic_if_you_re_lucky_and_got_a_myth_track_item_skip_to_next_week_s_upgrade_advice_for_it", text = "Mythic: If you're lucky and got a Myth track item, skip to next week's upgrade advice for it." },
            { id = "track_crests_220_220_heroic_0_220_mythic_never_hold_mythic_crests", text = "Track crests: 220/220 Heroic, 0/220 Mythic - never hold Mythic crests" },
            { id = "ending_item_level_4x266_11x269", text = "Ending item level: 4x266, 11x269" },
        },
    },
    {
        id = "week_3_mar_31_final_raid_opens",
        title = "Week 3 - Mar 31 - Final Raid Opens",
        items = {
            { id = "open_vault_272_myth_item_upgrade_after_crafting", text = "Open vault (272+ myth item) - upgrade after crafting" },
            { id = "craft_items_see_guide_for_2_paths_to_pick", text = "Craft items - see guide for 2 paths to pick" },
            { id = "if_no_4p_do_lfr_for_tier_pieces_check_guide_for_why", text = "If no 4p, do LFR for tier pieces (check guide for why)" },
            { id = "farm_10s_for_vault_crests", text = "Farm +10s for vault + crests" },
            { id = "heroic_upgrade_2_of_your_4_6_269_items_to_6_6_276_for_80_heroic_crests", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests" },
            { id = "mythic_if_your_vault_item_was_1_6_upgrade_its_heroic_counterpart_first_to_6_6_heroic_for_20_heroic_crests_upgrade_your_1_6_272_myth_track_item_to_6_6_289_for_80_myth_crests", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "if_you_got_a_2nd_myth_track_item_skip_to_next_week_s_upgrade_advice_for_it", text = "If you got a 2nd myth track item, skip to next week's upgrade advice for it." },
            { id = "track_crests_320_320_heroic_160_320_mythic_never_hold_mythic_crests", text = "Track crests: 320/320 Heroic, 160/320 Mythic - never hold Mythic crests" },
            { id = "ending_item_level_3x266_8x269_2x276h_1x285_crafted_1x289", text = "Ending item level: 3x266, 8x269, 2x276h, 1x285(crafted), 1x289" },
        },
    },
    {
        id = "week_4_apr_7",
        title = "Week 4 - Apr 7",
        items = {
            { id = "open_vault_272_myth_item", text = "Open vault (272+ myth item)" },
            { id = "farm_10s_for_vault_crests", text = "Farm +10s for vault + crests" },
            { id = "heroic_upgrade_2_of_your_4_6_269_items_to_6_6_276_for_80_heroic_crests", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests" },
            { id = "mythic_if_your_vault_item_was_1_6_upgrade_its_heroic_counterpart_first_to_6_6_heroic_for_20_heroic_crests_upgrade_your_1_6_272_myth_track_item_to_6_6_289_for_80_myth_crests", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "mythic_upgrade_your_raid_drop_from_2_6_275_myth_track_to_6_6_289_for_80_myth_crests", text = "Mythic: Upgrade your raid drop from 2/6 275 Myth track to 6/6 289 for 80 Myth crests." },
            { id = "track_crests_420_400_heroic_320_420_mythic_never_hold_mythic_crests", text = "Track crests: 420/400 Heroic, 320/420 Mythic - never hold Mythic crests" },
            { id = "ending_item_level_2x266_5x269_4x276h_1x285_crafted_3x289", text = "Ending item level: 2x266, 5x269, 4x276h, 1x285(crafted), 3x289" },
        },
    },
    {
        id = "week_5_apr_14",
        title = "Week 5 - Apr 14",
        items = {
            { id = "open_vault_272_myth_item", text = "Open vault (272+ myth item)" },
            { id = "farm_10s_for_vault_crests", text = "Farm +10s for vault + crests" },
            { id = "craft_next_item_see_doc_for_more_info", text = "Craft next item (see doc for more info)" },
            { id = "heroic_upgrade_2_of_your_4_6_269_items_to_6_6_276_for_80_heroic_crests", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests" },
            { id = "mythic_if_your_vault_item_was_1_6_upgrade_its_heroic_counterpart_first_to_6_6_heroic_for_20_heroic_crests_upgrade_your_1_6_272_myth_track_item_to_6_6_289_for_80_myth_crests", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "track_crests_520_520_heroic_480_520_mythic_never_hold_mythic_crests", text = "Track crests: 520/520 Heroic, 480/520 Mythic - never hold Mythic crests" },
            { id = "ending_item_level_1x266_2x269_6x276h_2x285_crafted_4x289", text = "Ending item level:  1x266, 2x269, 6x276h, 2x285(crafted), 4x289" },
        },
    },
    {
        id = "week_6_apr_21_done_with_heroic_crests",
        title = "Week 6 - Apr 21 - Done with Heroic Crests",
        items = {
            { id = "open_vault_272_myth_item", text = "Open vault (272+ myth item)" },
            { id = "farm_10s_for_vault_crests", text = "Farm +10s for vault + crests" },
            { id = "heroic_upgrade_your_last_4_6_269_item_to_6_6_276_for_40_heroic_crests", text = "Heroic: Upgrade your last 4/6 269 item to 6/6 276 for 40 Heroic Crests" },
            { id = "mythic_if_your_vault_item_was_1_6_upgrade_its_heroic_counterpart_first_to_6_6_heroic_for_20_heroic_crests_upgrade_your_1_6_272_myth_track_item_to_6_6_289_for_80_myth_crests", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "mythic_upgrade_your_raid_drop_from_2_6_275_myth_track_to_6_6_289_for_80_myth_crests", text = "Mythic: Upgrade your raid drop from 2/6 275 Myth track to 6/6 289 for 80 Myth crests." },
            { id = "track_crests_560_620_heroic_620_620_mythic_never_hold_mythic_crests", text = "Track crests: 560/620 Heroic, 620/620 Mythic - never hold Mythic crests" },
            { id = "ending_item_level_7x276h_2x285_crafted_1x_285_5x289", text = "Ending item level:  7x276h, 2x285(crafted), 1x 285, 5x289" },
        },
    },
    {
        id = "week_7_apr_28",
        title = "Week 7 - Apr 28+",
        items = {
            { id = "do_not_craft_if_you_can_get_vault_items_higher_than_1_6", text = "Do not craft if you can get vault items higher than 1/6" },
            { id = "upgrade_mythic_items_as_you_get_them_preferring_to_jump_them_to_289_for_the_4_jump", text = "Upgrade Mythic items as you get them, preferring to jump them to 289 for the +4 jump" },
            { id = "plan_for_possible_1h_crafted_oh_swap", text = "Plan for possible 1H + crafted OH swap" },
            { id = "enjoy_blizzard_s_much_better_upgrade_system", text = "Enjoy Blizzard's much better upgrade system!" },
        },
    },
}

reg.data[LOCALE] = DATASET
