--!strict
--[[
	PlayerDataManager.lua
	Authoritative per-player persistence (PRD Section 3, 6, 13).

	Responsibilities:
	  * Provide a correctly-shaped default PlayerData (Types.PlayerData).
	  * Load on join, cache in memory, autosave + save-on-leave, BindToClose flush.
	  * Persist Shares balance, positions, cosmetics, streaks (Section 3).

	Testability:
	  The DataStore backend is injectable via setBackend(). Unit/E2E tests swap
	  in an in-memory fake so the DataStore round-trip (Section 15.2) can be
	  exercised without a live DataStoreService.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Types = require(Modules:WaitForChild("Types"))

type PlayerData = Types.PlayerData

-- A backend is anything with get/set(key)->value. Real DataStore or a fake.
export type Backend = {
	get: (key: string) -> any,
	set: (key: string, value: any) -> (),
}

local PlayerDataManager = {}

local DATASTORE_NAME = "PolyBloxPlayerData_v1"
local KEY_PREFIX = "Player_"
local AUTOSAVE_INTERVAL = 60

local cache: { [number]: PlayerData } = {}
local backend: Backend? = nil

--- Default profile for a brand-new account. NetWorth == balance with no positions.
function PlayerDataManager.defaultData(userId: number): PlayerData
	return {
		UserId = userId,
		SharesBalance = 0, -- starter grant applied by SharesEarningSystem, once
		NetWorth = 0,
		PortfolioSlotLimit = Constants.DEFAULT_PORTFOLIO_SLOTS,
		OpenPositions = {},
		PortfolioHistory = {},
		LoginStreak = 0,
		LastLoginDay = 0,
		EarnRateMultiplier = 1.0,
		Role = "Trader",
		OwnedCosmetics = {},
		UnlockedFeatures = {},
		ReceivedStarterGrant = false,
	}
end

--- Inject a persistence backend. Call once at startup (server) or in test setup.
function PlayerDataManager.setBackend(b: Backend)
	backend = b
end

--- Default backend wrapping DataStoreService with pcall guards. Lazily built so
--- unit tests that never touch persistence don't require the service to exist.
local function realBackend(): Backend
	local DataStoreService = game:GetService("DataStoreService")
	local store = DataStoreService:GetDataStore(DATASTORE_NAME)
	return {
		get = function(key)
			local ok, result = pcall(function()
				return store:GetAsync(key)
			end)
			if not ok then
				warn("[PlayerDataManager] GetAsync failed: " .. tostring(result))
				return nil
			end
			return result
		end,
		set = function(key, value)
			local ok, err = pcall(function()
				store:SetAsync(key, value)
			end)
			if not ok then
				warn("[PlayerDataManager] SetAsync failed: " .. tostring(err))
			end
		end,
	}
end

local function getBackend(): Backend
	if not backend then
		backend = realBackend()
	end
	return backend :: Backend
end

--- Merge a loaded profile onto defaults so schema additions never nil-crash old saves.
local function reconcile(userId: number, saved: any): PlayerData
	local data = PlayerDataManager.defaultData(userId)
	if type(saved) == "table" then
		for key, value in pairs(saved) do
			(data :: any)[key] = value
		end
	end
	return data
end

--- Load (or create) a player's data into the cache. Returns the cached table.
function PlayerDataManager.load(userId: number): PlayerData
	if cache[userId] then
		return cache[userId]
	end
	local saved = getBackend().get(KEY_PREFIX .. userId)
	local data = reconcile(userId, saved)
	cache[userId] = data
	return data
end

--- Get already-loaded data (nil if not loaded). Systems use this on hot paths.
function PlayerDataManager.get(userId: number): PlayerData?
	return cache[userId]
end

--- Iterate every loaded player's data (for leaderboard / market resolution).
function PlayerDataManager.forEach(callback: (userId: number, data: PlayerData) -> ())
	for userId, data in pairs(cache) do
		callback(userId, data)
	end
end

--- Persist a single player's cached data.
function PlayerDataManager.save(userId: number)
	local data = cache[userId]
	if not data then
		return
	end
	getBackend().set(KEY_PREFIX .. userId, data)
end

--- Drop from cache after a final save (called on player leaving).
function PlayerDataManager.release(userId: number)
	PlayerDataManager.save(userId)
	cache[userId] = nil
end

--- Wire lifecycle hooks. Only meaningful on a live server; guarded so requiring
--- this module in a headless test harness doesn't spin up loops.
function PlayerDataManager.start()
	if not RunService:IsServer() then
		return
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.release(player.UserId)
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for userId in pairs(cache) do
				PlayerDataManager.save(userId)
			end
		end
	end)

	game:BindToClose(function()
		for userId in pairs(cache) do
			PlayerDataManager.save(userId)
		end
	end)
end

return PlayerDataManager
