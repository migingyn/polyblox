--!strict
--[[
	OddsCalculator.lua
	Pooled-odds math (PRD Section 4.3).

	-- MVP SIMPLIFICATION: pooled odds model, not a full order book.
	-- v2 candidate: limit orders / order book for Analytical Arbitrageur persona.

	Model
	-----
	The implied probability of an outcome is its share of the total staked pool.
	Each outcome pool is seeded with a small VIRTUAL_LIQUIDITY constant so that:
	  * probabilities are always strictly inside (0, 1) - never 0 or 1 exactly,
	  * the first bettor on an empty market does not receive an infinite payout,
	  * there is never a division by zero.

	This module is intentionally PURE (no Roblox services, no globals) so it is
	fully unit-testable off a live server, per Section 15.1.
]]

local OddsCalculator = {}

-- Shares-equivalent liquidity seeded into every outcome pool. Larger = odds
-- move less per stake (more "liquid" market); smaller = odds swing harder.
OddsCalculator.VIRTUAL_LIQUIDITY = 50

--- Effective pool for an outcome = real stake + virtual seed.
local function effective(pool: number?): number
	return (pool or 0) + OddsCalculator.VIRTUAL_LIQUIDITY
end

--- Sum of effective pools across all outcomes.
--- @param outcomes list of valid outcome names (defines the market's dimension)
function OddsCalculator.totalEffective(poolByOutcome: { [string]: number }, outcomes: { string }): number
	local total = 0
	for _, outcome in ipairs(outcomes) do
		total += effective(poolByOutcome[outcome])
	end
	return total
end

--- Implied probability [strictly in (0,1)] of a single outcome.
function OddsCalculator.impliedProbability(
	poolByOutcome: { [string]: number },
	outcomes: { string },
	outcome: string
): number
	local total = OddsCalculator.totalEffective(poolByOutcome, outcomes)
	return effective(poolByOutcome[outcome]) / total
end

--- Implied probabilities for every outcome. Guaranteed to sum to 1.
function OddsCalculator.impliedOdds(
	poolByOutcome: { [string]: number },
	outcomes: { string }
): { [string]: number }
	local total = OddsCalculator.totalEffective(poolByOutcome, outcomes)
	local out: { [string]: number } = {}
	for _, outcome in ipairs(outcomes) do
		out[outcome] = effective(poolByOutcome[outcome]) / total
	end
	return out
end

--- Decimal odds (gross payout multiplier per Share) for a given probability.
--- e.g. p = 0.25 -> 4.0x gross. Used by ResolutionSystem for payout math.
function OddsCalculator.toDecimalOdds(probability: number): number
	assert(probability > 0 and probability < 1, "probability must be in (0,1)")
	return 1 / probability
end

--- Pool-weight fractions for the Terminal's visual "order book" bar (11.2).
--- Uses REAL stake only (not virtual seed) so an empty market reads as empty.
function OddsCalculator.poolWeights(
	poolByOutcome: { [string]: number },
	outcomes: { string }
): { [string]: number }
	local totalReal = 0
	for _, outcome in ipairs(outcomes) do
		totalReal += poolByOutcome[outcome] or 0
	end
	local out: { [string]: number } = {}
	for _, outcome in ipairs(outcomes) do
		if totalReal <= 0 then
			out[outcome] = 1 / #outcomes -- flat bars when nothing staked yet
		else
			out[outcome] = (poolByOutcome[outcome] or 0) / totalReal
		end
	end
	return out
end

return OddsCalculator
