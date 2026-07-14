--!strict
--[[
	ShopSystem.lua
	Validates and applies Robux cosmetic / QoL / analytics / social / earn-rate
	purchases (PRD Section 7), cross-checked against the NON-NEGOTIABLE rule
	(Section 2).

	HARD INVARIANT (enforced by scripts/check_monetization.sh + tests):
	  This module NEVER writes SharesBalance, PoolByOutcome, OddsAtEntry, or
	  ResolutionSeed. Buying a SKU can only:
	    * grant a cosmetic (OwnedCosmetics),
	    * raise Portfolio Slots (QoL),
	    * flip an analytics/social/QoL feature flag (UnlockedFeatures),
	    * multiply the EARNING RATE (EarnRateMultiplier) - not deposit Shares.
	  The E2E test "purchase does not change Shares balance" (Section 15.2) is the
	  most important check in the spec and is treated as required.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local ShopCatalog = require(Modules:WaitForChild("ShopCatalog"))
local Types = require(Modules:WaitForChild("Types"))

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataManager = require(ServerScriptService:WaitForChild("DataStore"):WaitForChild("PlayerDataManager"))

type PlayerData = Types.PlayerData

local ShopSystem = {}

export type PurchaseResult = {
	ok: boolean,
	error: string?,
	itemId: string?,
}

--- Apply a catalog item's grant to player data. Returns ok/error. Deliberately
--- has NO parameter and NO branch that could touch SharesBalance - the only
--- currency-adjacent field it may write is EarnRateMultiplier (a rate, not a
--- balance). Idempotent for one-time unlocks.
function ShopSystem.applyGrant(data: PlayerData, itemId: string): PurchaseResult
	local item = ShopCatalog.get(itemId)
	if not item then
		return { ok = false, error = "Unknown shop item" }
	end

	local grant = item.Grant

	if grant.Cosmetic then
		data.OwnedCosmetics[grant.Cosmetic] = true
	end

	if grant.SlotsDelta then
		data.PortfolioSlotLimit = math.min(
			Constants.MAX_PORTFOLIO_SLOTS,
			data.PortfolioSlotLimit + grant.SlotsDelta
		)
	end

	if grant.AnalyticsFlag then
		data.UnlockedFeatures[grant.AnalyticsFlag] = true
	end

	if grant.SocialFlag then
		data.UnlockedFeatures[grant.SocialFlag] = true
	end

	if grant.FastConfirm then
		data.UnlockedFeatures["FastConfirm"] = true
	end

	if grant.EarnRateMultiplier then
		-- Multiplies the earning RATE only; never grants Shares. Capped.
		data.EarnRateMultiplier = math.min(
			Constants.MAX_EARN_RATE_MULTIPLIER,
			data.EarnRateMultiplier * grant.EarnRateMultiplier
		)
	end

	return { ok = true, itemId = itemId }
end

--- Entry point for a completed Robux purchase (called from a
--- ProcessReceipt / gamepass-owned handler in Bootstrap). Looks up the loaded
--- player data and applies the grant. Does not itself perform the Robux charge.
function ShopSystem.grantPurchase(userId: number, itemId: string): PurchaseResult
	local data = PlayerDataManager.get(userId)
	if not data then
		return { ok = false, error = "Player data not loaded" }
	end
	return ShopSystem.applyGrant(data, itemId)
end

return ShopSystem
