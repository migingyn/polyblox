--!strict
--[[
	MarketManager.lua
	Market lifecycle: open -> lock -> resolve (PRD Section 4.2, 4.3, 4.4).

	Owns the live set of markets and, per market, the list of open positions
	(shared by reference with each player's PlayerData.OpenPositions so a single
	mutation is visible to both persistence and the pool). Coordinates:
	  * pool updates that move the odds (Section 4.3),
	  * seed generation for RandomSeed markets at LOCK time (Section 4.4),
	  * settlement + payout on resolve (delegated to ResolutionSystem),
	  * liquidation sweeps for leveraged positions (Section 11.6),
	  * Net Worth recomputation feeding the leaderboard (Section 6.2).

	Broadcasts (MarketUpdate / ResolutionAnnounced / LiquidationTriggered) are
	best-effort and no-op off a live server so this module stays test-drivable.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Constants = require(Modules:WaitForChild("Constants"))
local OddsCalculator = require(Modules:WaitForChild("OddsCalculator"))
local Types = require(Modules:WaitForChild("Types"))

local ServerScriptService = game:GetService("ServerScriptService")
local ResolutionSystem = require(ServerScriptService:WaitForChild("Systems"):WaitForChild("ResolutionSystem"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("DataStore"):WaitForChild("PlayerDataManager"))

type Market = Types.Market
type Position = Types.Position

local MarketManager = {}

local markets: { [string]: Market } = {}
local positionsByMarket: { [string]: { Position } } = {}
-- Map a position back to the owning player so settlement can credit balances.
local ownerByPosition: { [string]: number } = {}

-- ============================================================================
-- Broadcast helpers (best-effort; silent off a live server)
-- ============================================================================

local function broadcast(remoteName: string, ...: any)
	if not RunService:IsServer() then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	local remote = folder and folder:FindFirstChild(remoteName)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients(...)
	end
end

--- Client-safe projection of a market. CRITICALLY omits ResolutionSeed and any
--- ground-truth (Section 4.4) - the client only ever sees public pool/odds.
export type PublicMarket = {
	Id: string,
	Category: string,
	Question: string,
	Outcomes: { string },
	Lifespan: string,
	Status: string,
	PoolByOutcome: { [string]: number },
	Odds: { [string]: number },
	ResolvedOutcome: string?,
	LockTime: number,
}

function MarketManager.publicMarket(market: Market): PublicMarket
	return {
		Id = market.Id,
		Category = market.Category,
		Question = market.Question,
		Outcomes = market.Outcomes,
		Lifespan = market.Lifespan,
		Status = market.Status,
		PoolByOutcome = market.PoolByOutcome,
		Odds = OddsCalculator.impliedOdds(market.PoolByOutcome, market.Outcomes),
		ResolvedOutcome = market.ResolvedOutcome,
		LockTime = market.LockTime,
	}
end

-- ============================================================================
-- Creation / queries
-- ============================================================================

export type MarketConfig = {
	Id: string,
	Category: Types.MarketCategory,
	Question: string,
	Outcomes: { string },
	Lifespan: Types.Lifespan,
	ResolutionSource: Types.ResolutionSource,
	OpenTime: number?, -- defaults to os.time()
}

function MarketManager.reset()
	markets = {}
	positionsByMarket = {}
	ownerByPosition = {}
end

function MarketManager.createMarket(config: MarketConfig): Market
	assert(not markets[config.Id], "duplicate market id: " .. config.Id)
	local openTime = config.OpenTime or os.time()
	local pool: { [string]: number } = {}
	for _, outcome in ipairs(config.Outcomes) do
		pool[outcome] = 0
	end
	local market: Market = {
		Id = config.Id,
		Category = config.Category,
		Question = config.Question,
		Outcomes = config.Outcomes,
		Lifespan = config.Lifespan,
		Status = "Open",
		PoolByOutcome = pool,
		ResolutionSource = config.ResolutionSource,
		ResolutionSeed = nil, -- generated at lock time only (Section 4.4)
		ResolvedOutcome = nil,
		OpenTime = openTime,
		LockTime = openTime + Constants.LIFESPAN_SECONDS[config.Lifespan],
	}
	markets[config.Id] = market
	positionsByMarket[config.Id] = {}
	return market
end

function MarketManager.getMarket(id: string): Market?
	return markets[id]
end

function MarketManager.getAll(): { Market }
	local out = {}
	for _, m in pairs(markets) do
		table.insert(out, m)
	end
	return out
end

function MarketManager.getActive(): { Market }
	local out = {}
	for _, m in pairs(markets) do
		if m.Status ~= "Resolved" then
			table.insert(out, m)
		end
	end
	return out
end

--- Current implied odds for a market (Section 4.3).
function MarketManager.currentOdds(id: string): { [string]: number }
	local market = markets[id]
	assert(market, "unknown market: " .. id)
	return OddsCalculator.impliedOdds(market.PoolByOutcome, market.Outcomes)
end

-- ============================================================================
-- Positions / pool updates
-- ============================================================================

--- Register a newly-opened position with its market, moving the pool (and thus
--- the odds). Called by TradeSystem after it has validated + deducted margin.
--- The position table is the same reference stored in PlayerData.OpenPositions.
function MarketManager.registerPosition(ownerUserId: number, position: Position)
	local market = markets[position.MarketId]
	assert(market, "position references unknown market: " .. position.MarketId)
	assert(market.Status == "Open", "cannot add position to a non-open market")

	market.PoolByOutcome[position.Outcome] = (market.PoolByOutcome[position.Outcome] or 0)
		+ position.SharesStaked * position.Leverage -- notional exposure moves the pool
	table.insert(positionsByMarket[position.MarketId], position)
	ownerByPosition[position.PositionId] = ownerUserId

	broadcast("MarketUpdate", MarketManager.publicMarket(market))

	-- A new position moving the odds can trigger liquidations on others.
	MarketManager.checkLiquidations(position.MarketId)
end

-- ============================================================================
-- Net Worth (Section 6.2)
-- ============================================================================

--- Recompute a player's Net Worth = SharesBalance + equity of open positions at
--- current odds. Writes it back to PlayerData and returns it.
function MarketManager.recomputeNetWorth(userId: number): number
	local data = PlayerDataManager.get(userId)
	if not data then
		return 0
	end
	local net = data.SharesBalance
	for _, position in ipairs(data.OpenPositions) do
		local market = markets[position.MarketId]
		if market then
			local p = OddsCalculator.impliedProbability(market.PoolByOutcome, market.Outcomes, position.Outcome)
			net += ResolutionSystem.positionEquity(position, p)
		else
			net += position.SharesStaked -- market gone; fall back to margin
		end
	end
	data.NetWorth = net
	return net
end

-- ============================================================================
-- Liquidation sweep (Section 11.6)
-- ============================================================================

local function removeOpenPosition(userId: number, positionId: string): Position?
	local data = PlayerDataManager.get(userId)
	if not data then
		return nil
	end
	for index, position in ipairs(data.OpenPositions) do
		if position.PositionId == positionId then
			table.remove(data.OpenPositions, index)
			table.insert(data.PortfolioHistory, position)
			return position
		end
	end
	return nil
end

--- Check every open leveraged position on a market and liquidate any that have
--- crossed their threshold at the current odds. Loss is capped at margin.
function MarketManager.checkLiquidations(id: string)
	local market = markets[id]
	if not market or market.Status == "Resolved" then
		return
	end
	local positions = positionsByMarket[id]
	if not positions then
		return
	end

	local survivors: { Position } = {}
	for _, position in ipairs(positions) do
		local p = OddsCalculator.impliedProbability(market.PoolByOutcome, market.Outcomes, position.Outcome)
		if ResolutionSystem.isLiquidated(position, p) then
			ResolutionSystem.liquidatePosition(position)
			local userId = ownerByPosition[position.PositionId]
			if userId then
				removeOpenPosition(userId, position.PositionId)
				MarketManager.recomputeNetWorth(userId)
				broadcast("LiquidationTriggered", userId, position.MarketId, position.PositionId)
			end
			ownerByPosition[position.PositionId] = nil
		else
			table.insert(survivors, position)
		end
	end
	positionsByMarket[id] = survivors
end

-- ============================================================================
-- Lifecycle transitions
-- ============================================================================

--- Lock a market. For RandomSeed markets the resolution seed is generated HERE,
--- at lock time, from ResolutionSystem.generateResolutionSeed() which never sees
--- PoolByOutcome - so staking volume cannot influence the outcome (Section 4.4).
function MarketManager.lockMarket(id: string)
	local market = markets[id]
	assert(market, "unknown market: " .. id)
	if market.Status ~= "Open" then
		return
	end
	market.Status = "Locked"
	if market.ResolutionSource == "RandomSeed" and market.ResolutionSeed == nil then
		market.ResolutionSeed = ResolutionSystem.generateResolutionSeed()
	end
	broadcast("MarketUpdate", MarketManager.publicMarket(market))
end

--- Resolve a market: determine outcome, settle every open position, credit
--- winners, archive positions, refresh Net Worth, announce.
function MarketManager.resolveMarket(id: string, opts: ResolutionSystem.ResolveOptions?)
	local market = markets[id]
	assert(market, "unknown market: " .. id)
	if market.Status == "Resolved" then
		return
	end
	if market.Status == "Open" then
		MarketManager.lockMarket(id) -- ensure locked (and seed generated) first
	end

	local resolved = ResolutionSystem.determineOutcome(market, opts or {})
	market.ResolvedOutcome = resolved
	market.Status = "Resolved"

	local affected: { [number]: boolean } = {}
	for _, position in ipairs(positionsByMarket[id] or {}) do
		local userId = ownerByPosition[position.PositionId]
		local data = userId and PlayerDataManager.get(userId)
		if data then
			local credit = ResolutionSystem.settlePosition(position, resolved)
			data.SharesBalance += credit
			removeOpenPosition(userId, position.PositionId)
			affected[userId] = true
		end
		if userId then
			ownerByPosition[position.PositionId] = nil
		end
	end
	positionsByMarket[id] = {}

	for userId in pairs(affected) do
		MarketManager.recomputeNetWorth(userId)
	end

	broadcast("ResolutionAnnounced", id, resolved)
	broadcast("MarketUpdate", MarketManager.publicMarket(market))
end

--- Time-driven lifecycle advance. Locks markets past their LockTime and
--- auto-resolves RandomSeed markets (self-contained fair resolution).
--- Deterministic/Manual markets are left for their game/admin caller.
function MarketManager.tick(now: number)
	for id, market in pairs(markets) do
		if market.Status == "Open" and now >= market.LockTime then
			MarketManager.lockMarket(id)
		end
		if market.Status == "Locked" and market.ResolutionSource == "RandomSeed" then
			MarketManager.resolveMarket(id)
		end
	end
end

-- Test/introspection helper.
function MarketManager._positionsFor(id: string): { Position }
	return positionsByMarket[id] or {}
end

return MarketManager
