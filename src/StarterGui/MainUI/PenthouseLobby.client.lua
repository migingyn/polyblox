--!strict
--[[
	PenthouseLobby.client.lua (LocalScript) - PRD Section 11.3
	Frosted-glass prestige customization screen. Browses the cosmetic catalog
	(Section 7) and drives the Robux purchase flow. Entirely cosmetic - nothing
	here touches Shares balance or odds (Section 2). Built for extensibility:
	each catalog row renders generically, so new cosmetics need no code changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UITheme = require(Modules:WaitForChild("UITheme"))
local ShopCatalog = require(Modules:WaitForChild("ShopCatalog"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local Shared = script.Parent:WaitForChild("Shared")
local UIBuilder = require(Shared:WaitForChild("UIBuilder"))
local ClientStore = require(Shared:WaitForChild("ClientStore"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = (UIBuilder.screenGui("PenthouseLobby"))
gui.Enabled = false
gui.Parent = playerGui

-- Frosted glass panel (semi-transparent slate + gold border, Section 11.3).
local root = UIBuilder.frame({ Color = UITheme.Colors.PenthouseGlass, Transparency = UITheme.Transparency.PenthouseGlass, Corner = false })
root.Size = UDim2.fromScale(0.6, 0.75)
root.Position = UDim2.fromScale(0.2, 0.125)
root.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Color = UITheme.Colors.PenthouseGold
stroke.Thickness = 2
stroke.Parent = root
UIBuilder.padding(root)

UIBuilder.label({ Text = "PENTHOUSE - COSMETICS & PRESTIGE", Bold = true, Color = UITheme.Colors.PenthouseGold, Size = UDim2.fromScale(1, 0.07) }).Parent = root

local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Size = UDim2.fromScale(1, 0.9)
list.Position = UDim2.fromScale(0, 0.09)
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 4
list.Parent = root
UIBuilder.vlist(list, 6)

local function ownsItem(itemId: string): boolean
	local data = ClientStore.getPlayerData()
	if not data then
		return false
	end
	local item = ShopCatalog.get(itemId)
	if item and item.Grant.Cosmetic then
		return data.OwnedCosmetics[item.Grant.Cosmetic] == true
	end
	return false
end

local function renderRow(item, i: number)
	local row = UIBuilder.frame({ Color = UITheme.Colors.SyndicateSlate })
	row.Size = UDim2.new(1, 0, 0, 44)
	row.LayoutOrder = i
	row.Parent = list
	UIBuilder.padding(row)

	local nameLabel = UIBuilder.label({ Text = ("%s  [%s]"):format(item.Name, item.Kind), Size = UDim2.fromScale(0.7, 1) })
	nameLabel.TextScaled = false
	nameLabel.TextSize = 14
	nameLabel.Parent = row

	local buy = UIBuilder.button({ Text = ownsItem(item.Id) and "OWNED" or "BUY", Color = UITheme.Colors.PenthouseGold, TextColor = UITheme.Colors.TerminalBg })
	buy.Size = UDim2.fromScale(0.28, 0.9)
	buy.Position = UDim2.fromScale(0.72, 0.05)
	buy.Parent = row
	buy.MouseButton1Click:Connect(function()
		-- Real Robux flow: prompt purchase; server grants on the receipt callback.
		if item.ProductId and item.ProductId > 0 then
			if item.IsGamePass then
				MarketplaceService:PromptGamePassPurchase(player, item.ProductId)
			else
				MarketplaceService:PromptProductPurchase(player, item.ProductId)
			end
		else
			-- Placeholder product id (0): use the server test-grant hook so the
			-- cosmetic flow is exercisable before real ids are wired.
			Remotes.get("RequestPurchase"):FireServer(item.Id)
		end
	end)
end

for i, item in ipairs(ShopCatalog.Items) do
	renderRow(item, i)
end

-- Re-render OWNED state when player data updates after a purchase.
ClientStore.onDataChanged(function()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, item in ipairs(ShopCatalog.Items) do
		renderRow(item, i)
	end
end)
