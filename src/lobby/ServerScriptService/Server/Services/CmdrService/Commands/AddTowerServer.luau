local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local PostWebHook = require(ServerScriptService.Server.Services.CmdrService.PostWebHook)
local DataService

return function(context, player: Player, towerName: string, amount: number)
	DataService = DataService or ServiceRegistry:GetService("DataService")
	for _ = 1, amount do
		DataService:AddTower(player, towerName)
	end

	PostWebHook(
		"♜타워 추가 커맨드 사용",
		"타워 추가 커맨드(addTower)가 사용되었습니다!",
		context.Executor,
		player,
		{
			["타워 이름"] = towerName,
			["수량"] = amount,
		}
	)

	return nil
end
