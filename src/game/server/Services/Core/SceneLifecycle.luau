local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local FrameBudget = require(ReplicatedStorage.Shared.Modules.Utils.FrameBudget)
local InstanceBatch = require(ReplicatedStorage.Shared.Modules.Utils.InstanceBatch)
local SceneLifecycle = {}

-- Soft Lua budget; a single engine operation/atomic rig may exceed this limit.
local function budget()
	local frameTime = 1 / 60
	local step = FrameBudget.new(function()
		frameTime = RunService.Heartbeat:Wait()
	end, 256, 0.002, nil, function()
		-- Back off if the server is already missing frames; never grow past 2ms.
		local slow = frameTime > 1 / 40
		return if slow then 128 else 256, if slow then 0.001 else 0.002
	end)
	-- One shared time budget avoids double-yielding when switching scan/write phases.
	-- A cheap off-world/scan operation costs 1/8 of a live mutation.
	return step, function() step(1 / 8) end
end

function SceneLifecycle.Visit(roots, callback)
	local _, scanStep = budget()
	InstanceBatch.Visit(roots, callback, scanStep)
end

function SceneLifecycle.Clone(source)
	local started = os.clock()
	local clone = assert(source:Clone(), "Scene source must be Archivable: " .. source:GetFullName())
	local elapsed = os.clock() - started
	if elapsed > 0.016 then
		warn(string.format("[SceneLifecycle] Atomic Clone %.1fms: %s", elapsed * 1000, source:GetFullName()))
	end
	RunService.Heartbeat:Wait()
	return clone
end

function SceneLifecycle.Destroy(roots, scriptsDisabled)
	local step, scanStep = budget()
	if not scriptsDisabled then
		InstanceBatch.Visit(roots, function(instance)
			if instance:IsA("BaseScript") then instance.Enabled = false end
		end, scanStep)
	end
	InstanceBatch.Destroy(roots, step, scanStep)
end

-- This phase never parents anything to Workspace. It can run while clients prepare
-- the intro, before its synchronized clock starts.
function SceneLifecycle.Prepare(clone, atomicRoots)
	local _, prepareStep = budget()
	local roots = clone:GetChildren()
	local heldParts, heldScripts = {}, {}
	local entries = InstanceBatch.Plan(clone, function(instance)
		return (atomicRoots and atomicRoots[instance])
			or not (instance:IsA("Model") or instance:IsA("Folder"))
	end, prepareStep)
	local ok, err = xpcall(function()
		InstanceBatch.Visit(roots, function(instance)
			if instance:IsA("BasePart") and not instance.Anchored then
				table.insert(heldParts, instance)
				instance.Anchored = true
			elseif instance:IsA("BaseScript") and instance.Enabled then
				table.insert(heldScripts, instance)
				instance.Enabled = false
			end
		end, prepareStep)
		InstanceBatch.Detach(entries, prepareStep)
	end, debug.traceback)
	if not ok then
		local owned = {}
		for _, entry in entries do table.insert(owned, entry.Instance) end
		SceneLifecycle.Destroy(owned)
		clone:Destroy()
		error(err, 0)
	end
	return { Clone = clone, Roots = roots, Entries = entries, Parts = heldParts, Scripts = heldScripts }
end

function SceneLifecycle.Discard(prepared)
	if not prepared or prepared.Consumed then return end
	prepared.Consumed = true
	local owned = {}
	for _, entry in prepared.Entries do table.insert(owned, entry.Instance) end
	SceneLifecycle.Destroy(owned)
	prepared.Clone:Destroy()
end

function SceneLifecycle.MountPrepared(prepared, destination)
	assert(not prepared.Consumed, "Prepared scene already consumed")
	local step, prepareStep = budget()
	local ok, err = xpcall(function()
		InstanceBatch.Mount(prepared.Clone, destination, prepared.Entries, step, prepareStep, true)
		for _, part in prepared.Parts do part.Anchored = false; step() end
		for _, scriptInstance in prepared.Scripts do scriptInstance.Enabled = true; step() end
	end, debug.traceback)
	if not ok then SceneLifecycle.Discard(prepared); error(err, 0) end
	prepared.Consumed = true
	prepared.Clone:Destroy() -- empty wrapper only
	return prepared.Roots
end

function SceneLifecycle.Mount(clone, destination, atomicRoots)
	return SceneLifecycle.MountPrepared(SceneLifecycle.Prepare(clone, atomicRoots), destination)
end

return SceneLifecycle
