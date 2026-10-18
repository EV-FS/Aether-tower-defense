-- // VARIABLES // --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerAssets = {}

-- // FUNCTIONS // --
--[[ Resolves a usable unit template without changing the source asset. ]]
function TowerAssets.Resolve(towerName: string): (Model?, string?)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local towers = assets and assets:FindFirstChild("Towers")
	local model = towers and towers:FindFirstChild(towerName)
	if not model then return nil, "missing model" end
	if not model:IsA("Model") then return nil, "expected a Model" end
	if not model.Archivable then return nil, "Archivable is disabled" end
	if not model:FindFirstChildWhichIsA("BasePart", true) then return nil, "model has no BasePart" end
	return model, nil
end

--[[ Observes unit availability and template changes until the owner unsubscribes. ]]
function TowerAssets.Observe(towerName: string, onChanged: (Model?, string?, boolean) -> ()): () -> ()
	local active = true
	local pending = false
	local connections: { RBXScriptConnection } = {}
	local refresh
	local function disconnect()
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
	end
	local function schedule()
		if pending or not active then return end
		pending = true
		task.defer(function()
			pending = false
			if active then refresh(true) end
		end)
	end
	local function watchChildren(parent: Instance, name: string)
		local function changed(child: Instance)
			if child.Name == name then schedule() end
		end
		table.insert(connections, parent.ChildAdded:Connect(changed))
		table.insert(connections, parent.ChildRemoved:Connect(changed))
	end
	refresh = function(changed: boolean)
		disconnect()
		watchChildren(ReplicatedStorage, "Assets")
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local towers = assets and assets:FindFirstChild("Towers")
		if assets then watchChildren(assets, "Towers") end
		if towers then watchChildren(towers, towerName) end
		local candidate = towers and towers:FindFirstChild(towerName)
		if candidate then
			table.insert(connections, candidate.DescendantAdded:Connect(schedule))
			table.insert(connections, candidate.DescendantRemoving:Connect(schedule))
			table.insert(connections, candidate:GetPropertyChangedSignal("Archivable"):Connect(schedule))
		end
		local model, reason = TowerAssets.Resolve(towerName)
		onChanged(model, reason, changed)
	end
	refresh(false)
	return function()
		active = false
		disconnect()
	end
end

-- // INITIALIZATION // --
return TowerAssets
