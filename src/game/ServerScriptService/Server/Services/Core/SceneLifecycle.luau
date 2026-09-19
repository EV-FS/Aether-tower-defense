local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FrameBudget = require(ReplicatedStorage.Shared.Modules.Utils.FrameBudget)
local InstanceBatch = require(ReplicatedStorage.Shared.Modules.Utils.InstanceBatch)
local SceneLifecycle = {}

-- Soft Lua budget; a single engine operation/atomic rig may exceed this limit.
local function budget()
	local frameTime = 1 / 60
	local step = FrameBudget.new(function()
		frameTime = task.wait()
	end, 64, 0.0015, nil, function()
		-- Bound live work by descendant count as well as Lua time. Engine physics
		-- and replication work may occur AFTER the Parent write has returned.
		local slow = frameTime > 1 / 40
		return if slow then 32 else 64, if slow then 0.00075 else 0.0015
	end)
	-- One shared time budget avoids double-yielding when switching scan/write phases.
	-- A cheap off-world/scan operation costs 1/8 of a live mutation.
	return step, function(cost) step((cost or 1) / 8) end
end

local function phase(trace, name, callback)
	if trace then return trace:Run(name, callback) end
	return callback()
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
	task.wait()
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
function SceneLifecycle.Prepare(clone, atomicRoots, keepScriptsDisabled, trace)
	local _, prepareStep = budget()
	local roots = clone:GetChildren()
	local heldParts, heldScripts = {}, {}
	local function isAtomic(instance)
		if not (instance:IsA("Model") or instance:IsA("Folder")) then
			return true
		end
		if type(atomicRoots) == "function" then
			return atomicRoots(instance)
		end
		return atomicRoots and atomicRoots[instance] or false
	end
	local entries
	local nodeCount
	local function hold(instance)
		if instance:IsA("BasePart") and not instance.Anchored then
			table.insert(heldParts, instance)
			instance.Anchored = true
		elseif instance:IsA("BaseScript") and instance.Enabled then
			instance.Enabled = false
			if not keepScriptsDisabled then table.insert(heldScripts, instance) end
		end
	end
	local ok, err = xpcall(function()
		phase(trace, "Plan", function()
			if type(atomicRoots) == "number" then
				entries, nodeCount = InstanceBatch.PlanBounded(clone, atomicRoots, prepareStep, hold)
			else
				entries = InstanceBatch.Plan(clone, isAtomic, prepareStep)
				InstanceBatch.Visit(roots, hold, prepareStep)
			end
		end)
		if trace then
			print(string.format("[MapLoad] %s nodes=%d mountEntries=%d unanchoredParts=%d",
				trace.Name, nodeCount or 0, #entries, #heldParts))
		end
		phase(trace, "Detach", function() InstanceBatch.Detach(entries, prepareStep) end)
	end, debug.traceback)
	if not ok then
		warn("[SceneLifecycle] Prepare failed before cleanup: " .. tostring(err))
		task.wait()
		local owned = { clone }
		for _, entry in entries or {} do table.insert(owned, entry.Instance); prepareStep() end
		SceneLifecycle.Destroy(owned)
		error(err, 0)
	end
	return { Clone = clone, Roots = roots, Entries = entries, Parts = heldParts, Scripts = heldScripts }
end

function SceneLifecycle.Discard(prepared)
	if not prepared or prepared.Consumed then return end
	prepared.Consumed = true
	local owned = {}
	local _, scanStep = budget()
	for _, entry in prepared.Entries do table.insert(owned, entry.Instance); scanStep() end
	SceneLifecycle.Destroy(owned)
	prepared.Clone:Destroy()
end

function SceneLifecycle.MountPrepared(prepared, destination, trace)
	assert(not prepared.Consumed, "Prepared scene already consumed")
	local step, prepareStep = budget()
	local ok, err = xpcall(function()
		phase(trace, "Mount", function()
			InstanceBatch.Mount(prepared.Clone, destination, prepared.Entries, step, prepareStep, true)
		end)
		phase(trace, "RestorePhysics", function()
			for _, part in prepared.Parts do part.Anchored = false; step() end
			for _, scriptInstance in prepared.Scripts do scriptInstance.Enabled = true; step() end
		end)
	end, debug.traceback)
	if not ok then
		warn("[SceneLifecycle] Mount failed before cleanup: " .. tostring(err))
		task.wait()
		SceneLifecycle.Discard(prepared)
		error(err, 0)
	end
	prepared.Consumed = true
	prepared.Clone:Destroy() -- empty wrapper only
	return prepared.Roots
end

function SceneLifecycle.Mount(clone, destination, atomicRoots)
	return SceneLifecycle.MountPrepared(SceneLifecycle.Prepare(clone, atomicRoots), destination)
end

return SceneLifecycle
