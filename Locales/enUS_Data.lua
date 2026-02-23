--[[
English (enUS) checklist data for Larias's Weekly Checklist

NOTE: This is the canonical enUS dataset; other locales must keep IDs identical
so completion tracking stays consistent across locales.
]]

local addonName = ...
local locale = (GetLocale and GetLocale()) or nil
local LOCALE = "enUS"
local listKey = addonName .. "_LIST_DATA"

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
            { id = "level_characters_to_90_dmf_opens_sunday_for_10_more_exp", text = "Level characters to 90 - DMF opens Sunday for 10% more exp" },
            { id = "after_sunday_use_dmf_buff_to_raise_renowns_see_week_1", text = "After Sunday, use DMF buff to raise renowns (see week 1)" },
            { id = "complete_weekly_events_if_available_tbd_will_add_as_we_get_them", text = "Complete weekly events if available. (TBD, will add as we get them)" },
            { id = "if_prey_can_be_upgraded_do_so_as_nightmare_preys_might_give_champ_pieces", text = "If Prey can be upgraded, do so as Nightmare Preys might give champ pieces" },
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
            { id = "unlock_delves_through_tier_8_11_if_available", text = "Unlock Delves through tier 8 (11 if available)" },
            { id = "complete_weekly_events_if_available_tbd_will_add_as_we_get_them", text = "Complete weekly events if available. (TBD, will add as we get them)" },
            { id = "if_prey_gives_any_useful_rewards_do_prey_might_give_champ_pieces_on_nightmare", text = "If Prey gives any useful rewards, do Prey (might give champ pieces on nightmare)" },
            { id = "do_world_quests_that_give_gear_upgrades", text = "Do world quests that give gear upgrades" },
            { id = "complete_a_world_tour_of_m0_dungeons_rewards_vet_ilvl_do_not_upgrade_yet", text = "Complete a World Tour of M0 dungeons - rewards vet ilvl - do not upgrade yet" },
            { id = "queue_for_heroic_dungeons_for_remaining_slots", text = "Queue for Heroic Dungeons for remaining slots" },
        },
    },
    {
        id = "pre_season_week_2_march_10_m0_s",
        title = "Pre-Season Week 2 - March 10 - M0's",
        items = {
            { id = "do_not_spend_any_crests_until_told_to_do_so", text = "Do not spend any Crests until told to do so" },
            { id = "unlock_delves_through_tier_8_11_if_available", text = "Unlock Delves through tier 8 (11 if available)" },
            { id = "complete_weekly_events_if_available_tbd_will_add_as_we_get_them", text = "Complete weekly events if available. (TBD, will add as we get them)" },
            { id = "if_prey_gives_any_useful_rewards_do_prey_might_give_champ_pieces_on_nightmare", text = "If Prey gives any useful rewards, do Prey (might give champ pieces on nightmare)" },
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
            { id = "if_prey_gives_any_useful_rewards_do_prey_might_give_champ_pieces_on_nightmare", text = "If Prey gives any useful rewards, do Prey (might give champ pieces on nightmare)" },
            { id = "complete_pvp_quest_for_guaranteed_hero_neck_ring", text = "Complete pvp quest for guaranteed hero neck/ring" },
            { id = "before_raid_craft_2x_246_ilvl_pieces_2x_embellishments_on_weak_slots_use_160_vet_crests", text = "Before raid, craft 2x 246 ilvl pieces, 2x embellishments on weak slots, use 160 Vet Crests" },
            { id = "before_raid_spend_all_veteran_and_champion_crests_upgrading_everything", text = "Before raid, spend all Veteran and Champion Crests upgrading everything" },
            { id = "complete_your_raids", text = "Complete your raids" },
            { id = "track_crests_0_100_heroic_0_100_mythic", text = "Track crests: 0/100 Heroic, 0/100 Mythic" },
        },
    },
    {
        id = "week_2_mar_24_mythic_week_m_opens_take_off_work_giganerds",
        title = "Week 2 - Mar 24 - Mythic Week, M+ Opens, take off work giganerds",
        items = {
            { id = "do_lfr_for_tier_pieces_check_guide_for_why", text = "Do LFR for tier pieces (check guide for why)" },
            { id = "kill_world_boss_for_champ_ilvl", text = "Kill World Boss for champ ilvl" },
            { id = "do_high_level_bountiful_delves_with_coffer_keys_use_map_if_possible", text = "Do high level bountiful delves with coffer keys, use map if possible" },
            { id = "even_if_you_skip_delves_do_at_least_one_t11_to_get_cracked_keystone_quest", text = "Even if you skip Delves, do at least one t11 to get Cracked Keystone Quest" },
            { id = "farm_10s_for_266_gear_in_every_slot", text = "Farm +10s for 266 gear in every slot" },
            { id = "1h_crafted_note_check_guide_ignore_if_you_don_t_dual_wield", text = "1h crafted note, check guide (ignore if you don't dual wield)" },
            { id = "full_clear_normal_and_heroic", text = "Full Clear Normal and Heroic" },
            { id = "before_mythic_raid_upgrade_11x_3_6_hero_items_once_each", text = "Before Mythic raid, Upgrade 11x 3/6 hero items once each" },
            { id = "enjoy_mythic_progression", text = "Enjoy Mythic Progression!" },
            { id = "mythic_if_you_re_lucky_and_got_a_myth_track_item_skip_to_next_week_s_upgrade_advice_for_it", text = "Mythic: If you're lucky and got a Myth track item, skip to next week's upgrade advice for it." },
            { id = "track_crests_220_220_heroic_0_220_mythic", text = "Track crests: 220/220 Heroic, 0/220 Mythic" },
            { id = "ending_item_level_4x266_11x269", text = "Ending item level: 4x266, 11x269" },
        },
    },
    {
        id = "week_3_mar_31_final_raid_opens",
        title = "Week 3 - Mar 31 - Final Raid Opens",
        items = {
            { id = "open_vault_272_myth_item_upgrade_after_crafting", text = "Open vault (272+ myth item) - upgrade after crafting" },
            { id = "craft_2h_mythic_weapon_5_6_285_see_note_in_text_guide", text = "Craft 2H mythic weapon (5/6 285) - see note in text guide" },
            { id = "if_no_4p_do_lfr_for_tier_pieces_check_guide_for_why", text = "If no 4p, do LFR for tier pieces (check guide for why)" },
            { id = "farm_12s_for_vault_crests", text = "Farm +12s for vault + crests" },
            { id = "heroic_upgrade_2_of_your_4_6_269_items_to_6_6_276_for_80_heroic_crests", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests" },
            { id = "mythic_if_your_vault_item_was_1_6_upgrade_its_heroic_counterpart_first_to_6_6_heroic_for_20_heroic_crests_upgrade_your_1_6_272_myth_track_item_to_6_6_289_for_80_myth_crests", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "full_clear_normal_heroic_and_do_as_much_of_mythic_as_you_can", text = "Full Clear Normal, Heroic, and do as much of Mythic as you can" },
            { id = "if_you_got_a_2nd_myth_track_item_skip_to_next_week_s_upgrade_advice_for_it", text = "If you got a 2nd myth track item, skip to next week's upgrade advice for it." },
            { id = "track_crests_320_320_heroic_160_320_mythic", text = "Track crests: 320/320 Heroic, 160/320 Mythic" },
            { id = "ending_item_level_3x266_8x269_2x276h_1x285_crafted_1x289", text = "Ending item level: 3x266, 8x269, 2x276h, 1x285(crafted), 1x289" },
        },
    },
    {
        id = "week_4_apr_7",
        title = "Week 4 - Apr 7",
        items = {
            { id = "open_vault_272_myth_item", text = "Open vault (272+ myth item)" },
            { id = "farm_12s_for_vault_crests", text = "Farm +12s for vault + crests" },
            { id = "heroic_upgrade_2_of_your_4_6_269_items_to_6_6_276_for_80_heroic_crests", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests" },
            { id = "mythic_if_your_vault_item_was_1_6_upgrade_its_heroic_counterpart_first_to_6_6_heroic_for_20_heroic_crests_upgrade_your_1_6_272_myth_track_item_to_6_6_289_for_80_myth_crests", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "mythic_upgrade_your_raid_drop_from_2_6_275_myth_track_to_6_6_289_for_80_myth_crests", text = "Mythic: Upgrade your raid drop from 2/6 275 Myth track to 6/6 289 for 80 Myth crests." },
            { id = "track_crests_420_400_heroic_320_420_mythic", text = "Track crests: 420/400 Heroic, 320/420 Mythic" },
            { id = "ending_item_level_2x266_5x269_4x276h_1x285_crafted_3x289", text = "Ending item level: 2x266, 5x269, 4x276h, 1x285(crafted), 3x289" },
        },
    },
    {
        id = "week_5_apr_14",
        title = "Week 5 - Apr 14",
        items = {
            { id = "open_vault_272_myth_item", text = "Open vault (272+ myth item)" },
            { id = "farm_12s_for_vault_crests", text = "Farm +12s for vault + crests" },
            { id = "craft_2nd_embellishment_at_285_ilvl_mythic_for_80_myth_crests", text = "Craft 2nd embellishment at 285 ilvl Mythic for 80 Myth crests" },
            { id = "heroic_upgrade_2_of_your_4_6_269_items_to_6_6_276_for_80_heroic_crests", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests" },
            { id = "mythic_if_your_vault_item_was_1_6_upgrade_its_heroic_counterpart_first_to_6_6_heroic_for_20_heroic_crests_upgrade_your_1_6_272_myth_track_item_to_6_6_289_for_80_myth_crests", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "track_crests_520_520_heroic_480_520_mythic", text = "Track crests: 520/520 Heroic, 480/520 Mythic" },
            { id = "ending_item_level_1x266_2x269_6x276h_2x285_crafted_4x289", text = "Ending item level:  1x266, 2x269, 6x276h, 2x285(crafted), 4x289" },
        },
    },
    {
        id = "week_6_apr_21_done_with_heroic_crests",
        title = "Week 6 - Apr 21 - Done with Heroic Crests",
        items = {
            { id = "open_vault_272_myth_item", text = "Open vault (272+ myth item)" },
            { id = "farm_12s_for_vault_crests", text = "Farm +12s for vault + crests" },
            { id = "heroic_upgrade_your_last_4_6_269_item_to_6_6_276_for_40_heroic_crests", text = "Heroic: Upgrade your last 4/6 269 item to 6/6 276 for 40 Heroic Crests" },
            { id = "mythic_if_your_vault_item_was_1_6_upgrade_its_heroic_counterpart_first_to_6_6_heroic_for_20_heroic_crests_upgrade_your_1_6_272_myth_track_item_to_6_6_289_for_80_myth_crests", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "mythic_upgrade_your_raid_drop_from_2_6_275_myth_track_to_6_6_289_for_80_myth_crests", text = "Mythic: Upgrade your raid drop from 2/6 275 Myth track to 6/6 289 for 80 Myth crests." },
            { id = "track_crests_560_620_heroic_620_620_mythic", text = "Track crests: 560/620 Heroic, 620/620 Mythic" },
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

-- Back-compat: only set the legacy global dataset when the client locale matches.
-- Locale override uses `reg.data[LOCALE]` and should not require a matching client locale.
if locale == LOCALE then
    _G[listKey] = DATASET
end
