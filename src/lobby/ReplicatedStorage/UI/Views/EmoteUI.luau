local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local EmoteRadialMenu = require(ReplicatedStorage.Shared.Modules.UI.Emote.EmoteRadialMenu)
local EmoteOverlay = require(ReplicatedStorage.Shared.Modules.UI.Emote.EmoteOverlay)
local EmoteClient
local InventoryClient
local InputController
local UIController

local create = Vide.create
local effect = Vide.effect
local source = Vide.source

local VIEW_ID = "EmoteWheel"
local EmoteInput
local emoteIcon = source(nil :: any)
local equipMode = source(nil :: string?)
local equipPending = source(false)

local emoteSlots = {}
for slot = 1, 4 do
	table.insert(emoteSlots, function()
		if not InventoryClient then return nil end
		local emoteName = InventoryClient.GetEmoteSlot(slot)
		return emoteName and EmoteData.ByName[emoteName] or nil
	end)
end

local EmoteUI = {}

function EmoteUI.OnSelected(emoteName: string)
	if EmoteClient then
		EmoteClient.PlayEmote(emoteName)
	end

	EmoteUI.Close()
end

function EmoteUI.OnSlotSelected(slotIndex: number, emoteName: string?)
	local targetEmote = equipMode()
	if targetEmote then
		if equipPending() then return end
		equipPending(true)
		InventoryClient.EquipEmote(targetEmote, slotIndex):andThen(function(result)
			equipPending(false)
			if result.Success then
				EmoteUI.Close()
			else
				warn(`[EmoteUI] Could not equip emote: {result.Message}`)
			end
		end):catch(function(err)
			equipPending(false)
			warn(`[EmoteUI] Could not equip emote: {err}`)
		end)
		return
	end

	if emoteName then EmoteUI.OnSelected(emoteName) end
end

function EmoteUI.RenderUI()
	effect(function()
		local icon = emoteIcon()
		if not icon or not UIController then return end

		local isOpen = UIController:IsOpen(VIEW_ID)
		if isOpen and not icon.isSelected then
			icon:select()
		elseif not isOpen and icon.isSelected then
			icon:deselect()
		end
	end)

	return create("Frame")({
		Name = "EmoteUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),

		EmoteOverlay({
			Name = "EmoteOverlay",
			IsOpen = UIController:IsVisible(VIEW_ID),
			OnClose = function()
				EmoteUI.Close()
			end,
			Content = EmoteRadialMenu({
				Emotes = emoteSlots,
				OnSelected = EmoteUI.OnSelected,
				OnSlotSelected = EmoteUI.OnSlotSelected,
				SlotActionText = function()
					return if equipMode() then "Select slot" else "Tap to play"
				end,
			}),
		}),

		create("TextLabel")({
			Name = "EquipPrompt",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Font.fromEnum(Enum.Font.FredokaOne),
			Position = UDim2.fromScale(0.5, 0.08),
			Size = UDim2.fromScale(0.5, 0.08),
			Text = function()
				local emoteName = equipMode()
				return if emoteName then `EQUIP {string.upper(emoteName)} - SELECT A SLOT` else ""
			end,
			TextColor3 = Color3.fromRGB(135, 245, 255),
			TextScaled = true,
			Visible = function() return equipMode() ~= nil end,
			ZIndex = 50,
			create("UIStroke")({ Thickness = 2.5 }),
		}),
	})
end

function EmoteUI.BindTopbarIcon(icon: any)
	emoteIcon(icon)
end

function EmoteUI.Open()
	equipMode(nil)
	if UIController and not UIController:IsOpen(VIEW_ID) then
		InventoryClient.RefreshEmoteLoadout():catch(function(err)
			warn(`[EmoteUI] Could not refresh emote slots: {err}`)
		end)
		UIController:Open(VIEW_ID)
	end
end

function EmoteUI.OpenEquipMode(emoteName: string): boolean
	if not InventoryClient or not EmoteData.ByName[emoteName] or (InventoryClient.Emotes()[emoteName] or 0) <= 0 then
		return false
	end
	equipMode(emoteName)
	equipPending(false)
	local opened = UIController and UIController:Open(VIEW_ID) or false
	if not opened then
		equipMode(nil)
	end
	return opened
end

function EmoteUI.Close()
	if UIController and UIController:IsOpen(VIEW_ID) then
		local shouldReturnToInventory = equipMode() ~= nil
		equipMode(nil)
		equipPending(false)
		if shouldReturnToInventory then
			UIController:Open("Inventory")
		else
			UIController:Close(VIEW_ID)
		end
	end
end

function EmoteUI.Init()
	EmoteClient = ServiceRegistry:GetService("EmoteClient")
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	InputController = ServiceRegistry:GetService("InputController")
	UIController = ServiceRegistry:GetService("UIController")
end

function EmoteUI.Start()
	local iScope = InputController.Scope
	local iAction = InputController.Action
	local iInfo = InputController.Info

	EmoteInput = iScope("EmoteInput", {
		iAction("Toggle", iInfo({ Enum.KeyCode.E })),
	}):Enable()

	EmoteInput.Actions.Toggle.Began:Connect(function()
		if UIController:IsOpen(VIEW_ID) then EmoteUI.Close() else EmoteUI.Open() end
	end)

end

return EmoteUI
