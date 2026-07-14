--!strict
--[[
	UIBuilder.lua (client ModuleScript)
	Small helpers for building themed GUI from Luau, so screens stay DRY and all
	pull colours/typography from UITheme (PRD Section 11.1). Every screen uses
	UIScale + UIAspectRatioConstraint-friendly Scale-based sizing (Section 11).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UITheme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UITheme"))

local UIBuilder = {}

function UIBuilder.corner(parent: Instance, radius: UDim?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UITheme.CornerRadius
	c.Parent = parent
	return c
end

function UIBuilder.padding(parent: Instance, amount: UDim?): UIPadding
	local p = Instance.new("UIPadding")
	local a = amount or UITheme.Padding
	p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight = a, a, a, a
	p.Parent = parent
	return p
end

--- Root ScreenGui with a UIScale so layouts stay resolution-independent.
function UIBuilder.screenGui(name: string): (ScreenGui, UIScale)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	return gui, scale
end

function UIBuilder.frame(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = props.Color or UITheme.Colors.TerminalBg
	f.BackgroundTransparency = props.Transparency or 0
	f.BorderSizePixel = 0
	f.Size = props.Size or UDim2.fromScale(1, 1)
	f.Position = props.Position or UDim2.fromScale(0, 0)
	if props.Corner ~= false then
		UIBuilder.corner(f)
	end
	return f
end

function UIBuilder.label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.Bold and UITheme.FontBold or UITheme.Font
	l.Text = props.Text or ""
	l.TextColor3 = props.Color or UITheme.Colors.TextPrimary
	l.TextScaled = props.Scaled ~= false
	l.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
	l.Size = props.Size or UDim2.fromScale(1, 0.1)
	l.Position = props.Position or UDim2.fromScale(0, 0)
	return l
end

function UIBuilder.button(props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = props.Color or UITheme.Colors.MasteryIndigo
	b.BorderSizePixel = 0
	b.Font = UITheme.FontBold
	b.Text = props.Text or ""
	b.TextColor3 = props.TextColor or UITheme.Colors.TextPrimary
	b.TextScaled = true
	b.Size = props.Size or UDim2.fromScale(1, 0.1)
	b.Position = props.Position or UDim2.fromScale(0, 0)
	b.AutoButtonColor = true
	UIBuilder.corner(b)
	return b
end

--- Vertical list layout helper.
function UIBuilder.vlist(parent: Instance, pad: number?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, pad or 6)
	layout.Parent = parent
	return layout
end

return UIBuilder
