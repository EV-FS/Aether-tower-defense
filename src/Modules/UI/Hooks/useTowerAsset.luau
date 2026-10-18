-- // VARIABLES // --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerAssets = require(ReplicatedStorage.Shared.Modules.Utils.TowerAssets)

-- // FUNCTIONS // --
--[[ Keeps a view's unit template synchronized with asset availability. ]]
local function useTowerAsset(towerName, onUpdated: ((Model) -> ())?): () -> Model?
	local snapshot = Vide.source({ Asset = nil :: Model? })
	Vide.effect(function()
		local name = Vide.read(towerName)
		snapshot({ Asset = nil })
		if not name or name == "" then return end
		local active = true
		local failure: string? = nil
		local latest: Model? = nil
		Vide.cleanup(TowerAssets.Observe(name, function(asset, reason, changed)
			latest, failure = asset, reason
			if changed and asset and onUpdated then onUpdated(asset) end
			snapshot({ Asset = asset })
		end))
		Vide.cleanup(function() active = false end)
		task.delay(10, function()
			if active and not latest then
				warn(`[TowerAssets] ReplicatedStorage.Assets.Towers.{name}: {failure or "unavailable"}`)
			end
		end)
	end)
	return function() return snapshot().Asset end
end

-- // INITIALIZATION // --
return useTowerAsset
