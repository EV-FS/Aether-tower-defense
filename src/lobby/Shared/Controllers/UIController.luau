local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Topbarplus = require(ReplicatedStorage.Packages.Topbarplus)

local source = Vide.source

local activeView = source(nil :: string?)
local isLocked = source(false)
local exclusiveView = source(nil :: string?)

local CORE_GUI_TYPES = {
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.Health,
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.EmotesMenu,
}

local focusModeActive = false
local topbarWasEnabled = true
local coreGuiState = {}

local UIController = {}

local function setFocusMode(enabled: boolean)
	if focusModeActive == enabled then
		return
	end

	focusModeActive = enabled
	if enabled then
		topbarWasEnabled = Topbarplus.topbarEnabled ~= false
		Topbarplus.setTopbarEnabled(false)

		table.clear(coreGuiState)
		for _, coreGuiType in CORE_GUI_TYPES do
			local readSuccess, wasEnabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, coreGuiType)
			if readSuccess then
				coreGuiState[coreGuiType] = wasEnabled
				pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreGuiType, false)
			end
		end
		return
	end

	Topbarplus.setTopbarEnabled(topbarWasEnabled)
	for coreGuiType, wasEnabled in coreGuiState do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreGuiType, wasEnabled)
	end
	table.clear(coreGuiState)
end

function UIController:IsOpen(name: string): boolean
	return activeView() == name
end

function UIController:IsVisible(name: string): () -> boolean
	return function()
		return activeView() == name
	end
end

function UIController:GetActiveView(): string?
	return activeView()
end

function UIController:IsExclusive(): boolean
	return exclusiveView() ~= nil
end

function UIController:Open(name: string): boolean
	local exclusive = exclusiveView()
	if isLocked() or name == "" or (exclusive ~= nil and exclusive ~= name) then
		return false
	end

	activeView(name)
	return true
end

function UIController:OpenExclusive(name: string): boolean
	if isLocked() or name == "" then
		return false
	end

	setFocusMode(true)
	exclusiveView(name)
	activeView(name)
	return true
end

function UIController:Close(name: string): boolean
	if isLocked() or activeView() ~= name then
		return false
	end

	activeView(nil)
	if exclusiveView() == name then
		exclusiveView(nil)
		setFocusMode(false)
	end
	return true
end

function UIController:CloseAll(): boolean
	if isLocked() or exclusiveView() ~= nil or activeView() == nil then
		return false
	end

	activeView(nil)
	return true
end

function UIController:Toggle(name: string): boolean
	if self:IsOpen(name) then
		return self:Close(name)
	end

	return self:Open(name)
end

function UIController:Lock(locked: boolean)
	isLocked(locked)
end

function UIController.Init() end
function UIController.Start() end

return UIController
