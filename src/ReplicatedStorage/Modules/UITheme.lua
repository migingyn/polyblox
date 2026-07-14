--!strict
--[[
	UITheme.lua
	Shared design tokens (PRD Section 11.1).
	Every screen pulls colours/typography from here - no per-screen hardcoded hex.
]]

local UITheme = {}

UITheme.Colors = {
	TerminalBg = Color3.fromHex("#0f172a"),
	PositiveGreen = Color3.fromHex("#22c55e"),
	NegativeRed = Color3.fromHex("#ef4444"),
	MasteryIndigo = Color3.fromHex("#6366f1"),
	PenthouseGlass = Color3.fromHex("#1e293b"), -- used at 85% transparency
	PenthouseGold = Color3.fromHex("#eab308"),
	SyndicateNavy = Color3.fromHex("#1e1b4b"),
	SyndicateSlate = Color3.fromHex("#334155"),
	SyndicateCyan = Color3.fromHex("#06b6d4"),
	HotkeyCharcoal = Color3.fromHex("#111827"),
	OptionsViolet = Color3.fromHex("#2e1065"),
	OptionsEmerald = Color3.fromHex("#10b981"),
	OptionsPurpleGlow = Color3.fromHex("#a855f7"),
	TextPrimary = Color3.fromHex("#f8fafc"),
	TextMuted = Color3.fromHex("#94a3b8"),
}

UITheme.Transparency = {
	PenthouseGlass = 0.85,
}

UITheme.Font = Enum.Font.GothamMedium
UITheme.FontBold = Enum.Font.GothamBold

-- Corner radius / padding tokens so screens stay visually consistent.
UITheme.CornerRadius = UDim.new(0, 8)
UITheme.Padding = UDim.new(0, 8)

return UITheme
