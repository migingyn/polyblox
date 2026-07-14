--!strict
-- End-to-end flows exercising the full system graph with an in-memory DataStore
-- backend (PRD Section 15.2). These drive TradeSystem/MarketManager/ShopSystem/
-- PlayerDataManager together, the way the live server does.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Systems = ServerScriptService:WaitForChild("Systems")
local MarketManager = require(Systems:WaitForChild("MarketManager"))
local TradeSystem = require(Systems:WaitForChild("TradeSystem"))
local ShopSystem = require(Systems:WaitForChild("ShopSystem"))
local SharesEarningSystem = require(Systems:WaitForChild("SharesEarningSystem"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("DataStore"):WaitForChild("PlayerDataManager"))

local MemoryBackend = require(script.Parent:WaitForChild("lib"):WaitForChild("MemoryBackend"))
local TestKit = require(script.Parent:WaitForChild("lib"):WaitForChild("TestKit"))

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local nextUserId = 9000
local function newUser(): number
	nextUserId += 1
	return nextUserId
end

local function fastManualMarket(id: string)
	return MarketManager.createMarket({
		Id = id,
		Category = "ServerPulse",
		Question = "Will Red team win?",
		Outcomes = { "Yes", "No" },
		Lifespan = "Fast",
		ResolutionSource = "Manual",
	})
end

describe("E2E: starter grant persists across a rejoin (DataStore round-trip)", function()
	it("saves the grant and reloads it after cache eviction", function()
		local backend = MemoryBackend.new()
		PlayerDataManager.setBackend(backend)
		local uid = newUser()

		local data = PlayerDataManager.load(uid)
		SharesEarningSystem.applyStarterGrant(data)
		local granted = data.SharesBalance
		expect(granted).toBeGreaterThan(0)

		PlayerDataManager.release(uid) -- saves then evicts from cache

		local reloaded = PlayerDataManager.load(uid)
		expect(reloaded.SharesBalance).toEqual(granted)
		expect(reloaded.ReceivedStarterGrant).toBeTruthy()
		PlayerDataManager.release(uid)
	end)
end)

describe("E2E: open a Fast position, resolve, get paid, Net Worth updates", function()
	it("credits the winning payout and updates Net Worth", function()
		PlayerDataManager.setBackend(MemoryBackend.new())
		MarketManager.reset()
		local uid = newUser()
		local data = PlayerDataManager.load(uid)
		SharesEarningSystem.applyStarterGrant(data)

		fastManualMarket("e2e_win")
		local result = TradeSystem.executeTrade(uid, { MarketId = "e2e_win", Outcome = "Yes", SharesStaked = 100 })
		expect(result.ok).toBeTruthy()
		local balanceAfterTrade = data.SharesBalance

		MarketManager.resolveMarket("e2e_win", { manualOutcome = "Yes" })

		-- Won at 0.5 entry -> gross payout 200 credited on top of post-trade balance.
		expect(data.SharesBalance).toEqual(balanceAfterTrade + 200)
		expect(#data.OpenPositions).toEqual(0)
		expect(#data.PortfolioHistory).toEqual(1)
		expect(data.PortfolioHistory[1].Status).toEqual("Won")
		expect(data.NetWorth).toEqual(data.SharesBalance)
		PlayerDataManager.release(uid)
	end)

	it("takes the stake on a loss and caps the loss at the margin", function()
		PlayerDataManager.setBackend(MemoryBackend.new())
		MarketManager.reset()
		local uid = newUser()
		local data = PlayerDataManager.load(uid)
		SharesEarningSystem.applyStarterGrant(data)

		fastManualMarket("e2e_lose")
		local before = data.SharesBalance
		TradeSystem.executeTrade(uid, { MarketId = "e2e_lose", Outcome = "Yes", SharesStaked = 100 })
		MarketManager.resolveMarket("e2e_lose", { manualOutcome = "No" })

		-- Net effect: -100 stake +5 trickle = before - 95 (loss never exceeds stake).
		expect(data.SharesBalance).toEqual(before - 100 + 5)
		expect(data.SharesBalance).toBeGreaterThan(0)
		expect(data.PortfolioHistory[1].Status).toEqual("Lost")
		PlayerDataManager.release(uid)
	end)
end)

describe("E2E: leveraged position liquidates when odds cross the threshold", function()
	it("auto-closes as Liquidated with the loss capped at margin", function()
		PlayerDataManager.setBackend(MemoryBackend.new())
		MarketManager.reset()
		local a = newUser()
		local b = newUser()
		local dataA = PlayerDataManager.load(a)
		local dataB = PlayerDataManager.load(b)
		SharesEarningSystem.applyStarterGrant(dataA)
		SharesEarningSystem.applyStarterGrant(dataB)

		fastManualMarket("e2e_liq")

		-- A goes long Yes at 5x (entry p=0.5, threshold=0.4).
		local balBeforeA = dataA.SharesBalance
		local resA = TradeSystem.executeTrade(a, { MarketId = "e2e_liq", Outcome = "Yes", SharesStaked = 100, Leverage = 5 })
		expect(resA.ok).toBeTruthy()

		-- B slams No hard enough to drop Yes probability below 0.4, liquidating A.
		TradeSystem.executeTrade(b, { MarketId = "e2e_liq", Outcome = "No", SharesStaked = 300, Leverage = 5 })

		-- A's position should now be liquidated and off the open book.
		expect(#dataA.OpenPositions).toEqual(0)
		expect(#dataA.PortfolioHistory).toEqual(1)
		expect(dataA.PortfolioHistory[1].Status).toEqual("Liquidated")
		-- Loss capped at the 100 margin (trickle +5 offsets): balBeforeA -100 +5.
		expect(dataA.SharesBalance).toEqual(balBeforeA - 100 + 5)
		expect(dataA.SharesBalance).toBeGreaterThan(0)
		PlayerDataManager.release(a)
		PlayerDataManager.release(b)
	end)
end)

describe("E2E: Robux purchase never changes Shares balance (Section 2, required)", function()
	it("grants a cosmetic with zero side-effect on SharesBalance", function()
		PlayerDataManager.setBackend(MemoryBackend.new())
		local uid = newUser()
		local data = PlayerDataManager.load(uid)
		SharesEarningSystem.applyStarterGrant(data)
		local balanceBefore = data.SharesBalance

		local res = ShopSystem.grantPurchase(uid, "desk_neon")
		expect(res.ok).toBeTruthy()
		expect(data.OwnedCosmetics["PLACEHOLDER_Desk_Neon"]).toBeTruthy()
		-- THE critical assertion: balance is byte-for-byte unchanged.
		expect(data.SharesBalance).toEqual(balanceBefore)
		PlayerDataManager.release(uid)
	end)

	it("grants extra Portfolio Slots (QoL) without touching Shares", function()
		PlayerDataManager.setBackend(MemoryBackend.new())
		local uid = newUser()
		local data = PlayerDataManager.load(uid)
		SharesEarningSystem.applyStarterGrant(data)
		local balanceBefore = data.SharesBalance
		local slotsBefore = data.PortfolioSlotLimit

		ShopSystem.grantPurchase(uid, "slots_plus3")
		expect(data.PortfolioSlotLimit).toEqual(slotsBefore + 3)
		expect(data.SharesBalance).toEqual(balanceBefore)
		PlayerDataManager.release(uid)
	end)
end)

describe("E2E: two players on the same Fast market move odds and resolve independently", function()
	it("shifts odds for both and settles each correctly", function()
		PlayerDataManager.setBackend(MemoryBackend.new())
		MarketManager.reset()
		local a = newUser()
		local b = newUser()
		local dataA = PlayerDataManager.load(a)
		local dataB = PlayerDataManager.load(b)
		SharesEarningSystem.applyStarterGrant(dataA)
		SharesEarningSystem.applyStarterGrant(dataB)

		fastManualMarket("e2e_two")

		local pYesStart = MarketManager.currentOdds("e2e_two").Yes
		TradeSystem.executeTrade(a, { MarketId = "e2e_two", Outcome = "Yes", SharesStaked = 200 })
		local pYesAfterA = MarketManager.currentOdds("e2e_two").Yes
		expect(pYesAfterA).toBeGreaterThan(pYesStart) -- odds moved because of A

		TradeSystem.executeTrade(b, { MarketId = "e2e_two", Outcome = "No", SharesStaked = 100 })

		MarketManager.resolveMarket("e2e_two", { manualOutcome = "Yes" })

		expect(dataA.PortfolioHistory[1].Status).toEqual("Won")
		expect(dataB.PortfolioHistory[1].Status).toEqual("Lost")
		PlayerDataManager.release(a)
		PlayerDataManager.release(b)
	end)
end)
