local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local PostWebHook = require(ServerScriptService.Server.Services.CmdrService.PostWebHook)
local DataService

return function(context, player: Player)
	DataService = DataService or ServiceRegistry:GetService("DataService")
	DataService:ClearData(player)

	PostWebHook(
		"데이터 초기화 커맨드 사용",
		"데이터 초기화 커맨드(ClearData)가 사용되었습니다!",
		context.Executor,
		player,
		{
			["레김이"] = "잘생김",
		}
	)

	return nil
end
