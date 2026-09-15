--/Services
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Net = require(ReplicatedStorage.Shared.Net)

--/Settings
local DB_UPDATE_INTERVAL = 300
local MEM_UPDATE_INTERVAL = 10
local MSG_UPDATE_INTERVAL = 1
local REFRESH_INTERVAL = 120
local MEMORY_TTL = 86400

--/Variables
local ExistDataStore = DataStoreService:GetDataStore("GlobalExistCounter")
local ExistMemoryMap = MemoryStoreService:GetSortedMap("GlobalExistMemoryMap")

--/Caches
local dbPending = {}
local memPending = {}
local msgPending = {}
local globalCounts = {}

--/Constants
local RANDOM = Random.new()
local DATASTORE_KEY = "AllGlobalCounts"
local MESSAGING_TOPIC = "GlobalExistUpdateChannel"

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function MakeCombinedKey(category: string, itemName: string): string
	return category .. ":" .. itemName
end

local function ParseCombinedKey(combinedKey: string): (string, string)
	local split = string.split(combinedKey, ":")
	return split[1], split[2]
end

local function GetMemoryMapAll()
	local counts = {}
	local exclusiveLowerBound = nil

	while true do
		local success, items = pcall(function()
			return ExistMemoryMap:GetRangeAsync(Enum.SortDirection.Ascending, 100, exclusiveLowerBound)
		end)

		if not success or not items or #items == 0 then
			break
		end

		local lastKey = nil
		for _, item in items do
			counts[item.key] = item.value
			lastKey = item.key
		end

		if #items < 100 then
			break
		end

		exclusiveLowerBound = lastKey
	end

	return counts
end

local function SnapshotAndClear(pendingTable)
	local snapshot = {}
	local hasData = false
	for k, v in pairs(pendingTable) do
		if v ~= 0 then
			snapshot[k] = v
			pendingTable[k] -= v
			hasData = true
		end
	end
	return hasData, snapshot
end

local function AddCounts(targetTable, sourceTable)
	for k, v in pairs(sourceTable) do
		targetTable[k] = (targetTable[k] or 0) + v
	end
end
local function SetCounts(targetTable, sourceTable)
	for k, v in pairs(sourceTable) do
		targetTable[k] = v
	end
end

local function CreateLoop(interval, callback, addJitter)
	task.spawn(function()
		while true do
			local waitTime = interval
			if addJitter then
				waitTime += RANDOM:NextInteger(1, 15)
			end
			task.wait(waitTime)
			callback()
		end
	end)
end

local function FetchAllGlobalCounts()
	local counts = GetMemoryMapAll()
	if next(counts) then
		return counts
	end

	local success, data = pcall(function()
		return ExistDataStore:GetAsync(DATASTORE_KEY)
	end)

	if success and type(data) == "table" then
		for k, v in pairs(data) do
			counts[k] = v
			task.spawn(function()
				local ok, err = pcall(function()
					ExistMemoryMap:SetAsync(k, v, MEMORY_TTL)
				end)
				if not ok then
					warn(
						`ExistMemoryMap:SetAsync failed for key: "{tostring(k)}" (type: {typeof(k)}), value: {tostring(
							v
						)} (type: {typeof(v)}). Error: {err}`
					)
				end
			end)
		end
	end

	return counts
end

local function SavePendingData()
	local hasData, snapshot = SnapshotAndClear(dbPending)
	if not hasData then
		return
	end

	local success, updatedTable = pcall(function()
		return ExistDataStore:UpdateAsync(DATASTORE_KEY, function(oldTable)
			local currentTable = oldTable or {}
			AddCounts(currentTable, snapshot)
			return currentTable
		end)
	end)

	if success and type(updatedTable) == "table" then
		SetCounts(globalCounts, updatedTable)
	else
		AddCounts(dbPending, snapshot)
	end
end

local function SaveMemoryPendingData()
	local hasData, snapshot = SnapshotAndClear(memPending)
	if not hasData then
		return
	end

	for combinedKey, amount in pairs(snapshot) do
		task.spawn(function()
			local success = pcall(function()
				return ExistMemoryMap:IncrementAsync(combinedKey, amount, MEMORY_TTL)
			end)

			if not success then
				memPending[combinedKey] = (memPending[combinedKey] or 0) + amount
			end
		end)
	end
end

-------------------------------------------------
--// GlobalExistService
-------------------------------------------------
local GlobalExistService = {}

function GlobalExistService.Init() end

function GlobalExistService.Start()
	globalCounts = FetchAllGlobalCounts()

	pcall(function()
		MessagingService:SubscribeAsync(MESSAGING_TOPIC, function(message)
			local data = message.Data
			if not data or data.SenderJobId == game.JobId or not data.Updates then
				return
			end

			AddCounts(globalCounts, data.Updates)

			for combinedKey, _ in pairs(data.Updates) do
				local category, itemName = ParseCombinedKey(combinedKey)
				if category and itemName then
					Net.GlobalExistService.CountUpdated.FireAll({
						category = category,
						itemName = itemName,
						newCount = globalCounts[combinedKey] or 0,
					})
				end
			end
		end)
	end)

	Net.GlobalExistService.GetCount.On(function(_: Player, data: { category: string, itemName: string })
		return GlobalExistService:GetCount(data.category, data.itemName)
	end)

	CreateLoop(DB_UPDATE_INTERVAL, SavePendingData, true)
	CreateLoop(MEM_UPDATE_INTERVAL, SaveMemoryPendingData)
	CreateLoop(MSG_UPDATE_INTERVAL, function()
		local hasData, snapshot = SnapshotAndClear(msgPending)
		if not hasData then
			return
		end

		pcall(function()
			MessagingService:PublishAsync(MESSAGING_TOPIC, {
				SenderJobId = game.JobId,
				Updates = snapshot,
			})
		end)
	end)

	CreateLoop(REFRESH_INTERVAL, function()
		local counts = GetMemoryMapAll()
		SetCounts(globalCounts, counts)

		for combinedKey, newCount in pairs(counts) do
			local category, itemName = ParseCombinedKey(combinedKey)
			if category and itemName then
				Net.GlobalExistService.CountUpdated.FireAll({
					category = category,
					itemName = itemName,
					newCount = newCount,
				})
			end
		end
	end)

	game:BindToClose(function()
		SaveMemoryPendingData()
		SavePendingData()
	end)
end

function GlobalExistService:AddExistCount(category: string, itemName: string, amount: number?)
	local combinedKey = MakeCombinedKey(category, itemName)
	local change = amount or 1

	dbPending[combinedKey] = (dbPending[combinedKey] or 0) + change
	memPending[combinedKey] = (memPending[combinedKey] or 0) + change
	msgPending[combinedKey] = (msgPending[combinedKey] or 0) + change

	globalCounts[combinedKey] = (globalCounts[combinedKey] or 0) + change

	Net.GlobalExistService.CountUpdated.FireAll({
		category = category,
		itemName = itemName,
		newCount = globalCounts[combinedKey],
	})
end

function GlobalExistService:GetCount(category: string, itemName: string): number
	local combinedKey = MakeCombinedKey(category, itemName)
	return globalCounts[combinedKey] or 0
end

return GlobalExistService
