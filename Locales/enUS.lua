local LOCALE_REGISTRY_KEY = "LARIASWEEKLYMIDNIGHTCHECKLIST_LOCALE_REGISTRY"

local reg = _G[LOCALE_REGISTRY_KEY]
if type(reg) ~= "table" then
	reg = {}
	_G[LOCALE_REGISTRY_KEY] = reg
end
if type(reg.strings) ~= "table" then reg.strings = {} end

reg.strings["enUS"] = reg.strings["enUS"] or {}
local L = reg.strings["enUS"]

local function Set(key, value)
	L[key] = value
end

Set("DISPLAY_NAME", "Larias Checklist")

Set("UPDATE_AVAILABLE_TITLE", "New version available")
Set("UPDATE_AVAILABLE_TEXT", "New version available")
Set("UPDATE_AVAILABLE_FMT", "%s has an update available.\n\nPlease update the addon to the newest version.")

Set("OPTIONS_SHOW_GREAT_VAULT", "Show Great Vault")
Set("OPTIONS_SHOW_CURRENCY", "Show Currency")

Set("HIDE_COMPLETED_WEEKS", "Hide completed weeks")
Set("OPTIONS_BUTTON", "Options")
Set("RESET_BUTTON", "Reset")
Set("DONE_PREFIX", "[Done] ")

Set("OPTIONS_LANGUAGE", "Language")
Set("OPTIONS_LANGUAGE_AUTO", "Auto")

Set("TRACKING_GREAT_VAULT_TITLE", "Great Vault")
Set("TRACKING_CURRENCY_TITLE", "Currency")
Set("TRACKING_GV_RAID", "Raid")
Set("TRACKING_GV_DUNGEONS", "Dungeons")
Set("TRACKING_NA", "N/A")

Set("TRACKING_SPARKS_LABEL", "Sparks:")
Set("TRACKING_DONE", "Done")
Set("TRACKING_NOT_DONE", "Not done")

Set("TRACKING_QUEST_DELVERS_BOUNTY", "Delver's Bounty:")
Set("TRACKING_QUEST_WEEKLY_PREY", "Weekly Prey:")

Set("TRACKING_CREST_LABEL", "Crest:")
Set("TRACKING_CREST_ID_LABEL_FMT", "Crest %s:")
Set("TRACKING_NO_ID", "No ID")
Set("TRACKING_TRADE_UP_SUFFIX", " Trade Up)")

Set("TRACKING_CATALYST_LABEL", "Catalyst:")

Set("TRACKING_CURRENCY_FALLBACK_PREFIX", "Currency ")
Set("TRACKING_CREST_MATCH_SUBSTRING", "crest")
Set("TRACKING_INF", "INF")
Set("MINIMAP_TOOLTIP_TEXT", "Left-click to toggle the checklist")