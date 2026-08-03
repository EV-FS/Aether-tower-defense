local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

local activeView = source(nil :: string?)
local isLocked = source(false)

local UIController = {}

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

function UIController:Open(name: string): boolean
	if isLocked() or name == "" then
		return false
	end

	activeView(name)
	return true
end

function UIController:Close(name: string): boolean
	if isLocked() or activeView() ~= name then
		return false
	end

	activeView(nil)
	return true
end

function UIController:CloseAll(): boolean
	if isLocked() or activeView() == nil then
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
