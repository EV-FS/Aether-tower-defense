local KillBuff = {}
KillBuff.__index = KillBuff

function KillBuff.new(tower, config, fireTriggered)
	local self = setmetatable({}, KillBuff)

	return self
end

function KillBuff:Destroy() end

return KillBuff
