--!strict
--[[
	Remotes.lua
	Thin accessor for the RemoteEvents defined in the Rojo project tree
	(ReplicatedStorage/RemoteEvents/*). Central lookup so no script hardcodes
	WaitForChild chains and typos surface immediately.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = ReplicatedStorage:WaitForChild("RemoteEvents")

--- Returns a RemoteEvent by name, waiting for replication on the client.
function Remotes.get(name: string): RemoteEvent
	local remote = folder:WaitForChild(name, 10)
	if not remote or not remote:IsA("RemoteEvent") then
		error(("Remotes: RemoteEvent '%s' not found"):format(name), 2)
	end
	return remote :: RemoteEvent
end

return Remotes
