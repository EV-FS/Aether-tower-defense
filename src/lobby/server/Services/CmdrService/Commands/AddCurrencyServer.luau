local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local PostWebHook = require(ServerScriptService.Server.Services.CmdrService.PostWebHook)
local DataService

return function(context, player: Player, currencyName: string, amount: number)
	DataService = DataService or ServiceRegistry:GetService("DataService")
	DataService:AddData(player, currencyName, amount)
	PostWebHook(
		"💵재화 커맨드 사용",
		"재화 커맨드(addCurrency)가 사용되었습니다!",
		context.Executor,
		player,
		{
			["재화 이름"] = currencyName,
			["수량"] = amount,
		}
	)

	return nil
end
