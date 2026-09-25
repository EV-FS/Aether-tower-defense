local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScenePaths = require(script.Parent.ScenePaths)

local LocalVFX = {}
LocalVFX.__index = LocalVFX

function LocalVFX.new(sceneRoots: { Instance }, events)
	local targets = {}
	for key, path in ScenePaths.Collect(events) do
		local target, reason = ScenePaths.ResolveTopLevel(sceneRoots, path)
		if target then
			targets[key] = target
		else
			warn(`[CutsceneVFX] {reason} (disabled for this playback)`)
		end
	end

	local frames = {}
	for frame in events do
		table.insert(frames, frame)
	end
	table.sort(frames)

	local forge = require(ReplicatedStorage.Shared.Modules.Utils.EmitModule)
	forge.init()
	local particles = nil
	for _, event in events do
		if event.AbsoluteEmit then
			local module = ReplicatedStorage:FindFirstChild("Part_Icles")
			if module then
				local ok, result = pcall(require, module)
				if ok then particles = result else warn(`[CutsceneVFX] {tostring(result)}`) end
			else
				warn("[CutsceneVFX] ReplicatedStorage.Part_Icles is missing; AbsoluteEmit is unavailable")
			end
			break
		end
	end
	return setmetatable({
		Events = events,
		Frames = frames,
		NextIndex = 1,
		Targets = targets,
		Forge = forge,
		Particles = particles,
		Handles = {},
		Warned = {},
		Destroyed = false,
	}, LocalVFX)
end

function LocalVFX:Run(event)
	if self.Destroyed then return end
	local function emitPaths(paths, callback)
		for _, path in paths or {} do
			if self.Destroyed then return end
			local key = ScenePaths.Key(path)
			local target = self.Targets[key]
			if not target then continue end
			if not target:IsDescendantOf(workspace) then
				if not self.Warned[key] then
					self.Warned[key] = true
					warn(`[CutsceneVFX] Target was removed: {table.concat(path, ".")}`)
				end
				continue
			end
			local ok, result = pcall(callback, target)
			if not ok then
				warn(`[CutsceneVFX] {table.concat(path, ".")}: {tostring(result)}`)
			elseif type(result) == "table" and result.Clear and result.Finished then
				if self.Destroyed then
					result:Clear()
				else
					self.Handles[result] = true
					result.Finished:finally(function()
						self.Handles[result] = nil
					end):catch(function(err)
						warn(`[CutsceneVFX] Emit failed: {tostring(err)}`)
					end)
				end
			end
		end
	end
	emitPaths(event.Emit, function(target) return self.Forge.emit(target) end)
	if self.Particles and event.AbsoluteEmit then
		local ok, err = pcall(function() self.Particles:Activate() end)
		if not ok then warn(`[CutsceneVFX] {tostring(err)}`); return end
		emitPaths(event.AbsoluteEmit, function(target) return self.Particles:AbsoluteEmit(target) end)
	end
end

function LocalVFX:Step(frame: number)
	if self.Destroyed then return end
	while self.NextIndex <= #self.Frames and self.Frames[self.NextIndex] <= frame + 1e-4 do
		local event = self.Events[self.Frames[self.NextIndex]]
		self.NextIndex += 1 -- Reserve before running an effect that may yield.
		task.spawn(function()
			self:Run(event)
		end)
	end
end

function LocalVFX:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	local handles = {}
	for handle in self.Handles do table.insert(handles, handle) end
	for _, handle in handles do
		local ok, err = pcall(handle.Clear, handle)
		if not ok then warn(`[CutsceneVFX] Cleanup: {tostring(err)}`) end
	end
	table.clear(self.Handles)
	table.clear(self.Targets)
end

return LocalVFX
