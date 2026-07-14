--!strict
--[[
	ClientStore.lua (client ModuleScript)
	Single client-side cache of replicated state (player data + market pools) so
	the Terminal, Hotkey Panel, Option, Portfolio and Leaderboard screens all
	read ONE consistent source - no per-screen desync (Section 14 acceptance:
	Terminal vs Hotkey reflect identical live state).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Remotes"))
local OddsCalculator = require(Modules:WaitForChild("OddsCalculator"))
local Types = require(Modules:WaitForChild("Types"))

local ClientStore = {}

-- A PublicMarket snapshot as broadcast by MarketManager.publicMarket.
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

local playerData: Types.PlayerData? = nil
local markets: { [string]: PublicMarket } = {}

local dataListeners: { (Types.PlayerData) -> () } = {}
local marketListeners: { (string) -> () } = {}

function ClientStore.getPlayerData(): Types.PlayerData?
	return playerData
end

function ClientStore.getMarket(marketId: string): PublicMarket?
	return markets[marketId]
end

--- All known markets (unordered).
function ClientStore.getMarkets(): { PublicMarket }
	local out = {}
	for _, m in pairs(markets) do
		table.insert(out, m)
	end
	return out
end

function ClientStore.getPool(marketId: string): { [string]: number }?
	local m = markets[marketId]
	return m and m.PoolByOutcome
end

--- Implied odds for a market. Prefers the server-sent odds; falls back to a
--- local recompute (display only; the server remains authoritative).
function ClientStore.getOdds(marketId: string): { [string]: number }?
	local m = markets[marketId]
	if not m then
		return nil
	end
	if m.Odds then
		return m.Odds
	end
	return OddsCalculator.impliedOdds(m.PoolByOutcome, m.Outcomes)
end

function ClientStore.onDataChanged(fn: (Types.PlayerData) -> ())
	table.insert(dataListeners, fn)
	if playerData then
		fn(playerData)
	end
end

function ClientStore.onMarketChanged(fn: (string) -> ())
	table.insert(marketListeners, fn)
end

function ClientStore.start()
	Remotes.get("PlayerDataUpdate").OnClientEvent:Connect(function(data)
		playerData = data
		for _, fn in ipairs(dataListeners) do
			task.spawn(fn, data)
		end
	end)

	Remotes.get("MarketUpdate").OnClientEvent:Connect(function(snapshot)
		if type(snapshot) ~= "table" or not snapshot.Id then
			return
		end
		markets[snapshot.Id] = snapshot
		for _, fn in ipairs(marketListeners) do
			task.spawn(fn, snapshot.Id)
		end
	end)
end

return ClientStore
