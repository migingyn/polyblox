--!strict
-- Unit tests for TradeSystem.validate (pure) + PortfolioSlotLimit enforcement
-- (PRD Section 15.1 - reject a trade that would exceed the slot cap; Section 14
-- - reject leverage over the 5x cap / over available Shares).

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradeSystem = require(ServerScriptService:WaitForChild("Systems"):WaitForChild("TradeSystem"))
local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local TestKit = require(script.Parent:WaitForChild("lib"):WaitForChild("TestKit"))

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function data(overrides)
	local base = {
		UserId = 1, SharesBalance = 1000, NetWorth = 1000, PortfolioSlotLimit = 3,
		OpenPositions = {}, PortfolioHistory = {}, LoginStreak = 0, LastLoginDay = 0,
		EarnRateMultiplier = 1.0, Role = "Trader", OwnedCosmetics = {}, UnlockedFeatures = {},
		ReceivedStarterGrant = true,
	}
	if overrides then
		for k, v in pairs(overrides) do
			base[k] = v
		end
	end
	return base
end

local function market()
	return {
		Id = "m1", Category = "ServerPulse", Question = "Q?", Outcomes = { "Yes", "No" },
		Lifespan = "Fast", Status = "Open", PoolByOutcome = { Yes = 0, No = 0 },
		ResolutionSource = "Manual", OpenTime = 0, LockTime = 999,
	}
end

describe("TradeSystem.validate", function()
	it("accepts a valid standard trade", function()
		local ok = TradeSystem.validate(data(), market(), "Yes", 100, 1)
		expect(ok).toBeTruthy()
	end)

	it("rejects an unknown market", function()
		local ok, err = TradeSystem.validate(data(), nil, "Yes", 100, 1)
		expect(ok).toBeFalsy()
		expect(err).toEqual("Market not found")
	end)

	it("rejects a non-open market", function()
		local m = market()
		m.Status = "Locked"
		local ok = TradeSystem.validate(data(), m, "Yes", 100, 1)
		expect(ok).toBeFalsy()
	end)

	it("rejects an invalid outcome", function()
		local ok = TradeSystem.validate(data(), market(), "Maybe", 100, 1)
		expect(ok).toBeFalsy()
	end)

	it("rejects a stake below the minimum", function()
		local ok = TradeSystem.validate(data(), market(), "Yes", Constants.MIN_STAKE - 1, 1)
		expect(ok).toBeFalsy()
	end)

	it("rejects a stake above the player's balance", function()
		local ok = TradeSystem.validate(data({ SharesBalance = 50 }), market(), "Yes", 100, 1)
		expect(ok).toBeFalsy()
	end)

	it("rejects leverage above the 5x cap", function()
		local ok, err = TradeSystem.validate(data(), market(), "Yes", 100, Constants.MAX_LEVERAGE + 1)
		expect(ok).toBeFalsy()
		expect(err).toBeTruthy()
	end)

	it("accepts leverage exactly at the 5x cap", function()
		local ok = TradeSystem.validate(data(), market(), "Yes", 100, Constants.MAX_LEVERAGE)
		expect(ok).toBeTruthy()
	end)

	it("rejects leverage below 1x", function()
		local ok = TradeSystem.validate(data(), market(), "Yes", 100, 0)
		expect(ok).toBeFalsy()
	end)

	it("rejects a trade that would exceed the Portfolio Slot limit", function()
		local d = data({ PortfolioSlotLimit = 2, OpenPositions = { {}, {} } })
		local ok, err = TradeSystem.validate(d, market(), "Yes", 100, 1)
		expect(ok).toBeFalsy()
		expect(err).toBeTruthy()
	end)

	it("allows a trade when exactly one slot remains", function()
		local d = data({ PortfolioSlotLimit = 3, OpenPositions = { {}, {} } })
		expect(TradeSystem.validate(d, market(), "Yes", 100, 1)).toBeTruthy()
	end)
end)
