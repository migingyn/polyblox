--!strict
--[[
	run_tests.server.lua
	Headless test entry point for run-in-roblox / CI. Waits for the built
	DataModel, runs the suite, and errors (non-zero exit) if anything failed.

	Usage (with a synced/built place):
	  rojo build -o build.rbxlx
	  run-in-roblox --place build.rbxlx --script scripts/run_tests.server.lua
]]

-- The project maps tests/ to ServerStorage.Tests (server-only, not replicated).
local testsFolder = game:GetService("ServerStorage"):WaitForChild("Tests", 10)
assert(testsFolder, "ServerStorage.Tests folder not found - is the project built with tests?")

local TestRunner = require(testsFolder:WaitForChild("TestRunner"))
local _passed, failed = TestRunner.run()

if failed > 0 then
	error(("PolyBlox tests failed: %d failing"):format(failed))
end
print("All PolyBlox tests passed.")
