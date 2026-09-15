local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)

local RANDOM = Random.new()
local ROLL_COST = 5

local DataService

local function GetRandomTrait(): string
	local totalChance = 0
	for _, trait in TraitData.ByName do
		totalChance += trait.Chance
	end

	local randomNum = RANDOM:NextNumber(0, totalChance)
	local currentChance = 0

	for traitName, trait in TraitData.ByName do
		currentChance += trait.Chance

		if randomNum <= currentChance then
			return traitName
		end
	end

	error("Trait을 뽑지 못함.")
end

local TraitService = {}

function TraitService.RollTrait(player: Player, towerName: string, towerKey: string)
	local playerData = DataService:GetData(player)
	if not playerData then
		return
	end

	if not playerData.OwnedTowers[towerName] or not playerData.OwnedTowers[towerName][towerKey] then
		warn(`요청한 타워를 가지고 있지 않음.`)
		return
	end

	if playerData.Gems < ROLL_COST then
		return
	end
	playerData.Gems -= ROLL_COST

	local newTrait = GetRandomTrait()
	DataService:AdjustTower(player, towerName, towerKey, "Trait", newTrait)

	return newTrait
end

function TraitService.Init(services)
	DataService = services:GetService("DataService")
end

function TraitService.Start() end

return TraitService
