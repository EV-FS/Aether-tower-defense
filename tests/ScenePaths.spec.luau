-- Pure resolver tests: luau tests/ScenePaths.spec.luau
local Paths = require("../src/Modules/Cutscene/ScenePaths")
local Node = {}
Node.__index = Node
local function node(name, children)
	local result = setmetatable({ Name = name, Children = children or {} }, Node)
	for _, child in result.Children do child.Parent = result end
	return result
end
function Node:GetChildren() return self.Children end
function Node:GetDescendants()
	local result = {}
	for _, child in self.Children do
		table.insert(result, child)
		for _, descendant in child:GetDescendants() do table.insert(result, descendant) end
	end
	return result
end
function Node:GetFullName()
	return if self.Parent then self.Parent:GetFullName() .. "." .. self.Name else self.Name
end
local direct = node("FX")
local nested = node("Explode")
local duplicate = node("FX")
local light = node("bowlight2")
local folder = node("Effects", { nested, duplicate })
local rig = node("PlayerRig", { light })
local roots = { direct, folder, rig }
assert(Paths.Resolve(roots, { "FX" }) == direct)
assert(Paths.Resolve(roots, { "Explode" }) == nested)
assert(Paths.Resolve(roots, { "Effects", "FX" }) == duplicate)
assert(Paths.Resolve(roots, { "PlayerRig", "bowlight2" }) == light)
local missing, reason = Paths.Resolve(roots, { "NotPresent" })
assert(missing == nil and reason:find("Missing", 1, true))
local unrelated = node("NotPresent") -- must never search outside supplied roots
assert(Paths.Resolve(roots, { unrelated.Name }) == nil)
local ambiguous, ambiguity = Paths.Resolve({ node("A", { node("Same") }), node("B", { node("Same") }) }, { "Same" })
assert(ambiguous == nil and ambiguity:find("Ambiguous", 1, true))
assert(Paths.Resolve({ node("FX"), node("FX") }, { "FX" }) == nil)
assert(Paths.Key({ "a.b", "c" }) ~= Paths.Key({ "a", "b.c" }))
assert(Paths.Key({ "a:b", "c" }) ~= Paths.Key({ "a", "b:c" }))
local collected = Paths.Collect({ [0] = { Emit = { { "FX" } } }, [1] = { Emit = { { "FX" } }, AbsoluteEmit = { { "Explode" } } } })
local count = 0
for _ in collected do count += 1 end
assert(count == 2)
assert(not pcall(Paths.Key, {}))
assert(not pcall(Paths.Key, { "" }))
print("ScenePaths tests passed")
