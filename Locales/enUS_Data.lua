--[[
English (enUS) checklist data for Larias's Weekly Checklist

NOTE: This is the canonical enUS dataset; other locales must keep IDs identical
so completion tracking stays consistent across locales.
]]

-- @sheet-version: 28

local LOCALE = "enUS"

local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"

local reg = _G[LOCALE_REGISTRY_KEY]
if type(reg) ~= "table" then
    reg = {}
    _G[LOCALE_REGISTRY_KEY] = reg
end
if type(reg.data) ~= "table" then reg.data = {} end
reg.sheet_version = "28"

local DATASET = {

    {
        id = "89ba2d2a",
        title = "Season 1 Week 1 - Mar 17 - Heroic Week, 2nd craft",
        items = {
            { id = "791379ba", text = "Do not spend any Heroic or Mythic Crests until told to do so. Check Guide for why we hold crests." },
            { id = "fab7aef9", text = "Almost everyone can probably craft your spark item now. Check Guide for what and when to craft." },
            { id = "e66847d8", text = "Do LFR for tier pieces - obtaining a 4set bonus will allow catalyst charges to drop from all content" },
            { id = "b1a6f7eb", text = "Complete weekly world event quest for pinnacle cache and spark from Lady Liadrin - Doing the Arcantina takes 3 minutes" },
            { id = "c17e68f1", text = "Complete weekly housing quest from Vaeli - reward is capped crests, doesn't matter what you pick but the biggest short term boost is to select Champion Crests" },
            { id = "d8d237fa", text = "(Optional) Raise PVP ranking to 1600 for catalyst charge (this is the same catalyst charge shared with 2,000 M+ rating from the next week). If you get 2 pieces of tier from your raid this week, this would allow you to catalyze 2 items and start getting Catalyst charge drops from your m+ next week." },
            { id = "ef789b0b", text = "(Optional) Complete a World Tour of M0 dungeons. These will reward champ ilvl on a daily lockout - DON'T BURN YOURSELF OUT! M+ opens next week and will replace all of this." },
            { id = "d78939c6", text = "Daily Task: consider running a specific m0 that drops a great trinket for you each day. The item will be champion ilvl (normal raid) and could be a nice boost going into raid next week if you don't manage to farm it on Heroic yet." },
            { id = "05b7e462", text = "Complete 4x Hard Prey to unlock Nightmare Prey." },
            { id = "78aea6fe", text = "Complete 3x Nightmare Prey for Champion gear on each character and to complete the weekly quest for boss summoning item and 20 uncapped hero crests" },
            { id = "cc5a28dd", text = "Complete Nullaeus on ? difficulty for 30 uncapped Hero crests. Remember don't spend these." },
            { id = "bad52b04", text = "Complete Nullaeus on ?? difficulty for 30 MORE uncapped Hero crests and 30 uncapped Myth crests. NOTE: While the Hall of Fame achievement requires you to do this solo, you can do this easily in a group. With a tank + healer delve companion, just keep adding more DPS to your group." },
            { id = "f7a876a0", text = "The vendor in the delve area has a bag with 2 free keys that go over cap. This is once per warband - make sure to purchase it on your main." },
            { id = "b6846065", text = "Do t8 or higher bountiful delves, use map on t8+ delve - while doing this, unlock t11 delves" },
            { id = "2f9c0f4f", text = "Use your boss summoning item from Nightmare Prey weekly quest in a tier 8 Delve to get a map and then use it for a Hero track item." },
            { id = "5ccc7694", text = "Kill World Boss for champ 3/6 253 ilvl item" },
            { id = "bf5d2e12", text = "Fill your vault in every slot for multiple chances at hero tier items next week." },
            { id = "0755c002", text = "BEFORE RAID, craft 1x-2x 246 ilvl pieces with embellishments on weak slots, using 80-160 Vet Crests. THESE DO NOT TAKE SPARKS. The items you are crafting are the blue quality items at the crafting bench that you insert 80x Veteran crests in to increase their ilvl.  Check Guide for more information. Can also ask in the Discord for help if you need it." },
            { id = "146b7d62", text = "After doing as much above as you can, but BEFORE raid, spend all Adventurer, Veteran and Champion Crests upgrading anything. Do not spend Heroic or Mythic crests." },
            { id = "c5055967", text = "Track spent crests: 0/180 Heroic, 0/130 Mythic" },
        },
    },
    {
        id = "d2de9d43",
        title = "Week 2 - Mar 24 - Mythic Week, M+ Opens, take off work giganerds",
        items = {
            { id = "e8cef00e", text = "Check Guide for what and when to craft." },
            { id = "4056a14a", text = "If you don't have 4set, do LFR for tier pieces - obtaining a 4set bonus will allow catalyst charges to drop from all content" },
            { id = "83fd4310", text = "Complete weekly world event quest for spark from Lady Liadrin" },
            { id = "4c264b7f", text = "Complete weekly housing quest from Vaeli for quick hero crests" },
            { id = "e8673800", text = "No real repeatable reward, no reason to do ?? Nulleaus after the first completion" },
            { id = "547b880e", text = "Complete the 3x nightmare prey weekly quest to get an item that summons a delve boss to get a map and 20 uncapped Hero crests." },
            { id = "73ad86e4", text = "Do at least one t11 bountiful delve to get Cracked Keystone Quest for 20 uncapped Hero and Myth crests. While doing it, use your boss item from the 3x Nightmare prey quest to get a map and use it in this delve" },
            { id = "e2da3aa8", text = "Recraft your spark weapon to myth once you get 80 myth crests" },
            { id = "74924a7b", text = "Farm +10s for 266 gear in every slot" },
            { id = "591e911b", text = "Before entering Mythic, upgrade the following 3/6 hero track items to 6/6 - chest, pants, helm, 1 ring, 1 trinket. This should take 300/320 hero crests. Save the last 20 Hero crests in case you get a myth 1/6 item that you need to upgrade to 2/6 first. This gives you the largest power spike possible heading into your first week of mythic while still giving you an opportunity to save on crests in other slots. This assumption is based off of crafting a 2h + 1 other embellished item next week. Hunters or others who didn't craft weapons might consider leveling their weapon instead of pants or helmet in order to gain that power spike after they kill the first boss on mythic if the weapons don't drop." },
            { id = "cbfb6966", text = "Mythic: If you're lucky and got a Myth track item, skip to next week's upgrade advice for it." },
            { id = "92eaba33", text = "Track spent crests: 320/320 Heroic, 0/250 Mythic - never hold Mythic crests - may vary if you crafted" },
        },
    },
    {
        id = "8f5b5aeb",
        title = "Week 3 - Mar 31 - Final Raid Opens, 3rd craft",
        items = {
            { id = "1fbc825e", text = "Open vault (272+ myth item) - upgrade after crafting" },
            { id = "83fd4310", text = "Complete weekly world event quest for spark from Lady Liadrin" },
            { id = "e8673800", text = "No real repeatable reward, no reason to do ?? Nulleaus after the first completion" },
            { id = "09b2b53b", text = "Complete the 3x nightmare prey weekly quest for 20 uncapped Hero crests." },
            { id = "1db5f946", text = "Farm +10s for vault + crests" },
            { id = "d0aed922", text = "Heroic: Upgrade a 3/6 266 item to 6/6 276 for 60 Heroic Crests. Upgrade 2 3/6 266 items to 4/6 269 for 40 Heroic Crests. Save 20 Heroic Crests for the next step." },
            { id = "2568bd36", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "484da4b0", text = "If you got a 2nd myth track item, skip to next week's upgrade advice for it." },
            { id = "8e67d484", text = "Track spent crests: 440/440 Heroic, 240/350 Mythic - never hold Mythic crests - may vary if you crafted" },
        },
    },
    {
        id = "572003ec",
        title = "Week 4 - Apr 7",
        items = {
            { id = "9375e497", text = "Open vault (272+ myth item)" },
            { id = "83fd4310", text = "Complete weekly world event quest for spark from Lady Liadrin" },
            { id = "e8673800", text = "No real repeatable reward, no reason to do ?? Nulleaus after the first completion" },
            { id = "09b2b53b", text = "Complete the 3x nightmare prey weekly quest for 20 uncapped Hero crests." },
            { id = "1db5f946", text = "Farm +10s for vault + crests" },
            { id = "6e25b0ce", text = "Heroic: Upgrade 2 of your 4/6 269 items to 6/6 276 for 80 Heroic Crests. Upgrade 1 3/6 266 items to 4/6 269 for 20 Heroic Crests. Save 20 Heroic Crests for the next step." },
            { id = "7bfe99b2", text = "Mythic:  If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "0ccf5c83", text = "Mythic: Upgrade your raid drop from 2/6 275 Myth track to 6/6 289 for 80 Myth crests." },
            { id = "b95b0829", text = "Track spent crests: 560/560 Heroic, 400/450 Mythic - never hold Mythic crests" },
        },
    },
    {
        id = "067d2566",
        title = "Week 5 - Apr 14 - Done with Heroic Crests",
        items = {
            { id = "9375e497", text = "Open vault (272+ myth item)" },
            { id = "83fd4310", text = "Complete weekly world event quest for spark from Lady Liadrin" },
            { id = "e8673800", text = "No real repeatable reward, no reason to do ?? Nulleaus after the first completion" },
            { id = "09b2b53b", text = "Complete the 3x nightmare prey weekly quest for 20 uncapped Hero crests." },
            { id = "1db5f946", text = "Farm +10s for vault + crests" },
            { id = "cb431e83", text = "Craft next item (Check Guide for more info)" },
            { id = "13957611", text = "Heroic: Upgrade the last of your heroic items to 6/6 276. Save 20 Heroic Crests for the next step." },
            { id = "2568bd36", text = "Mythic: If your vault item was 1/6, upgrade its heroic counterpart first to 6/6 heroic for 20 Heroic Crests. Upgrade your 1/6 272 Myth track item to 6/6 289 for 80 Myth crests." },
            { id = "c581850d", text = "Track spent crests: 680/680 Heroic, 480/550 Mythic - never hold Mythic crests" },
        },
    },
    {
        id = "db70d77d",
        title = "Week 6 - Apr 21+",
        items = {
            { id = "f9978f0e", text = "Do not craft if you can get vault items higher than 1/6" },
            { id = "66e83cc1", text = "Upgrade Mythic items as you get them, preferring to jump them to 289 for the +4 jump" },
            { id = "1786deeb", text = "If needed, plan for possible 1H + crafted OH swap" },
            { id = "10aac768", text = "Enjoy Blizzard's much better upgrade system!" },
        },
    },
}

reg.data[LOCALE] = DATASET
