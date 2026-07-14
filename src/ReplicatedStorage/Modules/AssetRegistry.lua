--!strict
--[[
	AssetRegistry.lua
	Single source of truth for every placeholder asset id (PRD Section 9).

	RULE: no gameplay script may contain a hardcoded `rbxassetid://`. Every
	cosmetic/NPC/decal id is looked up here by convention name so art can be
	swapped later without touching logic. The static-check gate in
	scripts/check_no_hardcoded_assets.sh enforces this repo-wide.

	All ids below are placeholder 0 ("blank/gray") on purpose - swap real ids
	in here only, never at call sites.
	-- TODO: Act 2+, replace placeholder ids with final art.
]]

local AssetRegistry = {}

-- Convention: PLACEHOLDER_<Category>_<Variant>
local ASSETS: { [string]: string } = {
	-- Trading desk skins (cosmetic, Section 7)
	PLACEHOLDER_Desk_Neon = "rbxassetid://0",
	PLACEHOLDER_Desk_RetroTicker = "rbxassetid://0",
	PLACEHOLDER_Desk_Gold = "rbxassetid://0",

	-- Avatar trader outfits
	PLACEHOLDER_Avatar_TraderCoat = "rbxassetid://0",

	-- Luxury vehicles (lobby flex)
	PLACEHOLDER_Vehicle_Gold = "rbxassetid://0",

	-- Penthouse decor
	PLACEHOLDER_Penthouse_GlassPanel = "rbxassetid://0",

	-- Terminal screen theme packs (cosmetic, visual only)
	PLACEHOLDER_TerminalTheme_Midnight = "rbxassetid://0",

	-- Hotkey panel keybind preset skins (cosmetic)
	PLACEHOLDER_HotkeySkin_Charcoal = "rbxassetid://0",

	-- Signal Provider cosmetic badge/frame (role earned; badge is cosmetic)
	PLACEHOLDER_Badge_SignalProvider = "rbxassetid://0",

	-- NPCs (basic R15 dummy + placeholder face decal)
	-- TODO: Act 2+, swap dummy for custom model.
	PLACEHOLDER_NPC_ServerGhostFace = "rbxassetid://0",
}

--- Returns the asset id for a placeholder name, or errors loudly so a typo'd
--- lookup fails fast in Studio rather than silently rendering nothing.
function AssetRegistry.get(name: string): string
	local id = ASSETS[name]
	if not id then
		error(("AssetRegistry: unknown asset '%s'"):format(tostring(name)), 2)
	end
	return id
end

--- Non-throwing variant for optional lookups.
function AssetRegistry.find(name: string): string?
	return ASSETS[name]
end

function AssetRegistry.has(name: string): boolean
	return ASSETS[name] ~= nil
end

return AssetRegistry
