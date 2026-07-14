--!strict
-- Unit tests for OddsCalculator pooled-odds math (PRD Section 15.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OddsCalculator = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OddsCalculator"))
local TestKit = require(script.Parent:WaitForChild("lib"):WaitForChild("TestKit"))

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("OddsCalculator", function()
	local YESNO = { "Yes", "No" }

	it("returns 0.5/0.5 for zero stake on both sides", function()
		local odds = OddsCalculator.impliedOdds({ Yes = 0, No = 0 }, YESNO)
		expect(odds.Yes).toBeCloseTo(0.5)
		expect(odds.No).toBeCloseTo(0.5)
	end)

	it("returns 0.5/0.5 for equal stake", function()
		local odds = OddsCalculator.impliedOdds({ Yes = 500, No = 500 }, YESNO)
		expect(odds.Yes).toBeCloseTo(0.5)
		expect(odds.No).toBeCloseTo(0.5)
	end)

	it("always has probabilities summing to 1", function()
		local odds = OddsCalculator.impliedOdds({ Yes = 137, No = 42 }, YESNO)
		expect(odds.Yes + odds.No).toBeCloseTo(1)
	end)

	it("keeps probabilities strictly inside (0,1) even with all stake on one side", function()
		local odds = OddsCalculator.impliedOdds({ Yes = 100000, No = 0 }, YESNO)
		expect(odds.Yes).toBeLessThan(1)
		expect(odds.No).toBeGreaterThan(0)
		expect(odds.Yes).toBeGreaterThan(0.9) -- heavily favoured but bounded
	end)

	it("moves odds toward the side receiving a single position", function()
		local before = OddsCalculator.impliedProbability({ Yes = 0, No = 0 }, YESNO, "Yes")
		local after = OddsCalculator.impliedProbability({ Yes = 200, No = 0 }, YESNO, "Yes")
		expect(after).toBeGreaterThan(before)
	end)

	it("handles many simultaneous positions consistently", function()
		local pool = { Yes = 0, No = 0 }
		for _ = 1, 50 do
			pool.Yes += 10
			pool.No += 5
		end
		local odds = OddsCalculator.impliedOdds(pool, YESNO)
		expect(odds.Yes).toBeGreaterThan(odds.No)
		expect(odds.Yes + odds.No).toBeCloseTo(1)
	end)

	it("supports multi-outcome markets", function()
		local outs = { "A", "B", "C" }
		local odds = OddsCalculator.impliedOdds({ A = 0, B = 0, C = 0 }, outs)
		expect(odds.A + odds.B + odds.C).toBeCloseTo(1)
		expect(odds.A).toBeCloseTo(1 / 3)
	end)

	it("toDecimalOdds is the reciprocal of probability", function()
		expect(OddsCalculator.toDecimalOdds(0.25)).toBeCloseTo(4)
		expect(OddsCalculator.toDecimalOdds(0.5)).toBeCloseTo(2)
	end)

	it("toDecimalOdds rejects impossible probabilities", function()
		expect(function()
			OddsCalculator.toDecimalOdds(0)
		end).toThrow()
		expect(function()
			OddsCalculator.toDecimalOdds(1)
		end).toThrow()
	end)

	it("poolWeights are flat when nothing is staked", function()
		local w = OddsCalculator.poolWeights({ Yes = 0, No = 0 }, YESNO)
		expect(w.Yes).toBeCloseTo(0.5)
	end)

	it("poolWeights reflect real stake share", function()
		local w = OddsCalculator.poolWeights({ Yes = 300, No = 100 }, YESNO)
		expect(w.Yes).toBeCloseTo(0.75)
		expect(w.No).toBeCloseTo(0.25)
	end)
end)
