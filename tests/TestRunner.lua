--!strict
--[[
	TestRunner.lua
	Discovers every *.spec ModuleScript sibling, requires it (which registers its
	tests with TestKit), then runs them. Returns (passed, failed) so a CI harness
	can set a non-zero exit on failure.

	Run headlessly via run-in-roblox with scripts/run_tests.server.lua, or call
	require(ServerStorageTests.TestRunner).run() from the command bar in Studio.
]]

local TestKit = require(script.Parent:WaitForChild("lib"):WaitForChild("TestKit"))

local TestRunner = {}

function TestRunner.run(): (number, number)
	TestKit.reset()

	-- Require every spec so its describe/it blocks register.
	for _, child in ipairs(script.Parent:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name:match("%.spec$") then
			require(child)
		end
	end

	print("\n=== PolyBlox test run ===")
	local passed, failed = TestKit.run()
	return passed, failed
end

return TestRunner
