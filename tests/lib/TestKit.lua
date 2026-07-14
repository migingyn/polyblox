--!strict
--[[
	TestKit.lua
	Lightweight assertion-based test framework (PRD Section 15.1 explicitly
	permits "an equivalent lightweight assertion-based runner" in place of
	TestEZ). Provides a familiar describe/it structure plus an `expect` matcher.

	Specs register via TestKit.describe(...) at require time; the TestRunner then
	requires every *.spec and calls TestKit.run() to execute + report.

	Deliberately dependency-free so pure-logic specs run headlessly.
]]

local TestKit = {}

type Test = { name: string, fn: () -> (), path: { string } }

local contextStack: { string } = {}
local pendingTests: { Test } = {}

function TestKit.describe(name: string, body: () -> ())
	table.insert(contextStack, name)
	body()
	table.remove(contextStack)
end

function TestKit.it(name: string, fn: () -> ())
	local path = {}
	for _, c in ipairs(contextStack) do
		table.insert(path, c)
	end
	table.insert(pendingTests, { name = name, fn = fn, path = path })
end

-- ---- expect matcher --------------------------------------------------------
-- Matchers are value-bound CLOSURES so specs read `expect(x).toEqual(y)` with
-- dot syntax (no self / colon).

local function fail(msg: string)
	error(msg, 3)
end

function TestKit.expect(value: any)
	return {
		toEqual = function(expected: any)
			if value ~= expected then
				fail(("expected %s to equal %s"):format(tostring(value), tostring(expected)))
			end
		end,
		toNotEqual = function(expected: any)
			if value == expected then
				fail(("expected %s to NOT equal %s"):format(tostring(value), tostring(expected)))
			end
		end,
		toBeCloseTo = function(expected: number, eps: number?)
			local tolerance = eps or 1e-6
			if type(value) ~= "number" or math.abs(value - expected) > tolerance then
				fail(("expected %s to be within %g of %s"):format(tostring(value), tolerance, tostring(expected)))
			end
		end,
		toBeTruthy = function()
			if not value then
				fail(("expected %s to be truthy"):format(tostring(value)))
			end
		end,
		toBeFalsy = function()
			if value then
				fail(("expected %s to be falsy"):format(tostring(value)))
			end
		end,
		toBeNil = function()
			if value ~= nil then
				fail(("expected %s to be nil"):format(tostring(value)))
			end
		end,
		toBeLessThan = function(other: number)
			if not (value < other) then
				fail(("expected %s to be < %s"):format(tostring(value), tostring(other)))
			end
		end,
		toBeGreaterThan = function(other: number)
			if not (value > other) then
				fail(("expected %s to be > %s"):format(tostring(value), tostring(other)))
			end
		end,
		-- value must be a function; asserts it errors when called.
		toThrow = function()
			if type(value) ~= "function" then
				fail("toThrow expects a function")
			end
			if pcall(value) then
				fail("expected function to throw, but it did not")
			end
		end,
		toNotThrow = function()
			if type(value) ~= "function" then
				fail("toNotThrow expects a function")
			end
			local ok, err = pcall(value)
			if not ok then
				fail("expected function not to throw, but it threw: " .. tostring(err))
			end
		end,
	}
end

-- ---- runner ----------------------------------------------------------------

--- Executes all registered tests. Returns (passed, failed, failures).
function TestKit.run(): (number, number, { string })
	local passed, failed = 0, 0
	local failures: { string } = {}

	for _, test in ipairs(pendingTests) do
		local label = table.concat(test.path, " > ") .. " > " .. test.name
		local ok, err = pcall(test.fn)
		if ok then
			passed += 1
			print(("  [PASS] %s"):format(label))
		else
			failed += 1
			table.insert(failures, label .. "\n      " .. tostring(err))
			print(("  [FAIL] %s\n      %s"):format(label, tostring(err)))
		end
	end

	print(("\n[TestKit] %d passed, %d failed, %d total"):format(passed, failed, passed + failed))
	return passed, failed, failures
end

--- Clears registered tests (useful if re-running in one session).
function TestKit.reset()
	pendingTests = {}
	contextStack = {}
end

return TestKit
