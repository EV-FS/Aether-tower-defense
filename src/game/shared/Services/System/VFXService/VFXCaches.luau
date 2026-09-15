local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InstanceCache = require(ReplicatedStorage.Shared.Modules.Core.InstanceCache)

local VFX_FOLDER = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX")
local CACHE_FOLDER = workspace:WaitForChild("Caches")

local DEFAULT_POOL_SIZE = 50

type PoolData = {
	Storage: any,
	ActiveCount: number,
	Capacity: number,
}

local VFXCaches = {}

local Pools: { [string]: PoolData } = {}
local RunId = 0

local function getRootInstance(effect: Instance): Instance
	if effect:IsA("BasePart") and effect.Parent and effect.Parent:IsA("Model") and effect.Parent.PrimaryPart == effect then
		return effect.Parent
	end
	return effect
end

local function resetEffect(effect: Instance)
	local root = getRootInstance(effect)
	for _, object in root:GetDescendants() do
		if object:IsA("ParticleEmitter") then
			object.Enabled = false
			object:Clear()
		elseif object:IsA("Beam") or object:IsA("Trail") then
			object.Enabled = false
		elseif object:IsA("Sound") then
			object:Stop()
		end
	end
end

local function hide(effect: Instance)
	local root = getRootInstance(effect)
	if root:IsA("BasePart") then
		root:SetAttribute("VFX_OT", root.Transparency)
		root.Transparency = 1
	end

	for _, object in root:GetDescendants() do
		if object:IsA("BasePart") then
			object:SetAttribute("VFX_OT", object.Transparency)
			object.Transparency = 1
		end
	end
end

local function show(effect: Instance)
	local root = getRootInstance(effect)
	if root:IsA("BasePart") then
		local toSet = root:GetAttribute("VFX_OT")
		if toSet then
			root.Transparency = toSet
		end
	end

	for _, object in root:GetDescendants() do
		if object:IsA("BasePart") then
			local toSet = object:GetAttribute("VFX_OT")
			if toSet then
				object.Transparency = toSet
			end
		end
	end
end

function VFXCaches.GetTemplate(effectPath: string): Instance?
	local current: Instance? = VFX_FOLDER

	for name in string.gmatch(effectPath, "[^/]+") do
		current = current and current:FindFirstChild(name)

		if not current then
			warn(`Effect를 찾을 수 없음: {effectPath}`)
			return nil
		end
	end

	return current
end

function VFXCaches.SetCFrame(effect: Instance, cframe: CFrame)
	if effect:IsA("BasePart") then
		effect.CFrame = cframe
	elseif effect:IsA("Model") then
		effect:PivotTo(cframe)
	end
end

function VFXCaches.Get(effectPath: string, cframe: CFrame?, poolSize: number?): (Instance?, number?)
	local pool = Pools[effectPath]

	if not pool then
		local template = VFXCaches.GetTemplate(effectPath)

		if not template then
			return nil, nil
		end

		local size = poolSize or DEFAULT_POOL_SIZE

		pool = {
			Storage = InstanceCache.new(template, size, CACHE_FOLDER),
			ActiveCount = 0,
			Capacity = size,
		}

		Pools[effectPath] = pool
	end

	pool.ActiveCount += 1

	if pool.ActiveCount > pool.Capacity then
		pool.Storage:ExpandCache(1)
		pool.Capacity += 1
	end

	local effect = pool.Storage:GetInstance(cframe)

	if not effect then
		return nil, nil
	end

	RunId += 1

	effect:SetAttribute("VFXRunId", RunId)

	resetEffect(effect)
	show(effect)
	if cframe then
		VFXCaches.SetCFrame(effect, cframe)
	end

	return effect, RunId
end

function VFXCaches.Return(effectPath: string, effect: Instance)
	local pool = Pools[effectPath]
	if not pool then
		return
	end

	resetEffect(effect)
	hide(effect)
	effect:SetAttribute("VFXRunId", nil)

	task.delay(0.5, function()
		pool.ActiveCount = math.max(0, pool.ActiveCount - 1)
		pool.Storage:ReturnInstance(effect)
	end)
end

function VFXCaches.ReturnAfter(effectPath: string, effect: Instance, runId: number, lifetime: number)
	task.delay(lifetime, function()
		if effect:GetAttribute("VFXRunId") ~= runId then
			return
		end

		VFXCaches.Return(effectPath, effect)
	end)
end

return VFXCaches
