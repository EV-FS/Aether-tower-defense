local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local NotificationFeed = require(ReplicatedStorage.Shared.Modules.UI.Notifications.NotificationFeed)
local UnitCatalog = require(ReplicatedStorage.Settings.Data.UnitCatalog)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local StageSelection = require(script.Parent.StageSelectionUI)

local create = Vide.create
local source = Vide.source
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local invite = source(nil :: any)
local responding = source(false)
local PartyController

local PartyInvitePromptUI = {}

local function caption(name: string, value: any, position: UDim2, size: UDim2, color: Color3?)
	return create("TextLabel")({
		Name = name,
		BackgroundTransparency = 1,
		FontFace = FONT,
		Position = position,
		Size = size,
		Text = value,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		create("UIStroke")({ Color = Color3.new(), Thickness = 1.5 }),
	})
end

local function responseButton(name: string, title: string, position: UDim2, first: Color3, last: Color3, activated: () -> ())
	return create("ImageButton")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromScale(0.28, 0.17),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Image = "rbxassetid://83967774994235",
		Interactable = function() return not responding() end,
		Activated = activated,
		useButtonEffect(0.94, 1.05),
		create("UIGradient")({ Color = ColorSequence.new(first, last) }),
		create("UIStroke")({ Color = first, Thickness = 1.5 }),
		create("UICorner")({ CornerRadius = UDim.new(0, 5) }),
		caption("Title", title, UDim2.fromScale(0.2, 0.2), UDim2.fromScale(0.65, 0.6)),
	})
end

local function deckSlot(index: number)
	return create("ImageLabel")({
		Name = `Unit_{index}`,
		LayoutOrder = index,
		Size = UDim2.fromScale(0.155, 0.95),
		BackgroundTransparency = 1,
		Image = "rbxassetid://87496848270095",
		create("UIAspectRatioConstraint")({ AspectRatio = 0.8, DominantAxis = Enum.DominantAxis.Height }),
		create("ImageLabel")({
			Name = "UnitImage",
			Position = UDim2.fromScale(0.08, 0.08),
			Size = UDim2.fromScale(0.84, 0.84),
			BackgroundTransparency = 1,
			Image = function()
				local current = invite()
				local name = current and current.Loadout[index] or ""
				return UnitCatalog.GetImage(name)
			end,
		}),
	})
end

local function respond(accept: boolean)
	local current = invite()
	if not current or responding() then return end
	responding(true)
	PartyController:RespondInvite(current.Id, accept):andThen(function(result)
		if invite() == current then invite(nil) end
		if not result.Success then
			NotificationFeed.Pull(`Party invitation failed ({result.Code}).`, "Error")
		elseif accept then
			StageSelection.Open()
		end
	end):finally(function() responding(false) end)
end

function PartyInvitePromptUI.Init()
	PartyController = ServiceRegistry:GetService("PartyController")
end

function PartyInvitePromptUI.RenderUI()
	local connection = PartyController:ObserveInvites(function(incoming)
		if PartyController:GetCachedParty() then return end
		invite(incoming)
		responding(false)
		local id = incoming.Id
		task.delay(math.max(0, incoming.ExpiresAt - workspace:GetServerTimeNow()), function()
			local current = invite()
			if current and current.Id == id then invite(nil) end
		end)
	end)
	local partyConnection = PartyController:ObserveParty(function(current)
		if current then invite(nil) end
	end)
	Vide.cleanup(function() connection:Disconnect(); partyConnection:Disconnect(); invite(nil) end)
	return create("CanvasGroup")({
		Name = "PartyInvitePrompt",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = function() return invite() ~= nil end,
		ZIndex = 60,
		create("TextButton")({
			Name = "Backdrop",
			Size = UDim2.fromScale(1, 1),
			Text = "",
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.4,
			Activated = function() respond(false) end,
		}),
		create("ImageLabel")({
			Name = "RequestFrame",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(0.4465, 0.48),
			BackgroundTransparency = 1,
			Image = "rbxassetid://76428524579923",
			create("UIAspectRatioConstraint")({ AspectRatio = 1.91 }),
			create("ImageLabel")({
				Name = "Avatar",
				Position = UDim2.fromScale(0.05, 0.08),
				Size = UDim2.fromScale(0.19, 0.39),
				BackgroundColor3 = Color3.fromRGB(30, 30, 40),
				Image = function()
					local current = invite()
					return if current then `rbxthumb://type=AvatarHeadShot&id={current.FromUserId}&w=150&h=150` else ""
				end,
				create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
				create("UIStroke")({ Color = Color3.fromRGB(75, 75, 75), Thickness = 2 }),
			}),
			caption("Name", function()
				local current = invite()
				return if current then `{current.FromDisplayName} invited you to a party` else ""
			end, UDim2.fromScale(0.29, 0.1), UDim2.fromScale(0.58, 0.15)),
			caption("Level", function()
				local current = invite()
				return if current then `LV. {current.FromLevel}  /  @{current.FromName}` else ""
			end, UDim2.fromScale(0.29, 0.27), UDim2.fromScale(0.55, 0.1), Color3.fromRGB(145, 160, 255)),
			create("Frame")({
				Name = "PartyDetails",
				Position = UDim2.fromScale(0.06, 0.4),
				Size = UDim2.fromScale(0.88, 0.13),
				BackgroundColor3 = Color3.fromRGB(15, 15, 20),
				create("UICorner")({ CornerRadius = UDim.new(0, 7) }),
				create("UIStroke")({ Color = Color3.fromRGB(75, 75, 75), Thickness = 2 }),
				caption("Stage", function()
					local current = invite()
					return if current then `{current.Map}  /  {current.Difficulty}  /  {current.MemberCount}/4` else ""
				end, UDim2.fromScale(0.05, 0.2), UDim2.fromScale(0.9, 0.6)),
			}),
			create("Frame")({
				Name = "UnitDeck",
				Position = UDim2.fromScale(0.05, 0.56),
				Size = UDim2.fromScale(0.9, 0.22),
				BackgroundTransparency = 1,
				create("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.014, 0), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
			deckSlot(1), deckSlot(2), deckSlot(3),
			deckSlot(4), deckSlot(5), deckSlot(6),
			}),
			responseButton("AcceptButton", "ACCEPT", UDim2.fromScale(0.33, 0.85), Color3.fromRGB(55, 255, 0), Color3.fromRGB(255, 238, 1), function() respond(true) end),
			responseButton("DenyButton", "DENY", UDim2.fromScale(0.66, 0.85), Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 6, 209), function() respond(false) end),
			create("ImageButton")({ Name = "CancelButton", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.95, 0.09), Size = UDim2.fromScale(0.13, 0.25), BackgroundTransparency = 1, Image = "rbxassetid://92651860309635", Activated = function() respond(false) end, useButtonEffect(0.92, 1.1), create("UIAspectRatioConstraint")({}) }),
		}),
	})
end

function PartyInvitePromptUI.Destroy()
	invite(nil)
end

return PartyInvitePromptUI
