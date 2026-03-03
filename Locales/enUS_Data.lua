--[[
English (enUS) checklist data for Larias's Weekly Checklist

NOTE: This is the canonical enUS dataset; other locales must keep IDs identical
so completion tracking stays consistent across locales.
]]

-- @sheet-version: 14

local LOCALE = "enUS"

local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"

local reg = _G[LOCALE_REGISTRY_KEY]
if type(reg) ~= "table" then
    reg = {}
    _G[LOCALE_REGISTRY_KEY] = reg
end
if type(reg.data) ~= "table" then reg.data = {} end
reg.sheet_version = "14"

local DATASET = {

    {
        id = "bd6b2f68",
        title = "Early Access - Feb 26 through Mar 2",
        items = {
            { id = "f4b92a82", text = "Log on to each character you plan on leveling so they start accumulating rested XP." },
            { id = "90db618c", text = "Level characters warmode on to 90 - DMF opens Sunday for 10% more exp." },
            { id = "6af1d802", text = "Complete the weekly Stormarion Assault in the Voidstorm. (It is available in Early Access)" },
            { id = "35bc0cfd", text = "(Optional) Kill each rare once in each zone for renown. These are a weekly lockout for each rare." },
            { id = "2687fe6c", text = "Hunt down each region's treasures for free Renown. See doc for guide" },
            { id = "91e7ee6c", text = "Complete 4x Prey on normal difficulty for renown" },
            { id = "8bf4f442", text = "Complete the Midnight Lore Hunter achievement for renown - see doc for guide" },
            { id = "c886190c", text = "Complete the Highest Peaks achievement for renown - see doc for guide" },
            { id = "f9b8eb01", text = "Complete side quest chains for renown. (can be done on alts to level at same time). DMF buff does not give renown." },
            { id = "11425027", text = "Note: Only the Singularity AND Eversong champion renown trinket are available in early access - the others will become available either Monday after the official launch or after each region's weekly reset." },
            { id = "34624ba9", text = "March 2nd Emergency Update" },
            { id = "2c77c3c4", text = "Complete the weekly Saltheril's Soiree in Eversong Woods. THIS JUST OPENED, YOU HAVE TO COMPLETE BEFORE WEEKLY RESET! Don't forget to grab renown quest for the champion helmet if you have the renown" },
        },
    },
    {
        id = "50281d6f",
        title = "Pre-Season Week 1 - March 3 - M0's",
        items = {
            { id = "c3de7d35", text = "Do not spend any Crests until told to do so" },
            { id = "c06ee1a3", text = "If you are on an alt and don't see some of these quests, go to Soridormi in the Silvermoon City Inn and choose \"I Stopped the Voidstorm\" to skip the campaign." },
            { id = "6b199064", text = "Raise The Singularity renown to rank 7 for 1/6 champion trinket - available in early access - comes from quest from the renown vendor (not purchased)" },
            { id = "2a9b4f4c", text = "Raise Hara'ti renown to rank 8 for 1/6 champion belt - NOT available in early access - comes from quest from the renown vendor (not purchased)" },
            { id = "6f39070d", text = "Raise Silvermoon renown to rank 9 for 1/6 champion helm - NOT available in early access - comes from quest from the renown vendor (not purchased)" },
            { id = "6ba4afc1", text = "Raise Amani Tribe renown to rank 9 for 1/6 champion necklace - NOT available in early access - comes from quest from the renown vendor (not purchased)" },
            { id = "101e78a9", text = "Complete weekly dungeon quest from Halduron Brightwing for 1000 renown" },
            { id = "0c3b8835", text = "Complete weekly world event quest for pinnacle cache from Lady Liadrin - can pick weekly event quest and do it with the events below" },
            { id = "879d3833", text = "Complete weekly world tour quest from Lorthremar for spark by doing the below quests" },
            { id = "9f3c8578", text = "Complete weekly housing quest from Vaeli for ??" },
            { id = "e326ed96", text = "Complete the weekly Saltheril's Soiree in Eversong Woods." },
            { id = "da2fa0ef", text = "Complete the weekly Abundance Event in Zul'aman." },
            { id = "dbc8384b", text = "Complete the weekly Legends of the Haranir event in Harandar." },
            { id = "9ad64245", text = "Complete the weekly Stormarion Assault in the Voidstorm." },
            { id = "35bc0cfd", text = "(Optional) Kill each rare once in each zone for renown. These are a weekly lockout for each rare." },
            { id = "1b42ce30", text = "If not done, hunt down each region's treasures, lore hunter, and high peaks for free Renown. See doc for guide" },
            { id = "346bdd7e", text = "Unlock Delves through tier 8 (11 if available)" },
            { id = "9bc44f02", text = "Complete 2x Hard Prey for Veteran gear on each character - if only one character, do 4x on one character for renown" },
            { id = "a7ee4829", text = "Complete a World Tour of M0 dungeons - rewards vet ilvl - do not upgrade yet" },
        },
    },
    {
        id = "ff1f5a67",
        title = "Pre-Season Week 2 - March 10 - M0's",
        items = {
            { id = "c3de7d35", text = "Do not spend any Crests until told to do so" },
            { id = "75c5fe6e", text = "If not completed, continue to raise renown for Champion Pieces" },
            { id = "101e78a9", text = "Complete weekly dungeon quest from Halduron Brightwing for 1000 renown" },
            { id = "0c3b8835", text = "Complete weekly world event quest for pinnacle cache from Lady Liadrin - can pick weekly event quest and do it with the events below" },
            { id = "879d3833", text = "Complete weekly world tour quest from Lorthremar for spark by doing the below quests" },
            { id = "9f3c8578", text = "Complete weekly housing quest from Vaeli for ??" },
            { id = "e326ed96", text = "Complete the weekly Saltheril's Soiree in Eversong Woods." },
            { id = "da2fa0ef", text = "Complete the weekly Abundance Event in Zul'aman." },
            { id = "dbc8384b", text = "Complete the weekly Legends of the Haranir event in Harandar." },
            { id = "9ad64245", text = "Complete the weekly Stormarion Assault in the Voidstorm." },
            { id = "35bc0cfd", text = "(Optional) Kill each rare once in each zone for renown. These are a weekly lockout for each rare." },
            { id = "072e6955", text = "Unlock Delves through tier 8 (11 if available) if not done yet" },
            { id = "9bc44f02", text = "Complete 2x Hard Prey for Veteran gear on each character - if only one character, do 4x on one character for renown" },
            { id = "a7ee4829", text = "Complete a World Tour of M0 dungeons - rewards vet ilvl - do not upgrade yet" },
            { id = "c33e5c84", text = "If you raid Tuesday the 17th, craft. See doc for more info." },
        },
    },
    {
        id = "33a3fcba",
        title = "Season 1 Week 1 - Mar 17 - Heroic Week",
        items = {
            { id = "c3de7d35", text = "Do not spend any Crests until told to do so" },
            { id = "5b379666", text = "Do LFR for tier pieces (check guide for why)" },
            { id = "879d3833", text = "Complete weekly world tour quest from Lorthremar for spark by doing the below quests" },
            { id = "9f3c8578", text = "Complete weekly housing quest from Vaeli for ??" },
            { id = "952916cd", text = "(Optional) Complete a World Tour of M0 dungeons - rewards champ ilvl" },
            { id = "22842538", text = "Complete 2x Nightmare Prey for Champion gear on each character" },
            { id = "dc0e2686", text = "Kill World Boss for champ 2/6 250 ilvl item" },
            { id = "3e0dfde7", text = "If available, complete pvp quest for guaranteed hero neck/ring" },
            { id = "fdfd56bc", text = "Do t8 bountiful delves with coffer keys, use map on t8+ delve" },
            { id = "eff76e73", text = "Before raid, craft 2x 246 ilvl pieces, 2x embellishments on weak slots, use 160 Vet Crests" },
            { id = "2af0bfb5", text = "Before raid, spend all Adventurer, Veteran and Champion Crests upgrading anything" },
            { id = "5768e0fe", text = "Track crests: 0/100 Heroic, 0/100 Mythic" },
        },
    },
    {
        id = "d2de9d43",
        title = "Week 2 - Mar 24 - Mythic Week, M+ Opens, take off work giganerds",
        items = {
            { id = "c3de7d35", text = "Do not spend any Crests until told to do so" },
            { id = "7e42a12d", text = "1h crafted note, check guide, check craft path info(VERY IMPORTANT!)" },
            { id = "5b379666", text = "Do LFR for tier pieces (check guide for why)" },
            { id = "16cf341e", text = "(Optional) Kill World Boss for champ 2/6 250 ilvl item" },
            { id = "3ccf0a1f", text = "(Optional) Complete 4x Nightmare Prey for Champion gear and renown." },
            { id = "26d0b610", text = "Do at least one t11 bountiful delve to get Cracked Keystone Quest" },
            { id = "286f219c", text = "Continue to spend all Adventurer, Veteran and Champion Crests upgrading anything" },
            { id = "74924a7b", text = "Farm +10s for 266 gear in every slot" },
            { id = "eb45e64d", text = "Before Mythic raid, Upgrade 11x 3/6 hero items once each" },
            { id = "cbfb6966", text = "Mythic: If you're lucky and got a Myth track item, skip to next week's upgrade advice for it." },
            { id = "0e855644", text = "Track crests: 220/220 Heroic, 0/220 Mythic - never hold Mythic crests" },
            { id = "721f006f", text = "Ending item level: 4x266, 11x269" },
        },
    },
    {
        id = "b0abc363",
        title = "Week 3 - Mar 31 - Final Raid Opens",
        items = {
            { id = "1fbc825e", text = "Open vault (272+ myth item) - upgrade after crafting" },
            { id = "fb8255a7", text = "Craft items - see guide for 2 paths to pick" },
            { id = "8226c872", text = "If no 4p, do LFR for tier pieces (check guide for why)" },
            { id = "1db5f946", text = "Farm +10s for vault + crests" },
            { id = "c316485a", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests" },
            { id = "2568bd36", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "484da4b0", text = "If you got a 2nd myth track item, skip to next week's upgrade advice for it." },
            { id = "0ecf8e89", text = "Track crests: 320/320 Heroic, 160/320 Mythic - never hold Mythic crests" },
            { id = "02884180", text = "Ending item level: 3x266, 8x269, 2x276h, 1x285(crafted), 1x289" },
        },
    },
    {
        id = "572003ec",
        title = "Week 4 - Apr 7",
        items = {
            { id = "9375e497", text = "Open vault (272+ myth item)" },
            { id = "1db5f946", text = "Farm +10s for vault + crests" },
            { id = "c316485a", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests" },
            { id = "2568bd36", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "0ccf5c83", text = "Mythic: Upgrade your raid drop from 2/6 275 Myth track to 6/6 289 for 80 Myth crests." },
            { id = "299f3284", text = "Track crests: 420/400 Heroic, 320/420 Mythic - never hold Mythic crests" },
            { id = "8b8cde46", text = "Ending item level: 2x266, 5x269, 4x276h, 1x285(crafted), 3x289" },
        },
    },
    {
        id = "239053b5",
        title = "Week 5 - Apr 14",
        items = {
            { id = "9375e497", text = "Open vault (272+ myth item)" },
            { id = "1db5f946", text = "Farm +10s for vault + crests" },
            { id = "11e426da", text = "Craft next item (see doc for more info)" },
            { id = "c316485a", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests" },
            { id = "2568bd36", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "8d74c3e1", text = "Track crests: 520/520 Heroic, 480/520 Mythic - never hold Mythic crests" },
            { id = "4f04ba4e", text = "Ending item level:  1x266, 2x269, 6x276h, 2x285(crafted), 4x289" },
        },
    },
    {
        id = "6a36daa1",
        title = "Week 6 - Apr 21 - Done with Heroic Crests",
        items = {
            { id = "9375e497", text = "Open vault (272+ myth item)" },
            { id = "1db5f946", text = "Farm +10s for vault + crests" },
            { id = "c35cf0b6", text = "Heroic: Upgrade your last 4/6 269 item to 6/6 276 for 40 Heroic Crests" },
            { id = "2568bd36", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "0ccf5c83", text = "Mythic: Upgrade your raid drop from 2/6 275 Myth track to 6/6 289 for 80 Myth crests." },
            { id = "4510d1aa", text = "Track crests: 560/620 Heroic, 620/620 Mythic - never hold Mythic crests" },
            { id = "67f84375", text = "Ending item level:  7x276h, 2x285(crafted), 1x 285, 5x289" },
        },
    },
    {
        id = "fd1bf82c",
        title = "Week 7 - Apr 28+",
        items = {
            { id = "f9978f0e", text = "Do not craft if you can get vault items higher than 1/6" },
            { id = "66e83cc1", text = "Upgrade Mythic items as you get them, preferring to jump them to 289 for the +4 jump" },
            { id = "a90c240c", text = "Plan for possible 1H + crafted OH swap" },
            { id = "10aac768", text = "Enjoy Blizzard's much better upgrade system!" },
        },
    },
}

reg.data[LOCALE] = DATASET
