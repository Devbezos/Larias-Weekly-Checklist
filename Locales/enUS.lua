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

	-- Update popup
	UPDATE_AVAILABLE_TEXT = "New version available",

	-- Shared buttons
	CLOSE         = "Close",

	-- Options tab
	OPTIONS_HIDE_GREAT_VAULT = "Hide Great Vault",
	OPTIONS_HIDE_CURRENCY = "Hide Currency",
	OPTIONS_HIDE_WEEKLIES = "Hide Weeklies",
	HIDE_COMPLETED_WEEKS = "Hide Completed Weeks",
	HIDE_COMPLETED_TASKS = "Hide Completed Tasks",
	HIDE_COMPLETED       = "Hide Completed",
	OPTIONS_HIDE_CHANGE_WEEK_BTN = 'Hide Week Selector',
	OPTIONS_HIDE_ILVL_REF_BTN = 'Hide Item Level Popup',

	OPTIONS_HIDE_CHAR_SELECT = "Hide character selector",
	OPTIONS_HIDDEN_CHARS_TITLE = "Hidden characters:",
	OPTIONS_HIDDEN_CHARS_NONE = "None",
	RESET_BUTTON = "Reset List",
	UI_SCALE_LABEL       = "Scale",
	UI_SCALE_MIN_LABEL   = "50%",
	UI_SCALE_MAX_LABEL   = "150%",
	OPTIONS_HIDE_SLIDERS        = "Hide Sliders",
	OPTIONS_HIDE_UPDATE_NOTICE  = "Hide Update Warnings",
	OPTIONS_HIDE_MINIMAP_BTN    = "Hide Minimap Button",
	-- Options tooltips (shown on hover in gear popup and settings tab)
	TOOLTIP_OPT_HIDE_COMPLETED_TASKS  = "Hides individual checklist items as you check them off.",
	TOOLTIP_OPT_HIDE_COMPLETED_WEEKS  = "Hides an entire week section once all its tasks are completed.",
	TOOLTIP_OPT_HIDE_GREAT_VAULT      = "Removes the Great Vault reward tracker from the panel.",
	TOOLTIP_OPT_HIDE_CURRENCY         = "Removes the currency tracker rows from the panel.",
	TOOLTIP_OPT_HIDE_WEEKLIES         = "Removes the inline weekly rewards section.",
	TOOLTIP_OPT_HIDE_CHANGE_WEEK      = "Hides the arrow buttons used to jump between weeks.",
	TOOLTIP_OPT_HIDE_ILVL_REF         = "Hides the item level reference popup button in the header.",
	TOOLTIP_OPT_HIDE_CHAR_SELECT      = "Hides the character picker dropdown in the footer.",
	TOOLTIP_OPT_HIDE_SLIDERS          = "Hides the scale and opacity sliders at the bottom of the window.",
	TOOLTIP_OPT_HIDE_UPDATE_NOTICE    = "Suppresses the banner shown when a newer version or data update is available.",
	TOOLTIP_OPT_HIDE_MINIMAP_BTN      = "Removes the addon icon from the minimap.",

	-- Color picker swatch labels (gear popup)
	COLOR_PICKER_BG             = "Background",
	COLOR_PICKER_TEXT           = "Text",
	COLOR_PICKER_HDR            = "Header",
	-- Status banner (shown below the slider row)
	STATUS_SHEET_UPDATE_FMT      = "Spreadsheet Update Detected - You are %d version(s) behind the spreadsheet",
	STATUS_NO_TRANSLATION_FMT    = "No translation available for %s. Consider contributing!",
	STATUS_TRANSLATION_NOTICE    = "English is the most up-to-date language. Your checklist may be slightly out of date.",
	UI_OPACITY_LABEL     = "Opacity",
	UI_OPACITY_MIN_LABEL = "10%",
	UI_OPACITY_MAX_LABEL = "100%",

	-- Tracking panel header tooltips
	TOOLTIP_OPEN_GREAT_VAULT  = "Click to open the Great Vault",
	TOOLTIP_OPEN_CURRENCIES   = "Click to open the Currency panel",
	TOOLTIP_OPEN_WEEKLY       = "Click to open the Weekly Rewards",

	-- Tracking panel
	TRACKING_GREAT_VAULT_TITLE = "Great Vault",
	TRACKING_CURRENCY_TITLE = "Currency",
	TRACKING_GV_RAID     = "Raid",
	TRACKING_GV_DUNGEONS = "Dungeons",
	TRACKING_GV_WORLD    = "World",
	TRACKING_NA = "N/A",

	TRACKING_SPARKS_LABEL = "Sparks",
	TRACKING_DONE = "Done",
	TRACKING_NOT_DONE = "Not done",

	TRACKING_QUEST_DELVERS_BOUNTY = "Delver's Bounty",
	TRACKING_QUEST_WEEKLY_PREY = "Weekly Prey",

	-- Weeklies section
	TRACKING_WEEKLIES_TITLE              = "Weeklies",
	TRACKING_QUEST_PREY                  = "Prey Hunted",
	TRACKING_QUEST_ABUNDANCE             = "Abundance",
	TRACKING_QUEST_LOST_LEGENDS          = "Lost Legends",
	TRACKING_QUEST_HIGH_ESTEEM           = "High Esteem",
	TRACKING_QUEST_FORTIFY_RUNESTONES    = "Fortify the Runestones",
	TRACKING_QUEST_STAND_YOUR_GROUND     = "Stand Your Ground",

	TRACKING_NO_ID = "No ID",
	TRACKING_TRADE_UP_SUFFIX = " Convert)",

	TRACKING_CATALYST_LABEL = "Catalyst",

	-- Minimap tooltip
	MINIMAP_TOOLTIP_LEFT_CLICK_TOGGLE = "Left-click: Toggle checklist",
	MINIMAP_TOOLTIP_RIGHT_CLICK_OPTIONS = "Right-click: Options",
	MINIMAP_TOOLTIP_MIDDLE_CLICK_ILVL = "Middle-click: Ilvl Refs",

	-- Main window
	TAB_OPTIONS = "Options",
	CHANGE_WEEK_BUTTON = "Change Week",
	CHAR_PICKER_BUTTON = "Swap Profile",
	CHAR_PICKER_TOOLTIP_REMOVE = "To remove a character, use the Options menu.",
	ILVLREF_BUTTON = "View Item Levels",


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

	ILVLREF_TOGGLE_EXPAND = "Expand",
	ILVLREF_TOGGLE_SHRINK = "Shrink",

	-- Slash commands
	SLASH_USAGE_TOGGLE = "Usage: /larias or /lcl to toggle the checklist",
	SLASH_USAGE_LOCALE = "Usage: /larias locale auto|enUS|deDE|esES|esMX|frFR|itIT|ptBR|ruRU",
	SLASH_LOCALE_SET_FMT = "Locale override set to %s (effective: %s)",
	SLASH_LOCALE_NOT_FOUND = "Unknown locale '%s'. Available: auto|%s",
}

for key, value in pairs(STRINGS) do
	L[key] = value
end
