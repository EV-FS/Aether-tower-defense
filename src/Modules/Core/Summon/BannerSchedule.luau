local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SummonConfig = require(ReplicatedStorage.Settings.Data.SummonConfig)

local BannerSchedule = {}

local INTERVAL = SummonConfig.BannerTimerDuration
local KST_OFFSET = 9 * 60 * 60

-- Unix timestamps remain the wire format. Offset before dividing so each
-- interval is explicitly anchored to Korean local :00 and :30 boundaries.
function BannerSchedule.GetSlot(timestamp: number): number
	return math.floor((timestamp + KST_OFFSET) / INTERVAL)
end

function BannerSchedule.GetNextChange(timestamp: number): number
	return (BannerSchedule.GetSlot(timestamp) + 1) * INTERVAL - KST_OFFSET
end

function BannerSchedule.FormatKST(timestamp: number): string
	local localSeconds = (math.floor(timestamp) + KST_OFFSET) % (24 * 60 * 60)
	return string.format("%02d:%02d", math.floor(localSeconds / 3600), math.floor(localSeconds % 3600 / 60))
end

return table.freeze(BannerSchedule)
