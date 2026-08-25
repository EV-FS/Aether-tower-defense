local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local PostWebHook = require(ServerScriptService.Server.Services.CmdrService.PostWebHook)
local DataService

return function(
	context,
	player: Player,
	timezone: "UTC" | "KST",
	year: number,
	month: number,
	day: number,
	hour: number,
	minute: number,
	second: number
)
	if timezone ~= "UTC" and timezone ~= "KST" then
		return "timezone은 UTC 또는 KST만 가능함"
	end

	local timestamp = DateTime.fromUniversalTime(year, month, day, hour, minute, second).UnixTimestamp

	DataService = DataService or ServiceRegistry:GetService("DataService")
	DataService:_RollbackData(player, timestamp, timezone == "UTC")
	PostWebHook(
		"⌛롤백 커맨드 사용",
		"롤백 커맨드(RollbackData)가 사용되었습니다!",
		context.Executor,
		player,
		`{timezone} {timestamp}`
	)

	return nil
end
