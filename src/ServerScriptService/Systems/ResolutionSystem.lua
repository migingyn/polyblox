--!strict
--[[
	ResolutionSystem.lua
	Resolution + payout math (PRD Section 4.4, 6, 11.6, 14).

	Handles all three resolution sources (Deterministic / RandomSeed / Manual)
	and the payout/liquidation math for standard (1x) and leveraged (<=5x)
	positions. All money math lives here and is PURE so it is unit-testable
	(Section 15.1/15.2).

	Payout model (pooled / parimutuel, Section 4.3)
	-----------------------------------------------
	At entry the player's margin M (SharesStaked) is deducted by TradeSystem and
	the chosen outcome's implied probability p (OddsAtEntry) is recorded.
	  * WIN  gross credit back = M + M*L*(1-p)/p   (net profit = M*L*(1-p)/p)
	  * LOSS credit back        = 0                (net loss = M, the margin)
	  * LIQUIDATED credit back  = 0                (net loss = M, the margin)
	Because a losing/liquidated position credits 0 and only M was ever deducted,
	the maximum loss is exactly the staked margin - never a negative balance
	(Section 14 acceptance criterion).

	Leverage L (1..MAX_LEVERAGE) amplifies profit and pulls the liquidation
	threshold closer to entry; it is funded entirely by M, never purchased.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Types = require(Modules:WaitForChild("Types"))

type Position = Types.Position
type Market = Types.Market

local ResolutionSystem = {}

-- ============================================================================
-- Payout math (pure)
-- ============================================================================

--- Net profit for a winning position. margin * leverage * (1-p)/p.
function ResolutionSystem.computeNetProfit(sharesStaked: number, leverage: number, oddsAtEntry: number): number
	assert(oddsAtEntry > 0 and oddsAtEntry < 1, "oddsAtEntry must be in (0,1)")
	return sharesStaked * leverage * (1 - oddsAtEntry) / oddsAtEntry
end

--- Gross Shares credited back to balance for a WINNING position (margin + profit).
function ResolutionSystem.computeWinPayout(sharesStaked: number, leverage: number, oddsAtEntry: number): number
	return sharesStaked + ResolutionSystem.computeNetProfit(sharesStaked, leverage, oddsAtEntry)
end

-- ============================================================================
-- Liquidation math (pure) - Section 11.6
-- ============================================================================

--- The implied-probability level of the chosen outcome at which a leveraged
--- position is wiped out. Derivation: mark-to-market loss = notional *
--- relativeDrop = (M*L) * (p_entry - p_now)/p_entry. Setting that equal to the
--- margin M gives p_now = p_entry * (1 - 1/L). For L = 1 this is 0 (a standard
--- position is never liquidated by odds movement, it just resolves).
function ResolutionSystem.computeLiquidationThreshold(oddsAtEntry: number, leverage: number): number
	if leverage <= 1 then
		return 0
	end
	return oddsAtEntry * (1 - 1 / leverage)
end

--- True if a position should liquidate at the current implied probability of its
--- chosen outcome. Only leveraged positions can liquidate before resolution.
function ResolutionSystem.isLiquidated(position: Position, currentProbabilityOfChosen: number): boolean
	if position.Leverage <= 1 or position.Status ~= "Open" then
		return false
	end
	local threshold = position.LiquidationThreshold
		or ResolutionSystem.computeLiquidationThreshold(position.OddsAtEntry, position.Leverage)
	return currentProbabilityOfChosen <= threshold
end

--- Current mark-to-market equity of an OPEN position, used for Net Worth
--- (Section 6.2 - "value of open positions at current odds"). Equity =
--- M * (1 + L*(p_now - p_entry)/p_entry), floored at 0 (a position can never be
--- worth less than nothing - the liquidation mechanism caps downside at margin).
function ResolutionSystem.positionEquity(position: Position, currentProbabilityOfChosen: number): number
	local p0 = position.OddsAtEntry
	local ratio = (currentProbabilityOfChosen - p0) / p0
	local equity = position.SharesStaked * (1 + position.Leverage * ratio)
	return math.max(0, equity)
end

-- ============================================================================
-- Resolution sources (Section 4.4)
-- ============================================================================

--- Generate a fresh resolution seed for a RandomSeed market. CRITICAL: this is
--- independent of any pool/staking data - it takes no market argument at all, so
--- staking volume can never influence the seed (Section 4.4, 14, 15.1).
function ResolutionSystem.generateResolutionSeed(): number
	-- Fresh, high-entropy seed. os.clock/os.time + a fresh RNG draw.
	local rng = Random.new()
	return rng:NextInteger(1, 2 ^ 31 - 1)
end

--- Pick the resolved outcome for a RandomSeed market from its seed. Uniform over
--- outcomes; PoolByOutcome is intentionally NOT referenced. Deterministic given
--- the same seed (so it is testable and auditable).
function ResolutionSystem.resolveFromSeed(outcomes: { string }, seed: number): string
	local rng = Random.new(seed)
	local index = rng:NextInteger(1, #outcomes)
	return outcomes[index]
end

--- Determine a market's resolved outcome based on its ResolutionSource.
--- opts carries the externally-supplied truth for Deterministic (game state)
--- and Manual (admin-set) markets.
export type ResolveOptions = {
	deterministicOutcome: string?, -- required for Deterministic markets
	manualOutcome: string?, -- required for Manual markets
}

function ResolutionSystem.determineOutcome(market: Market, opts: ResolveOptions): string
	if market.ResolutionSource == "RandomSeed" then
		assert(market.ResolutionSeed ~= nil, "RandomSeed market resolved before seed generated at lock")
		return ResolutionSystem.resolveFromSeed(market.Outcomes, market.ResolutionSeed :: number)
	elseif market.ResolutionSource == "Deterministic" then
		local outcome = opts.deterministicOutcome
		assert(outcome ~= nil, "Deterministic market requires a game-state outcome")
		return outcome :: string
	else -- Manual
		local outcome = opts.manualOutcome or market.ResolvedOutcome
		assert(outcome ~= nil, "Manual market requires an admin-set outcome")
		return outcome :: string
	end
end

-- ============================================================================
-- Position settlement (mutating)
-- ============================================================================

--- Settle a single position against a resolved outcome. Returns the gross Shares
--- to credit back to the player's balance (0 for a loss). Mutates the position's
--- Status and PayoutShares. Assumes the position was not already liquidated.
function ResolutionSystem.settlePosition(position: Position, resolvedOutcome: string): number
	if position.Status ~= "Open" then
		return 0 -- already liquidated or settled; no double payout
	end
	if position.Outcome == resolvedOutcome then
		local payout = ResolutionSystem.computeWinPayout(
			position.SharesStaked,
			position.Leverage,
			position.OddsAtEntry
		)
		position.Status = "Won"
		position.PayoutShares = payout
		return payout
	else
		position.Status = "Lost"
		position.PayoutShares = 0
		return 0
	end
end

--- Mark a position as liquidated (no credit). Loss is the margin already deducted.
function ResolutionSystem.liquidatePosition(position: Position)
	position.Status = "Liquidated"
	position.PayoutShares = 0
end

return ResolutionSystem
