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

	UPDATE_AVAILABLE_TEXT = "New version available",
	UPDATE_AVAILABLE_FMT = "%s has an update available.\n\nPlease update the addon to the newest version.",

	BUTTON_OK = "OK",
	BUTTON_CANCEL = "Cancel",

	OPTIONS_HIDE_GREAT_VAULT = "Hide Great Vault",
	OPTIONS_HIDE_CURRENCY = "Hide Currency",
	HIDE_COMPLETED_WEEKS = "Hide completed weeks",
	OPTIONS_HIDE_CHANGE_WEEK_BTN = 'Hide Change Week button',
	OPTIONS_HIDE_ILVL_REF_BTN = 'Hide Ilvl Refs button',
	RESET_BUTTON = "Reset List",
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
		[3347] = "Myth",
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

	ILVLREF_SEC_TRACKS    = "Upgrade Tracks  (20 crests per step)",
	ILVLREF_SEC_CRAFTED   = "Crafted Item Levels",
	ILVLREF_SEC_DUNGEONS  = "Dungeon Item Levels",
	ILVLREF_SEC_RAID      = "Approx. Midnight Raid Item Levels",
	ILVLREF_SEC_DELVES    = "Bountiful Delve Item Levels",

	ILVLREF_COL_ILVL         = "ilvl",
	ILVLREF_COL_TRACK        = "Upgrade Tracks",
	ILVLREF_COL_CREST_NEEDED = "Crests",
	ILVLREF_COL_QUALITY      = "Quality",
	ILVLREF_COL_SOURCE       = "Source",
	ILVLREF_COL_END_LOOT     = "End Loot",
	ILVLREF_COL_GREAT_VAULT  = "Great Vault",
	ILVLREF_COL_DIFFICULTY   = "Difficulty",
	ILVLREF_COL_BOSS1        = "Early",
	ILVLREF_COL_BOSS2        = "Mid",
	ILVLREF_COL_BOSS3        = "Late",
	ILVLREF_COL_BOSS4        = "End",
	ILVLREF_COL_TIER         = "Tier",
	ILVLREF_COL_MAP_DROP     = "Map Drop",

	ILVLREF_CREST_ADV          = "Adv",
	ILVLREF_CREST_VET          = "Vet",
	ILVLREF_CREST_CHAMP        = "Champ",
	ILVLREF_CREST_HERO         = "Hero",
	ILVLREF_CREST_MYTH         = "Myth",
	ILVLREF_DO_NOT_USE_CRESTS_FMT = "DO NOT USE %s CRESTS",

	ILVLREF_DUNGEON_PRE_HEROIC = "Pre-Season Heroic",
	ILVLREF_DUNGEON_HEROIC     = "Heroic",
	ILVLREF_DUNGEON_PRE_MYTHIC = "Pre-Season Mythic",
	ILVLREF_DUNGEON_MYTHIC     = "Mythic",

	ILVLREF_RAID_LFR           = "LFR",
	ILVLREF_RAID_NORMAL        = "Normal",
	ILVLREF_RAID_HEROIC        = "Heroic",
	ILVLREF_RAID_MYTHIC        = "Mythic",

	ILVLREF_DELVE_TIER_FMT     = "T%d",

	SLASH_USAGE_TOGGLE = "Usage: /larias or /lcl to toggle the checklist",
	SLASH_USAGE_LOCALE = "Usage: /larias locale auto|enUS|deDE|esES|esMX|frFR|itIT|ptBR|ruRU",
	SLASH_LOCALE_SET_FMT = "Locale override set to %s (effective: %s)",
}

for key, value in pairs(STRINGS) do
	L[key] = value
end
