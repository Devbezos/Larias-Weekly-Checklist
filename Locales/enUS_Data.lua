--[[
English (enUS) checklist data for Larias's Weekly Checklist

NOTE: This is the canonical enUS dataset; other locales must keep IDs identical
so completion tracking stays consistent across locales.
]]

-- @sheet-version: 26

local LOCALE = "enUS"

local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"

local reg = _G[LOCALE_REGISTRY_KEY]
if type(reg) ~= "table" then
    reg = {}
    _G[LOCALE_REGISTRY_KEY] = reg
end
if type(reg.data) ~= "table" then reg.data = {} end
reg.sheet_version = "26"

local DATASET = {

    {
        id = "bd6b2f68",
        title = "Early Access - Feb 26 through Mar 2",
        items = {
            { id = "f4b92a82", text = "Log on to each character you plan on leveling so they start accumulating rested XP." },
            { id = "90db618c", text = "Level characters warmode on to 90 - DMF opens Sunday for 10% more exp." },
            { id = "6af1d802", text = "Complete the weekly Stormarion Assault in the Voidstorm. (It is available in Early Access)" },
            { id = "6762e305", text = "(Optional) Kill each rare once in each zone for renown. This is a one time bonus for each rare and does not reset weekly." },
            { id = "0394cb0d", text = "Hunt down each region's treasures for free Renown. Check guide for more info" },
            { id = "91e7ee6c", text = "Complete 4x Prey on normal difficulty for renown" },
            { id = "c699a5d6", text = "Complete the Midnight Lore Hunter achievement for renown - Check guide for more info" },
            { id = "cfd4a904", text = "Complete the Highest Peaks achievement for renown - Check guide for more info" },
            { id = "f9b8eb01", text = "Complete side quest chains for renown. (can be done on alts to level at same time). DMF buff does not give renown." },
            { id = "4aa4b47d", text = "Note: Only the Singularity AND Eversong champion items are available in early access - the others will become available either Monday after the official launch or after each region's weekly reset." },
            { id = "ba1890e4", text = "Complete the weekly Saltheril's Soiree in Eversong Woods. Don't forget to grab renown quest for the champion helmet if you have the renown" },
        },
    },
    {
        id = "50281d6f",
        title = "Pre-Season Week 1 - March 3 - M0's",
        items = {
            { id = "79c35167", text = "Save 160 Veteran crests for crafting - see further down for instructions (These do not take Sparks)" },
            { id = "e8cef00e", text = "Check Guide for what and when to craft." },
            { id = "c06ee1a3", text = "If you are on an alt and don't see some of these quests, go to Soridormi in the Silvermoon City Inn and choose \"I Stopped the Voidstorm\" to skip the campaign." },
            { id = "755d27e7", text = "Raise The Singularity renown to rank 7 for 1/6 champion trinket - comes from a quest from the renown vendor" },
            { id = "f213fee8", text = "Raise Hara'ti renown to rank 8 for 1/6 champion belt - comes from a quest from the renown vendor" },
            { id = "81fd810d", text = "Raise Silvermoon renown to rank 9 for 1/6 champion helm - comes from a quest from the renown vendor" },
            { id = "804b15e3", text = "Raise Amani Tribe renown to rank 9 for 1/6 champion necklace - comes from a quest from the renown vendor" },
            { id = "101e78a9", text = "Complete weekly dungeon quest from Halduron Brightwing for 1000 renown" },
            { id = "0c3b8835", text = "Complete weekly world event quest for pinnacle cache from Lady Liadrin - can pick weekly event quest and do it with the events below" },
            { id = "879d3833", text = "Complete weekly world tour quest from Lorthremar for spark by doing the below quests" },
            { id = "e326ed96", text = "Complete the weekly Saltheril's Soiree in Eversong Woods." },
            { id = "da2fa0ef", text = "Complete the weekly Abundance Event in Zul'aman." },
            { id = "dbc8384b", text = "Complete the weekly Legends of the Haranir event in Harandar." },
            { id = "9ad64245", text = "Complete the weekly Stormarion Assault in the Voidstorm." },
            { id = "6762e305", text = "(Optional) Kill each rare once in each zone for renown. This is a one time bonus for each rare and does not reset weekly." },
            { id = "666a0192", text = "If not done, hunt down each region's treasures, lore hunter, and high peaks for free Renown. Check guide for more info." },
            { id = "a892ac44", text = "Unlock Delves through tier 8" },
            { id = "d54f7430", text = "Complete 4x Hard Prey. The first 2 will give Veteran gear; all 4 will give Veteran Crests which you need to cap." },
            { id = "efb035ba", text = "(Optional) Complete 2x random Hard Prey for Veteran crests on each character - doing 2x optional per week will cap Veteran crests by the end of week 2" },
            { id = "a7ee4829", text = "Complete a World Tour of M0 dungeons - rewards vet ilvl - do not upgrade yet" },
            { id = "c60d586a", text = "Thursday, March 5th Hotfix Info: Blizzard has hotfixed in the ability to earn an achievement that reduces the cost of upgrading your crests by 50% on your account once one character is 237 in every single slot. Check guide for more info." },
            { id = "77405dc2", text = "New: If you only have one character, after completing your first world tour of M0 dungeons you can spend Adventurer crests on remaining items." },
            { id = "95531889", text = "New: If you have multiple characters, once you have earned the new achievement, you can freely upgrade on all other characters." },
        },
    },
    {
        id = "ff1f5a67",
        title = "Pre-Season Week 2 - March 10 - M0's",
        items = {
            { id = "79c35167", text = "Save 160 Veteran crests for crafting - see further down for instructions (These do not take Sparks)" },
            { id = "b4de098c", text = "Special note for dual wield classes - you can probably craft your spark item now. Check Guide for what and went to craft." },
            { id = "d8f307f2", text = "Text guide update alert: I have updated Spark crafting advice for every single class. Highly recommend you Check Guide with the new information." },
            { id = "0d50e744", text = "NA: Blizzard hotfixed in a PvE spark quest from Liadrin. If you already did the PvP one, you can skip this as it does not give a fourth spark. If you have not completed any spark quest this week, do the Liadrin one for your third spark." },
            { id = "ab127896", text = "EU: After your reset, complete the weekly quest from Liadrin for a spark." },
            { id = "5fd1b2ad", text = "DO NOT DO the pvp quest for the heroic ring/amulet. you can't finish the quest line until after m+ opens" },
            { id = "ed534745", text = "(Optional) New: Farm 10,000 honor and either purchase on the AH or farm 6 Infused Heliotrope for next week. See next week for info.  Note: this is very min-maxy.  It's for 2 extra sockets going into first two weeks." },
            { id = "9626318e", text = "(Optional) Complete weekly dungeon quest from Halduron Brightwing for 1000 renown" },
            { id = "8b55f0c7", text = "(Optional) Complete the weekly Saltheril's Soiree in Eversong Woods." },
            { id = "8e107032", text = "(Optional) Complete the weekly Abundance Event in Zul'aman." },
            { id = "d5a12c89", text = "(Optional) Complete the weekly Legends of the Haranir event in Harandar." },
            { id = "514a6926", text = "(Optional) Complete the weekly Stormarion Assault in the Voidstorm." },
            { id = "6762e305", text = "(Optional) Kill each rare once in each zone for renown. This is a one time bonus for each rare and does not reset weekly." },
            { id = "23cb93ed", text = "Unlock Delves through tier 8 if not done yet" },
            { id = "d54f7430", text = "Complete 4x Hard Prey. The first 2 will give Veteran gear; all 4 will give Veteran Crests which you need to cap." },
            { id = "7b67a15d", text = "(Optional) Complete random Hard Prey to cap Veteran crests on each character" },
            { id = "a7ee4829", text = "Complete a World Tour of M0 dungeons - rewards vet ilvl - do not upgrade yet" },
            { id = "dc01eba9", text = "If you have any adventurer pieces left, you should feel free to upgrade them." },
            { id = "5853685a", text = "If you raid Tuesday the 17th, read next week's crafting steps. Otherwise, wait until the day of your raid or the day before your raid to do this." },
        },
    },
    {
        id = "89ba2d2a",
        title = "Season 1 Week 1 - Mar 17 - Heroic Week, 2nd craft",
        items = {
            { id = "791379ba", text = "Do not spend any Heroic or Mythic Crests until told to do so. Check Guide for why we hold crests." },
            { id = "fab7aef9", text = "Almost everyone can probably craft your spark item now. Check Guide for what and when to craft." },
            { id = "e66847d8", text = "Do LFR for tier pieces - obtaining a 4set bonus will allow catalyst charges to drop from all content" },
            { id = "b1a6f7eb", text = "Complete weekly world event quest for pinnacle cache and spark from Lady Liadrin - Doing the Arcantina takes 3 minutes" },
            { id = "c17e68f1", text = "Complete weekly housing quest from Vaeli - reward is capped crests, doesn't matter what you pick but the biggest short term boost is to select Champion Crests" },
            { id = "1e1d846c", text = "Note: the next two things are tied together - they are for a small upgrade - two additional sockets going into the first two weeks." },
            { id = "50eaf609", text = "(Optional) New: Complete PvP matches to obtain a quest item that rewards 9x Galactic Gladiator's Heraldry. You will use these to craft items below. Only do this if you have or are going to farm the honor for the sockets below. Note: this is very min-maxy, it is for 2 additional sockets essentially. Arena is fastest" },
            { id = "a1884373", text = "(Optional) New: Purchase 2 Galactic Jeweler's Settings from the vendor for 5000 Honor and 3 Infused Heliotrope each. You will use these to socket the crafted items below. These items will not appear on the vendor until this week. This is very min-maxy, it's for 2 additional sockets essentially." },
            { id = "d8d237fa", text = "(Optional) Raise PVP ranking to 1600 for catalyst charge (this is the same catalyst charge shared with 2,000 M+ rating from the next week). If you get 2 pieces of tier from your raid this week, this would allow you to catalyze 2 items and start getting Catalyst charge drops from your m+ next week." },
            { id = "ef789b0b", text = "(Optional) Complete a World Tour of M0 dungeons. These will reward champ ilvl on a daily lockout - DON'T BURN YOURSELF OUT! M+ opens next week and will replace all of this." },
            { id = "d78939c6", text = "Daily Task: consider running a specific m0 that drops a great trinket for you each day. The item will be champion ilvl (normal raid) and could be a nice boost going into raid next week if you don't manage to farm it on Heroic yet." },
            { id = "05b7e462", text = "Complete 4x Hard Prey to unlock Nightmare Prey." },
            { id = "78aea6fe", text = "Complete 3x Nightmare Prey for Champion gear on each character and to complete the weekly quest for boss summoning item and 20 uncapped hero crests" },
            { id = "cc5a28dd", text = "Complete Nullaeus on ? difficulty for 30 uncapped Hero crests. Remember don't spend these." },
            { id = "5c891668", text = "Complete Nullaeus on ?? difficulty for 30 MORE uncapped Hero crests and 30 uncapped Myth crests. NOTE: While the Hall of Fame achievement requires you to do this solo, you can do this more easily in a group. With a tank + healer delve companion, just keep adding more DPS to your group." },
            { id = "f7a876a0", text = "The vendor in the delve area has a bag with 2 free keys that go over cap. This is once per warband - make sure to purchase it on your main." },
            { id = "b6846065", text = "Do t8 or higher bountiful delves, use map on t8+ delve - while doing this, unlock t11 delves" },
            { id = "2f9c0f4f", text = "Use your boss summoning item from Nightmare Prey weekly quest in a tier 8 Delve to get a map and then use it for a Hero track item." },
            { id = "5ccc7694", text = "Kill World Boss for champ 3/6 253 ilvl item" },
            { id = "bf5d2e12", text = "Fill your vault in every slot for multiple chances at hero tier items next week." },
            { id = "4820451a", text = "(Optional) New: If you did farm honor and have obtained your Galactic Gladiator's Heraldry and Galactic Jeweler's Sockets(see above), craft Bracers and Belt at 246 ilvl and add a socket to them. These items can take embellishments - if you crafted a weapon with an embellishment, only put one embellishment on these. If you did not craft a weapon, put 2x embellishments on them. These items are the equivalent of 1/6 Champion track with a socket and you can use these for a couple weeks into the season. Item level confirmed to be 1/6 champion." },
            { id = "2e0ae86e", text = "If you did not farm honor for PvP items, then BEFORE RAID, craft 1x-2x 246 ilvl pieces with embellishments on weak slots, using 80-160 Vet Crests. THESE DO NOT TAKE SPARKS. The items you are crafting are the blue quality items at the crafting bench that you insert 80x Veteran crests in to increase their ilvl.  Check Guide for more information. Can also ask in the Discord for help if you need it." },
            { id = "146b7d62", text = "After doing as much above as you can, but BEFORE raid, spend all Adventurer, Veteran and Champion Crests upgrading anything. Do not spend Heroic or Mythic crests." },
            { id = "8824d048", text = "Track spent crests: 0/100 Heroic, 0/100 Mythic" },
        },
    },
    {
        id = "d2de9d43",
        title = "Week 2 - Mar 24 - Mythic Week, M+ Opens, take off work giganerds",
        items = {
            { id = "36d21691", text = "Do not spend any Heroic or Mythic Crests until told to do so. Check guide for why we hold crests." },
            { id = "e8cef00e", text = "Check Guide for what and when to craft." },
            { id = "4056a14a", text = "If you don't have 4set, do LFR for tier pieces - obtaining a 4set bonus will allow catalyst charges to drop from all content" },
            { id = "e0ecce24", text = "Complete weekly world event quest for pinnacle cache and spark from Lady Liadrin" },
            { id = "4c264b7f", text = "Complete weekly housing quest from Vaeli for quick hero crests" },
            { id = "0c60ad29", text = "(Optional) Kill World Boss for champ 3/6 253 ilvl item" },
            { id = "4aa82ede", text = "(Optional) Complete 2x Nightmare Prey for Champion gear on each character" },
            { id = "26d0b610", text = "Do at least one t11 bountiful delve to get Cracked Keystone Quest" },
            { id = "286f219c", text = "Continue to spend all Adventurer, Veteran and Champion Crests upgrading anything" },
            { id = "74924a7b", text = "Farm +10s for 266 gear in every slot" },
            { id = "ae0baeca", text = "After N/H reclears but BEFORE Mythic raid, Upgrade 11x 3/6 hero items once each. If you don't have that many Heroic items, upgrade a ring or trinket more to reduce risk of wasting crests." },
            { id = "cbfb6966", text = "Mythic: If you're lucky and got a Myth track item, skip to next week's upgrade advice for it." },
            { id = "00cb43a8", text = "Track spent crests: 220/220 Heroic, 0/220 Mythic - never hold Mythic crests - may vary if you crafted" },
            { id = "adb492bd", text = "Ending item level: 4x266, 11x269 - may vary if you crafted" },
        },
    },
    {
        id = "8f5b5aeb",
        title = "Week 3 - Mar 31 - Final Raid Opens, 3rd craft",
        items = {
            { id = "1fbc825e", text = "Open vault (272+ myth item) - upgrade after crafting" },
            { id = "8226c872", text = "If no 4p, do LFR for tier pieces (check guide for why)" },
            { id = "1db5f946", text = "Farm +10s for vault + crests" },
            { id = "c316485a", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests" },
            { id = "2568bd36", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "484da4b0", text = "If you got a 2nd myth track item, skip to next week's upgrade advice for it." },
            { id = "40b01764", text = "Track spent crests: 320/320 Heroic, 160/320 Mythic - never hold Mythic crests - may vary if you crafted" },
            { id = "c0774809", text = "Ending item level: 2x266, 8x269, 2x276h, 2x285(crafted), 1x289 - may vary if you crafted" },
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
            { id = "bccfe037", text = "Track spent crests: 420/400 Heroic, 320/420 Mythic - never hold Mythic crests" },
            { id = "8184483b", text = "Ending item level: 2x266, 4x269, 4x276h, 2x285(crafted), 3x289" },
        },
    },
    {
        id = "71d2703a",
        title = "Week 5 - Apr 14, 4th craft",
        items = {
            { id = "9375e497", text = "Open vault (272+ myth item)" },
            { id = "1db5f946", text = "Farm +10s for vault + crests" },
            { id = "11e426da", text = "Craft next item (see doc for more info)" },
            { id = "c316485a", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests" },
            { id = "2568bd36", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "92a40a6f", text = "Track spent crests: 520/520 Heroic, 480/520 Mythic - never hold Mythic crests" },
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
            { id = "4f11d7d8", text = "Track spent crests: 560/620 Heroic, 620/620 Mythic - never hold Mythic crests" },
            { id = "37472f94", text = "Ending item level:  7x276h, 2x285(crafted), 1x285, 5x289" },
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
