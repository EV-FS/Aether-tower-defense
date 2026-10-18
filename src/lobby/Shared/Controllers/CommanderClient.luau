-- // VARIABLES // --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Net = require(ReplicatedStorage.Shared.Net.client)
local DialogueData = require(ReplicatedStorage.Settings.Data.CommanderDialogueData)
local DialogueClient = require(script.Parent.DialogueClient)
local UIController = require(script.Parent.UIController)

local CommanderClient = {}
CommanderClient.IsOpen = Vide.source(false)
CommanderClient.Rig = Vide.source(nil :: Model?)
CommanderClient.Text = Vide.source("")
CommanderClient.VisibleGraphemes = Vide.source(0)
CommanderClient.LineIndex = Vide.source(0)

local lineIndex = 0
local graphemeCount = 0
local progress = 0
local generation = 0
local requested = false
local connections: { RBXScriptConnection } = {}

-- // FUNCTIONS // --
--[[ Releases the active presentation without recording completion. ]]
local function closePresentation()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	CommanderClient.IsOpen(false)
	CommanderClient.Rig(nil)
end

--[[ Selects a passage and resets its reveal progress. ]]
local function setLine(index: number)
	lineIndex = index
	local text = DialogueData.Introduction[index]
	graphemeCount = 0
	for _ in utf8.graphemes(text) do
		graphemeCount += 1
	end
	progress = 0
	CommanderClient.VisibleGraphemes(0)
	CommanderClient.Text(text)
	CommanderClient.LineIndex(index)
end

--[[ Reports whether another interface currently owns the player's attention. ]]
function CommanderClient.CanPresent(): boolean
	return not DialogueClient.IsOpen() and UIController:GetActiveView() == nil
end

--[[ Reports whether the current passage is still being revealed. ]]
function CommanderClient.IsTyping(): boolean
	return CommanderClient.VisibleGraphemes() < graphemeCount
end

--[[ Reports whether this presentation can currently receive attention. ]]
function CommanderClient.IsVisible(): boolean
	return CommanderClient.IsOpen() and CommanderClient.CanPresent()
end

--[[ Reveals the passage or continues to the next one. ]]
function CommanderClient.Advance()
	if not CommanderClient.IsVisible() then
		return
	end
	if CommanderClient.VisibleGraphemes() < graphemeCount then
		progress = graphemeCount
		CommanderClient.VisibleGraphemes(graphemeCount)
	elseif lineIndex < #DialogueData.Introduction then
		setLine(lineIndex + 1)
	else
		closePresentation()
		Net.CommanderService.CompleteIntroduction.Fire()
	end
end

--[[ Starts an eligible player's introduction after the interface is ready. ]]
function CommanderClient.PlayIntroduction()
	if requested or #DialogueData.Introduction == 0 then
		return
	end
	requested = true
	generation += 1
	local token = generation
	local ok, result = pcall(function()
		local assets = ReplicatedStorage:WaitForChild("Assets", 15)
		local npcs = assets and assets:WaitForChild("NPC", 15)
		local commander = npcs and npcs:WaitForChild("Commander", 15)
		local rig = if commander and commander:IsA("Model") then commander
			else commander and commander:FindFirstChild("Rig")
		if not rig or not rig:IsA("Model") or not rig.Archivable then
			error("ReplicatedStorage.Assets.NPC.Commander must contain an Archivable rig Model")
		end
		if token ~= generation then
			return nil
		end
		local eligible = Net.CommanderService.RequestIntroduction.Invoke():expect()
		return if eligible then rig else nil
	end)
	if token ~= generation then
		return
	end
	if not ok then
		warn(`[CommanderClient] Introduction unavailable: {result}`)
		return
	end
	if not result then
		return
	end
	CommanderClient.Rig(result)
	setLine(1)
	CommanderClient.IsOpen(true)
	table.insert(connections, RunService.Heartbeat:Connect(function(deltaTime)
		if not CommanderClient.IsVisible() or CommanderClient.VisibleGraphemes() >= graphemeCount then
			return
		end
		progress = math.min(progress + deltaTime * DialogueData.CharactersPerSecond, graphemeCount)
		local visible = math.floor(progress)
		if visible ~= CommanderClient.VisibleGraphemes() then
			CommanderClient.VisibleGraphemes(visible)
		end
	end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local selected = GuiService.SelectedObject
		if selected and selected.Name == "Advance" and selected:FindFirstAncestor("CommanderDialogueGui") then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			CommanderClient.Advance()
		end
	end))
end

--[[ Cancels pending work and releases the current presentation. ]]
function CommanderClient.Destroy()
	generation += 1
	closePresentation()
end

-- // INITIALIZATION // --
return CommanderClient
