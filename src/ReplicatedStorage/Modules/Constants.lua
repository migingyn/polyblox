--!strict
--[[
	Constants.lua
	Shared tuning values referenced by server systems, tests, and (read-only) UI.
	Central home so balance changes happen in one place.
]]

local Constants = {}

-- Currency / earning (Section 6.1)
Constants.STARTER_GRANT = 1000 -- Shares granted exactly once on first join
Constants.DAILY_BONUS_BASE = 100 -- base daily login bonus
Constants.DAILY_STREAK_STEP = 0.1 -- +10% of base per consecutive streak day
Constants.DAILY_STREAK_MAX_MULT = 2.0 -- streak multiplier hard cap (anti-runaway)
Constants.PASSIVE_TRICKLE_PER_TRADE = 5 -- small Shares reward per placed trade (not idle)

-- Portfolio (Section 6.3)
Constants.DEFAULT_PORTFOLIO_SLOTS = 3
Constants.MAX_PORTFOLIO_SLOTS = 12 -- ceiling even with purchased expansions

-- Trading / leverage (Section 11.6)
Constants.MIN_STAKE = 10
Constants.MAX_LEVERAGE = 5 -- MVP cap.
-- TODO: post-MVP, consider raising leverage cap once liquidation/margin math is proven stable.

-- Roles (Section 6.4) - earned thresholds, never purchased.
Constants.SIGNAL_PROVIDER_NETWORTH = 25000
Constants.SIGNAL_PROVIDER_WIN_STREAK = 10 -- alternative unlock path
Constants.SYNDICATE_LEADER_NETWORTH = 100000

-- Market lifespans in seconds (Section 4.2)
Constants.LIFESPAN_SECONDS = {
	Fast = 180, -- 3 min (within the 2-5 min band)
	Medium = 86400, -- 1 day
	Long = 604800, -- 7 days
}

-- Earn-rate booster (Section 7) - speeds earning, never grants Shares directly.
Constants.MAX_EARN_RATE_MULTIPLIER = 3.0

return Constants
