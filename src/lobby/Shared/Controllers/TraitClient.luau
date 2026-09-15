local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages.Promise)

local InventoryClient
local TraitClient = {}

function TraitClient.Roll(towerName: string, towerKey: string | number)
	return Promise.new(function(resolve, reject)
		task.spawn(function()
			local remotes = ReplicatedStorage:WaitForChild("RuntimeRemotes", 5)
			local remote = remotes and remotes:FindFirstChild("TraitRoll")
			if not remote or not remote:IsA("RemoteFunction") then
				reject("Trait service is unavailable.")
				return
			end
			local ok, result = pcall(function()
				return remote:InvokeServer({ TowerName = towerName, TowerKey = towerKey })
			end)
			if not ok then reject(result) return end
			if typeof(result) ~= "table" then reject("Invalid trait response.") return end
			if result.Success == true then
				InventoryClient.UpdateTowerField(towerName, towerKey, "Trait", result.Trait)
			end
			resolve(result)
		end)
	end)
end

function TraitClient.Init(services)
	InventoryClient = services:GetService("InventoryClient")
end

TraitClient.Dependencies = { "InventoryClient" }
function TraitClient.Start() end

return TraitClient
