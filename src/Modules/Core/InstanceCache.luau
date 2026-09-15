--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local ObjectCache = require(ReplicatedStorage.Packages.ObjectCache)

-------------------------------------------------
--// InstanceCache
-------------------------------------------------
local InstanceCache = {}
InstanceCache.__index = InstanceCache

local FAR_AWAY_CFRAME = CFrame.new(2 ^ 24, 2 ^ 24, 2 ^ 24)

local function getObjectPart(inst: Instance): BasePart?
	return if inst:IsA("BasePart") then inst else nil
end

local function createInstance(template: Instance, folder: Instance): Instance
	local newInst = template:Clone()
	if newInst:IsA("Model") then
		newInst:PivotTo(FAR_AWAY_CFRAME)
	end
	newInst.Parent = folder
	return newInst
end

function InstanceCache:ExpandCache(amount: number?)
	local expandAmount = amount or self.PoolSize

	if self.ObjectCache then
		-- ObjectCache 1.4.6 removes one object from its free list while expanding.
		-- Capture that object through its internal helper and return it immediately.
		local objectPart = self.ObjectCache:_GetNew(expandAmount, false)
		if objectPart then
			self.ObjectCache:ReturnPart(objectPart)
		end
		return
	end

	for _ = 1, expandAmount do
		table.insert(self.Available, createInstance(self.Template, self.Folder))
	end
end

function InstanceCache:GetInstance(cframe: CFrame?): Instance
	if self.ObjectCache then
		local objectPart = self.ObjectCache:GetPart(cframe)
		self.InUse[objectPart] = true
		return objectPart
	end

	if #self.Available == 0 then
		warn("InstanceCache: cache exhausted; expanding")
		self:ExpandCache(math.ceil(self.PoolSize * 0.5))
	end

	local inst = table.remove(self.Available)
	if not inst or inst.Parent == nil then
		inst = createInstance(self.Template, self.Folder)
	end
	self.InUse[inst] = true
	if cframe and inst:IsA("Model") then
		inst:PivotTo(cframe)
	end

	return inst
end

function InstanceCache:ReturnInstance(inst: Instance)
	if self.ObjectCache then
		local objectPart = getObjectPart(inst)
		if not objectPart or not self.InUse[objectPart] then
			warn(`InstanceCache: {inst:GetFullName()} is not in use by this spatial cache`)
			return
		end

		self.InUse[objectPart] = nil
		self.ObjectCache:ReturnPart(objectPart)
		return
	end

	if not self.InUse[inst] then
		warn("InstanceCache: tried to return an instance that is not in use")
		return
	end

	self.InUse[inst] = nil

	local success = pcall(function()
		if inst:IsA("Model") then
			inst:PivotTo(FAR_AWAY_CFRAME)
		end
		inst.Parent = self.Folder
	end)

	if not success then
		table.insert(self.Available, createInstance(self.Template, self.Folder))
		return
	end

	if inst:IsA("AudioPlayer") then
		inst:Stop()
	elseif inst:IsA("GuiObject") then
		inst.Visible = false
	end

	table.insert(self.Available, inst)
end

function InstanceCache:IsInUse(inst: Instance): boolean
	if self.ObjectCache then
		local objectPart = getObjectPart(inst)
		return objectPart ~= nil and self.InUse[objectPart] == true
	end

	return self.InUse[inst] == true
end

function InstanceCache:Destroy()
	if self.ObjectCache then
		self.ObjectCache:Destroy()
		table.clear(self.InUse)
		return
	end

	for _, inst in self.Available do
		inst:Destroy()
	end
	for inst in self.InUse do
		inst:Destroy()
	end

	table.clear(self.Available)
	table.clear(self.InUse)
end

function InstanceCache.new(inst: Instance, cacheSize: number?, cachesFolder: Instance)
	local self = setmetatable({}, InstanceCache)

	self.Template = inst
	self.PoolSize = cacheSize or 10
	self.Folder = cachesFolder
	self.ObjectCache = nil

	self.Available = {}
	self.InUse = {}

	if inst:IsA("BasePart") then
		self.ObjectCache = ObjectCache.new(inst, self.PoolSize, cachesFolder)
		return self
	end

	self:ExpandCache(self.PoolSize)

	return self
end

return InstanceCache
