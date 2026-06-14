local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local MAX_LOADOUT_SIZE = 5

-------------------------------------------------
--// Local Function
-------------------------------------------------
local function isValidIndex(loadoutIndex: any): boolean
	return typeof(loadoutIndex) == "number" and loadoutIndex > 0 and loadoutIndex <= MAX_LOADOUT_SIZE
end

-------------------------------------------------
--// LoadoutService
-------------------------------------------------
local LoadoutService = {}

function LoadoutService:SetLoadout(player: Player, loadoutIndex: number | "Auto", towerName: string, towerKey: string)
	if loadoutIndex ~= "Auto" and not isValidIndex(loadoutIndex) then
		warn(`요청한 로드아웃 번호가 유효하지 않음.`)
		return false
	end

	if typeof(towerName) ~= "string" or typeof(towerKey) ~= "string" then
		warn(`요청한 타워 정보가 유효하지 않음.`)
		return false
	end

	local playerData = DataService:GetData(player)
	local ownedTowerMap = playerData.OwnedTowers[towerName]
	if not ownedTowerMap or not ownedTowerMap[towerKey] then
		warn(`소유하지 않은 타워를 로드아웃에 장착하려 함.`)
		return false
	end

	for index = 1, MAX_LOADOUT_SIZE do
		local strIndex = tostring(index)
		local equippedTower = playerData.Loadout[strIndex] or playerData.Loadout[index]
		if equippedTower and (equippedTower.Name == towerName or equippedTower.Key == towerKey) then
			DataService:UpdateData(player, "Loadout", nil, strIndex)
			DataService:UpdateData(player, "Loadout", nil, index)

			if loadoutIndex ~= "Auto" then
				break
			end
		end
	end

	if loadoutIndex == "Auto" then
		for index = 1, MAX_LOADOUT_SIZE do
			local strIndex = tostring(index)
			if not (playerData.Loadout[strIndex] or playerData.Loadout[index]) then
				loadoutIndex = index
				break
			end
		end

		if loadoutIndex == "Auto" then
			warn(`로드아웃이 가득 참.`)
			return false
		end
	end

	DataService:UpdateData(player, "Loadout", { Name = towerName, Key = towerKey }, tostring(loadoutIndex))

	return true
end

function LoadoutService:UnequipLoadout(player: Player, loadoutIndex: number | "All")
	if loadoutIndex == "All" then
		DataService:UpdateData(player, "Loadout", {})
		return true
	end
	if not isValidIndex(loadoutIndex) then
		warn(`요청한 로드아웃 번호가 유효하지 않음.`)
		return false
	end

	DataService:UpdateData(player, "Loadout", nil, tostring(loadoutIndex))
	DataService:UpdateData(player, "Loadout", nil, loadoutIndex)

	return true
end

function LoadoutService:UnequipTower(player: Player, towerName: string, towerKey: string)
	if typeof(towerName) ~= "string" then
		warn(`요청한 타워 이름이 유효하지 않음.`)
		return false
	end

	if towerKey ~= nil and typeof(towerKey) ~= "string" then
		warn(`요청한 타워 키가 유효하지 않음.`)
		return false
	end

	local playerData = DataService:GetData(player)
	for index = 1, MAX_LOADOUT_SIZE do
		local strIndex = tostring(index)
		local equippedTower = playerData.Loadout[strIndex] or playerData.Loadout[index]

		if not equippedTower then
			continue
		end

		local sameTower = if towerKey then equippedTower.Key == towerKey else equippedTower.Name == towerName

		if sameTower then
			LoadoutService:UnequipLoadout(player, index)
			return true
		end
	end

	warn(`장착 중인 타워를 찾을 수 없음: {towerName}`)
	return false
end

function LoadoutService.Init() end

function LoadoutService.Start()
	Net.LoadoutService.SetLoadout.On(function(player: Player, data)
		if typeof(data) ~= "table" then
			return false
		end

		if data.requestType == "Equip" then
			local targetTower = data.targetTower
			if typeof(targetTower) ~= "table" then
				return false
			end

			if typeof(targetTower.towerName) ~= "string" or typeof(targetTower.towerKey) ~= "number" then
				return false
			end

			local targetKey = `t_{targetTower.towerKey}`
			return LoadoutService:SetLoadout(player, "Auto", targetTower.towerName, targetKey)
		end

		if data.requestType == "Unequip" then
			local targetTower = data.targetTower
			if typeof(targetTower) ~= "table" then
				return false
			end

			if typeof(targetTower.towerName) ~= "string" or typeof(targetTower.towerKey) ~= "number" then
				return false
			end

			local targetKey = `t_{targetTower.towerKey}`
			return LoadoutService:UnequipTower(player, targetTower.towerName, targetKey)
		end

		if data.requestType == "UnequipAll" then
			return LoadoutService:UnequipLoadout(player, "All")
		end

		return false
	end)
end

return LoadoutService
