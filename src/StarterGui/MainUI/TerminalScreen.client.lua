--!strict
--[[
	TerminalScreen.client.lua (LocalScript) - PRD Section 11.2
	Market Board + Trade Panel merged. Dark-mode three-column layout:
	  [ markets/chart ] [ pool-weight "order book" bar ] [ execution panel ]
	Clicking a pool bar auto-populates the trade outcome (Rapid Scalper / Order
	Book Analyst latency win). Uses the SHARED TradeClient.submit call.

	-- MVP SIMPLIFICATION: the middle column is a pool-weight bar, not a literal
	-- bid/ask ladder (pooled-odds model, Section 4.3).
	-- TODO: post-MVP, real order book UI once limit orders exist.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UITheme = require(Modules:WaitForChild("UITheme"))

local Shared = script.Parent:WaitForChild("Shared")
local UIBuilder = require(Shared:WaitForChild("UIBuilder"))
local ClientStore = require(Shared:WaitForChild("ClientStore"))
local TradeClient = require(Shared:WaitForChild("TradeClient"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local selectedMarketId: string? = nil
local selectedOutcome: string? = nil

local gui, scale = UIBuilder.screenGui("TerminalScreen")
scale.Scale = 1
gui.Parent = playerGui

local root = UIBuilder.frame({ Color = UITheme.Colors.TerminalBg, Corner = false })
root.Size = UDim2.fromScale(0.9, 0.8)
root.Position = UDim2.fromScale(0.05, 0.1)
root.Parent = gui
UIBuilder.padding(root)

-- Header ---------------------------------------------------------------------
local header = UIBuilder.label({ Text = "POLYBLOX TERMINAL", Bold = true, Size = UDim2.fromScale(0.5, 0.06) })
header.Parent = root

local balanceLabel = UIBuilder.label({
	Text = "Shares: --",
	Bold = true,
	Color = UITheme.Colors.PositiveGreen,
	XAlign = Enum.TextXAlignment.Right,
	Size = UDim2.fromScale(0.5, 0.06),
	Position = UDim2.fromScale(0.5, 0),
})
balanceLabel.Parent = root

-- Trading Mastery pulsing indigo widget (subtle, non-blocking, Section 11.2) --
local mastery = UIBuilder.frame({ Color = UITheme.Colors.MasteryIndigo })
mastery.Size = UDim2.fromScale(1, 0.02)
mastery.Position = UDim2.fromScale(0, 0.08)
mastery.Parent = root
task.spawn(function()
	while mastery.Parent do
		for _, t in ipairs({ 0.2, 0.6 }) do
			mastery.BackgroundTransparency = t
			task.wait(0.8)
		end
	end
end)

-- Three columns --------------------------------------------------------------
local function column(x: number, w: number): Frame
	local f = UIBuilder.frame({ Color = UITheme.Colors.PenthouseGlass, Transparency = 0.3 })
	f.Size = UDim2.fromScale(w, 0.86)
	f.Position = UDim2.fromScale(x, 0.12)
	f.Parent = root
	UIBuilder.padding(f)
	return f
end

local marketsCol = column(0, 0.34)
local bookCol = column(0.35, 0.3)
local execCol = column(0.66, 0.34)

-- Column 1: market list ------------------------------------------------------
UIBuilder.label({ Text = "MARKETS", Bold = true, Size = UDim2.fromScale(1, 0.06) }).Parent = marketsCol
local marketList = Instance.new("ScrollingFrame")
marketList.BackgroundTransparency = 1
marketList.BorderSizePixel = 0
marketList.Size = UDim2.fromScale(1, 0.92)
marketList.Position = UDim2.fromScale(0, 0.08)
marketList.CanvasSize = UDim2.new()
marketList.AutomaticCanvasSize = Enum.AutomaticSize.Y
marketList.ScrollBarThickness = 4
marketList.Parent = marketsCol
UIBuilder.vlist(marketList, 6)

-- Column 2: pool-weight "order book" ----------------------------------------
UIBuilder.label({ Text = "POOL WEIGHT", Bold = true, Size = UDim2.fromScale(1, 0.06) }).Parent = bookCol
local bookBody = UIBuilder.frame({ Corner = false })
bookBody.BackgroundTransparency = 1
bookBody.Size = UDim2.fromScale(1, 0.92)
bookBody.Position = UDim2.fromScale(0, 0.08)
bookBody.Parent = bookCol
UIBuilder.vlist(bookBody, 6)

-- Column 3: execution panel --------------------------------------------------
UIBuilder.label({ Text = "EXECUTE", Bold = true, Size = UDim2.fromScale(1, 0.06) }).Parent = execCol
local questionLabel = UIBuilder.label({ Text = "Select a market", Size = UDim2.fromScale(1, 0.12) })
questionLabel.TextWrapped = true
questionLabel.Position = UDim2.fromScale(0, 0.08)
questionLabel.Parent = execCol

local outcomeLabel = UIBuilder.label({
	Text = "Outcome: --",
	Size = UDim2.fromScale(1, 0.06),
	Position = UDim2.fromScale(0, 0.24),
})
outcomeLabel.Parent = execCol

local stakeBox = Instance.new("TextBox")
stakeBox.PlaceholderText = "Shares to stake"
stakeBox.Text = ""
stakeBox.Font = UITheme.Font
stakeBox.TextScaled = true
stakeBox.TextColor3 = UITheme.Colors.TextPrimary
stakeBox.BackgroundColor3 = UITheme.Colors.HotkeyCharcoal
stakeBox.BorderSizePixel = 0
stakeBox.Size = UDim2.fromScale(1, 0.1)
stakeBox.Position = UDim2.fromScale(0, 0.32)
stakeBox.Parent = execCol
UIBuilder.corner(stakeBox)

local placeBtn = UIBuilder.button({ Text = "PLACE POSITION", Color = UITheme.Colors.PositiveGreen })
placeBtn.Size = UDim2.fromScale(1, 0.12)
placeBtn.Position = UDim2.fromScale(0, 0.46)
placeBtn.Parent = execCol

local statusLabel = UIBuilder.label({
	Text = "",
	Color = UITheme.Colors.TextMuted,
	Size = UDim2.fromScale(1, 0.1),
	Position = UDim2.fromScale(0, 0.6),
})
statusLabel.TextWrapped = true
statusLabel.Parent = execCol

-- Rendering ------------------------------------------------------------------
local function setOutcome(outcome: string)
	selectedOutcome = outcome
	outcomeLabel.Text = "Outcome: " .. outcome
end

local function renderBook()
	for _, child in ipairs(bookBody:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if not selectedMarketId then
		return
	end
	local market = ClientStore.getMarket(selectedMarketId)
	local odds = ClientStore.getOdds(selectedMarketId)
	if not market or not odds then
		return
	end
	for i, outcome in ipairs(market.Outcomes) do
		local p = odds[outcome] or 0
		local bar = UIBuilder.button({
			Text = ("%s   %d%%  (x%.2f)"):format(outcome, math.floor(p * 100 + 0.5), 1 / math.max(p, 0.0001)),
			Color = i == 1 and UITheme.Colors.PositiveGreen or UITheme.Colors.NegativeRed,
		})
		bar.LayoutOrder = i
		bar.Size = UDim2.new(p, 0, 0, 34) -- width encodes pool weight
		bar.AutomaticSize = Enum.AutomaticSize.None
		-- Clicking the bar auto-populates the trade outcome (Section 11.2).
		bar.MouseButton1Click:Connect(function()
			setOutcome(outcome)
		end)
		bar.Parent = bookBody
	end
end

local function selectMarket(marketId: string)
	selectedMarketId = marketId
	selectedOutcome = nil
	local market = ClientStore.getMarket(marketId)
	if market then
		questionLabel.Text = market.Question
		outcomeLabel.Text = "Outcome: --"
	end
	renderBook()
end

local function renderMarketList()
	for _, child in ipairs(marketList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i, market in ipairs(ClientStore.getMarkets()) do
		local btn = UIBuilder.button({
			Text = ("[%s] %s"):format(market.Status, market.Question),
			Color = UITheme.Colors.SyndicateSlate,
		})
		btn.LayoutOrder = i
		btn.Size = UDim2.new(1, 0, 0, 44)
		btn.TextScaled = false
		btn.TextSize = 13
		btn.TextWrapped = true
		btn.MouseButton1Click:Connect(function()
			selectMarket(market.Id)
		end)
		btn.Parent = marketList
	end
end

placeBtn.MouseButton1Click:Connect(function()
	if not selectedMarketId or not selectedOutcome then
		statusLabel.Text = "Pick a market and an outcome first."
		return
	end
	local stake = tonumber(stakeBox.Text)
	if not stake then
		statusLabel.Text = "Enter a valid stake amount."
		return
	end
	TradeClient.submit({ MarketId = selectedMarketId, Outcome = selectedOutcome, SharesStaked = math.floor(stake) })
	statusLabel.Text = "Order sent (server validates)."
end)

ClientStore.onDataChanged(function(data)
	balanceLabel.Text = ("Shares: %d  |  Net Worth: %d"):format(
		math.floor(data.SharesBalance),
		math.floor(data.NetWorth)
	)
end)

ClientStore.onMarketChanged(function(marketId)
	renderMarketList()
	if marketId == selectedMarketId then
		renderBook()
	end
end)

renderMarketList()
