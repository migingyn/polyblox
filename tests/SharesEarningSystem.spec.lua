--!strict
-- Unit tests for SharesEarningSystem (PRD Section 15.1): streak caps, no
-- runaway compounding, and exactly-once starter grant.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharesEarningSystem = require(ServerScriptService:WaitForChild("Systems"):WaitForChild("SharesEarningSystem"))
local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local TestKit = require(script.Parent:WaitForChild("lib"):WaitForChild("TestKit"))

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function freshData()
	return {
		UserId = 1,
		SharesBalance = 0,
		NetWorth = 0,
		PortfolioSlotLimit = 3,
		OpenPositions = {},
		PortfolioHistory = {},
		LoginStreak = 0,
		LastLoginDay = 0,
		EarnRateMultiplier = 1.0,
		Role = "Trader",
		OwnedCosmetics = {},
		UnlockedFeatures = {},
		ReceivedStarterGrant = false,
	}
end

local DAY = 86400

describe("SharesEarningSystem starter grant", function()
	it("grants exactly once", function()
		local data = freshData()
		expect(SharesEarningSystem.applyStarterGrant(data)).toEqual(Constants.STARTER_GRANT)
		expect(data.SharesBalance).toEqual(Constants.STARTER_GRANT)
		-- Second call is a no-op.
		expect(SharesEarningSystem.applyStarterGrant(data)).toEqual(0)
		expect(data.SharesBalance).toEqual(Constants.STARTER_GRANT)
	end)
end)

describe("SharesEarningSystem daily streak", function()
	it("does not grant twice in the same calendar day", function()
		local data = freshData()
		local first = SharesEarningSystem.applyDailyLogin(data, 10 * DAY + 100)
		expect(first).toBeGreaterThan(0)
		local second = SharesEarningSystem.applyDailyLogin(data, 10 * DAY + 5000)
		expect(second).toEqual(0)
	end)

	it("increments streak on consecutive days and resets on a gap", function()
		local data = freshData()
		SharesEarningSystem.applyDailyLogin(data, 10 * DAY)
		expect(data.LoginStreak).toEqual(1)
		SharesEarningSystem.applyDailyLogin(data, 11 * DAY)
		expect(data.LoginStreak).toEqual(2)
		-- Skip day 12; log in day 13 -> streak resets to 1.
		SharesEarningSystem.applyDailyLogin(data, 13 * DAY)
		expect(data.LoginStreak).toEqual(1)
	end)

	it("caps the streak multiplier so it cannot runaway-compound", function()
		-- Even at an absurd streak the multiplier is bounded by the cap.
		expect(SharesEarningSystem.streakMultiplier(9999)).toEqual(Constants.DAILY_STREAK_MAX_MULT)
		local capped = SharesEarningSystem.computeDailyBonus(9999, 1.0)
		local uncappedIfNoCap = Constants.DAILY_BONUS_BASE * Constants.DAILY_STREAK_MAX_MULT
		expect(capped).toEqual(math.floor(uncappedIfNoCap + 0.5))
	end)

	it("day 1 streak uses the base multiplier (1.0)", function()
		expect(SharesEarningSystem.streakMultiplier(1)).toBeCloseTo(1.0)
	end)
end)

describe("SharesEarningSystem trade trickle", function()
	it("adds a small amount scaled by earn-rate multiplier", function()
		local data = freshData()
		data.EarnRateMultiplier = 2.0
		local amount = SharesEarningSystem.applyTradeTrickle(data)
		expect(amount).toEqual(Constants.PASSIVE_TRICKLE_PER_TRADE * 2)
	end)
end)
