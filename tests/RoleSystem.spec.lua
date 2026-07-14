--!strict
-- Unit tests for RoleSystem earned-threshold boundaries (PRD Section 15.1):
-- test at threshold-1, threshold, threshold+1.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoleSystem = require(ServerScriptService:WaitForChild("Systems"):WaitForChild("RoleSystem"))
local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local TestKit = require(script.Parent:WaitForChild("lib"):WaitForChild("TestKit"))

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local SP = Constants.SIGNAL_PROVIDER_NETWORTH
local SL = Constants.SYNDICATE_LEADER_NETWORTH

describe("RoleSystem Signal Provider threshold", function()
	it("does not qualify just below the Net Worth threshold", function()
		expect(RoleSystem.qualifiesForSignalProvider(SP - 1, 0)).toBeFalsy()
	end)
	it("qualifies exactly at the threshold", function()
		expect(RoleSystem.qualifiesForSignalProvider(SP, 0)).toBeTruthy()
	end)
	it("qualifies above the threshold", function()
		expect(RoleSystem.qualifiesForSignalProvider(SP + 1, 0)).toBeTruthy()
	end)
	it("qualifies via the win-streak path independent of Net Worth", function()
		expect(RoleSystem.qualifiesForSignalProvider(0, Constants.SIGNAL_PROVIDER_WIN_STREAK)).toBeTruthy()
		expect(RoleSystem.qualifiesForSignalProvider(0, Constants.SIGNAL_PROVIDER_WIN_STREAK - 1)).toBeFalsy()
	end)
end)

describe("RoleSystem Syndicate Leader threshold", function()
	it("boundary behaviour at threshold-1 / threshold / threshold+1", function()
		expect(RoleSystem.qualifiesForSyndicateLeader(SL - 1)).toBeFalsy()
		expect(RoleSystem.qualifiesForSyndicateLeader(SL)).toBeTruthy()
		expect(RoleSystem.qualifiesForSyndicateLeader(SL + 1)).toBeTruthy()
	end)
end)

describe("RoleSystem evaluate", function()
	local function data(netWorth: number, role: string)
		return {
			UserId = 1, SharesBalance = 0, NetWorth = netWorth, PortfolioSlotLimit = 3,
			OpenPositions = {}, PortfolioHistory = {}, LoginStreak = 0, LastLoginDay = 0,
			EarnRateMultiplier = 1.0, Role = role, OwnedCosmetics = {}, UnlockedFeatures = {},
			ReceivedStarterGrant = true,
		}
	end

	it("promotes Trader -> SignalProvider at the threshold", function()
		local d = data(SP, "Trader")
		expect(RoleSystem.evaluate(d, 0)).toEqual("SignalProvider")
		expect(d.Role).toEqual("SignalProvider")
	end)

	it("promotes to SyndicateLeader at the higher threshold", function()
		local d = data(SL, "SignalProvider")
		expect(RoleSystem.evaluate(d, 0)).toEqual("SyndicateLeader")
	end)

	it("never demotes an earned role when Net Worth falls", function()
		local d = data(0, "SyndicateLeader")
		expect(RoleSystem.evaluate(d, 0)).toBeNil()
		expect(d.Role).toEqual("SyndicateLeader")
	end)
end)
