local Batch = require("../src/Modules/Utils/InstanceBatch")
local Node = {}
local metatable = {
	__index = function(self, key)
		if key == "Parent" then return rawget(self, "_parent") end
		return Node[key]
	end,
	__newindex = function(self, key, value)
		if key ~= "Parent" then rawset(self, key, value); return end
		local previous = rawget(self, "_parent")
		local ancestor = previous
		while ancestor do
			if ancestor.PrimaryPart == self then ancestor.PrimaryPart = nil end
			ancestor = ancestor.Parent
		end
		if previous then table.remove(previous.Children, assert(table.find(previous.Children, self))) end
		rawset(self, "_parent", value)
		if value then table.insert(value.Children, self) end
	end,
}
local function node(name, kind, parent)
	local result = setmetatable({ Name = name, Kind = kind, Children = {} }, metatable)
	result.Parent = parent
	return result
end
function Node:GetChildren() return table.clone(self.Children) end
function Node:IsA(kind) return self.Kind == kind end
function Node:Destroy()
	assert(#self.Children == 0, "Destroy recursively removed a nonempty subtree: " .. self.Name)
	assert(not self.Destroyed, "Destroyed twice")
	self.Destroyed = true
	self.Parent = nil
end
local clone = node("Clone", "Folder")
local environment = node("Environment", "Model", clone)
local a = node("A", "Part", environment)
local b = node("B", "Part", environment)
local nextNode = node("Next", "ObjectValue", a)
nextNode.Value = b
environment.PrimaryPart = a
local rig = node("PlayerRig", "Model", clone)
local root = node("Root", "Part", rig)
local joint = node("Joint", "Motor6D", root)
joint.Part0, joint.Part1 = root, a
local count = 0
local function step() count += 1 end
local entries = Batch.Plan(clone, function(instance)
	return instance == rig or (instance.Kind ~= "Folder" and instance.Kind ~= "Model")
end, step)
assert(#entries == 4, "Containers must split while rigs/parts stay atomic")
local destination = node("Map", "Folder")
Batch.Mount(clone, destination, entries, step)
assert(#clone.Children == 0)
assert(environment.Parent == destination and rig.Parent == destination)
assert(a.Parent == environment and b.Parent == environment)
assert(nextNode.Value == b and environment.PrimaryPart == a and joint.Part1 == a)
assert(root.Parent == rig and joint.Parent == root)
assert(count >= #entries * 3, "Planning/detach/mount must all checkpoint")
Batch.Destroy({ environment, rig }, step)
assert(environment.Destroyed and rig.Destroyed and joint.Destroyed and nextNode.Destroyed)
assert(#destination.Children == 0)
-- Overlapping ownership lists on rollback must still destroy leaves first, once.
local parent = node("Parent", "Folder")
local child = node("Child", "Folder", parent)
local leaf = node("Leaf", "Part", child)
Batch.Destroy({ parent, child, leaf }, step)
assert(parent.Destroyed and child.Destroyed and leaf.Destroyed)

-- Large/deep inputs must not recurse through Lua or delete a giant subtree at once.
local large = node("Large", "Folder")
for index = 1, 10000 do node(tostring(index), "Part", large) end
local before = count
Batch.Destroy({ large }, step)
assert(count - before >= 20002)
local deep = node("Deep", "Folder")
local cursor = deep
for index = 1, 2000 do cursor = node(tostring(index), "Folder", cursor) end
Batch.Destroy({ deep }, step)
assert(deep.Destroyed and cursor.Destroyed)
local mutations, scans = 0, 0
local separated = node("Separated", "Folder")
for index = 1, 100 do node(tostring(index), "Part", separated) end
Batch.Destroy({ separated }, function() mutations += 1 end, function() scans += 1 end)
assert(mutations == 101 and scans == 101, "Traversal must not count as a live deletion")
print("InstanceBatch tests passed")
