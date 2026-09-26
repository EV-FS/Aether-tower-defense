local Slow = {}
Slow.__index = Slow

function Slow.new(tower, config, _)
	local self = setmetatable({}, Slow)
	self.Config = config

	self.Connection = tower:GetEvent("AfterDamaged"):Connect(function(enemy)
		if not enemy then
			return
		end

		enemy:ApplyDebuff("Slow", self.Config.Duration, self.Config.Amount)
	end)

	return self
end

function Slow:UpdateConfig(newConfig)
	self.Config = newConfig
end

function Slow:Destroy()
	self.Connection:Disconnect()
end

return Slow
