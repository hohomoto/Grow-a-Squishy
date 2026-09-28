--!strict
-- Loads, autosaves, and releases player data.
--
-- Session locking: while a server holds a player's data it stamps
-- `lock = {jobId, time}` into the saved record and refreshes it on every
-- autosave. Another server that sees a fresh lock waits instead of loading,
-- and a server that finds its lock was taken over refuses to overwrite. This
-- prevents the classic "rejoin fast on another server" item duplication, which
-- matters a lot once trading exists.
--
-- In Studio without API access, data lives in memory only and a warning is
-- printed. Enable it under Game Settings > Security > Enable Studio Access to
-- API Services to test saving.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

type PlayerData = Types.PlayerData

local STORE_NAME = "PlayerData_v1"
local SCHEMA_VERSION = 1
local AUTOSAVE_INTERVAL = 120
-- A lock older than this belongs to a server that died without releasing it.
-- Must be comfortably longer than AUTOSAVE_INTERVAL.
local LOCK_TIMEOUT = AUTOSAVE_INTERVAL * 3
local LOAD_ATTEMPTS = 6
local LOAD_RETRY_DELAY = 5
local SAVE_ATTEMPTS = 3

local DataService = {}

-- Fires once per join after the player's data is ready.
DataService.Loaded = Signal.new() :: Signal.Signal<Player, PlayerData>

local profiles: { [Player]: PlayerData } = {}
-- UserIds whose final save is still in flight; a rejoin waits for it.
local releasing: { [number]: boolean } = {}
-- UserIds with a save running. Saves for one player run one at a time, so a
-- slow autosave can never land after the final save and re-lock the record.
local saving: { [number]: boolean } = {}
local store: DataStore? = nil

local function defaultData(): PlayerData
	return {
		version = SCHEMA_VERSION,
		coins = Economy.StartingCoins,
		seeds = table.clone(Economy.StartingSeeds),
		backpack = {},
		plants = {},
		shop = { window = -1, bought = {} },
		stats = { harvested = 0, earned = 0 },
	}
end

-- Fills in keys missing from saved data (fields added after the player last
-- played). Deliberately shallow: descending into `seeds` would hand back the
-- starting seeds to everyone who had used them up.
local function fillMissing(target: any, defaults: any)
	for key, value in defaults do
		if target[key] == nil then
			target[key] = value
		end
	end
end

local function migrate(data: PlayerData): PlayerData
	local defaults = defaultData()
	fillMissing(data, defaults)
	fillMissing(data.shop, defaults.shop)
	fillMissing(data.stats, defaults.stats)
	-- Add versioned migrations here, e.g.:
	-- if data.version < 2 then ...; data.version = 2 end
	data.version = SCHEMA_VERSION
	return data
end

local function keyFor(userId: number): string
	return "Player_" .. userId
end

local function openStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		warn("[DataService] DataStores unavailable, using in-memory data:", result)
		return
	end
	if RunService:IsStudio() then
		-- In Studio, GetDataStore can succeed while requests still fail when
		-- API access is off. Probe once so we fail loudly up front.
		local probeOk, probeErr = pcall(function()
			return result:GetAsync("__studio_probe")
		end)
		if not probeOk then
			warn("[DataService] Studio has no DataStore access, using in-memory data:", probeErr)
			return
		end
	end
	store = result
end

local function loadAsync(player: Player): PlayerData?
	local activeStore = store
	if not activeStore then
		return defaultData()
	end

	while releasing[player.UserId] do
		task.wait(0.5)
	end

	for attempt = 1, LOAD_ATTEMPTS do
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return activeStore:UpdateAsync(keyFor(player.UserId), function(old: PlayerData?)
				lockedElsewhere = false
				local data = old or defaultData()
				local lock = data.lock
				if lock and lock.jobId ~= game.JobId and os.time() - lock.time < LOCK_TIMEOUT then
					lockedElsewhere = true
					return nil
				end
				data.lock = { jobId = game.JobId, time = os.time() }
				return data
			end)
		end)

		if ok and not lockedElsewhere and result then
			local data = result :: PlayerData
			data.lock = nil
			return migrate(data)
		elseif not ok then
			warn(`[DataService] load attempt {attempt} failed for {player.UserId}:`, result)
		end

		if player.Parent ~= Players then
			return nil
		end
		task.wait(LOAD_RETRY_DELAY)
	end
	return nil
end

local function saveAsync(userId: number, data: PlayerData, release: boolean): boolean
	local activeStore = store
	if not activeStore then
		return true
	end

	while saving[userId] do
		task.wait(0.1)
	end
	saving[userId] = true

	local saved = false
	for attempt = 1, SAVE_ATTEMPTS do
		local ok, err = pcall(function()
			activeStore:UpdateAsync(keyFor(userId), function(old: PlayerData?)
				if not old or not old.lock or old.lock.jobId ~= game.JobId then
					-- Another server owns this record now; writing would
					-- overwrite newer progress.
					warn(`[DataService] lost session lock for {userId}, not saving`)
					return nil
				end
				local toSave = table.clone(data)
				toSave.lock = if release then nil else { jobId = game.JobId, time = os.time() }
				return toSave
			end)
		end)
		if ok then
			saved = true
			break
		end
		warn(`[DataService] save attempt {attempt} failed for {userId}:`, err)
		task.wait(2 ^ attempt)
	end

	saving[userId] = nil
	return saved
end

local function release(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	profiles[player] = nil
	releasing[player.UserId] = true
	saveAsync(player.UserId, data, true)
	releasing[player.UserId] = nil
end

local function onPlayerAdded(player: Player)
	local data = loadAsync(player)
	if player.Parent ~= Players then
		-- Left while loading. We may still hold the lock, so release it.
		if data and store then
			profiles[player] = data
			release(player)
		end
		return
	end
	if not data then
		player:Kick("Your squishies are still being saved on another server. Please rejoin in a minute!")
		return
	end
	profiles[player] = data
	DataService.Loaded:Fire(player, data)
end

-- Returns the live, mutable data table, or nil if not loaded yet.
function DataService.Get(player: Player): PlayerData?
	return profiles[player]
end

function DataService.Start()
	openStore()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(release)
	-- Deferred so every other service has connected to Loaded first.
	for _, player in Players:GetPlayers() do
		task.defer(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, data in profiles do
				task.spawn(saveAsync, player.UserId, data, false)
			end
		end
	end)

	game:BindToClose(function()
		for player in profiles do
			task.spawn(release, player)
		end
		-- Wait for every final save, including ones PlayerRemoving started.
		local deadline = os.clock() + 25
		while (next(profiles) ~= nil or next(releasing) ~= nil) and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
