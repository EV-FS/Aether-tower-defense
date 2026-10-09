--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--/Modules
local Signal = require(ReplicatedStorage.Packages.Signal)
local DataConstants = require(ReplicatedStorage.Settings.Data.DataConstants)
local AFKSettings = require(ReplicatedStorage.Settings.Game.AFKSettings)

local Net = require(ReplicatedStorage.Shared.Net)
local ItemUtils = require(ReplicatedStorage.Shared.Modules.Utils.ItemUtils)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local EmojiData = require(ReplicatedStorage.Settings.Data.EmojiData)
local PurchaseData = require(ReplicatedStorage.Settings.Data.PurchaseData)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

--/Variables
local PlayerStore = ProfileStore.New("MainData_v1", DataConstants.PROFILE_TEMPLATE)
local Profiles: { [Player]: profile } = {}
local LockedPlayers: { [Player]: boolean } = {}

--/Types
type profile = typeof(PlayerStore:StartSessionAsync())
type PlayerData = typeof(DataConstants.PROFILE_TEMPLATE)
type PurchaseType = "Owned" | "Gifted" | "Token" | "Unknown"
type towerTemplate = typeof(DataConstants.TOWER_TEMPLATE)

export type DataService = {
	Init: () -> nil,
	GetProfile: (self: DataService, player: Player) -> profile?,
	GetData: (self: DataService, player: Player) -> PlayerData?,
	SaveData: (self: DataService, player: Player) -> nil,
	SaveDataAsync: (self: DataService, player: Player, timeoutSeconds: number?) -> (boolean, string?),
	ClearData: (self: DataService, player: Player) -> nil,

	Lock: (self: DataService, player: Player) -> nil,
	Unlock: (self: DataService, player: Player) -> nil,
	IsLocked: (self: DataService, player: Player) -> boolean,

	AddData: (self: DataService, player: Player, mainKey: string, amount: number, ...any) -> number?,
	UpdateData: (self: DataService, player: Player, mainKey: string, value: any, ...any) -> any?,

	CanAfford: (self: DataService, player: Player, mainKey: string, amount: boolean | number, ...any) -> boolean,

	AddTower: (self: DataService, player: Player, towerName: string, towerData: towerTemplate?) -> boolean,
	AdjustTower: (
		self: DataService,
		player: Player,
		towerName: string,
		towerKey: string,
		key: string,
		value: any
	) -> boolean,
	RemoveTower: (self: DataService, player: Player, towerName: string, towerKey: string) -> boolean,

	IsOwnGamePass: (self: DataService, player: Player, gamePassId: number | string) -> (boolean, PurchaseType?),
	AddGamePass: (
		self: DataService,
		player: Player,
		gamePassId: number | string,
		purchaseType: PurchaseType?
	) -> boolean,
	ProcessProduct: (self: DataService, player: Player, productId: number) -> Enum.ProductPurchaseDecision,

	GetChangedSignal: (self: DataService, mainKey: string) -> typeof(Signal.new()),
	FireChanged: (self: DataService, player: Player, mainKey: string, value: any) -> nil,
}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function UpdateLeaderstats(player: Player, playerData: PlayerData)
	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local level = leaderstats:FindFirstChild("Level") or Instance.new("IntValue")
	level.Name = "Level"
	level.Value = playerData.Level
	level.Parent = leaderstats

	local coins = leaderstats:FindFirstChild("Coins") or Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = playerData.Coins
	coins.Parent = leaderstats

	local gems = leaderstats:FindFirstChild("Gems") or Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = playerData.Gems
	gems.Parent = leaderstats
end

local function ExpLogic(currentLevel: number): number
	return 50 * (currentLevel + math.ceil(currentLevel / 10)) + 50
end

local function GetTowerRequiredExp(level: number): number
	return 100 * (level + 1)
end

local function ensurePath(rootTable: { [any]: any }, subKeys: { any }): ({ [any]: any }, any)
	local current = rootTable
	for i = 1, #subKeys - 1 do
		local k = subKeys[i]
		if type(current[k]) ~= "table" then
			current[k] = {}
		end
		current = current[k]
	end
	return current, subKeys[#subKeys]
end

local function patchTowerRenames(playerData: PlayerData)
	local nameMapping = {
		["Wizard Noob"] = "Wizard",
		["Glitch"] = "Hacker",
		["Batter Noob"] = "Batter Bacon",
		["Poor Noob"] = "Poor Bacon",
		["Katana Bacon"] = "Katana Noob",
		["Railgun Noob"] = "Laser Noob",
		["Boxer Noob"] = "Fighter Noob",
		["Smith Dummy"] = "Smith Noob",
		["Sworder Dummy"] = "Swordsman Dummy",
		["Rpg Noob"] = "RPG Noob",
	}

	if playerData.OwnedTowers then
		for oldName, newName in pairs(nameMapping) do
			local oldTowers = playerData.OwnedTowers[oldName]
			if oldTowers then
				playerData.OwnedTowers[newName] = playerData.OwnedTowers[newName] or {}
				for key, towerData in pairs(oldTowers) do
					playerData.OwnedTowers[newName][key] = towerData
				end
				playerData.OwnedTowers[oldName] = nil
			end
		end
	end

	if playerData.Loadout then
		for _, equippedUnit in pairs(playerData.Loadout) do
			if type(equippedUnit) == "table" and equippedUnit.Name then
				local mappedName = nameMapping[equippedUnit.Name]
				if mappedName then
					equippedUnit.Name = mappedName
				end
			end
		end
	end
end

local function patchItemInventory(playerData: PlayerData)
	playerData.Inventory = if type(playerData.Inventory) == "table" then playerData.Inventory else {}
	local rawItems = if type(playerData.Inventory.Items) == "table" then playerData.Inventory.Items else {}

	local mergedItems = {}
	for rawName, rawAmount in rawItems do
		local canonicalName = ItemUtils.GetCanonicalName(rawName)
		local amount = tonumber(rawAmount)
		if canonicalName and amount and amount > 0 then
			mergedItems[canonicalName] = (mergedItems[canonicalName] or 0) + math.floor(amount)
		end
	end

	playerData.Inventory.Items = mergedItems
end

local function patchEmoteInventory(playerData: PlayerData)
	playerData.Inventory = if type(playerData.Inventory) == "table" then playerData.Inventory else {}
	playerData.Inventory.Emotes = if type(playerData.Inventory.Emotes) == "table"
		then playerData.Inventory.Emotes
		else {}
	playerData.Inventory.Emotes["Look Out"] =
		math.max(0, math.floor(tonumber(playerData.Inventory.Emotes["Look Out"]) or 0))

	local rawLoadout = if type(playerData.EmoteLoadout) == "table" then playerData.EmoteLoadout else {}
	local cleanLoadout = {}
	local equipped = {}
	for slot = 1, 4 do
		local emoteName = rawLoadout[slot] or rawLoadout[tostring(slot)]
		if
			type(emoteName) == "string"
			and EmoteData.ByName[emoteName]
			and (tonumber(playerData.Inventory.Emotes[emoteName]) or 0) > 0
			and not equipped[emoteName]
		then
			cleanLoadout[tostring(slot)] = emoteName
			equipped[emoteName] = true
		end
	end
	playerData.EmoteLoadout = cleanLoadout
end

local function patchEmojiInventory(playerData: PlayerData)
	playerData.Inventory = if type(playerData.Inventory) == "table" then playerData.Inventory else {}
	local rawEmojis = if type(playerData.Inventory.Emojis) == "table" then playerData.Inventory.Emojis else {}
	local emojis = {}
	for emojiId in EmojiData.ByName do
		local count = tonumber(rawEmojis[emojiId]) or 0
		if count >= 0 then
			emojis[emojiId] = math.floor(count)
		end
	end
	playerData.Inventory.Emojis = emojis

	local raw = if type(playerData.EmojiLoadout) == "table" then playerData.EmojiLoadout else {}
	local clean = {}
	local used = {}
	for slot = 1, 4 do
		local emojiId = raw[slot] or raw[tostring(slot)]
		if
			type(emojiId) == "string"
			and emojis[emojiId]
			and emojis[emojiId] > 0
			and EmojiData.ByName[emojiId]
			and not used[emojiId]
		then
			clean[tostring(slot)] = emojiId
			used[emojiId] = true
		end
	end
	if not playerData._EmojiLoadoutInitialized then
		if next(clean) == nil and (emojis.Wave or 0) > 0 then
			clean["1"] = "Wave"
		end
		playerData._EmojiLoadoutInitialized = true
	end
	playerData.EmojiLoadout = clean
end

-------------------------------------------------
--// DataService
-------------------------------------------------
local DataService = {} :: DataService
DataService.KeySignals = {}

function DataService.Init() end

function DataService.Start()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(DataService._PlayerAdded, player)
	end

	Players.PlayerAdded:Connect(DataService._PlayerAdded)
	Players.PlayerRemoving:Connect(DataService._PlayerRemoving)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			DataService._PlayerRemoving(player)
		end
	end)

	Net.DataService.GetDataValue.On(function(player: Player, valueName: string)
		local playerData = DataService:GetData(player)
		if not playerData then
			warn(`{player.Name} 데이터가 아직 로드되지 않음.`)
			return nil
		end

		return playerData[valueName]
	end)

	for _, currencyName in { "Coins", "Gems", "Blossom", "Exp", "Level", "Inventory" } do
		DataService:GetChangedSignal(currencyName):Connect(function(player, value)
			Net.DataService.CurrencyChanged.Fire(player, { CurrencyName = currencyName, CurrencyValue = value })
		end)
	end

	DataService:GetChangedSignal("Quests"):Connect(function(player)
		Net.DataService.CurrencyChanged.Fire(player, { CurrencyName = "Quests", CurrencyValue = 0 })
	end)
	DataService:GetChangedSignal("MapClears"):Connect(function(player)
		Net.DataService.CurrencyChanged.Fire(player, { CurrencyName = "MapClears", CurrencyValue = 0 })
	end)

	DataService:GetChangedSignal("OwnedTowersAdded"):Connect(function(player, data)
		local towerInfo = TowerData.ByName[data.towerName]
		if not towerInfo then
			return
		end

		Net.DataService.OwnedTowersAdded.Fire(player, {
			towerIndex = towerInfo.Index,
			towerKeyId = data.towerKeyId,
			towerData = data.towerData,
		})
	end)

	DataService:GetChangedSignal("OwnedTowersRemoved"):Connect(function(player, data)
		local towerInfo = TowerData.ByName[data.towerName]
		if not towerInfo then
			return
		end

		Net.DataService.OwnedTowersRemoved.Fire(player, {
			towerIndex = towerInfo.Index,
			towerKeyId = data.towerKeyId,
		})
	end)
end

function DataService:GetProfile(player: Player): profile
	local passTime = 0
	while not Profiles[player] and passTime <= 30 do
		if player.Parent ~= Players then
			return nil
		end

		passTime += task.wait(0.1)
	end

	return Profiles[player]
end

function DataService:GetData(player: Player): PlayerData?
	local profile = DataService:GetProfile(player)
	if profile then
		return profile.Data
	end

	return nil
end

function DataService:SaveData(player: Player)
	local profile = DataService:GetProfile(player)
	if profile and profile:IsActive() then
		profile:Save()
	end
end

function DataService:SaveDataAsync(player: Player, timeoutSeconds: number?): (boolean, string?)
	local profile = DataService:GetProfile(player)
	if not profile or not profile:IsActive() then
		return false
	end

	local saveCounter = self:AddData(player, "_SaveAsyncCounter", 1)
	if not saveCounter then
		return false
	end
	profile:Save()

	local deadline = os.clock() + (timeoutSeconds or 60)
	while (profile.LastSavedData._SaveAsyncCounter or 0) < saveCounter do
		if not profile:IsActive() or os.clock() >= deadline then
			return false
		end
		task.wait(0.1)
	end
	return true
end

function DataService:ClearData(player: Player)
	local profile = self:GetProfile(player)
	if not profile or not profile:IsActive() then
		return
	end

	profile.Data = TableUtils.DeepCopy(DataConstants.PROFILE_TEMPLATE)
	profile:Save()
end

function DataService:Lock(player: Player)
	LockedPlayers[player] = true
end

function DataService:Unlock(player: Player)
	LockedPlayers[player] = nil
end

function DataService:IsLocked(player: Player): boolean
	return LockedPlayers[player] == true
end

function DataService:AddData(player: Player, mainKey: string, amount: number, ...: any): number?
	local playerData = DataService:GetData(player)
	if not playerData then
		return
	end

	assert(typeof(amount) == "number", `유효하지 않은 수량타입: {typeof(amount)}.`)
	local function check(current)
		local val = current or 0
		if val + amount < 0 then
			warn(`감산 하려는 재화의 수량이 보유 수량 보다 적음.`)
			return false
		end
		return true
	end

	local totalValue
	local subKeys = { ... }
	if mainKey == "Inventory" and subKeys[1] == "Items" then
		local canonicalName = ItemUtils.GetCanonicalName(subKeys[2])
		if not canonicalName then
			warn(`[DataService] Rejected unknown inventory item: {tostring(subKeys[2])}`)
			return nil
		end
		subKeys[2] = canonicalName
	end

	if #subKeys == 0 then
		if not check(playerData[mainKey]) then
			return
		end
		playerData[mainKey] = (playerData[mainKey] or 0) + amount
		totalValue = playerData[mainKey]
	else
		if type(playerData[mainKey]) ~= "table" then
			playerData[mainKey] = {}
		end

		local parentTable, lastKey = ensurePath(playerData[mainKey], subKeys)

		if not check(parentTable[lastKey]) then
			return
		end
		totalValue = (parentTable[lastKey] or 0) + amount
		parentTable[lastKey] = totalValue
	end

	if string.upper(mainKey) == "EXP" then
		DataService._SetLevel(player, playerData)
	end

	UpdateLeaderstats(player, playerData)
	self:FireChanged(player, mainKey, totalValue)

	return totalValue
end

function DataService:UpdateData(player: Player, mainKey: string, value: any, ...: any): any?
	local playerData = self:GetData(player)
	if not playerData then
		return
	end

	local subKeys = { ... }

	if #subKeys == 0 then
		playerData[mainKey] = value
	else
		if type(playerData[mainKey]) ~= "table" then
			playerData[mainKey] = {}
		end

		local parentTable, lastKey = ensurePath(playerData[mainKey], subKeys)
		parentTable[lastKey] = value
	end

	UpdateLeaderstats(player, playerData)
	self:FireChanged(player, mainKey, value)

	return value
end

function DataService:CanAfford(player: Player, mainKey: string, amount: boolean | number, ...: any): boolean
	if typeof(amount) ~= "boolean" and (typeof(amount) ~= "number" or not (amount >= 0 and amount < math.huge)) then
		return false
	end
	local playerData = self:GetData(player)
	if not playerData then
		return false
	end

	local subKeys = { ... }
	if mainKey == "Inventory" and subKeys[1] == "Items" then
		local canonicalName = ItemUtils.GetCanonicalName(subKeys[2])
		if not canonicalName then
			return false
		end
		subKeys[2] = canonicalName
	end

	local tradeReservations = playerData.TradeReservations
	local keyValue = playerData[mainKey]
	-- ReserveOfferAssets stores inventory categories directly under TradeReservations.
	local reservedValue = if mainKey == "Inventory"
		then tradeReservations
		else tradeReservations and tradeReservations[mainKey]
	for _, key in subKeys do
		keyValue = if typeof(keyValue) == "table" then keyValue[key] else nil
		reservedValue = if typeof(reservedValue) == "table" then reservedValue[key] else nil
	end

	if typeof(amount) == "boolean" then
		return keyValue == amount
	end
	local owned = if keyValue == nil then 0 else keyValue
	local reserved = if reservedValue == nil then 0 else reservedValue
	if typeof(owned) ~= "number" or typeof(reserved) ~= "number" then
		return false
	end
	return owned >= 0 and owned < math.huge and reserved >= 0 and reserved < math.huge and owned - reserved >= amount
end

function DataService:AddTower(player: Player, towerName: string, towerData: towerTemplate?): boolean
	local playerData = self:GetData(player)
	if not playerData then
		return false
	end

	local towerId = playerData._NextId
	local towerKey = `t_{towerId}`
	local newTower = TableUtils.DeepCopy(towerData or DataConstants.TOWER_TEMPLATE)

	self:UpdateData(player, "OwnedTowers", newTower, towerName, towerKey)
	playerData._NextId += 1

	self:FireChanged(player, "OwnedTowersAdded", {
		towerName = towerName,
		towerKeyId = towerId,
		towerData = newTower,
	})

	return true
end

function DataService:AdjustTower(player: Player, towerName: string, towerKey: string, key: string, value: any): boolean
	local playerData = self:GetData(player)
	if not playerData then
		return false
	end

	local targetTowerType = playerData.OwnedTowers[towerName]
	if not targetTowerType then
		warn(`요청한 타워 타입 "{towerName}"이 존재하지 않음.`)
		return false
	end

	local targetTower = playerData.OwnedTowers[towerName][towerKey]
	if not targetTower then
		warn(`요청한 타워 "{towerKey}"를 가지고 있지 않음.`)
		return false
	end

	local handlers = {
		Exp = function()
			if not value or typeof(value) ~= "number" then
				warn(`추가하려는 타워 경험치 값이 유효하지 않음.`)
				return
			end

			self:AddData(player, "OwnedTowers", value, towerName, towerKey, "Exp")
			local hasLevelUp = DataService._SetTowerLevel(targetTower)

			return "TowerExpChanged",
				{
					TowerName = towerName,
					TowerKey = towerKey,
					Exp = targetTower.Exp,
					Level = targetTower.Lv,
					HasLevelUp = hasLevelUp,
				}
		end,
		Trait = function()
			if not value or typeof(value) ~= "string" then
				warn(`추가하려는 타워 경험치 값이 유효하지 않음.`)
				return
			end

			self:UpdateData(player, "OwnedTowers", value, towerName, towerKey, "Trait")

			return "TowerTraitChanged", {
				TowerName = towerName,
				TowerKey = towerKey,
				Trait = value,
			}
		end,
		Shiny = function()
			if typeof(value) ~= "boolean" then
				warn(`추가하려는 타워 경험치 값이 유효하지 않음.`)
				return
			end

			self:UpdateData(player, "OwnedTowers", value, towerName, towerKey, "Shiny")

			return "TowerShinyChanged", {
				TowerName = towerName,
				TowerKey = towerKey,
				IsShiny = value,
			}
		end,
		Trading = function()
			if typeof(value) ~= "boolean" then
				warn(`추가하려는 타워 경험치 값이 유효하지 않음.`)
				return
			end

			self:UpdateData(player, "OwnedTowers", value, towerName, towerKey, "Trading")

			return "TowerTradingChanged",
				{
					TowerName = towerName,
					TowerKey = towerKey,
					IsShiny = value,
				}
		end,
	}

	local handler = handlers[key]
	if not handler then
		warn(`유효하지 않은 속성 "{key}"을 호출 함.`)
		return false
	end

	local updateKey, newValue = handler()
	if updateKey and newValue then
		self:FireChanged(player, updateKey, newValue)
	end

	return true
end

function DataService:RemoveTower(player: Player, towerName: string, towerKey: string): boolean
	local playerData = self:GetData(player)
	if not playerData then
		return false
	end

	local targetTowerType = playerData.OwnedTowers[towerName]
	if not targetTowerType then
		warn(`요청한 타워 타입 "{towerName}"이 존재하지 않음.`)
		return false
	end

	local targetTower = playerData.OwnedTowers[towerName][towerKey]
	if not targetTower then
		warn(`요청한 타워 "{towerKey}"를 가지고 있지 않음.`)
		return false
	end

	self:UpdateData(player, "OwnedTowers", nil, towerName, towerKey)

	for index, equippedTower in playerData.Loadout do
		if equippedTower.Name == towerName and equippedTower.Key == towerKey then
			self:UpdateData(player, "Loadout", nil, index)
		end
	end

	local towerKeyId = tonumber(towerKey:match("%d+$") or towerKey) or towerKey
	self:FireChanged(player, "OwnedTowersRemoved", {
		towerName = towerName,
		towerKeyId = towerKeyId,
	})

	return true
end

function DataService:IsOwnGamePass(player: Player, gamePassId: number | string): (boolean, PurchaseType?)
	local playerData = self:GetData(player)
	if not playerData then
		return false, nil
	end

	local passKey = tostring(gamePassId)
	local gamePassData = playerData.GamePasses[passKey]
	if not gamePassData then
		return false, nil
	end

	return gamePassData.Owned, gamePassData.PurchaseType
end

function DataService:AddGamePass(player: Player, gamePassId: number | string, purchaseType: PurchaseType?): boolean
	local passIdType = typeof(gamePassId)
	if passIdType ~= "number" and passIdType ~= "string" then
		warn(`요청한 게임패스 Id가 유효하지 않음.`)
		return false
	end

	local finalPurchaseType = "Unknown"
	if purchaseType and DataConstants.VALID_PURCHASE_TYPES[purchaseType] then
		finalPurchaseType = purchaseType
	end

	self:UpdateData(player, "GamePasses", { Owned = true, PurchaseType = finalPurchaseType }, tostring(gamePassId))
	return true
end

function DataService:ProcessProduct(player: Player, receiptInfo): Enum.ProductPurchaseDecision
	local playerData = self:GetData(player)
	if not playerData then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	playerData.ProcessedPurchases = playerData.ProcessedPurchases or {}
	if playerData.ProcessedPurchases[tostring(receiptInfo.PurchaseId)] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productId = receiptInfo.ProductId
	local productIdType = typeof(productId)
	if productIdType ~= "number" then
		warn(`요청한 개발자 상품 Id: {productId}가 유효하지 않음.`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local targetProduct = PurchaseData.ById[productId]
	if not targetProduct or targetProduct.Category ~= "DevProducts" then
		warn(`요청한 개발자 상품 Id: {productId}의 정보가 유효하지 않거나, 존재하지 않음.`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if
		targetProduct.MaxPurchases
		and (playerData.DevProducts[tostring(productId)] or 0) >= targetProduct.MaxPurchases
	then
		warn(
			`요청한 개발자 상품 Id: {productId}의 최대 구매 횟수 {targetProduct.MaxPurchases}를 초과함.`
		)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local targetRewards = targetProduct.Rewards
	if not targetRewards then
		warn(`요청한 개발자 상품 Id: {productId}의 보상이 유효하지 않음.`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	for _, rewardData in targetRewards do
		if rewardData.Type == "Currency" then
			self:AddData(player, rewardData.Target, rewardData.Amount)
		elseif rewardData.Type == "Tower" then
			for _ = 1, rewardData.Amount or 1 do
				self:AddTower(player, rewardData.Target)
			end
		end
	end

	self:AddData(player, "DevProducts", 1, tostring(productId))
	self:UpdateData(player, "ProcessedPurchases", os.time(), tostring(receiptInfo.PurchaseId))

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function DataService:GetChangedSignal(mainKey: string): typeof(Signal.new())
	if not self.KeySignals[mainKey] then
		self.KeySignals[mainKey] = Signal.new()
	end

	return self.KeySignals[mainKey]
end

function DataService:FireChanged(player: Player, mainKey: string, value: any)
	local signal = self.KeySignals[mainKey]
	if signal then
		signal:Fire(player, value)
	end
end

--/내부 함수
function DataService:_RollbackData(player: Player | number, timestampKST: number, isUTC: boolean?): boolean
	local targetUserId = if typeof(player) == "number" then player else player.UserId
	local key = `Player_{targetUserId}`

	local timestampUTC_MS = (isUTC and timestampKST or (timestampKST - DataConstants.KST_OFFSET)) * 1000

	local query = PlayerStore:VersionQuery(key, Enum.SortDirection.Descending, nil, timestampUTC_MS)
	local profile = query:NextAsync()

	if profile then
		profile:SetAsync()

		local rollbackTimeKST = os.date("!%Y-%m-%d %H:%M:%S", profile.KeyInfo.UpdatedTime + DataConstants.KST_OFFSET)
		print(`{targetUserId}의 데이터를 {rollbackTimeKST} (KST) 시점의 버전으로 롤백 성공.`)
		return true
	else
		local requestedKST = os.date("!%Y-%m-%d %H:%M:%S", timestampKST)
		warn(`[{targetUserId}의 {requestedKST} (KST) 시점 이전 버전을 찾을 수 없음.`)
		return false
	end
end

function DataService:_MigrateData(profile: profile)
	local playerData = profile.Data

	patchTowerRenames(playerData)
	TraitData.MigrateOwnedTowers(playerData.OwnedTowers)
	patchItemInventory(playerData)
	patchEmoteInventory(playerData)
	patchEmojiInventory(playerData)
end

function DataService._SetLevel(player: Player, playerData: PlayerData)
	local requireExp = ExpLogic(playerData.Level)
	local playerExp = playerData.Exp
	local totalLevel = 0

	while playerExp >= requireExp do
		playerExp -= requireExp
		totalLevel += 1

		requireExp = ExpLogic(playerData.Level + totalLevel)
	end

	DataService:UpdateData(player, "Exp", playerExp)
	DataService:AddData(player, "Level", totalLevel)
end

function DataService._SetTowerLevel(towerData: towerTemplate): boolean
	local maxLevel = DataConstants.MAX_TOWER_LEVEL or 30
	if towerData.Lv >= maxLevel then
		towerData.Exp = 0
		return false
	end

	local requireExp = GetTowerRequiredExp(towerData.Lv)

	local hasLevelUp = false
	while towerData.Exp >= requireExp do
		hasLevelUp = true
		towerData.Exp -= requireExp
		towerData.Lv += 1

		if towerData.Lv >= maxLevel then
			towerData.Exp = 0
			break
		end

		requireExp = GetTowerRequiredExp(towerData.Lv)
	end

	return hasLevelUp
end

function DataService._PlayerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player:IsDescendantOf(Players) == false
		end,
	})

	if not profile then
		player:Kick("Data load failed. Please rejoin(데이터 로딩에 실패했습니다. 재접속 해주세요).")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	DataService:_MigrateData(profile)

	local pendingAFK = profile.Data.AFKRewards
	if type(pendingAFK) == "table" then
		profile.Data.Coins = (tonumber(profile.Data.Coins) or 0) + math.max(tonumber(pendingAFK.Coins) or 0, 0)
		profile.Data.Gems = (tonumber(profile.Data.Gems) or 0) + math.max(tonumber(pendingAFK.Gems) or 0, 0)
		pendingAFK.Coins = 0
		pendingAFK.Gems = 0
	end

	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	if
		joinData.SourcePlaceId == AFKSettings.AFKPlaceId
		and type(teleportData) == "table"
		and teleportData.HandoffVersion == 1
	then
		profile.Data.Coins = math.max(tonumber(profile.Data.Coins) or 0, tonumber(teleportData.CoinsSnapshot) or 0)
		profile.Data.Gems = math.max(tonumber(profile.Data.Gems) or 0, tonumber(teleportData.GemsSnapshot) or 0)
	end

	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		player:Kick(
			`Profile session end. Please rejoin(프로필 세션이 만료되었습니다. 재접속 해주세요).`
		)
	end)

	if not player:IsDescendantOf(Players) then
		profile:EndSession()
		return
	end

	Profiles[player] = profile
	DataService._SetLevel(player, profile.Data)
	UpdateLeaderstats(player, profile.Data)
	print(`플레이어 {player.DisplayName}의 데이터 로딩 성공.`, profile)

	local playerData = profile.Data
	if not playerData._StarterTowerReceived then
		playerData._StarterTowerReceived = true
		DataService:AddTower(player, DataConstants.STARTER_TOWER)

		local firstKey = next(playerData.OwnedTowers[DataConstants.STARTER_TOWER])
		local isLoadoutEmpty = not next(playerData.Loadout)

		if firstKey and isLoadoutEmpty and not playerData.Loadout["1"] then
			DataService:UpdateData(player, "Loadout", { Name = DataConstants.STARTER_TOWER, Key = firstKey }, "1")
		end
	end
	DataService:FireChanged(player, "ProfileLoaded", playerData)
end

function DataService._PlayerRemoving(player: Player)
	LockedPlayers[player] = nil
	local profile = Profiles[player]
	if profile ~= nil then
		profile:EndSession()
		Profiles[player] = nil
	end
end

return DataService
