--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local ObjectCache = require(ReplicatedStorage.Packages.ObjectCache)

-------------------------------------------------
--// InstanceCache
-------------------------------------------------
local InstanceCache = {}
InstanceCache.__index = InstanceCache

function InstanceCache:ExpandCache(amount: number)
	for _ = 1, amount or self.PoolSize do
		local newInst = self.Template:Clone()
		newInst.Parent = self.Folder

		table.insert(self.Available, newInst)
	end
end

function InstanceCache:GetInstance(): Instance
	if #self.Available == 0 then
		warn("캐시 한도 도달. 확장 중...")
		self:ExpandCache(math.ceil(self.PoolSize * 0.5))
	end

	local inst = table.remove(self.Available)
	self.InUse[inst] = true

	return inst
end

function InstanceCache:ReturnInstance(inst: Instance)
	if not self.InUse[inst] then
		warn("이 캐시에서 생성된 객체가 아니거나 이미 반납됨.")
		return
	end

	self.InUse[inst] = nil

	local success = pcall(function()
		inst.Parent = self.Folder
	end)

	if not success then
		local newInst = self.Template:Clone()
		newInst.Parent = self.Folder
		table.insert(self.Available, newInst)
		return
	end

	if inst:IsA("AudioPlayer") then
		inst:Stop()
	elseif inst:IsA("GuiObject") then
		inst.Visible = false
	end

	table.insert(self.Available, inst)
end

function InstanceCache.new(inst: Instance, cacheSize: number?, cachesFolder: Instance)
	if inst:IsA("BasePart") or inst:IsA("Model") then
		return ObjectCache.new(inst, cacheSize, cachesFolder)
	end

	local self = setmetatable({}, InstanceCache)

	self.Template = inst
	self.PoolSize = cacheSize or 10
	self.Folder = cachesFolder

	self.Available = {}
	self.InUse = {}

	self:ExpandCache(self.PoolSize)

	return self
end

return InstanceCache
