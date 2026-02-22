local addonName = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)

if not L then return end

L["DISPLAY_NAME"] = "Larias Weekly Midnight Checklist"

-- UI: popup shown when a new addon version is installed (until acknowledged).
L["UPDATE_AVAILABLE_TITLE"] = "New version available"
L["UPDATE_AVAILABLE_TEXT"] = "New version available"
L["UPDATE_AVAILABLE_FMT"] = "%s has an update available.\n\nPlease update the addon to the newest version."

L["OPTIONS_SHOW_GREAT_VAULT"] = "Show Great Vault"
L["OPTIONS_SHOW_CURRENCY"] = "Show Currency"

L["HIDE_COMPLETED_WEEKS"] = "Hide completed weeks"
L["OPTIONS_BUTTON"] = "Options"
L["RESET_BUTTON"] = "Reset"
L["DONE_PREFIX"] = "[Done] "

L["TRACKING_GREAT_VAULT_TITLE"] = "Great Vault"
L["TRACKING_CURRENCY_TITLE"] = "Currency"
L["TRACKING_GV_RAID"] = "Raid"
L["TRACKING_GV_DUNGEONS"] = "Dungeons"
L["TRACKING_NA"] = "N/A"

L["TRACKING_SPARKS_LABEL"] = "Sparks:"
L["TRACKING_DONE"] = "Done"
L["TRACKING_NOT_DONE"] = "Not done"

L["TRACKING_QUEST_DELVERS_BOUNTY"] = "Delver's Bounty:"
L["TRACKING_QUEST_WEEKLY_PREY"] = "Weekly Prey:"

L["TRACKING_CREST_LABEL"] = "Crest:"
L["TRACKING_CREST_ID_LABEL_FMT"] = "Crest %s:"
L["TRACKING_NO_ID"] = "No ID"
L["TRACKING_TRADE_UP_SUFFIX"] = " Trade Up)"

L["TRACKING_CATALYST_LABEL"] = "Catalyst:"

L["TRACKING_CURRENCY_FALLBACK_PREFIX"] = "Currency "
L["TRACKING_CREST_MATCH_SUBSTRING"] = "crest"
L["TRACKING_INF"] = "INF"
L["MINIMAP_TOOLTIP_TEXT"] = "Left-click to toggle the checklist"