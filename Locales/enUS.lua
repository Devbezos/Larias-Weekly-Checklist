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

	HIDE_COMPLETED_WEEKS = "Hide completed weeks",
	OPTIONS_BUTTON = "Options",
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
	TRACKING_NO_ID = "No ID",
	TRACKING_TRADE_UP_SUFFIX = " Trade Up)",

	TRACKING_CATALYST_LABEL = "Catalyst:",

	TRACKING_CURRENCY_FALLBACK_PREFIX = "Currency ",
	TRACKING_CREST_MATCH_SUBSTRING = "crest",
	TRACKING_INF = "INF",
	MINIMAP_TOOLTIP_TEXT = "Left-click to toggle the checklist",

	MINIMAP_TOOLTIP_LEFT_CLICK_TOGGLE = "Left-click: Toggle checklist",
	MINIMAP_TOOLTIP_RIGHT_CLICK_OPTIONS = "Right-click: Options",

	TAB_LIST = "List",
	TAB_OPTIONS = "Options",

	SLASH_USAGE_TOGGLE = "Usage: /larias or /lcl to toggle the checklist",
	SLASH_USAGE_LOCALE = "Usage: /larias locale auto|enUS|esMX",
	SLASH_LOCALE_SET_FMT = "Locale override set to %s (effective: %s)",
}

for key, value in pairs(STRINGS) do
	L[key] = value
end
