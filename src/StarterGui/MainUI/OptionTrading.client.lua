--!strict
--[[
	OptionTrading.client.lua (LocalScript) - PRD Section 11.6
	Violet/emerald leverage/margin screen. A risk-scroll wheel sets leverage
	(MVP cap: 5x), and a readout shows live margin, potential payout and the
	liquidation threshold. Margin is ALWAYS the player's own Shares - there is no
	"leverage token" purchase (Section 2/11.6). Submits via the SHARED TradeClient.

	-- TODO: post-MVP, consider raising leverage cap once liquidation/margin math
	-- is proven stable.

	Note: the threshold/payout numbers here are DISPLAY-ONLY mirrors of the
	server formula (ResolutionSystem is server-authoritative).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UITheme = require(Modules:WaitForChild("UITheme"))
local Constants = require(Modules:WaitForChild("Constants"))

local Shared = script.Parent:WaitForChild("Shared")
local UIBuilder = require(Shared:WaitForChild("UIBuilder"))
local ClientStore = require(Shared:WaitForChild("ClientStore"))
local TradeClient = require(Shared:WaitForChild("TradeClient"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local leverage = 1
local selectedMarketId: string? = nil
local selectedOutcome: string? = nil

local gui = (UIBuilder.screenGui("OptionTrading"))
gui.Enabled = false -- toggled open by a hub button; hidden by default
gui.Parent = playerGui

local root = UIBuilder.frame({ Color = UITheme.Colors.OptionsViolet, Corner = false })
root.Size = UDim2.fromScale(0.5, 0.7)
root.Position = UDim2.fromScale(0.25, 0.15)
root.Parent = gui
UIBuilder.padding(root)

UIBuilder.label({ Text = "OPTION TRADING - LEVERAGE", Bold = true, Size = UDim2.fromScale(1, 0.08) }).Parent = root

local marketLabel = UIBuilder.label({ Text = "Market: (open one from Terminal first)", Size = UDim2.fromScale(1, 0.06), Position = UDim2.fromScale(0, 0.1) })
marketLabel.TextWrapped = true
marketLabel.Parent = root

-- Leverage "risk-scroll wheel" as 1x..5x segmented buttons -------------------
local wheel = UIBuilder.frame({ Corner = false })
wheel.BackgroundTransparency = 1
wheel.Size = UDim2.fromScale(1, 0.1)
wheel.Position = UDim2.fromScale(0, 0.2)
wheel.Parent = root
local wheelLayout = Instance.new("UIListLayout")
wheelLayout.FillDirection = Enum.FillDirection.Horizontal
wheelLayout.Padding = UDim.new(0, 6)
wheelLayout.Parent = wheel

local levLabel = UIBuilder.label({
	Text = "Leverage: 1x",
	Color = UITheme.Colors.OptionsPurpleGlow,
	Bold = true,
	Size = UDim2.fromScale(1, 0.06),
	Position = UDim2.fromScale(0, 0.32),
})
levLabel.Parent = root

local readout = UIBuilder.label({
	Text = "Margin -- | Payout -- | Liquidation --",
	Color = UITheme.Colors.OptionsEmerald,
	Size = UDim2.fromScale(1, 0.1),
	Position = UDim2.fromScale(0, 0.4),
})
readout.TextWrapped = true
readout.Parent = root

local stakeBox = Instance.new("TextBox")
stakeBox.PlaceholderText = "Margin (your Shares)"
stakeBox.Font = UITheme.Font
stakeBox.TextScaled = true
stakeBox.Text = ""
stakeBox.TextColor3 = UITheme.Colors.TextPrimary
stakeBox.BackgroundColor3 = UITheme.Colors.HotkeyCharcoal
stakeBox.BorderSizePixel = 0
stakeBox.Size = UDim2.fromScale(1, 0.1)
stakeBox.Position = UDim2.fromScale(0, 0.54)
stakeBox.Parent = root
UIBuilder.corner(stakeBox)

local submit = UIBuilder.button({ Text = "OPEN LEVERAGED POSITION", Color = UITheme.Colors.OptionsEmerald })
submit.Size = UDim2.fromScale(1, 0.12)
submit.Position = UDim2.fromScale(0, 0.68)
submit.Parent = root

local status = UIBuilder.label({ Text = "", Color = UITheme.Colors.TextMuted, Size = UDim2.fromScale(1, 0.1), Position = UDim2.fromScale(0, 0.82) })
status.TextWrapped = true
status.Parent = root

-- Live readout (display-only mirror of server math) --------------------------
local function refreshReadout()
	local stake = tonumber(stakeBox.Text) or 0
	local odds = selectedMarketId and ClientStore.getOdds(selectedMarketId)
	local p = odds and selectedOutcome and odds[selectedOutcome]
	if not p or stake <= 0 then
		readout.Text = "Margin -- | Payout -- | Liquidation --"
		return
	end
	local profit = stake * leverage * (1 - p) / p
	-- p_liq = p_entry * (1 - 1/L); for L=1 there is no liquidation.
	local liq = leverage <= 1 and 0 or p * (1 - 1 / leverage)
	readout.Text = ("Margin %d | Win payout %d | Liquidates if odds fall to %d%%"):format(
		math.floor(stake),
		math.floor(stake + profit),
		math.floor(liq * 100 + 0.5)
	)
end

for lev = 1, Constants.MAX_LEVERAGE do
	local btn = UIBuilder.button({ Text = lev .. "x", Color = UITheme.Colors.OptionsViolet })
	btn.Size = UDim2.fromScale(0.18, 1)
	btn.MouseButton1Click:Connect(function()
		leverage = lev
		levLabel.Text = "Leverage: " .. lev .. "x"
		refreshReadout()
	end)
	btn.Parent = wheel
end

stakeBox:GetPropertyChangedSignal("Text"):Connect(refreshReadout)

submit.MouseButton1Click:Connect(function()
	if not selectedMarketId or not selectedOutcome then
		status.Text = "Select a market + outcome in the Terminal, then reopen this screen."
		return
	end
	local stake = tonumber(stakeBox.Text)
	if not stake then
		status.Text = "Enter a valid margin amount."
		return
	end
	TradeClient.submit({
		MarketId = selectedMarketId,
		Outcome = selectedOutcome,
		SharesStaked = math.floor(stake),
		Leverage = leverage,
	})
	status.Text = "Leveraged order sent (server validates margin + 5x cap)."
end)

-- Public hook so a hub/Terminal can hand this screen the active selection.
local api = {}
function api.open(marketId: string, outcome: string)
	selectedMarketId = marketId
	selectedOutcome = outcome
	local market = ClientStore.getMarket(marketId)
	marketLabel.Text = "Market: " .. (market and market.Question or marketId) .. "  (" .. outcome .. ")"
	gui.Enabled = true
	refreshReadout()
end
_G.PolyBloxOptionTrading = api
