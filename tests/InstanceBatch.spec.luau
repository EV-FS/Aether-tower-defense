-- Run with the standalone Luau CLI: luau tests/InstanceBatch.spec.luau
local Batch = require("../src/Modules/Utils/InstanceBatch")
local FrameBudget = require("../src/Modules/Utils/FrameBudget")

local function node(class, parent)
	local props = { ClassName = class, WorldPivot = {}, Children = {} }
	local obj
	obj = setmetatable({}, {
		__index = props,
		__newindex = function(_, key, value)
			if key == "Parent" then
				if props.Parent then
					table.remove(props.Parent.Children, assert(table.find(props.Parent.Children, obj)))
				end
				if value then table.insert(value.Children, obj) end
			end
			props[key] = value
		end,
	})
	function obj:IsA(wanted) return class == wanted end
	function obj:GetChildren() return table.clone(props.Children) end
	function obj:Destroy()
		assert(#props.Children == 0, "Destroy must be child-first")
		assert(not props.Destroyed, "Destroy must not visit overlapping roots twice")
		props.Destroyed = true
		obj.Parent = nil
	end
	obj.Parent = parent
	return obj
end

local function count(root)
	local total = 0
	Batch.Visit({ root }, function() total += 1 end, function() end)
	return total
end

local function roundTrip(root, limit)
	local originalParents, visited, total = {}, {}, count(root) - 1
	Batch.Visit(root:GetChildren(), function(item) originalParents[item] = item.Parent end, function() end)
	local steps = 0
	local function scanStep() steps += 1 end
	local entries, plannedCount = Batch.PlanBounded(root, limit, scanStep, function(item)
		assert(not visited[item], "Preparation must visit each node exactly once")
		visited[item] = true
	end)
	assert(plannedCount == total)
	assert(steps >= total, "Planning must expose scheduling points")
	local modelMetadata = {}
	for _, entry in entries do
		if entry.IsModel then
			modelMetadata[entry.Instance] = { PrimaryPart = entry.Instance.PrimaryPart, WorldPivot = entry.Instance.WorldPivot }
		end
	end
	Batch.Detach(entries, scanStep)
	-- Simulate metadata being invalidated while model descendants are detached.
	for model in modelMetadata do model.PrimaryPart = nil; model.WorldPivot = {} end
	local sum = 0
	for _, entry in entries do
		local chunkSize = count(entry.Instance)
		assert(chunkSize <= limit, "A mount chunk exceeded its descendant limit")
		assert(entry.Cost == chunkSize, "Frame cost must include the full subtree")
		sum += chunkSize
	end
	assert(sum == total, "Detached chunks must cover every original object once")
	local destination = node("Folder")
	local costs, yields = 0, 0
	local budget = FrameBudget.new(function() yields += 1 end, limit, 100, function() return 0 end)
	Batch.Mount(root, destination, entries, function(cost)
		costs += cost or 1
		budget(cost)
	end, scanStep, true)
	assert(count(destination) - 1 == total)
	assert(costs >= total)
	if total >= limit then assert(yields > 0, "Large mounts must yield") end
	for item, parent in originalParents do
		assert(visited[item])
		assert(item.Parent == (if parent == root then destination else parent), "Hierarchy changed")
	end
	for model, saved in modelMetadata do
		assert(model.PrimaryPart == saved.PrimaryPart and model.WorldPivot == saved.WorldPivot,
			"Split model metadata was not restored")
	end
	return entries, destination
end

-- Reproduces the old loophole: a large hierarchy underneath one BasePart.
local root = node("Folder")
local part = node("BasePart", root)
for _ = 1, 1000 do node("Attachment", part) end
local other = node("Model", root)
local primary = node("BasePart", other)
other.PrimaryPart = primary
local pivot = other.WorldPivot
local reference = node("ObjectValue", part)
reference.Value = primary
roundTrip(root, 32)
assert(reference.Value == primary, "Cross-chunk ObjectValue reference changed")
assert(other.PrimaryPart == primary and other.WorldPivot == pivot)
print("PASS: BasePart descendants, subtree costs, cross-chunk references")

local deep = node("Folder")
local cursor = deep
for _ = 1, 2000 do cursor = node("Model", cursor) end
local deepPrimary = node("BasePart", cursor)
deep:GetChildren()[1].PrimaryPart = deepPrimary
roundTrip(deep, 32)
print("PASS: deeply nested models without recursive stack overflow")

local wide = node("Folder")
for _ = 1, 10000 do node("BasePart", wide) end
roundTrip(wide, 32)
print("PASS: wide tree, bounded mount, scheduling during child enumeration")

local small = node("Folder")
local group = node("Model", small)
for _ = 1, 31 do node("BasePart", group) end
local entries, destination = roundTrip(small, 32)
assert(#entries == 1, "Small groups should remain intact")
local roots = destination:GetChildren()
table.insert(roots, group:GetChildren()[1])
Batch.Destroy(roots, function() end)
assert(#destination:GetChildren() == 0)
print("PASS: exact-size chunk and cleanup of overlapping roots")

local simulatedTime, waits = 0, 0
local timedStep = FrameBudget.new(function() waits += 1 end, 1000, 0.002, function() return simulatedTime end)
simulatedTime = 0.003
timedStep()
assert(waits == 1, "Time budget must yield before reaching item limit")
print("PASS: time-based frame budget")

-- Existing cutscene callers explicitly designate complete rigs as atomic.
local scene = node("Folder")
local rig = node("Model", scene)
local rigPart = node("BasePart", rig)
rig.PrimaryPart = rigPart
local legacyEntries = Batch.Plan(scene, function(item) return item == rig end, function() end)
assert(#legacyEntries == 1 and not legacyEntries[1].IsModel)
Batch.Mount(scene, node("Folder"), legacyEntries, function() end)
assert(rigPart.Parent == rig and rig.PrimaryPart == rigPart)
print("PASS: legacy atomic cutscene rig remains intact")
