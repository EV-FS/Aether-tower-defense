-- // VARIABLES // --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommanderClient = require(ReplicatedStorage.Shared.Controllers.CommanderClient)
local CommanderDialogueView = require(ReplicatedStorage.Shared.Modules.UI.Commander.CommanderDialogueView)

local CommanderDialogueUI = {}

-- // FUNCTIONS // --
--[[ Presents the lobby introduction through the shared dialogue view. ]]
function CommanderDialogueUI.RenderUI()
	return CommanderDialogueView.RenderUI(CommanderClient)
end

--[[ Releases the introduction when its interface is removed. ]]
function CommanderDialogueUI.Destroy()
	CommanderClient.Destroy()
end

-- // INITIALIZATION // --
return CommanderDialogueUI
