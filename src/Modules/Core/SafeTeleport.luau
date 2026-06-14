local TeleportService = game:GetService("TeleportService")

local MAX_RETRIES = 5
local RETRY_DELAY = 3

TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
	warn(`{player.Name} 텔레포트 실패. 사유: {errorMessage}, {tostring(result)}`)
end)

return function(placeId, players, teleportOptions)
	local attempt = 0
	local success = false
	local errorMessage = ""

	repeat
		if typeof(placeId) ~= "number" then
			warn("플레이스의 Id가 숫자가 아님.")
			return
		end
		if typeof(players) ~= "table" or next(players) == nil then
			warn("플레이어 테이블이 비어있거나 테이블 타입이 아님.")
			return
		end

		attempt += 1

		success, errorMessage = pcall(function()
			return TeleportService:TeleportAsync(placeId, players, teleportOptions)
		end)

		if not success then
			warn("텔레포트 실패. 사유:", errorMessage)
			task.wait(RETRY_DELAY)
		end
	until success or attempt >= MAX_RETRIES

	if not success then
		warn("텔레포트 실패.")
	end

	return success, errorMessage
end
