--!strict
--[[
	PortfolioPanel.client.lua (LocalScript) - PRD Section 6.2 / 11.7
	Shows open positions + resolved history, plus a JSON transaction-log export
	button for the Statistical Modeler persona (reads PortfolioHistory; no new
	backend). Also surfaces Role + streak (achievement/badge data, Section 11.7).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UITheme = require(Modules:WaitForChild("UITheme"))

local Shared = script.Parent:WaitForChild("Shared")
local UIBuilder = require(Shared:WaitForChild("UIBuilder"))
local ClientStore = require(Shared:WaitForChild("ClientStore"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = (UIBuilder.screenGui("PortfolioPanel"))
gui.Enabled = false
gui.Parent = playerGui

local root = UIBuilder.frame({ Color = UITheme.Colors.TerminalBg, Corner = false })
root.Size = UDim2.fromScale(0.5, 0.75)
root.Position = UDim2.fromScale(0.25, 0.125)
root.Parent = gui
UIBuilder.padding(root)

local header = UIBuilder.label({ Text = "PORTFOLIO", Bold = true, Size = UDim2.fromScale(0.6, 0.06) })
header.Parent = root

local roleLabel = UIBuilder.label({
	Text = "Role: Trader | Streak: 0",
	Color = UITheme.Colors.MasteryIndigo,
	XAlign = Enum.TextXAlignment.Right,
	Size = UDim2.fromScale(0.4, 0.06),
	Position = UDim2.fromScale(0.6, 0),
})
roleLabel.Parent = root

local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Size = UDim2.fromScale(1, 0.8)
list.Position = UDim2.fromScale(0, 0.08)
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 4
list.Parent = root
UIBuilder.vlist(list, 4)

local exportBtn = UIBuilder.button({ Text = "EXPORT JSON LOG", Color = UITheme.Colors.SyndicateCyan, TextColor = UITheme.Colors.TerminalBg })
exportBtn.Size = UDim2.fromScale(1, 0.08)
exportBtn.Position = UDim2.fromScale(0, 0.9)
exportBtn.Parent = root

local function row(text: string, color: Color3, order: number)
	local r = UIBuilder.frame({ Color = UITheme.Colors.PenthouseGlass, Transparency = 0.3 })
	r.Size = UDim2.new(1, 0, 0, 30)
	r.LayoutOrder = order
	r.Parent = list
	UIBuilder.padding(r)
	local l = UIBuilder.label({ Text = text, Color = color, Size = UDim2.fromScale(1, 1) })
	l.TextScaled = false
	l.TextSize = 13
	l.Parent = r
end

local function render(data)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	roleLabel.Text = ("Role: %s | Streak: %d"):format(data.Role, data.LoginStreak)

	local order = 0
	order += 1
	row("-- OPEN POSITIONS --", UITheme.Colors.TextMuted, order)
	for _, pos in ipairs(data.OpenPositions) do
		order += 1
		row(("%s | %s | %d @ %d%% | %dx"):format(pos.MarketId, pos.Outcome, pos.SharesStaked, math.floor(pos.OddsAtEntry * 100 + 0.5), pos.Leverage), UITheme.Colors.TextPrimary, order)
	end

	order += 1
	row("-- HISTORY --", UITheme.Colors.TextMuted, order)
	for _, pos in ipairs(data.PortfolioHistory) do
		order += 1
		local color = pos.Status == "Won" and UITheme.Colors.PositiveGreen or UITheme.Colors.NegativeRed
		row(("%s | %s | %s | payout %d"):format(pos.MarketId, pos.Outcome, pos.Status, math.floor(pos.PayoutShares or 0)), color, order)
	end
end

exportBtn.MouseButton1Click:Connect(function()
	local data = ClientStore.getPlayerData()
	if not data then
		return
	end
	-- Valid, readable JSON of the transaction log (Section 11.7 / manual test 8).
	local json = HttpService:JSONEncode({
		UserId = data.UserId,
		OpenPositions = data.OpenPositions,
		PortfolioHistory = data.PortfolioHistory,
	})
	print("[PolyBlox] Portfolio JSON export:\n" .. json)
end)

ClientStore.onDataChanged(render)
