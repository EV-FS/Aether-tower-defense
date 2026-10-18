-- // VARIABLES // --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommanderBattleClient = require(ReplicatedStorage.Shared.Services.System.CommanderBattleClient)
local CommanderDialogueView = require(ReplicatedStorage.Shared.Modules.UI.Commander.CommanderDialogueView)
local ChapterData = require(ReplicatedStorage.Settings.Data.CommanderChapterData)

local CommanderDialogueUI = {}

-- // FUNCTIONS // --
--[[ Presents combat messages using the shared commander interface. ]]
function CommanderDialogueUI.RenderUI()
	return CommanderDialogueView.RenderUI(CommanderBattleClient, ChapterData.Layout)
end

--[[ Starts combat dialogue after the interface has mounted. ]]
function CommanderDialogueUI.Start()
	CommanderBattleClient.Start()
end

--[[ Releases combat dialogue with its owning interface. ]]
function CommanderDialogueUI.Destroy()
	CommanderBattleClient.Destroy()
end

-- // INITIALIZATION // --
return CommanderDialogueUI
