local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local PostWebHook = require(ServerScriptService.Server.Services.CmdrService.PostWebHook)
local DataService

return function(context, player: Player, currencyName: string, amount: number)
	DataService = DataService or ServiceRegistry:GetService("DataService")
	if not DataService:GetData(player) or DataService:IsLocked(player) then
		return `Data is still loading for {player.Name}.`
	end
	if amount < 0 and not DataService:CanAfford(player, currencyName, -amount) then
		return `Not enough available {currencyName} to remove {-amount}.`
	end
	if DataService:AddData(player, currencyName, amount) == nil then
		return `Could not update {currencyName} for {player.Name}.`
	end
	PostWebHook(
		"💵재화 커맨드 사용",
		"재화 커맨드(AddCurrency)가 사용되었습니다!",
		context.Executor,
		player,
		{
			["재화 이름"] = currencyName,
			["수량"] = amount,
		}
	)

	return nil
end
