--!strict
--[[
	ShopCatalog.lua
	The complete Robux monetization catalog (PRD Section 7), cross-checked
	against the NON-NEGOTIABLE rule in Section 2.

	CONTRACT (enforced by tests + scripts/check_monetization.sh):
	  * Every entry's `kind` is one of the allowed monetization-neutral kinds
	    below. There is NO "Shares", "Stake", "Odds", or "Payout" kind.
	  * No entry grants SharesBalance, stake, or altered odds. The EarnRate kind
	    only multiplies the *earning rate*, it never deposits Shares.
	  * `grant` describes what buying the SKU does; ShopSystem applies it via a
	    handler that is statically forbidden from touching SharesBalance /
	    PoolByOutcome / OddsAtEntry / ResolutionSeed.

	Adding a SKU that violates the above should fail check_monetization.sh.
]]

export type ShopKind = "Cosmetic" | "QoL" | "Analytics" | "Social" | "EarnRate"

export type ShopItem = {
	Id: string,
	Name: string,
	Kind: ShopKind,
	-- Placeholder Roblox product/gamepass id. -- TODO: replace with real ids.
	ProductId: number,
	IsGamePass: boolean,
	-- Machine-readable effect. NEVER includes a Shares grant.
	Grant: {
		Cosmetic: string?, -- AssetRegistry name unlocked
		SlotsDelta: number?, -- extra Portfolio Slots (QoL, Section 6.3)
		AnalyticsFlag: string?, -- feature flag unlocked (chart overlay / sentiment)
		SocialFlag: string?, -- VIP lobby / event hosting / signal badge frame
		EarnRateMultiplier: number?, -- multiplies earning RATE only (Section 7)
		FastConfirm: boolean?, -- Hotkey Panel zero-delay confirm (QoL)
	},
}

local Catalog: { ShopItem } = {
	-- Cosmetics -------------------------------------------------------------
	{ Id = "desk_neon", Name = "Neon Trading Desk", Kind = "Cosmetic", ProductId = 0, IsGamePass = true, Grant = { Cosmetic = "PLACEHOLDER_Desk_Neon" } },
	{ Id = "desk_retro", Name = "Retro Ticker Desk", Kind = "Cosmetic", ProductId = 0, IsGamePass = true, Grant = { Cosmetic = "PLACEHOLDER_Desk_RetroTicker" } },
	{ Id = "desk_gold", Name = "Gold Trading Desk", Kind = "Cosmetic", ProductId = 0, IsGamePass = true, Grant = { Cosmetic = "PLACEHOLDER_Desk_Gold" } },
	{ Id = "avatar_coat", Name = "Trader Coat Outfit", Kind = "Cosmetic", ProductId = 0, IsGamePass = true, Grant = { Cosmetic = "PLACEHOLDER_Avatar_TraderCoat" } },
	{ Id = "vehicle_gold", Name = "Gold Luxury Vehicle", Kind = "Cosmetic", ProductId = 0, IsGamePass = true, Grant = { Cosmetic = "PLACEHOLDER_Vehicle_Gold" } },
	{ Id = "penthouse_glass", Name = "Glass Penthouse Panel", Kind = "Cosmetic", ProductId = 0, IsGamePass = false, Grant = { Cosmetic = "PLACEHOLDER_Penthouse_GlassPanel" } },
	{ Id = "terminal_midnight", Name = "Midnight Terminal Theme", Kind = "Cosmetic", ProductId = 0, IsGamePass = true, Grant = { Cosmetic = "PLACEHOLDER_TerminalTheme_Midnight" } },
	{ Id = "hotkey_charcoal", Name = "Charcoal Hotkey Skin", Kind = "Cosmetic", ProductId = 0, IsGamePass = true, Grant = { Cosmetic = "PLACEHOLDER_HotkeySkin_Charcoal" } },
	-- Signal Provider cosmetic badge/frame. Role itself is EARNED (Section 6.4).
	{ Id = "signal_badge", Name = "Signal Provider Badge Frame", Kind = "Cosmetic", ProductId = 0, IsGamePass = true, Grant = { Cosmetic = "PLACEHOLDER_Badge_SignalProvider" } },

	-- Analytics / QoL -------------------------------------------------------
	{ Id = "chart_overlays", Name = "Chart Overlay Pack", Kind = "Analytics", ProductId = 0, IsGamePass = true, Grant = { AnalyticsFlag = "ChartOverlays" } },
	{ Id = "sentiment_feed", Name = "Sentiment Feed Access", Kind = "Analytics", ProductId = 0, IsGamePass = true, Grant = { AnalyticsFlag = "SentimentFeed" } },
	{ Id = "slots_plus3", Name = "+3 Portfolio Slots", Kind = "QoL", ProductId = 0, IsGamePass = true, Grant = { SlotsDelta = 3 } },
	{ Id = "fast_confirm", Name = "Fast Order Confirmation", Kind = "QoL", ProductId = 0, IsGamePass = true, Grant = { FastConfirm = true } },

	-- Social / Status -------------------------------------------------------
	{ Id = "vip_lobby", Name = "VIP Lobby Room + Event Hosting", Kind = "Social", ProductId = 0, IsGamePass = true, Grant = { SocialFlag = "VIPLobby" } },

	-- Earning-rate multiplier (Section 7) - speeds earning, never grants Shares.
	{ Id = "login_booster", Name = "Login-Streak Earn Booster", Kind = "EarnRate", ProductId = 0, IsGamePass = true, Grant = { EarnRateMultiplier = 1.5 } },
}

local ShopCatalog = {}
ShopCatalog.Items = Catalog

local byId: { [string]: ShopItem } = {}
for _, item in ipairs(Catalog) do
	byId[item.Id] = item
end

function ShopCatalog.get(id: string): ShopItem?
	return byId[id]
end

return ShopCatalog
