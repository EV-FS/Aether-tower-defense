--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--/Modules
local Signal = require(ReplicatedStorage.Packages.Signal)
local DataConstants = require(ReplicatedStorage.Settings.Data.DataConstants)

local Net = require(ReplicatedStorage.Shared.Net)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local PurchaseData = require(ReplicatedStorage.Settings.Data.PurchaseData)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

--/Variables
local PlayerStore = ProfileStore.New("TowerDefenseData_v1", DataConstants.PROFILE_TEMPLATE)
local Profiles: { [Player]: profile } = {}

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
	ClearData: (self: DataService, player: Player) -> nil,

	AddData: (self: DataService, player: Player, mainKey: string, amount: number, ...any) -> number?,
	UpdateData: (self: DataService, player: Player, mainKey: string, value: any, ...any) -> any?,

	AddTower: (self: DataService, player: Player, towerName: string, towerData: towerTemplate?) -> any,
	AdjustTower: (
		self: DataService,
		player: Player,
		towerName: string,
		towerKey: string,
		key: string,
		value: any
	) -> nil,
	RemoveTower: (self: DataService, player: Player, towerName: string, towerKey: string) -> nil,

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

	local blossom = leaderstats:FindFirstChild("Blossom") or Instance.new("IntValue")
	blossom.Name = "Blossom"
	blossom.Value = playerData.Blossom or 0
	blossom.Parent = leaderstats
end

local function IsOldData(playerData: PlayerData): boolean
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

-------------------------------------------------
--// DataService
-------------------------------------------------
local DataService = {} :: DataService
DataService.KeySignals = {}

function DataService.Init() end

function DataService.Start()
	local tutorialCompletedEvent = ReplicatedStorage:FindFirstChild("TutorialCompleted")
	if not tutorialCompletedEvent then
		tutorialCompletedEvent = Instance.new("RemoteEvent")
		tutorialCompletedEvent.Name = "TutorialCompleted"
		tutorialCompletedEvent.Parent = ReplicatedStorage
	end

	(tutorialCompletedEvent :: RemoteEvent).OnServerEvent:Connect(function(player)
		local playerData = DataService:GetData(player)
		if playerData and playerData.TutorialCompleted ~= true then
			DataService:UpdateData(player, "TutorialCompleted", true)
			DataService:SaveData(player)
		end
	end)

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

	for _, currencyName in { "Coins", "Gems", "Blossom", "Exp", "Level" } do
		DataService:GetChangedSignal(currencyName):Connect(function(player, value)
			Net.DataService.CurrencyChanged.Fire(player, { CurrencyName = currencyName, CurrencyValue = value })
		end)
	end

	DataService:GetChangedSignal("Quests"):Connect(function(player, value)
		Net.DataService.CurrencyChanged.Fire(player, { CurrencyName = "Quests", CurrencyValue = 0 })
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

function DataService:ClearData(player: Player)
	local profile = self:GetProfile(player)
	if not profile or not profile:IsActive() then
		return
	end

	profile.Data = TableUtils.DeepCopy(DataConstants.PROFILE_TEMPLATE)
	profile:Save()
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
		parentTable[lastKey] = (parentTable[lastKey] or 0) + amount
		totalValue = parentTable[lastKey]
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

function DataService:AddTower(player: Player, towerName: string, towerData: towerTemplate?)
	local playerData = self:GetData(player)
	if not playerData then
		return
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
end

function DataService:AdjustTower(player: Player, towerName: string, towerKey: string, key: string, value: any)
	local playerData = self:GetData(player)
	if not playerData then
		return
	end

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
	}

	local handler = handlers[key]
	if not handler then
		warn(`유효하지 않은 속성 "{key}"을 호출 함.`)
		return
	end

	local updateKey, newValue = handler()
	if updateKey and newValue then
		self:FireChanged(player, updateKey, newValue)
	end
end

function DataService:RemoveTower(player: Player, towerName: string, towerKey: string)
	local playerData = self:GetData(player)
	if not playerData then
		return
	end

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

function DataService:_MigrateData(profile: profile, player: Player)
	local playerData = profile.Data
	local version = if IsOldData(playerData) then "v1" else "v2"

	if version == "v1" then
		self:_v1Tov2(playerData, player)
	end

	patchTowerRenames(playerData)
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

	DataService:_MigrateData(profile, player)

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
end

function DataService._PlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:EndSession()
		Profiles[player] = nil
	end
end

return DataService
