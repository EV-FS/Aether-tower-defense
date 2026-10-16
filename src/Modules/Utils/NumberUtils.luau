local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TimeService

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

local NumberUtils = {}

function NumberUtils.FormatComma(num: number): string
	local str = tostring(num)
	local integer, decimal = str:match("^(%-?%d+)(%.?%d*)$")

	if not integer then
		return str
	end

	integer = integer:reverse():gsub("(%d%d%d)", "%1,"):gsub(",$", ""):reverse()

	return integer .. decimal
end

function NumberUtils.Abbreviate(num: number, decimalPlaces: number?): string
	local dp = decimalPlaces or 1
	local absNum = math.abs(num)
	local isNegative = num < 0

	if absNum < 1000 then
		return tostring(math.floor(num + 0.5))
	end

	local index = math.floor(math.log10(absNum) / 3)
	local suffix = SUFFIXES[math.min(index + 1, #SUFFIXES)]
	local value = absNum / (10 ^ (index * 3))

	local formatStr = "%." .. dp .. "f%s"
	local result = string.format(formatStr, value, suffix):gsub("%.0+$", "")

	return (isNegative and "-" or "") .. result
end

function NumberUtils.FormatTime(seconds: number): string
	if seconds < 0 then
		return "00:00"
	end

	local days = math.floor(seconds / 86400)
	local hours = math.floor(seconds % 86400 / 3600)
	local mins = math.floor(seconds % 3600 / 60)
	local secs = math.floor(seconds % 60)

	if days > 0 then
		return string.format("%dd %02dh", days, hours)
	elseif hours > 0 then
		return string.format("%d:%02d:%02d", hours, mins, secs)
	end

	return string.format("%02d:%02d", mins, secs)
end

function NumberUtils.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function NumberUtils.FormatSendClockTime(): number
	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	return TimeService:Now()
end

function NumberUtils.FormatSendClockTimeMs(): number
	return math.floor(NumberUtils.FormatSendClockTime() * 1000)
end

function NumberUtils.GetClockPingTime(sentClockTime: number): number
	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	return math.max(0, TimeService:Now() - sentClockTime)
end

return NumberUtils
