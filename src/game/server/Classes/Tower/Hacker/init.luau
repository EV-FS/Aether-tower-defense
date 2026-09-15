--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--/Modules
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)

--/Classes
local BaseTower = require(ServerScriptService.Server.Classes.Tower.BaseTower)

--/Constants
local RANDOM = Random.new()

-------------------------------------------------
--// Hacker
-------------------------------------------------
local Hacker = setmetatable({}, BaseTower)
Hacker.__index = Hacker

function Hacker.new(player: Player, towerId: number, towerName: string, position: Vector3)
	local self = BaseTower.new(player, towerId, towerName, position)
	setmetatable(self, Hacker)

	self:GetEvent("Killed"):Connect(function(target)
		if target.IsBoss then
			return
		end

		local chance = RANDOM:NextNumber() * 100
		if chance <= self.Stats.HackingChance then
			local UnitService = ServiceRegistry:GetService("UnitService")

			UnitService.Spawn(self, target.Name, target.PathAlpha, true)
		end
	end)

	return self
end

return Hacker
