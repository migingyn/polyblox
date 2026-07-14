--!strict
--[[
	Types.lua
	Shared type definitions for PolyBlox (PRD Section 10 - Data Model).

	These types are the single source of truth for the shape of Markets,
	Positions and PlayerData across both server systems and client UI.
	Keeping them here means the server (authoritative) and client (display)
	agree on structure without duplicating field lists.
]]

export type MarketCategory = "ServerPulse" | "TrendMeta" | "InsiderHunch" | "Seasonal" | "Community"
export type Lifespan = "Fast" | "Medium" | "Long"
export type MarketStatus = "Open" | "Locked" | "Resolved"
export type ResolutionSource = "Deterministic" | "RandomSeed" | "Manual"
export type PositionStatus = "Open" | "Won" | "Lost" | "Liquidated"
export type Role = "Trader" | "SignalProvider" | "SyndicateLeader"

export type Market = {
	Id: string,
	Category: MarketCategory,
	Question: string,
	Outcomes: { string },
	Lifespan: Lifespan,
	Status: MarketStatus,
	PoolByOutcome: { [string]: number }, -- total Shares staked per outcome, drives odds
	ResolutionSource: ResolutionSource,
	ResolutionSeed: number?, -- only for RandomSeed markets, generated at lock time
	ResolvedOutcome: string?,
	OpenTime: number,
	LockTime: number,
}

export type Position = {
	PositionId: string,
	PlayerId: number,
	MarketId: string,
	Outcome: string,
	SharesStaked: number, -- player's own Shares committed as margin
	Leverage: number, -- 1x (standard) to 5x (MVP cap), never purchased
	LiquidationThreshold: number?, -- only set when Leverage > 1
	OddsAtEntry: number, -- implied probability [0,1] of the chosen outcome at entry
	Status: PositionStatus,
	PayoutShares: number?, -- populated once resolved (0 for Lost/Liquidated)
}

export type PlayerData = {
	UserId: number,
	SharesBalance: number,
	NetWorth: number,
	PortfolioSlotLimit: number, -- default 3, Robux-purchasable increase
	OpenPositions: { Position },
	PortfolioHistory: { Position }, -- resolved positions, for profile/flex display
	LoginStreak: number,
	LastLoginDay: number, -- os.time day-index of last claimed daily bonus
	EarnRateMultiplier: number, -- login-streak booster (Section 7); 1.0 = base rate
	Role: Role,
	OwnedCosmetics: { [string]: boolean },
	-- Non-cosmetic Robux unlocks: analytics/social/QoL feature flags (Section 7).
	-- Never includes anything that grants Shares/stake/odds.
	UnlockedFeatures: { [string]: boolean },
	ReceivedStarterGrant: boolean, -- starter grant is exactly-once per account (15.1)
}

return {}
