local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VFXContext = {}

function VFXContext.new(state, events)
	local forge = require(ReplicatedStorage.Shared.Modules.Utils.ForgeVFX)
	forge.init()
	local particles = nil
	for _, event in events do
		if event.AbsoluteEmit then
			local module = ReplicatedStorage:WaitForChild("Part_Icles", 5)
			if module then
				local ok, result = pcall(require, module)
				if ok then particles = result else warn("[CutsceneVFX] " .. tostring(result)) end
			else
				warn("[CutsceneVFX] ReplicatedStorage.Part_Icles is missing; AbsoluteEmit is unavailable")
			end
			break
		end
	end
	local scene = state:WaitForChild("SceneRoots", 10)
	local function resolve(path)
		if not scene or not state.Parent then return nil end
		local current = nil
		for _, reference in scene:GetChildren() do
			if reference.Value and reference.Value.Name == path[1] then
				current = reference.Value
				break
			end
		end
		for index = 2, #path do
			current = current and current:FindFirstChild(path[index])
		end
		return current
	end
	return function(event)
		local function emitPaths(paths, callback)
			for _, path in paths or {} do
				if not state.Parent then return end
				local target = resolve(path)
				if target then
					local ok, err = pcall(callback, target)
					if not ok then warn("[CutsceneVFX] " .. tostring(err)) end
				else
					warn("[CutsceneVFX] Missing scene object: " .. table.concat(path, "."))
				end
			end
		end
		emitPaths(event.Emit, function(target) forge.emit(target) end)
		if particles and event.AbsoluteEmit then
			local ok, err = pcall(function() particles:Activate() end)
			if not ok then warn("[CutsceneVFX] " .. tostring(err)); return end
			emitPaths(event.AbsoluteEmit, function(target) particles:AbsoluteEmit(target) end)
		end
	end
end

return VFXContext
