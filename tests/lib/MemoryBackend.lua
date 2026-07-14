--!strict
-- In-memory DataStore backend for E2E tests (PRD Section 15.2 - DataStore
-- round-trip without a live DataStoreService). Deep-copies on set/get so a saved
-- snapshot is decoupled from the live table, mimicking real serialization.

local MemoryBackend = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

function MemoryBackend.new()
	local store: { [string]: any } = {}
	return {
		get = function(key: string): any
			return deepCopy(store[key])
		end,
		set = function(key: string, value: any)
			store[key] = deepCopy(value)
		end,
		_raw = store,
	}
end

return MemoryBackend
