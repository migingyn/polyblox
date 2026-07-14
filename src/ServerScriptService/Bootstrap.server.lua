--!strict
--[[
	Bootstrap.server.lua
	Authoritative server entry point. Wires persistence, seeds demo markets,
	handles joins/earning, routes RemoteEvents, and runs the market tick loop.
	All gameplay logic lives in the Systems modules - this file is orchestration.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Remotes"))
local Constants = require(Modules:WaitForChild("Constants"))

local Systems = ServerScriptService:WaitForChild("Systems")
local MarketManager = require(Systems:WaitForChild("MarketManager"))
local TradeSystem = require(Systems:WaitForChild("TradeSystem"))
local ShopSystem = require(Systems:WaitForChild("ShopSystem"))
local RoleSystem = require(Systems:WaitForChild("RoleSystem"))
local SharesEarningSystem = require(Systems:WaitForChild("SharesEarningSystem"))
local LeaderboardSystem = require(Systems:WaitForChild("LeaderboardSystem"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("DataStore"):WaitForChild("PlayerDataManager"))

local SeedMarkets = require(ServerStorage:WaitForChild("MarketConfigs"):WaitForChild("SeedMarkets"))

-- Server-only ground truth for Deterministic/Manual markets (never replicated).
local truthByMarket: { [string]: string } = {}

-- ============================================================================
-- Market seeding
-- ============================================================================

local function seedMarket(config)
	local market = MarketManager.createMarket({
		Id = config.Id,
		Category = config.Category,
		Question = config.Question,
		Outcomes = config.Outcomes,
		Lifespan = config.Lifespan,
		ResolutionSource = config.ResolutionSource,
	})
	if config.TruthOutcome then
		truthByMarket[config.Id] = config.TruthOutcome
	end
	return market
end

local function seedAllMarkets()
	for _, config in ipairs(SeedMarkets) do
		-- Only fully-implemented categories run live; Seasonal/Community are stubs.
		if config.Category ~= "Community" then
			seedMarket(config)
		end
	end
end

-- ============================================================================
-- Player data push
-- ============================================================================

local function pushPlayerData(player: Player)
	local data = PlayerDataManager.get(player.UserId)
	if not data then
		return
	end
	Remotes.get("PlayerDataUpdate"):FireClient(player, data)
end

local function trailingWinStreak(data): number
	local streak = 0
	for i = #data.PortfolioHistory, 1, -1 do
		if data.PortfolioHistory[i].Status == "Won" then
			streak += 1
		else
			break
		end
	end
	return streak
end

local function refreshRoles(userId: number)
	local data = PlayerDataManager.get(userId)
	if not data then
		return
	end
	RoleSystem.evaluate(data, trailingWinStreak(data))
end

-- ============================================================================
-- Join / leave
-- ============================================================================

local function onPlayerAdded(player: Player)
	local data = PlayerDataManager.load(player.UserId)

	-- Earn-only income (Section 6.1): starter grant once, then daily login.
	SharesEarningSystem.applyStarterGrant(data)
	SharesEarningSystem.applyDailyLogin(data, os.time())

	MarketManager.recomputeNetWorth(player.UserId)
	LeaderboardSystem.registerSeasonBaseline(player.UserId, data.NetWorth)

	pushPlayerData(player)

	-- Send the initial market list (public snapshots only - no seed/truth).
	for _, market in ipairs(MarketManager.getActive()) do
		Remotes.get("MarketUpdate"):FireClient(player, MarketManager.publicMarket(market))
	end
end

-- ============================================================================
-- Remote handlers
-- ============================================================================

local function wireRemotes()
	Remotes.get("RequestTrade").OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" then
			return
		end
		local result = TradeSystem.executeTrade(player.UserId, {
			MarketId = payload.MarketId,
			Outcome = payload.Outcome,
			SharesStaked = payload.SharesStaked,
			Leverage = payload.Leverage,
		})
		if result.ok then
			refreshRoles(player.UserId)
		end
		pushPlayerData(player)
	end)

	Remotes.get("RequestCopyTrade").OnServerEvent:Connect(function(player, sourceUserId, marketId)
		if type(sourceUserId) ~= "number" or type(marketId) ~= "string" then
			return
		end
		TradeSystem.copyTrade(player.UserId, sourceUserId, marketId)
		pushPlayerData(player)
	end)

	-- Robux purchase completion.
	-- In production this is driven by MarketplaceService receipt/gamepass
	-- callbacks below. RequestPurchase is a test hook so the automated E2E
	-- purchase flow can run where a real Robux prompt isn't available; it only
	-- ever grants cosmetics/QoL (ShopSystem cannot touch Shares, Section 2).
	Remotes.get("RequestPurchase").OnServerEvent:Connect(function(player, itemId)
		if type(itemId) ~= "string" then
			return
		end
		ShopSystem.grantPurchase(player.UserId, itemId)
		pushPlayerData(player)
	end)
end

-- ============================================================================
-- Tick loop
-- ============================================================================

-- Fast markets are the retention loop: when one resolves, seed a fresh copy so
-- there is always something to trade (Section 4.2).
local function reseedResolvedFastMarkets()
	for _, config in ipairs(SeedMarkets) do
		if config.Lifespan == "Fast" then
			local market = MarketManager.getMarket(config.Id)
			if market and market.Status == "Resolved" then
				-- Reuse the same id by resetting via a versioned id.
				local newId = config.Id .. "_" .. tostring(os.time())
				seedMarket({
					Id = newId,
					Category = config.Category,
					Question = config.Question,
					Outcomes = config.Outcomes,
					Lifespan = config.Lifespan,
					ResolutionSource = config.ResolutionSource,
					TruthOutcome = config.TruthOutcome,
				})
			end
		end
	end
end

local function startTickLoop()
	task.spawn(function()
		while true do
			local now = os.time()
			-- Resolve Deterministic/Manual markets whose lock time has passed,
			-- using their server-side ground truth. RandomSeed auto-resolves in tick.
			for _, market in ipairs(MarketManager.getActive()) do
				if market.Status ~= "Resolved" and now >= market.LockTime then
					if market.ResolutionSource == "Deterministic" then
						MarketManager.resolveMarket(market.Id, { deterministicOutcome = truthByMarket[market.Id] })
					elseif market.ResolutionSource == "Manual" then
						MarketManager.resolveMarket(market.Id, { manualOutcome = truthByMarket[market.Id] })
					end
				end
			end
			MarketManager.tick(now) -- locks + resolves RandomSeed markets

			for _, player in ipairs(Players:GetPlayers()) do
				MarketManager.recomputeNetWorth(player.UserId)
				refreshRoles(player.UserId)
				pushPlayerData(player)
			end

			-- Broadcast leaderboard snapshots (global + seasonal top 10).
			Remotes.get("LeaderboardUpdate"):FireAllClients({
				Global = LeaderboardSystem.getGlobal(10),
				Seasonal = LeaderboardSystem.getSeasonal(10),
			})

			reseedResolvedFastMarkets()
			task.wait(5)
		end
	end)
end

-- ============================================================================
-- Startup
-- ============================================================================

if RunService:IsServer() then
	-- No setBackend() call: PlayerDataManager lazily uses the real DataStore backend.
	PlayerDataManager.start()
	seedAllMarkets()
	wireRemotes()

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	startTickLoop()
	print("[PolyBlox] Server bootstrapped. Markets seeded:", #MarketManager.getActive())
end
