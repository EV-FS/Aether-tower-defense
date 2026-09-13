local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScenePaths = require(script.Parent.ScenePaths)
local VFXContext = {}
VFXContext.__index = VFXContext

function VFXContext.new(state, events)
	local wanted = ScenePaths.Collect(events)
	local targets, unavailable = {}, {}
	local deadline = os.clock() + 20
	local pending = {}
	repeat
		assert(state.Parent, "Cutscene removed during VFX preparation")
		table.clear(pending)
		local manifest = state:FindFirstChild("VFXTargets")
		local references = {}
		for _, reference in if manifest then manifest:GetChildren() else {} do
			local key = reference:GetAttribute("PathKey")
			if key then references[key] = reference end
		end
		for key, path in wanted do
			local reference = references[key]
			local reason = reference and reference:GetAttribute("Unavailable")
			local target = reference and reference.Value
			local descendantCount = reference and reference:GetAttribute("DescendantCount")
			if reason then
				unavailable[key] = reason
			elseif target and target:IsDescendantOf(workspace) and descendantCount
				and #target:GetDescendants() >= descendantCount then
				targets[key] = target
			else
				table.insert(pending, table.concat(path, "."))
			end
		end
		if #pending == 0 then break end
		assert(os.clock() < deadline, "VFX replication timed out: " .. table.concat(pending, ", "))
		RunService.Heartbeat:Wait()
	until false
	for _, reason in unavailable do warn("[CutsceneVFX] " .. reason .. " (disabled for this playback)") end
	local forge = require(ReplicatedStorage.Shared.Modules.Utils.EmitModule)
	forge.init()
	local particles = nil
	for _, event in events do
		if event.AbsoluteEmit then
			local module = ReplicatedStorage:WaitForChild("Part_Icles", 3)
			if module then
				local ok, result = pcall(require, module)
				if ok then particles = result else warn("[CutsceneVFX] " .. tostring(result)) end
			else
				warn("[CutsceneVFX] ReplicatedStorage.Part_Icles is missing; AbsoluteEmit is unavailable")
			end
			break
		end
	end
	return setmetatable({ State = state, Targets = targets, Forge = forge, Particles = particles,
		Handles = {}, Warned = {}, Destroyed = false }, VFXContext)
end

function VFXContext:Run(event)
	if self.Destroyed or not self.State.Parent then return end
	local function emitPaths(paths, callback)
		for _, path in paths or {} do
			if self.Destroyed or not self.State.Parent then return end
			local key = ScenePaths.Key(path)
			local target = self.Targets[key]
			if not target then continue end -- diagnosed during preparation
			if not target:IsDescendantOf(workspace) then
				if not self.Warned[key] then
					self.Warned[key] = true
					warn("[CutsceneVFX] Prepared target was removed: " .. table.concat(path, "."))
				end
				continue
			end
			local ok, result = pcall(callback, target)
			if not ok then
				warn("[CutsceneVFX] " .. table.concat(path, ".") .. ": " .. tostring(result))
			elseif type(result) == "table" and result.Clear and result.Finished then
				if self.Destroyed then result:Clear(); continue end
				self.Handles[result] = true
				result.Finished:finally(function() self.Handles[result] = nil end):catch(function(err)
					warn("[CutsceneVFX] Emit failed: " .. tostring(err))
				end)
			end
		end
	end
	emitPaths(event.Emit, function(target) return self.Forge.emit(target) end)
	if self.Particles and event.AbsoluteEmit then
		local ok, err = pcall(function() self.Particles:Activate() end)
		if not ok then warn("[CutsceneVFX] " .. tostring(err)); return end
		emitPaths(event.AbsoluteEmit, function(target) return self.Particles:AbsoluteEmit(target) end)
	end
end

function VFXContext:Destroy()
	self.Destroyed = true
	-- Snapshot because completion callbacks can remove handles during cancellation.
	local handles = {}
	for handle in self.Handles do table.insert(handles, handle) end
	for _, handle in handles do
		local ok, err = pcall(handle.Clear, handle)
		if not ok then warn("[CutsceneVFX] Cleanup: " .. tostring(err)) end
	end
	table.clear(self.Handles)
	table.clear(self.Targets)
end

return VFXContext
