local AttributeComponent = {}
AttributeComponent.__index = AttributeComponent

function AttributeComponent.new(enemy, attributes)
	local self = setmetatable({}, AttributeComponent)
	self.Enemy = enemy
	self.Attributes = {}
	self.ActiveAttributes = {}
	self.Started = false
	self.IsDestroyed = false

	for name, config in pairs(attributes or {}) do
		self:SetAttribute(name, config)
	end

	return self
end

function AttributeComponent:Start()
	if self.Started or self.IsDestroyed then
		return
	end

	self.Started = true
	for name, config in pairs(self.Attributes) do
		self:SetAttribute(name, config)
	end
end

function AttributeComponent:SetAttribute(name: string, config)
	if self.IsDestroyed then
		return
	end

	config = table.clone(config)
	local module = script.Attributes:FindFirstChild(name)
	if not module then
		warn(`알 수 없는 Attribute: {name}.`)
		return
	end

	if not self.Started then
		self.Attributes[name] = config
		return config
	end

	local attribute = self.ActiveAttributes[name]
	if attribute then
		attribute:UpdateConfig(config)
	else
		attribute = require(module).new(self.Enemy, config)
		self.ActiveAttributes[name] = attribute
		self.Attributes[name] = config
		if attribute.Start then
			attribute:Start()
		end
	end

	self.Attributes[name] = config
	return config
end

function AttributeComponent:GetAttribute(name: string)
	local config = self.Attributes[name]
	return config and table.clone(config)
end

function AttributeComponent:GetAttributes()
	local attributes = {}
	for name, config in pairs(self.Attributes) do
		attributes[name] = table.clone(config)
	end
	return attributes
end

function AttributeComponent:HasAttribute(name: string): boolean
	return self.Attributes[name] ~= nil
end

function AttributeComponent:RemoveAttribute(name: string)
	local attribute = self.ActiveAttributes[name]
	self.ActiveAttributes[name] = nil
	self.Attributes[name] = nil
	if attribute then
		attribute:Destroy()
	end
end

function AttributeComponent:Update(now: number, gameDt: number)
	if not self.Started or self.IsDestroyed then
		return
	end

	for name, attribute in pairs(table.clone(self.ActiveAttributes)) do
		if self.IsDestroyed or self.Enemy.IsDead or self.Enemy.IsDestroyed then
			break
		end
		if self.ActiveAttributes[name] == attribute and attribute.Update then
			attribute:Update(now, gameDt)
		end
	end
end

function AttributeComponent:Destroy()
	if self.IsDestroyed then
		return
	end

	self.IsDestroyed = true
	self.Started = false
	for _, attribute in pairs(self.ActiveAttributes) do
		attribute:Destroy()
	end
	table.clear(self.ActiveAttributes)
	table.clear(self.Attributes)
end

return AttributeComponent
