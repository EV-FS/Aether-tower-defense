local Bleed = {}
Bleed.__index = Bleed

function Bleed.new(tower, config, _)
	local self = setmetatable({}, Bleed)
	self.Config = config

	self.Connection = tower:GetEvent("AfterDamaged"):Connect(function(enemy)
		if not enemy then
			return
		end

		enemy:ApplyDebuff("Bleed", self.Config.Duration, self.Config.Amount, tower)
	end)

	return self
end

function Bleed:UpdateConfig(newConfig)
	self.Config = newConfig
end

function Bleed:Destroy()
	self.Connection:Disconnect()
end

return Bleed
