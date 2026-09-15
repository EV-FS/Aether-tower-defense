--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--/Modules
local DataConstants = require(script.DataConstants)
local DataSignals = require(script.DataSignals)

local Net = require(ReplicatedStorage.Shared.Net)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local PurchaseData = require(ReplicatedStorage.Settings.Data.PurchaseData)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local GlobalExistService

--/Variables
local PlayerStore = ProfileStore.New("TowerDefenseData_v1", DataConstants.PROFILE_TEMPLATE)
local Profiles: { [Player]: profile } = {}

--/Types
type profile = typeof(PlayerStore:StartSessionAsync())

type PurchaseType = "Owned" | "Gifted" | "Token" | "Unknown"
type towerTemplate = typeof(DataConstants.TOWER_TEMPLATE)

export type DataService = {
	Init: () -> nil,
	GetProfile: (self: DataService, player: Player) -> profile?,
	GetData: (self: DataService, player: Player) -> typeof(DataConstants.PROFILE_TEMPLATE)?,
	SaveData: (self: DataService, player: Player) -> nil,

	AddData: (self: DataService, player: Player, mainKey: string, amount: number, ...any) -> number?,
	UpdateData: (self: DataService, player: Player, mainKey: string, value: any, ...any) -> any?,

	AddTower: (self: DataService, player: Player, towerName: string, towerData: towerTemplate?) -> any,
	RemoveTower: (self: DataService, player: Player, towerName: string, towerKey: string) -> nil,

	IsOwnGamePass: (self: DataService, player: Player, gamePassId: number | string) -> (boolean, PurchaseType?),
	AddGamePass: (
		self: DataService,
		player: Player,
		gamePassId: number | string,
		purchaseType: PurchaseType?
	) -> boolean,
	ProcessProduct: (self: DataService, player: Player, productId: number) -> Enum.ProductPurchaseDecision,
}
-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function UpdateLeaderstats(player: Player, playerData)
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

local function IsOldData(playerData): boolean
	return playerData.Health ~= nil
		or playerData.EndlessSeason ~= nil
		or playerData.HaveUnit ~= nil
		or playerData.HaveCrate ~= nil
		or playerData.EquippedUnits ~= nil
		or playerData.QuestData ~= nil
		or playerData.LuckMultiplier ~= nil
		or playerData.LastPlayTime ~= nil
		or playerData.SignedUnits ~= nil
		or playerData.ReceivedStarterUnit ~= nil
end

local function ExpLogic(currentLevel: number)
	return 50 * (currentLevel + math.ceil(currentLevel / 10)) + 50
end

local function GetTowerRequiredExp(level)
	return 100 * (level + 1)
end

local function SetLevel(playerData)
	local requireExp = ExpLogic(playerData.Level)

	while playerData.Exp >= requireExp do
		playerData.Exp -= requireExp
		playerData.Level += 1

		requireExp = ExpLogic(playerData.Level)
	end
end

local function SetTowerLevel(towerData: towerTemplate)
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

local function patchTowerRenames(playerData)
	local nameMapping = {
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

local function reconcileCollection(playerData: PlayerData)
	if typeof(playerData.Collection) ~= "table" then
		playerData.Collection = {}
	end
	if typeof(playerData.Collection.Units) ~= "table" then
		playerData.Collection.Units = {}
	end
	if typeof(playerData.Collection.Items) ~= "table" then
		playerData.Collection.Items = {}
	end

	-- Seed the permanent discovery history for profiles created before the index.
	for towerName, towers in playerData.OwnedTowers or {} do
		if typeof(towers) == "table" and next(towers) ~= nil then
			playerData.Collection.Units[towerName] = true
		end
	end
	local items = playerData.Inventory and playerData.Inventory.Items
	if typeof(items) == "table" then
		for itemName, count in items do
			if typeof(count) == "number" and count > 0 then
				playerData.Collection.Items[itemName] = true
			end
		end
	end
end

-------------------------------------------------
--// DataService
-------------------------------------------------
local DataService = {} :: DataService

function DataService.Init(services)
	GlobalExistService = services:GetService("GlobalExistService")
end

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

	for _, currencyName in { "Coins", "Gems", "Exp", "Level" } do
		DataSignals:GetChangedSignal(currencyName):Connect(function(player, value)
			Net.DataService.CurrencyChanged.Fire(player, { CurrencyName = currencyName, CurrencyValue = value })
		end)
	end

<<<<<<< HEAD
<<<<<<< HEAD:src/lobby/ServerScriptService/Server/Services/DataService/init.luau
	DataService:GetChangedSignal("Quests"):Connect(function(player, value)
		Net.DataService.CurrencyChanged.Fire(player, { CurrencyName = "Quests", CurrencyValue = 0 })
	end)

	DataService:GetChangedSignal("Inventory"):Connect(function(player, value)
		Net.DataService.CurrencyChanged.Fire(player, {
			CurrencyName = "Inventory",
			CurrencyValue = if typeof(value) == "number" then value else 0,
		})
	end)

	DataService:GetChangedSignal("OwnedTowersAdded"):Connect(function(player, data)
=======
	DataSignals:GetChangedSignal("OwnedTowersAdded"):Connect(function(player, data)
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로):src/lobby/server/Services/DataService/init.luau
=======
	DataSignals:GetChangedSignal("OwnedTowersAdded"):Connect(function(player, data)
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
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

	DataSignals:GetChangedSignal("OwnedTowersRemoved"):Connect(function(player, data)
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
	while not Profiles[player] do
		if player.Parent ~= Players then
			return nil
		end

		task.wait(0.1)
	end

	return Profiles[player]
end

function DataService:GetData(player: Player)
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

function DataService:AddData(player: Player, mainKey: string, amount: number, ...): number?
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

		local current = playerData[mainKey]

		for i = 1, #subKeys - 1 do
			local k = subKeys[i]
			if type(current[k]) ~= "table" then
				current[k] = {}
			end
			current = current[k]
		end

		local lastKey = subKeys[#subKeys]

		if not check(current[lastKey]) then
			return
		end
		current[lastKey] = (current[lastKey] or 0) + amount
		totalValue = current[lastKey]
	end

	if string.upper(mainKey) == "EXP" then
		SetLevel(playerData)
		DataSignals:Fire(player, "Level", playerData.Level)
		totalValue = playerData.Exp
	elseif mainKey == "OwnedTowers" and string.upper(subKeys[#subKeys]) == "EXP" then
		local towerName = subKeys[1]
		local towerKey = subKeys[2]
		local towerData = playerData.OwnedTowers[towerName][towerKey]
		local hasLevelUp = SetTowerLevel(towerData)

		DataSignals:Fire(player, "TowerExpChanged", {
			TowerName = towerName,
			TowerKey = towerKey,
			Exp = towerData.Exp,
			Level = towerData.Lv,
			HasLevelUp = hasLevelUp,
		})
		return towerData.Exp
<<<<<<< HEAD
	end

	-- Discovery is monotonic: spending or trading an item never removes it from the index.
	if mainKey == "Inventory" and amount > 0 and subKeys[1] == "Items" and typeof(subKeys[2]) == "string" then
		playerData.Collection = playerData.Collection or { Units = {}, Items = {} }
		playerData.Collection.Items = playerData.Collection.Items or {}
		playerData.Collection.Items[subKeys[2]] = true
=======
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
	end

	UpdateLeaderstats(player, playerData)
	DataSignals:Fire(player, mainKey, totalValue)

	return totalValue
end

function DataService:UpdateData(player: Player, mainKey: string, value: any, ...): any?
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

		local current = playerData[mainKey]

		for i = 1, #subKeys - 1 do
			local k = subKeys[i]
			if type(current[k]) ~= "table" then
				current[k] = {}
			end
			current = current[k]
		end

		local lastKey = subKeys[#subKeys]
		current[lastKey] = value
	end

	DataSignals:Fire(player, mainKey, value)

	return value
end

function DataService:AddTower(player: Player, towerName: string, towerData: typeof(DataConstants.TOWER_TEMPLATE) | nil)
	local playerData = self:GetData(player)

	local towerId = playerData._NextId
	local towerKey = `t_{towerId}`
	local newTower = TableUtils.DeepCopy(towerData or DataConstants.TOWER_TEMPLATE)
	playerData.Collection = playerData.Collection or { Units = {}, Items = {} }
	playerData.Collection.Units = playerData.Collection.Units or {}
	playerData.Collection.Units[towerName] = true

	self:UpdateData(player, "OwnedTowers", newTower, towerName, towerKey)
	playerData._NextId += 1

	GlobalExistService:AddExistCount("Towers", towerName)

	DataSignals:Fire(player, "OwnedTowersAdded", {
		towerName = towerName,
		towerKeyId = towerId,
		towerData = newTower,
	})
end

function DataService:RemoveTower(player: Player, towerName: string, towerKey: string)
	local playerData = self:GetData(player)

	local targetTowerType = playerData.OwnedTowers[towerName]
	if not targetTowerType then
		warn(`요청한 타워 타입 "{towerName}"이 존재하지 않음.`)
		return
	end

	local targetTower = playerData.OwnedTowers[towerName][towerKey]
	if not targetTower then
		warn(`요청한 타워 "{towerKey}"를 가지고 있지 않음.`)
		return
	end

	self:UpdateData(player, "OwnedTowers", nil, towerName, towerKey)

	GlobalExistService:AddExistCount("Towers", towerName, -1)

	for index, equippedTower in playerData.Loadout do
		if equippedTower.Name == towerName and equippedTower.Key == towerKey then
			self:UpdateData(player, "Loadout", nil, index)
		end
	end

	local towerKeyId = tonumber(towerKey:match("%d+$") or towerKey) or towerKey
	DataSignals:Fire(player, "OwnedTowersRemoved", {
		towerName = towerName,
		towerKeyId = towerKeyId,
	})
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

	if targetProduct.MaxPurchases then
		if (playerData.DevProducts[tostring(productId)] or 0) >= targetProduct.MaxPurchases then
			warn(
				`요청한 개발자 상품 Id: {productId}의 최대 구매 횟수 {targetProduct.MaxPurchases}를 초과함.`
			)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
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
	playerData.ProcessedPurchases[tostring(receiptInfo.PurchaseId)] = os.time()

	local saveSuccess = pcall(function()
		self:SaveData(player)
	end)

	if not saveSuccess then
		playerData.ProcessedPurchases[tostring(receiptInfo.PurchaseId)] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
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

function DataService:_v1Tov2(playerData)
	local towerKeys = {}

	if playerData.HaveUnit then
		for towerName, amount in playerData.HaveUnit do
			playerData.OwnedTowers[towerName] = playerData.OwnedTowers[towerName] or {}

			for _ = 1, amount do
				local towerId = playerData._NextId
				local towerKey = `t_{towerId}`
				local newTower = TableUtils.DeepCopy(DataConstants.TOWER_TEMPLATE)

				playerData.OwnedTowers[towerName][towerKey] = newTower
				playerData._NextId += 1

				if type(towerKeys[towerName]) ~= "table" then
					towerKeys[towerName] = {}
				end
				table.insert(towerKeys[towerName], towerId)
			end
		end
		playerData.HaveUnit = nil
	end

	if playerData.HaveCrate then
		for crateName, amount in playerData.HaveCrate do
			playerData.Inventory.Crates[crateName] = amount
		end

		playerData.HaveCrate = nil
	end

	if playerData.EquippedUnits then
		for towerName, equipData in playerData.EquippedUnits do
			if type(equipData) == "table" and equipData.Slot then
				local keysList = towerKeys[towerName]
				local targetKeyId = keysList and table.remove(keysList, 1)
				local targetKey = targetKeyId and `t_{targetKeyId}`
				if targetKey then
					playerData.Loadout[equipData.Slot] = { Name = towerName, Key = targetKey }
				end
			end
		end

		playerData.EquippedUnits = nil
	end

	if playerData.SignedUnits then
		for towerName, signerList in playerData.SignedUnits do
			local ownedTowerMap = playerData.OwnedTowers[towerName]

			if ownedTowerMap then
				if type(signerList) == "table" then
					for _, signerName in signerList do
						local _, towerData = TableUtils.Random(ownedTowerMap)

						if towerData then
							towerData.Sign = signerName
							break
						end
					end
				else
					local _, towerData = TableUtils.Random(ownedTowerMap)

					if towerData then
						towerData.Sign = signerList
					end
				end
			end
		end

		playerData.SignedUnits = nil
	end

	playerData.EndlessSeason = nil
	playerData.LastPlayTime = nil
	playerData.Health = nil
	playerData.LuckMultiplier = nil
	playerData.Materials = nil
	playerData.QuestData = nil
	playerData.ReceivedStarterUnit = nil
end

function DataService:_MigrateData(profile, player: Player)
	local playerData = profile.Data
	local version = if IsOldData(playerData) then "v1" else "v2"

	if version == "v1" then
		self:_v1Tov2(playerData, player)
	end

	patchTowerRenames(playerData)
<<<<<<< HEAD
	reconcileCollection(playerData)
=======
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
end

function DataService._PlayerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player:IsDescendantOf(Players) == false
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		DataService:_MigrateData(profile, player)
		SetLevel(profile.Data)
		UpdateLeaderstats(player, profile.Data)

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick(
				`Profile session end. Please rejoin(프로필 세션이 만료되었습니다. 재접속 해주세요).`
			)
		end)

		if player:IsDescendantOf(Players) == true then
			Profiles[player] = profile
			print(`플레이어 {player.DisplayName}의 데이터 로딩 성공.`)
			print(profile)

			local playerData = profile.Data
			local hasFighterNoob = playerData.OwnedTowers["Fighter Noob"] ~= nil
				and next(playerData.OwnedTowers["Fighter Noob"]) ~= nil
			if not hasFighterNoob then
				DataService:AddTower(player, "Fighter Noob")
				local ownedFighterMap = playerData.OwnedTowers["Fighter Noob"]
				if ownedFighterMap then
					local firstKey = next(ownedFighterMap)
					if firstKey then
						local currentEquipped = playerData.Loadout["1"] or playerData.Loadout[1]
						if not currentEquipped then
							DataService:UpdateData(player, "Loadout", { Name = "Fighter Noob", Key = firstKey }, "1")
						end
					end
				end
			end
		else
			profile:EndSession()
		end
	else
		player:Kick(`Data load failed. Please rejoin(데이터 로딩에 실패했습니다. 재접속 해주세요).`)
	end
end

function DataService._PlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:EndSession()
		Profiles[player] = nil
	end
end

return DataService
