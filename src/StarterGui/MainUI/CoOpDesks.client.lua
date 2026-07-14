--!strict
--[[
	CoOpDesks.client.lua (LocalScript) - PRD Section 11.4 (STUB-LEVEL for MVP)
	Syndicate hub: navy/slate + cyan, dense tabular layout showing pooled member
	Net Worth (NOT pooled stake - dividends are cosmetic/aggregate, Section 6.4).
	MVP builds the shared view table + invite flow shell.

	-- TODO: post-MVP, live tactical projection map + instant contract-matching
	-- (stretch goals, not required for acceptance, Section 11.4 / 13).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UITheme = require(Modules:WaitForChild("UITheme"))

local Shared = script.Parent:WaitForChild("Shared")
local UIBuilder = require(Shared:WaitForChild("UIBuilder"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = (UIBuilder.screenGui("CoOpDesks"))
gui.Enabled = false
gui.Parent = playerGui

local root = UIBuilder.frame({ Color = UITheme.Colors.SyndicateNavy, Corner = false })
root.Size = UDim2.fromScale(0.55, 0.7)
root.Position = UDim2.fromScale(0.225, 0.15)
root.Parent = gui
UIBuilder.padding(root)

UIBuilder.label({ Text = "SYNDICATE DESK", Bold = true, Color = UITheme.Colors.SyndicateCyan, Size = UDim2.fromScale(1, 0.08) }).Parent = root

UIBuilder.label({
	Text = "Pooled member Net Worth growth (cosmetic dividends only)",
	Color = UITheme.Colors.TextMuted,
	Size = UDim2.fromScale(1, 0.05),
	Position = UDim2.fromScale(0, 0.08),
}).Parent = root

-- Placeholder member table (stub data). -- TODO: wire live Syndicate roster.
local table_ = UIBuilder.frame({ Corner = false })
table_.BackgroundTransparency = 1
table_.Size = UDim2.fromScale(1, 0.55)
table_.Position = UDim2.fromScale(0, 0.15)
table_.Parent = root
UIBuilder.vlist(table_, 4)

local placeholderMembers = {
	{ name = "You", growth = "+0" },
	{ name = "(invite members to populate)", growth = "--" },
}
for i, member in ipairs(placeholderMembers) do
	local row = UIBuilder.frame({ Color = UITheme.Colors.SyndicateSlate })
	row.Size = UDim2.new(1, 0, 0, 32)
	row.LayoutOrder = i
	row.Parent = table_
	UIBuilder.padding(row)
	local l = UIBuilder.label({ Text = ("%s      NetWorth Δ: %s"):format(member.name, member.growth), Size = UDim2.fromScale(1, 1) })
	l.TextScaled = false
	l.TextSize = 14
	l.Parent = row
end

-- Invite flow shell ----------------------------------------------------------
local inviteBox = Instance.new("TextBox")
inviteBox.PlaceholderText = "Invite by username (stub)"
inviteBox.Font = UITheme.Font
inviteBox.TextScaled = true
inviteBox.Text = ""
inviteBox.TextColor3 = UITheme.Colors.TextPrimary
inviteBox.BackgroundColor3 = UITheme.Colors.HotkeyCharcoal
inviteBox.BorderSizePixel = 0
inviteBox.Size = UDim2.fromScale(0.7, 0.1)
inviteBox.Position = UDim2.fromScale(0, 0.75)
inviteBox.Parent = root
UIBuilder.corner(inviteBox)

local inviteBtn = UIBuilder.button({ Text = "INVITE", Color = UITheme.Colors.SyndicateCyan, TextColor = UITheme.Colors.SyndicateNavy })
inviteBtn.Size = UDim2.fromScale(0.28, 0.1)
inviteBtn.Position = UDim2.fromScale(0.72, 0.75)
inviteBtn.Parent = root
inviteBtn.MouseButton1Click:Connect(function()
	inviteBox.Text = ""
	inviteBox.PlaceholderText = "Invite sent (stub - no backend for MVP)"
end)
