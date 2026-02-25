local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"

local reg = _G[LOCALE_REGISTRY_KEY]
if type(reg) ~= "table" then
	reg = {}
	_G[LOCALE_REGISTRY_KEY] = reg
end
if type(reg.strings) ~= "table" then reg.strings = {} end

reg.strings["enUS"] = reg.strings["enUS"] or {}
local L = reg.strings["enUS"]

local STRINGS = {
	DISPLAY_NAME = "Larias's Weekly Checklist",

	UPDATE_AVAILABLE_TITLE = "New version available",
	UPDATE_AVAILABLE_TEXT = "New version available",
	UPDATE_AVAILABLE_FMT = "%s has an update available.\n\nPlease update the addon to the newest version.",

	BUTTON_OK = "OK",
	BUTTON_CANCEL = "Cancel",

	OPTIONS_SHOW_GREAT_VAULT = "Show Great Vault",
	OPTIONS_SHOW_CURRENCY = "Show Currency",
    OPTIONS_SHOW_CHANGE_WEEK_BTN = 'Show "Change Week" button',
    OPTIONS_SHOW_ILVL_REF_BTN = 'Show "Ilvl Refs" button',
	RESET_BUTTON = "Reset",
	DONE_PREFIX = "[Done] ",

	TRACKING_GREAT_VAULT_TITLE = "Great Vault",
	TRACKING_CURRENCY_TITLE = "Currency",
	TRACKING_GV_RAID = "Raid",
	TRACKING_GV_DUNGEONS = "Dungeons",
	TRACKING_NA = "N/A",

	TRACKING_SPARKS_LABEL = "Sparks:",
	TRACKING_DONE = "Done",
	TRACKING_NOT_DONE = "Not done",

	TRACKING_QUEST_DELVERS_BOUNTY = "Delver's Bounty:",
	TRACKING_QUEST_WEEKLY_PREY = "Weekly Prey:",

	TRACKING_CREST_LABEL = "Crest:",
	TRACKING_CREST_ID_LABEL_FMT = "Crest %s:",
	-- Optional: if present, crest labels are taken from this table instead of the game currency name.
	-- Keys are currency IDs; values should be display names (with or without a trailing ':').
	TRACKING_CREST_NAMES_BY_ID = {
		[3383] = "Adventurer",
		[3341] = "Veteran",
		[3343] = "Champion",
		[3345] = "Hero",
		[3347] = "Gilded",
	},
	TRACKING_NO_ID = "No ID",
	TRACKING_TRADE_UP_SUFFIX = " Trade Up)",

	TRACKING_CATALYST_LABEL = "Catalyst:",

	TRACKING_INF = "INF",

	MINIMAP_TOOLTIP_LEFT_CLICK_TOGGLE = "Left-click: Toggle checklist",
	MINIMAP_TOOLTIP_RIGHT_CLICK_OPTIONS = "Right-click: Options",

	TAB_LIST = "List",
	TAB_OPTIONS = "Options",
	CHANGE_WEEK_BUTTON = "Change Week",
	ILVLREF_BUTTON = "Ilvl Refs",

	-- Item level reference popup
	ILVLREF_WINDOW_TITLE  = "Midnight Season 1 Item Level Reference",
	ILVLREF_OR            = "or",

	ILVLREF_SEC_TRACKS    = "Upgrade Tracks  (20 crests per step)",
	ILVLREF_SEC_CRAFTED   = "Crafted Item Levels",
	ILVLREF_SEC_DUNGEONS  = "Dungeon Item Levels",
	ILVLREF_SEC_RAID      = "Approx. Midnight Raid Item Levels",
	ILVLREF_SEC_DELVES    = "Bountiful Delve Item Levels",
	ILVLREF_SEC_CRESTS    = "Dawncrest Types",

	ILVLREF_COL_ILVL         = "ilvl",
	ILVLREF_COL_TRACK        = "Upgrade Tracks",
	ILVLREF_COL_CREST_NEEDED = "Crests",
	ILVLREF_COL_GEAR         = "Gear",
	ILVLREF_COL_SOURCE       = "Source",
	ILVLREF_COL_END_LOOT     = "End Loot",
	ILVLREF_COL_GREAT_VAULT  = "Great Vault",
	ILVLREF_COL_CRESTS       = "Crests",
	ILVLREF_COL_DIFFICULTY   = "Difficulty",
	ILVLREF_COL_BOSS1        = "Early",
	ILVLREF_COL_BOSS2        = "Mid",
	ILVLREF_COL_BOSS3        = "Late",
	ILVLREF_COL_BOSS4        = "End",
	ILVLREF_COL_TIER         = "Tier",
	ILVLREF_COL_MAP_DROP     = "Map Drop",
	ILVLREF_COL_CREST        = "Crest",
	ILVLREF_COL_ILVL_RANGE   = "ilvl Range",
	ILVLREF_COL_TITLE_REWARD = "Title",

	ILVLREF_CREST_ADV          = "Adventurer",
	ILVLREF_CREST_VET          = "Veteran",
	ILVLREF_CREST_CHAMP        = "Champion",
	ILVLREF_CREST_HERO         = "Hero",
	ILVLREF_CREST_MYTH         = "Myth",
	ILVLREF_CREST_ADV_SHORT    = "Adv",
	ILVLREF_CREST_VET_SHORT    = "Vet",
	ILVLREF_CREST_CHAMP_SHORT  = "Champ",

	ILVLREF_DUNGEON_HEROIC     = "Heroic",
	ILVLREF_DUNGEON_MYTHIC     = "Mythic",
ILVLREF_DUNGEON_CRESTS     = "Champ x",

	ILVLREF_RAID_LFR           = "LFR",
	ILVLREF_RAID_NORMAL        = "Normal",
	ILVLREF_RAID_HEROIC        = "Heroic",
	ILVLREF_RAID_MYTHIC        = "Mythic",

	ILVLREF_DELVE_TIER_FMT     = "T%d",

	ILVLREF_TRACK_ADV1         = "Adventurer 1",
	ILVLREF_TRACK_ADV2         = "Adventurer 2",
	ILVLREF_TRACK_ADV3         = "Adventurer 3",
	ILVLREF_TRACK_ADV4         = "Adventurer 4",
	ILVLREF_TRACK_ADV5_VET1    = "Adventurer 5 / Veteran 1",
	ILVLREF_TRACK_ADV6_VET2    = "Adventurer 6 / Veteran 2",
	ILVLREF_TRACK_VET3         = "Veteran 3",
	ILVLREF_TRACK_VET4         = "Veteran 4",
	ILVLREF_TRACK_VET5_CHAMP1  = "Veteran 5 / Champion 1",
	ILVLREF_TRACK_VET6_CHAMP2  = "Veteran 6 / Champion 2",
	ILVLREF_TRACK_CHAMP3       = "Champion 3",
	ILVLREF_TRACK_CHAMP4       = "Champion 4",
	ILVLREF_TRACK_CHAMP5_HERO1 = "Champion 5 / Hero 1",
	ILVLREF_TRACK_CHAMP6_HERO2 = "Champion 6 / Hero 2",
	ILVLREF_TRACK_HERO3        = "Hero 3",
	ILVLREF_TRACK_HERO4        = "Hero 4",
	ILVLREF_TRACK_HERO5_MYTH1  = "Hero 5 / Myth 1",
	ILVLREF_TRACK_HERO6_MYTH2  = "Hero 6 / Myth 2",
	ILVLREF_TRACK_MYTH3        = "Myth 3",
	ILVLREF_TRACK_MYTH4        = "Myth 4",
	ILVLREF_TRACK_MYTH5        = "Myth 5",
	ILVLREF_TRACK_MYTH6        = "Myth 6",

	ILVLREF_DAWNCREST_ADV         = "Adventurer Dawncrest",
	ILVLREF_DAWNCREST_VET         = "Veteran Dawncrest",
	ILVLREF_DAWNCREST_CHAMP       = "Champion Dawncrest",
	ILVLREF_DAWNCREST_HERO        = "Hero Dawncrest",
	ILVLREF_DAWNCREST_MYTH        = "Myth Dawncrest",
	ILVLREF_DAWNCREST_TITLE_ADV   = "Adventurer of the Dawn",
	ILVLREF_DAWNCREST_TITLE_VET   = "Veteran of the Dawn",
	ILVLREF_DAWNCREST_TITLE_CHAMP = "Champion of the Dawn",
	ILVLREF_DAWNCREST_TITLE_HERO  = "Hero of the Dawn",
	ILVLREF_DAWNCREST_TITLE_MYTH  = "Myth of the Dawn",

	SLASH_USAGE_TOGGLE = "Usage: /larias or /lcl to toggle the checklist",
	SLASH_USAGE_LOCALE = "Usage: /larias locale auto|enUS|deDE|esES|esMX|frFR|itIT|ptBR|ruRU",
	SLASH_LOCALE_SET_FMT = "Locale override set to %s (effective: %s)",
}

for key, value in pairs(STRINGS) do
	L[key] = value
end
