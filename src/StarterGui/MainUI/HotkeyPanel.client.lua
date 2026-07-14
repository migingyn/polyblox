--!strict
--[[
	HotkeyPanel.client.lua (LocalScript) - PRD Section 11.5
	Ultra-compact, zero-animation-delay Trade Panel for the Rapid/Quick Scalper.
	Rebindable keys, no separate server logic - it calls the SAME shared
	TradeClient.submit as the Terminal (Section 14 acceptance: one system, many
	skins). Reads the SAME ClientStore, so it can never desync from the Terminal.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UITheme = require(Modules:WaitForChild("UITheme"))

local Shared = script.Parent:WaitForChild("Shared")
local UIBuilder = require(Shared:WaitForChild("UIBuilder"))
local ClientStore = require(Shared:WaitForChild("ClientStore"))
local TradeClient = require(Shared:WaitForChild("TradeClient"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Rebindable keybinds (cosmetic preset skins layer on top; Section 7 note).
local keybinds = {
	OutcomeA = Enum.KeyCode.Q,
	OutcomeB = Enum.KeyCode.E,
	Fire = Enum.KeyCode.F,
}
local presetStake = 100

local gui = (UIBuilder.screenGui("HotkeyPanel"))
gui.Parent = playerGui

local root = UIBuilder.frame({ Color = UITheme.Colors.HotkeyCharcoal })
root.Size = UDim2.fromScale(0.22, 0.14)
root.Position = UDim2.fromScale(0.76, 0.82)
root.Parent = gui
UIBuilder.padding(root)

local title = UIBuilder.label({ Text = "SCALPER", Bold = true, Size = UDim2.fromScale(1, 0.25) })
title.Parent = root

local info = UIBuilder.label({ Text = "No open market", Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.25) })
info.TextWrapped = true
info.Parent = root

local hint = UIBuilder.label({
	Text = "Q/E = side  |  F = fire (100)",
	Color = UITheme.Colors.TextMuted,
	Size = UDim2.fromScale(1, 0.3),
	Position = UDim2.fromScale(0, 0.68),
})
hint.Parent = root

-- Always target the first currently-Open market (live from ClientStore).
local function activeMarket()
	for _, m in ipairs(ClientStore.getMarkets()) do
		if m.Status == "Open" then
			return m
		end
	end
	return nil
end

local selectedOutcomeIndex = 1

local function refresh()
	local m = activeMarket()
	if not m then
		info.Text = "No open market"
		return
	end
	local outcome = m.Outcomes[selectedOutcomeIndex] or m.Outcomes[1]
	local odds = ClientStore.getOdds(m.Id)
	local p = odds and outcome and odds[outcome] or 0
	info.Text = ("%s\n%s @ %d%%"):format(m.Question, outcome, math.floor(p * 100 + 0.5))
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local m = activeMarket()
	if not m then
		return
	end
	if input.KeyCode == keybinds.OutcomeA then
		selectedOutcomeIndex = 1
		refresh()
	elseif input.KeyCode == keybinds.OutcomeB then
		selectedOutcomeIndex = math.min(2, #m.Outcomes)
		refresh()
	elseif input.KeyCode == keybinds.Fire then
		local outcome = m.Outcomes[selectedOutcomeIndex] or m.Outcomes[1]
		TradeClient.submit({ MarketId = m.Id, Outcome = outcome, SharesStaked = presetStake })
		hint.Text = ("Fired %d on %s"):format(presetStake, outcome)
	end
end)

ClientStore.onMarketChanged(function()
	refresh()
end)
refresh()
