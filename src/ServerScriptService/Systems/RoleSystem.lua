--!strict
--[[
	RoleSystem.lua
	Earned role unlocks (PRD Section 6.4). Signal Provider and Syndicate Leader
	are unlocked ONLY by hitting an earned Net Worth / win-streak threshold -
	never by a Robux purchase (Robux may buy the cosmetic badge frame, not the
	role). ShopSystem never calls this.

	qualifiesForSignalProvider / qualifiesForSyndicateLeader are pure so the
	boundary tests (threshold-1, threshold, threshold+1) in Section 15.1 can run
	off a live server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Types = require(Modules:WaitForChild("Types"))

type PlayerData = Types.PlayerData

local RoleSystem = {}

--- Signal Provider: Net Worth threshold OR win-streak threshold (Section 6.4).
function RoleSystem.qualifiesForSignalProvider(netWorth: number, winStreak: number): boolean
	return netWorth >= Constants.SIGNAL_PROVIDER_NETWORTH
		or winStreak >= Constants.SIGNAL_PROVIDER_WIN_STREAK
end

--- Syndicate Leader: higher Net Worth threshold (Section 6.4).
function RoleSystem.qualifiesForSyndicateLeader(netWorth: number): boolean
	return netWorth >= Constants.SYNDICATE_LEADER_NETWORTH
end

--- Promote a player if newly qualified. Roles never downgrade automatically
--- (losing Net Worth doesn't strip an earned status). Returns the new role if
--- it changed, else nil. winStreak is the player's current consecutive wins.
function RoleSystem.evaluate(data: PlayerData, winStreak: number): Types.Role?
	-- Highest earned role wins; only ever promote.
	if data.Role ~= "SyndicateLeader" and RoleSystem.qualifiesForSyndicateLeader(data.NetWorth) then
		data.Role = "SyndicateLeader"
		return "SyndicateLeader"
	end

	if data.Role == "Trader" and RoleSystem.qualifiesForSignalProvider(data.NetWorth, winStreak) then
		data.Role = "SignalProvider"
		return "SignalProvider"
	end

	return nil
end

return RoleSystem
