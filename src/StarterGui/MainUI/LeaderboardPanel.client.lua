--!strict
--[[
	LeaderboardPanel.client.lua (LocalScript) - PRD Section 6.2
	Global "Rich List" + resettable Seasonal leaderboard with a toggle. Ranks by
	Net Worth (global) / Net Worth growth (seasonal). Fed by the server's
	LeaderboardUpdate broadcast.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UITheme = require(Modules:WaitForChild("UITheme"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local Shared = script.Parent:WaitForChild("Shared")
local UIBuilder = require(Shared:WaitForChild("UIBuilder"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = (UIBuilder.screenGui("LeaderboardPanel"))
gui.Enabled = false
gui.Parent = playerGui

local root = UIBuilder.frame({ Color = UITheme.Colors.TerminalBg, Corner = false })
root.Size = UDim2.fromScale(0.35, 0.65)
root.Position = UDim2.fromScale(0.05, 0.175)
root.Parent = gui
UIBuilder.padding(root)

UIBuilder.label({ Text = "LEADERBOARD", Bold = true, Size = UDim2.fromScale(1, 0.08) }).Parent = root

local mode: "Global" | "Seasonal" = "Global"
local latest: { Global: any, Seasonal: any }? = nil

local toggle = UIBuilder.button({ Text = "Mode: Global (tap for Seasonal)", Color = UITheme.Colors.MasteryIndigo })
toggle.Size = UDim2.fromScale(1, 0.08)
toggle.Position = UDim2.fromScale(0, 0.09)
toggle.Parent = root

local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Size = UDim2.fromScale(1, 0.8)
list.Position = UDim2.fromScale(0, 0.18)
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 4
list.Parent = root
UIBuilder.vlist(list, 4)

local function render()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if not latest then
		return
	end
	local entries = mode == "Global" and latest.Global or latest.Seasonal
	for i, entry in ipairs(entries) do
		local r = UIBuilder.frame({ Color = UITheme.Colors.PenthouseGlass, Transparency = 0.3 })
		r.Size = UDim2.new(1, 0, 0, 30)
		r.LayoutOrder = i
		r.Parent = list
		UIBuilder.padding(r)
		local mine = entry.UserId == player.UserId
		local l = UIBuilder.label({
			Text = ("#%d   User %d   %s%d"):format(i, entry.UserId, mode == "Seasonal" and "Δ" or "", math.floor(entry.Value)),
			Color = mine and UITheme.Colors.PositiveGreen or UITheme.Colors.TextPrimary,
			Size = UDim2.fromScale(1, 1),
		})
		l.TextScaled = false
		l.TextSize = 14
		l.Parent = r
	end
end

toggle.MouseButton1Click:Connect(function()
	mode = mode == "Global" and "Seasonal" or "Global"
	toggle.Text = ("Mode: %s (tap to switch)"):format(mode)
	render()
end)

Remotes.get("LeaderboardUpdate").OnClientEvent:Connect(function(payload)
	latest = payload
	render()
end)
