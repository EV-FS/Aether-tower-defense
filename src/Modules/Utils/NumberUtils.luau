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
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

function NumberUtils.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

return NumberUtils
