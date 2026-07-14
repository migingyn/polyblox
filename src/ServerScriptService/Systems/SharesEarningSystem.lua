--!strict
--[[
	SharesEarningSystem.lua
	Earn-only Shares income (PRD Section 6.1). The ONLY code paths that create
	Shares: starter grant (once), daily login streak bonus, and a small
	per-trade activity trickle. There is deliberately NO Robux entry point here
	(Section 2) - ShopSystem is forbidden from calling into this to grant Shares.

	Pure calculators (computeStreak, computeDailyBonus, dayIndex) are separated
	from the mutating apply* methods so streak/cap math is unit-testable off a
	live server (Section 15.1).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Types = require(Modules:WaitForChild("Types"))

type PlayerData = Types.PlayerData

local SharesEarningSystem = {}

local SECONDS_PER_DAY = 86400

--- Whole-day index for a unix timestamp (UTC). Same day -> same index.
function SharesEarningSystem.dayIndex(timestamp: number): number
	return math.floor(timestamp / SECONDS_PER_DAY)
end

--- Streak multiplier, hard-capped so it can never runaway-compound (Section 6.1).
function SharesEarningSystem.streakMultiplier(streak: number): number
	local mult = 1 + math.max(0, streak - 1) * Constants.DAILY_STREAK_STEP
	return math.min(mult, Constants.DAILY_STREAK_MAX_MULT)
end

--- Given the previous streak and whether the login is consecutive, return the
--- new streak value. Non-consecutive resets to 1 (a fresh streak day).
function SharesEarningSystem.computeStreak(prevStreak: number, consecutive: boolean): number
	if consecutive then
		return prevStreak + 1
	end
	return 1
end

--- Daily bonus amount for a given streak + earn-rate multiplier. Pure.
function SharesEarningSystem.computeDailyBonus(streak: number, earnRateMultiplier: number): number
	local amount = Constants.DAILY_BONUS_BASE
		* SharesEarningSystem.streakMultiplier(streak)
		* earnRateMultiplier
	return math.floor(amount + 0.5)
end

--- Apply the one-time starter grant. Returns granted amount (0 if already given).
--- Idempotent: guarded by ReceivedStarterGrant so it is exactly-once per account.
function SharesEarningSystem.applyStarterGrant(data: PlayerData): number
	if data.ReceivedStarterGrant then
		return 0
	end
	data.ReceivedStarterGrant = true
	data.SharesBalance += Constants.STARTER_GRANT
	return Constants.STARTER_GRANT
end

--- Apply the daily login bonus if not already claimed today. Returns granted
--- amount (0 if the player already claimed today). Updates streak + LastLoginDay.
function SharesEarningSystem.applyDailyLogin(data: PlayerData, now: number): number
	local today = SharesEarningSystem.dayIndex(now)
	if data.LastLoginDay == today then
		return 0 -- already claimed this calendar day
	end

	local consecutive = data.LastLoginDay == today - 1
	data.LoginStreak = SharesEarningSystem.computeStreak(data.LoginStreak, consecutive)
	data.LastLoginDay = today

	local bonus = SharesEarningSystem.computeDailyBonus(data.LoginStreak, data.EarnRateMultiplier)
	data.SharesBalance += bonus
	return bonus
end

--- Small activity reward for placing a trade (Section 6.1 - activity, not idle).
function SharesEarningSystem.applyTradeTrickle(data: PlayerData): number
	local amount = math.floor(Constants.PASSIVE_TRICKLE_PER_TRADE * data.EarnRateMultiplier + 0.5)
	data.SharesBalance += amount
	return amount
end

return SharesEarningSystem
