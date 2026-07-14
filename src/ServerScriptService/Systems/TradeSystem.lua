--!strict
--[[
	TradeSystem.lua
	Validates and executes position purchases (PRD Section 4.1, 6.3, 11.6, 14).

	Server-authoritative: never trusts client math (Section 3). Enforces
	  * market Open + valid outcome,
	  * stake >= MIN_STAKE and player can afford the margin,
	  * leverage in [1, MAX_LEVERAGE] (rejects the 5x-cap breach, Section 14),
	  * Portfolio Slot limit (Section 6.3) - rejects a trade over the cap.
	On success it deducts margin, records OddsAtEntry + LiquidationThreshold,
	registers the position with MarketManager (which moves the odds), and awards
	the small activity trickle (Section 6.1).

	validate() is pure (no side effects) so every rejection path is unit-testable.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local OddsCalculator = require(Modules:WaitForChild("OddsCalculator"))
local Types = require(Modules:WaitForChild("Types"))

local ServerScriptService = game:GetService("ServerScriptService")
local Systems = ServerScriptService:WaitForChild("Systems")
local MarketManager = require(Systems:WaitForChild("MarketManager"))
local ResolutionSystem = require(Systems:WaitForChild("ResolutionSystem"))
local SharesEarningSystem = require(Systems:WaitForChild("SharesEarningSystem"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("DataStore"):WaitForChild("PlayerDataManager"))

type Market = Types.Market
type Position = Types.Position
type PlayerData = Types.PlayerData

local TradeSystem = {}

export type TradeRequest = {
	MarketId: string,
	Outcome: string,
	SharesStaked: number,
	Leverage: number?, -- defaults to 1
}

export type TradeResult = {
	ok: boolean,
	error: string?,
	position: Position?,
}

local positionCounter = 0
local function nextPositionId(userId: number): string
	positionCounter += 1
	return ("pos_%d_%d"):format(userId, positionCounter)
end

--- Pure validation of a trade request against a snapshot of player + market.
--- Returns ok + error string, never mutates. `leverage` here is the resolved
--- (defaulted) leverage value.
function TradeSystem.validate(data: PlayerData, market: Market?, outcome: string, stake: number, leverage: number): (boolean, string?)
	if not market then
		return false, "Market not found"
	end
	if market.Status ~= "Open" then
		return false, "Market is not open for new positions"
	end
	if not table.find(market.Outcomes, outcome) then
		return false, "Invalid outcome for this market"
	end
	if type(stake) ~= "number" or stake ~= stake or stake < Constants.MIN_STAKE then
		return false, ("Minimum stake is %d Shares"):format(Constants.MIN_STAKE)
	end
	if math.floor(stake) ~= stake then
		return false, "Stake must be a whole number of Shares"
	end
	if type(leverage) ~= "number" or leverage < 1 or leverage > Constants.MAX_LEVERAGE then
		return false, ("Leverage must be between 1x and %dx"):format(Constants.MAX_LEVERAGE)
	end
	if math.floor(leverage) ~= leverage then
		return false, "Leverage must be a whole number"
	end
	if stake > data.SharesBalance then
		return false, "Insufficient Shares balance"
	end
	if #data.OpenPositions >= data.PortfolioSlotLimit then
		return false, ("Portfolio Slot limit reached (%d)"):format(data.PortfolioSlotLimit)
	end
	return true, nil
end

--- Execute a validated trade for a player. Returns a TradeResult.
function TradeSystem.executeTrade(userId: number, request: TradeRequest): TradeResult
	local data = PlayerDataManager.get(userId)
	if not data then
		return { ok = false, error = "Player data not loaded" }
	end

	local market = MarketManager.getMarket(request.MarketId)
	local leverage = request.Leverage or 1
	local ok, err = TradeSystem.validate(data, market, request.Outcome, request.SharesStaked, leverage)
	if not ok then
		return { ok = false, error = err }
	end
	assert(market) -- validate() guarantees non-nil past here

	-- Snapshot entry odds BEFORE this stake moves the pool.
	local oddsAtEntry = OddsCalculator.impliedProbability(market.PoolByOutcome, market.Outcomes, request.Outcome)

	local position: Position = {
		PositionId = nextPositionId(userId),
		PlayerId = userId,
		MarketId = request.MarketId,
		Outcome = request.Outcome,
		SharesStaked = request.SharesStaked,
		Leverage = leverage,
		LiquidationThreshold = ResolutionSystem.computeLiquidationThreshold(oddsAtEntry, leverage),
		OddsAtEntry = oddsAtEntry,
		Status = "Open",
		PayoutShares = nil,
	}

	-- Deduct margin (never a negative balance: validate() ensured affordability).
	data.SharesBalance -= request.SharesStaked
	table.insert(data.OpenPositions, position)

	-- Register (moves the pool/odds; may liquidate others). Shared reference.
	MarketManager.registerPosition(userId, position)

	-- Activity trickle (earn-only income, Section 6.1) + refresh Net Worth.
	SharesEarningSystem.applyTradeTrickle(data)
	MarketManager.recomputeNetWorth(userId)

	return { ok = true, position = position }
end

--- One-time Copy Trade (Section 11.7): open a position matching a source player's
--- current open position on `marketId`. NOT an auto-mirror - single action only.
function TradeSystem.copyTrade(copierUserId: number, sourceUserId: number, marketId: string): TradeResult
	local source = PlayerDataManager.get(sourceUserId)
	if not source then
		return { ok = false, error = "Source player not found" }
	end
	local template: Position? = nil
	for _, position in ipairs(source.OpenPositions) do
		if position.MarketId == marketId then
			template = position
			break
		end
	end
	if not template then
		return { ok = false, error = "Source has no open position on that market" }
	end
	return TradeSystem.executeTrade(copierUserId, {
		MarketId = marketId,
		Outcome = template.Outcome,
		SharesStaked = template.SharesStaked,
		Leverage = template.Leverage,
	})
end

return TradeSystem
