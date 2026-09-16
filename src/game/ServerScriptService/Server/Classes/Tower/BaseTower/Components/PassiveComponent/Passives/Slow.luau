local Slow = {}
Slow.__index = Slow

function Slow.new(tower, config, _)
	local self = setmetatable({}, Slow)

	self.Connection = tower:GetEvent("AfterDamaged"):Connect(function(enemy)
		if not enemy then
			return
		end

		enemy:ApplyDebuff("Slow", config.Duration, config.Amount)
	end)

	return self
end

function Slow:Destroy()
	self.Connection:Disconnect()
end

return Slow
