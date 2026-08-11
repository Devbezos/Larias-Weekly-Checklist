local Test = dofile("tests/test_helper.lua")
_G.LWMC_TEST = Test
_G.LWMC_TEST_ADDON = {}
_G.LWMC_HARNESS = dofile("tests/wow_mock.lua")

local addonName = "LWMC_TEST_ADDON"
local chunk, loadError = loadfile("features/services/general/LariasWeeklyChecklist_CoreLogic.lua")
if not chunk then error(loadError) end
chunk(addonName)

dofile("tests/core_logic_test.lua")
dofile("tests/utils_test.lua")
dofile("tests/database_character_test.lua")
dofile("tests/comms_tracking_test.lua")
dofile("tests/feature_logic_test.lua")
dofile("tests/window_persistence_test.lua")

print(string.format("1..%d", Test.total))
if Test.failed > 0 then
    error(string.format("%d of %d tests failed", Test.failed, Test.total), 0)
end
print(string.format("All %d tests passed.", Test.total))
