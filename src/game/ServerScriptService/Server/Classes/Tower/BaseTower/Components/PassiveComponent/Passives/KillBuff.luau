local KillBuff = {}
KillBuff.__index = KillBuff

function KillBuff.new(tower, config, fireTriggered)
	local self = setmetatable({}, KillBuff)
	self.Config = config

	return self
end

function KillBuff:UpdateConfig(newConfig)
	self.Config = newConfig
end

function KillBuff:Destroy() end

return KillBuff
