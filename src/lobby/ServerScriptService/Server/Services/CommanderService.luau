-- // VARIABLES // --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local CommanderService = { Dependencies = { "DataService" } }
local DataService
local issued: { [Player]: boolean } = {}
local requested: { [Player]: boolean } = {}
local connections: { RBXScriptConnection } = {}
local disconnectComplete: (() -> ())?

-- // FUNCTIONS // --
--[[ Determines whether the player has an introduction to finish. ]]
local function requestIntroduction(player: Player): boolean
	if requested[player] then
		return false
	end
	requested[player] = true
	local data = DataService:GetData(player)
	if player.Parent ~= Players or not data or data.CommanderIntroductionSeen then
		return false
	end
	issued[player] = true
	return true
end

--[[ Records completion for an introduction offered to this player. ]]
local function completeIntroduction(player: Player)
	if not issued[player] then
		return
	end
	issued[player] = nil
	local data = DataService:GetData(player)
	if player.Parent ~= Players or not data or data.CommanderIntroductionSeen then
		return
	end
	DataService:UpdateData(player, "CommanderIntroductionSeen", true)
	DataService:SaveData(player)
end

--[[ Resolves the owner of persistent player progress. ]]
function CommanderService.Init(registry)
	DataService = registry:GetService("DataService")
end

--[[ Begins accepting introduction requests. ]]
function CommanderService.Start()
	Net.CommanderService.RequestIntroduction.On(requestIntroduction)
	disconnectComplete = Net.CommanderService.CompleteIntroduction.On(completeIntroduction)
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		issued[player] = nil
		requested[player] = nil
	end))
end

--[[ Releases listeners and outstanding offers. ]]
function CommanderService.Destroy()
	Net.CommanderService.RequestIntroduction.On(function()
		return false
	end)
	if disconnectComplete then
		disconnectComplete()
		disconnectComplete = nil
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(issued)
	table.clear(requested)
end

-- // INITIALIZATION // --
return CommanderService
