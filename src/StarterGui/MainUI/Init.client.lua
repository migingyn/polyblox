--!strict
--[[
	Init.client.lua (LocalScript)
	Boots the shared client state cache before any screen reads from it.
]]

local ClientStore = require(script.Parent:WaitForChild("Shared"):WaitForChild("ClientStore"))
ClientStore.start()
