--!strict
--[[
	TradeClient.lua (client ModuleScript)
	THE single client-side entry point for placing a trade. Every trading screen
	(Terminal 11.2, Hotkey Panel 11.5, Option Trading 11.6) calls
	TradeClient.submit() so they are provably skins over ONE system rather than
	five parallel implementations (Section 14 acceptance criterion). The server
	(TradeSystem) re-validates everything - this is just the wire call.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local TradeClient = {}

export type Order = {
	MarketId: string,
	Outcome: string,
	SharesStaked: number,
	Leverage: number?, -- optional; Option Trading screen sets >1
}

--- Fire the shared RequestTrade remote. All five screens funnel through here.
function TradeClient.submit(order: Order)
	Remotes.get("RequestTrade"):FireServer({
		MarketId = order.MarketId,
		Outcome = order.Outcome,
		SharesStaked = order.SharesStaked,
		Leverage = order.Leverage or 1,
	})
end

--- One-time Copy Trade (Section 11.7).
function TradeClient.copy(sourceUserId: number, marketId: string)
	Remotes.get("RequestCopyTrade"):FireServer(sourceUserId, marketId)
end

return TradeClient
