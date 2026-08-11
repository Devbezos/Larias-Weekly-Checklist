std = "lua51"
codes = true
max_line_length = false

-- WoW API names are runtime-provided globals. Keep undefined-global checks out
-- of the baseline while retaining Luacheck's local, control-flow, and hygiene
-- diagnostics across first-party code.
ignore = {
    "111", -- setting a non-standard global
    "112", -- mutating a non-standard global
    "113", -- accessing an undefined global
    "211", -- unused local (legacy baseline)
    "212", -- unused callback argument (common in WoW handlers)
    "231", -- assigned local never accessed (legacy baseline)
    "311", -- value assigned but unused (legacy baseline)
    "421", -- shadowing a local (legacy baseline)
    "431", -- shadowing an upvalue (legacy baseline)
    "432", -- shadowing an upvalue argument (legacy baseline)
    "542", -- empty branch used for documented no-op cases
    "614", -- trailing whitespace in legacy comments
}

exclude_files = {
    "lib/**",
    "Locales/enUS_Data.lua",
}

-- New pure modules and the test runner do not depend on WoW-provided globals,
-- so keep the full LuaCheck rule set enabled there. Expand this list as older
-- modules gain explicit WoW-global declarations.
files["features/services/general/LariasWeeklyChecklist_CoreLogic.lua"] = { ignore = {} }
files["tests/*.lua"] = { ignore = {} }
