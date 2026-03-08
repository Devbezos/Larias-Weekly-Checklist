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

	-- Options tab
	OPTIONS_HIDE_COMPLETED_TASKS = "Hide Finished Tasks",
	HIDE_FINISHED_WEEKS          = "Hide Finished Weeks",
	OPTIONS_HIDE_GREAT_VAULT     = "Hide Great Vault",
	OPTIONS_HIDE_CURRENCY        = "Hide Currency",
	OPTIONS_HIDE_CHANGE_WEEK_BTN = "Hide Week Selector",
	OPTIONS_HIDE_ILVL_REF_BTN   = "Hide Item Level Popup",
	OPTIONS_HIDE_SLIDERS         = "Hide Sliders",
	OPTIONS_HIDE_UPDATE_NOTICE   = "Hide Update Warnings",
	OPTIONS_DISABLE_UPGRADE_WARN = "Hide Upgrade Warnings",
	OPTIONS_HIDE_MINIMAP_BTN     = "Hide Minimap Button",
	-- Options checkbox tooltips
	OPTIONS_TOOLTIP_HIDE_COMPLETED_TASKS = "Hides individual checked-off tasks from all weeks.",
	OPTIONS_TOOLTIP_HIDE_FINISHED_WEEKS  = "Hides entire week sections once all tasks in them are completed.\n|cffaaaaaa(Only active when Hide Finished Tasks is off.)|r",
	OPTIONS_TOOLTIP_HIDE_GREAT_VAULT     = "Hides the Great Vault progress tracker panel.",
	OPTIONS_TOOLTIP_HIDE_CURRENCY        = "Hides the currency tracker panel.",
	OPTIONS_TOOLTIP_HIDE_CHANGE_WEEK_BTN = "Hides the Change Week button in the header.",
	OPTIONS_TOOLTIP_HIDE_ILVL_REF_BTN    = "Hides the item level reference popup button in the header.",
	OPTIONS_TOOLTIP_HIDE_UPDATE_NOTICE   = "Hides the banner shown when a new spreadsheet version is available.",
	OPTIONS_TOOLTIP_DISABLE_UPGRADE_WARN = "Hides the popup warning shown when upgrading an item at 1/6 instead of 5/6.",
	OPTIONS_TOOLTIP_HIDE_MINIMAP_BTN     = "Hides the minimap button.\nYou can still open the checklist with /larias.",
	RESET_BUTTON = "Reset List",
	UI_SCALE_LABEL       = "Scale",
	UI_SCALE_MIN_LABEL   = "50%",
	UI_SCALE_MAX_LABEL   = "150%",
	UI_OPACITY_LABEL     = "Opacity",
	UI_OPACITY_MIN_LABEL = "10%",
	UI_OPACITY_MAX_LABEL = "100%",
	-- Settings panel section headers
	SETTINGS_SECTION_ACTIONS = "Actions",
	SETTINGS_SECTION_DISPLAY = "Display",
	SETTINGS_SECTION_COLORS  = "Colors",
	SETTINGS_SECTION_LANGUAGE = "Language",
	SETTINGS_SECTION_SLIDERS = "Scale & Opacity",
	-- Settings panel color-row labels
	SETTINGS_COLOR_RESET       = "Reset",
	SETTINGS_COLOR_BACKGROUND  = "Background",
	SETTINGS_COLOR_LIST_TEXT   = "List Text",
	SETTINGS_COLOR_HEADER_TEXT = "Header Text",
	-- Settings panel language override
	SETTINGS_LANGUAGE_AUTO     = "Auto (Client Default)",
	-- Upgrade warning
	UPGRADE_WARN_MSG             = "Upgrading a 1/6 %s item is a waste of %d crests.\nYou should upgrade a %s item to 6/6 first to save crests",
	UPGRADE_WARN_DISABLE_BTN     = "Hide Upgrade Warning",
	UPGRADE_WARN_DISABLE_TOOLTIP = "Check Larias's guide for more information.",
	-- Color picker swatch labels (gear popup)
	COLOR_PICKER_BG             = "Background",
	COLOR_PICKER_TEXT           = "Text",
	COLOR_PICKER_HDR            = "Header",
	-- Status banner (shown below the slider row)
	STATUS_SHEET_UPDATE_FMT      = "Spreadsheet Update Detected - You are %d version(s) behind the spreadsheet",
	STATUS_NO_TRANSLATION_FMT    = "No translation available for %s. Consider contributing!",
	STATUS_TRANSLATION_NOTICE    = "English is the most up-to-date language. Your checklist may be slightly out of date.",
	-- Tracking panel header tooltips
	TOOLTIP_OPEN_GREAT_VAULT  = "Click to open the Great Vault",
	TOOLTIP_OPEN_CURRENCIES   = "Click to open the Currency panel",

	-- Tracking panel
	TRACKING_GREAT_VAULT_TITLE = "Great Vault",
	TRACKING_CURRENCY_TITLE = "Currency",
	TRACKING_GV_RAID     = "Raid",
	TRACKING_GV_DUNGEONS = "Dungeons",
	TRACKING_GV_WORLD    = "World",
	TRACKING_NA = "N/A",

	TRACKING_SPARKS_LABEL = "Sparks",
	TRACKING_CREST_LABEL  = "Crests",
	TRACKING_DONE = "Done",

	TRACKING_QUEST_DELVERS_BOUNTY = "Delver's Bounty",
	TRACKING_QUEST_WEEKLY_PREY = "Weekly Prey",

	TRACKING_NO_ID = "No ID",
	TRACKING_TRADE_UP_SUFFIX = " Convert)",
	TRACKING_CONVERT_TOOLTIP = "Number of crests you will gain from converting previous crests",
	TRACKING_CREST_AMOUNT_TOOLTIP = "Accurately tracks how many crests you can hold including overcapped crests",

	TRACKING_CATALYST_LABEL = "Catalyst",

	-- Locale reload popup (shown after changing language)
	LOCALE_RELOAD_TEXT       = "Language change saved. Reload UI to apply the new language.",
	LOCALE_RELOAD_BTN_NOW    = "Reload Now",
	LOCALE_RELOAD_BTN_LATER  = "Later",
	-- Copy-link popup (shown when C_Browser is unavailable)
	COPY_LINK_POPUP_TEXT     = "Press |cffffffffCtrl+C|r to copy:",
	-- Guide hyperlink hover tooltip
	GUIDE_LINK_HOVER_TOOLTIP = "Click to copy guide link",
	-- Support section button labels (Settings panel + gear popup)
	SUPPORT_BTN_GUIDE_DOC    = "Guide Doc",
	SUPPORT_BTN_CHECKLIST    = "Checklist",
	SUPPORT_BTN_DISCORD      = "Discord",

	-- Minimap tooltip
	MINIMAP_TOOLTIP_LEFT_CLICK_TOGGLE = "Left-click: Toggle checklist",
	MINIMAP_TOOLTIP_RIGHT_CLICK_OPTIONS = "Right-click: Options",
	MINIMAP_TOOLTIP_MIDDLE_CLICK_ILVL = "Middle-click: Ilvl Refs",

	-- Main window
	TAB_OPTIONS = "Options",
	CLOSE               = "Close",
	CHANGE_WEEK_BUTTON  = "Change Week",
	ALL_WEEKS_COMPLETE  = "Finished!",
	DONE_PREFIX         = "",
	ILVLREF_BUTTON = "View Item Levels",

	-- Character picker
	CHAR_PICKER_BUTTON          = "Swap Profile",
	CHAR_PICKER_TOOLTIP_REMOVE  = "To remove a character, use the Options menu.",

	-- Week picker
	PICKER_RESET_WEEK_TOOLTIP   = "Reset to week:",
	PICKER_GO_TO_WEEK_TOOLTIP   = "Go to week:",

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
}

for key, value in pairs(STRINGS) do
	L[key] = value
end
