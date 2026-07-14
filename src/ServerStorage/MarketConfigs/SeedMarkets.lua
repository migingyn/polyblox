--!strict
--[[
	SeedMarkets.lua  (ServerStorage - hidden from client, Section 12)
	Ground-truth market definitions used to seed the demo. For Deterministic and
	Manual markets, the true outcome lives HERE, server-side, and is never
	replicated to the client (Section 4.4). RandomSeed markets have NO stored
	outcome - it is generated fairly at lock time.

	Fully implemented categories: ServerPulse, TrendMeta, InsiderHunch.
	Seasonal + Community are stubbed (UI-only placeholders, Section 5).
]]

export type SeedConfig = {
	Id: string,
	Category: string,
	Question: string,
	Outcomes: { string },
	Lifespan: string,
	ResolutionSource: string,
	-- Server-only ground truth (never sent to client):
	TruthOutcome: string?, -- for Deterministic (game-state) / Manual markets
}

local SeedMarkets: { SeedConfig } = {
	{
		Id = "pulse_redteam",
		Category = "ServerPulse",
		Question = "Will 60%+ of this server pick Red team next round?",
		Outcomes = { "Yes", "No" },
		Lifespan = "Fast",
		ResolutionSource = "Deterministic",
		TruthOutcome = "No", -- resolved off real game state at runtime; stub truth here
	},
	{
		Id = "hunch_ghost",
		Category = "InsiderHunch",
		Question = "Will the Server Ghost NPC appear tonight?",
		Outcomes = { "Yes", "No" },
		Lifespan = "Fast",
		ResolutionSource = "RandomSeed", -- fair seed at lock; no TruthOutcome stored
	},
	{
		Id = "trend_meta_daily",
		Category = "TrendMeta",
		Question = "Will the daily trend index close above 500 today?",
		Outcomes = { "Above", "Below" },
		Lifespan = "Medium",
		ResolutionSource = "Manual", -- admin/mod sets outcome
		TruthOutcome = "Above",
		-- TODO: post-MVP, real-world data feed integration.
	},

	-- Stubs (UI-only placeholders, no live resolution for MVP) -------------
	{
		Id = "seasonal_stub",
		Category = "Seasonal",
		Question = "[Seasonal event placeholder]",
		Outcomes = { "Yes", "No" },
		Lifespan = "Long",
		ResolutionSource = "Manual",
		TruthOutcome = "Yes",
	},
}

return SeedMarkets
