local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local NotificationFeed = require(ReplicatedStorage.Shared.Modules.UI.Notifications.NotificationFeed)
local EmojiData = require(ReplicatedStorage.Settings.Data.EmojiData)
local EmojiWheel = require(ReplicatedStorage.UI.Components.EmojiWheel)
local EmoteOverlay = require(ReplicatedStorage.Shared.Modules.UI.Emote.EmoteOverlay)

local create = Vide.create
local source = Vide.source

local VIEW_ID = "EmojiWheel"
local equipMode = source(nil :: string?)
local equipPending = source(false)
local returnView = source(nil :: string?)
local EmojiClient
local InventoryClient
local InputController
local UIController

local emojiSlots = {}
for slot = 1, 4 do
	table.insert(emojiSlots, function()
		if not InventoryClient then return nil end
		local emojiId = InventoryClient.GetEmojiSlot(slot)
		local config = emojiId and EmojiData.ByName[emojiId]
		if not config then return nil end
		return {
			Id = config.Id,
			Name = config.Id,
			DisplayName = config.DisplayName,
			Image = config.Image,
			Symbol = config.Symbol,
		}
	end)
end

local EmojiUI = {}

function EmojiUI.OnSelected(emojiId: string)
	if EmojiClient then EmojiClient.ShowEmoji(emojiId) end
	EmojiUI.Close()
end

function EmojiUI.OnSlotSelected(slot: number, emojiId: string?)
	local target = equipMode()
	if target then
		if equipPending() then return end
		equipPending(true)
		InventoryClient.EquipEmoji(target, slot):andThen(function(result)
			equipPending(false)
			if result.Success then
				EmojiUI.Close()
			else
				NotificationFeed.Pull(result.Message or "Could not equip emoji.", "Error")
			end
		end):catch(function(err)
			equipPending(false)
			NotificationFeed.Pull(`Could not equip emoji: {tostring(err)}`, "Error")
		end)
		return
	end
	if emojiId then EmojiUI.OnSelected(emojiId) end
end

function EmojiUI.RenderUI()
	return create("Frame")({
		Name = "EmojiUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		EmoteOverlay({
			Name = "EmojiOverlay",
			IsOpen = UIController:IsVisible(VIEW_ID),
			OnClose = function()
				if not equipPending() then EmojiUI.Close() end
			end,
			Content = EmojiWheel({
				Emojis = emojiSlots,
				EquipMode = function() return equipMode() ~= nil end,
				InteractionDisabled = equipPending,
				OnSelected = EmojiUI.OnSelected,
				OnSlotSelected = EmojiUI.OnSlotSelected,
			}),
		}),
	})
end

function EmojiUI.Open()
	equipMode(nil)
	returnView(nil)
	if UIController and not UIController:IsOpen(VIEW_ID) then
		InventoryClient.RefreshEmojiLoadout():catch(function(err)
			warn(`[EmojiUI] Could not refresh emoji slots: {err}`)
		end)
		UIController:Open(VIEW_ID)
	end
end

function EmojiUI.OpenEquipMode(emojiId: string): boolean
	if not InventoryClient or not EmojiData.ByName[emojiId]
		or (InventoryClient.Emojis()[emojiId] or 0) <= 0 then
		return false
	end
	local previousView = UIController and UIController:GetActiveView() or nil
	local opened = UIController and UIController:OpenExclusive(VIEW_ID) or false
	if not opened then return false end
	returnView(previousView or "Inventory")
	equipMode(emojiId)
	equipPending(false)
	return true
end

function EmojiUI.Close()
	if UIController and UIController:IsOpen(VIEW_ID) then
		if equipPending() then return end
		local targetView = returnView()
		equipMode(nil)
		equipPending(false)
		returnView(nil)
		UIController:Close(VIEW_ID)
		if targetView and targetView ~= VIEW_ID then UIController:Open(targetView) end
	end
end

function EmojiUI.Init()
	EmojiClient = ServiceRegistry:GetService("EmojiClient")
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	InputController = ServiceRegistry:GetService("InputController")
	UIController = ServiceRegistry:GetService("UIController")
end

function EmojiUI.Start()
	local scope = InputController.Scope("EmojiInput", {
		InputController.Action("Toggle", InputController.Info({ Enum.KeyCode.B })),
	}):Enable()
	scope.Actions.Toggle.Began:Connect(function()
		if equipPending() then return end
		if UIController:IsOpen(VIEW_ID) then EmojiUI.Close() else EmojiUI.Open() end
	end)
end

return EmojiUI
