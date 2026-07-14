--!strict
--[[
	LeaderboardSystem.lua
	Global "Rich List" + resettable seasonal leaderboard (PRD Section 6.2).

	Global ranks by absolute Net Worth. Seasonal ranks by Net Worth GROWTH since
	the season baseline, so newcomers aren't permanently locked out of top ranks.
	Seasonal baselines are in-memory for MVP.
	-- TODO: post-MVP, persist seasonal baselines + schedule automatic resets.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataManager = require(ServerScriptService:WaitForChild("DataStore"):WaitForChild("PlayerDataManager"))

local LeaderboardSystem = {}

export type Entry = { UserId: number, Value: number }

local seasonBaseline: { [number]: number } = {}

--- Ensure a player has a season baseline (called on join).
function LeaderboardSystem.registerSeasonBaseline(userId: number, netWorth: number)
	if seasonBaseline[userId] == nil then
		seasonBaseline[userId] = netWorth
	end
end

--- Reset the seasonal leaderboard: everyone's growth restarts from current worth.
function LeaderboardSystem.resetSeason()
	PlayerDataManager.forEach(function(userId, data)
		seasonBaseline[userId] = data.NetWorth
	end)
end

local function sortedDescending(entries: { Entry }): { Entry }
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	return entries
end

--- Global Rich List: all loaded players by absolute Net Worth, highest first.
function LeaderboardSystem.getGlobal(limit: number?): { Entry }
	local entries: { Entry } = {}
	PlayerDataManager.forEach(function(userId, data)
		table.insert(entries, { UserId = userId, Value = data.NetWorth })
	end)
	sortedDescending(entries)
	if limit then
		local trimmed = {}
		for i = 1, math.min(limit, #entries) do
			trimmed[i] = entries[i]
		end
		return trimmed
	end
	return entries
end

--- Seasonal: rank by Net Worth growth since baseline (can be negative).
function LeaderboardSystem.getSeasonal(limit: number?): { Entry }
	local entries: { Entry } = {}
	PlayerDataManager.forEach(function(userId, data)
		local baseline = seasonBaseline[userId] or data.NetWorth
		table.insert(entries, { UserId = userId, Value = data.NetWorth - baseline })
	end)
	sortedDescending(entries)
	if limit then
		local trimmed = {}
		for i = 1, math.min(limit, #entries) do
			trimmed[i] = entries[i]
		end
		return trimmed
	end
	return entries
end

return LeaderboardSystem
