local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local LocalSceneView = require(ReplicatedStorage.Shared.Modules.World.LocalSceneView)
local CurrencyRewardCard = require(ReplicatedStorage.UI.Components.CurrencyRewardCard)
local StageMapCard = require(ReplicatedStorage.UI.Components.StageMapCard)
local MapData = require(ReplicatedStorage.Settings.Data.MapData)
local MapProgression = require(ReplicatedStorage.Shared.Modules.Core.MapProgression)
local Config = require(ReplicatedStorage.Settings.Game.PartySettings)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local VIEW_ID = "StageSelection"
local BUTTON_IMAGE = "rbxassetid://139274506988816"
local CARD_IMAGE = "rbxassetid://91412212037031"
local SMALL_CARD_IMAGE = "rbxassetid://87496848270095"

local selectedMode = source("")
local selectedMap = source(Config.DefaultMap)
local selectedDifficulty = source(Config.DefaultDifficulty)
local party = source(nil :: any)
local busy = source(false)
local status = source("")
local dialog = source("")
local enteredCode = source("")
local partyIcon = source(nil :: any)
local PartyController
local UIController
local DataClient

local ERROR_MESSAGES = {
	NOT_LEADER = "Only the party leader can change the stage.",
	PARTY_FULL = "This party is full.",
	PARTY_NOT_FOUND = "That party no longer exists.",
	ALREADY_IN_PARTY = "Leave your current party first.",
	PARTY_BUSY = "The party is starting. Please wait.",
	RATE_LIMITED = "Please wait and try again.",
	MAP_UNAVAILABLE = "This stage is not available yet.",
	MAP_LOCKED = "Clear the previous chapter to unlock this stage.",
	STUDIO_TELEPORT_UNAVAILABLE = "Publish the experience to test teleporting.",
	DESTINATION_NOT_CONFIGURED = "The game destination is not configured.",
	RESERVATION_FAILED = "Could not create the match. Try again.",
	TELEPORT_FAILED = "Teleport failed. Try again.",
	TELEPORT_PARTIAL = "Some members left the lobby. Try again.",
	TELEPORT_TIMEOUT = "Teleport timed out. Try again.",
	NETWORK_ERROR = "Could not reach the server. Try again.",
	REQUEST_TIMEOUT = "The request timed out. Try again.",
	NOT_READY = "The party service is loading. Try again shortly.",
}

local function modeFor(mapName: string): string
	local definition = MapData[mapName]
	return if definition then definition.Mode else "Story"
end

local function currentStoryMap(): string
	return MapProgression.CurrentStoryMap(if DataClient then DataClient.MapClears() else nil)
end

local function isUnlocked(mapName: string): boolean
	return MapProgression.IsUnlocked(mapName, if DataClient then DataClient.MapClears() else nil)
end

local function rewardAmount(currencyName: string): number
	local definition = MapData[selectedMap()]
	local reward = definition and definition.Rewards[selectedDifficulty()]
	if not reward then
		return 0
	end
	if currencyName == "Coins" then
		return reward.WinCoins or 0
	elseif currencyName == "Exp" then
		return reward.WinExp or 0
	elseif currencyName == "Gems" then
		return reward.WinGems or 0
	end
	return 0
end

local function canEdit(): boolean
	local current = party()
	return not busy()
		and (current == nil or (current.LeaderUserId == Players.LocalPlayer.UserId and current.State == "Open"))
end

local function canStart(): boolean
	local current = party()
	if busy() or selectedMode() == "" or MapData[selectedMap()] == nil or not isUnlocked(selectedMap()) then
		return false
	end
	if not current then
		return true
	end
	return current.LeaderUserId == Players.LocalPlayer.UserId
		and (current.State == "Open" or (current.State == "Retryable"
			and current.Settings.Map == selectedMap()
			and current.Settings.Difficulty == selectedDifficulty()))
end

local function perform(callback: () -> any, onSuccess: ((any) -> ())?)
	if busy() then
		return
	end
	busy(true)
	status("")
	callback()
		:andThen(function(result)
			if result.Success then
				if onSuccess then
					onSuccess(result)
				end
			else
				status(ERROR_MESSAGES[result.Code] or `Could not complete the request ({result.Code}).`)
			end
		end)
		:finally(function()
			busy(false)
		end)
end

local function chooseMap(mapName: string)
	if not canEdit() or not MapData[mapName] or not isUnlocked(mapName) then
		return
	end
	selectedMap(mapName)
	local definition = MapData[mapName]
	if not table.find(definition.Difficulties, selectedDifficulty()) then
		selectedDifficulty(definition.Difficulties[1])
	end
end

local function startSelected()
	if not canStart() then
		return
	end
	local mapName = selectedMap()
	local difficulty = selectedDifficulty()
	perform(function()
		local current = party()
		if not current then
			return PartyController:CreateParty({ Map = mapName, Difficulty = difficulty }):andThen(function(result)
				return if result.Success then PartyController:StartParty() else result
			end)
		end
		if current.State == "Retryable" then
			return PartyController:StartParty()
		end
		if current.Settings.Map ~= mapName or current.Settings.Difficulty ~= difficulty then
			return PartyController:UpdateSettings({ Map = mapName, Difficulty = difficulty }):andThen(function(result)
				return if result.Success then PartyController:StartParty() else result
			end)
		end
		return PartyController:StartParty()
	end)
end

local function createInvite()
	if busy() then
		return
	end
	local function showInvite()
		if not UIController:IsOpen(VIEW_ID) then
			return
		end
		dialog("Invite")
		local player = Players.LocalPlayer
		task.spawn(function()
			local ok, allowed = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and allowed and dialog() == "Invite" then
				pcall(SocialService.PromptGameInvite, SocialService, player)
			end
		end)
	end
	if party() then
		local current = party()
		if canEdit() and (current.Settings.Map ~= selectedMap() or current.Settings.Difficulty ~= selectedDifficulty()) then
			perform(function()
				return PartyController:UpdateSettings({ Map = selectedMap(), Difficulty = selectedDifficulty() })
			end, showInvite)
			return
		end
		showInvite()
		return
	end
	perform(function()
		return PartyController:CreateParty({ Map = selectedMap(), Difficulty = selectedDifficulty() })
	end, showInvite)
end

local function label(name: string, value: any, position: UDim2, size: UDim2, fontSize: number?, alignment: Enum.TextXAlignment?, color: Color3?, transparency: any?)
	return create("TextLabel")({
		Name = name,
		BackgroundTransparency = 1,
		FontFace = FONT,
		Position = position,
		Size = size,
		Text = value,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextTransparency = transparency,
		TextSize = fontSize or 25,
		TextWrapped = true,
		TextXAlignment = alignment or Enum.TextXAlignment.Center,
		create("UIStroke")({ Thickness = 1.5, Color = Color3.fromRGB(16, 15, 26), Transparency = transparency }),
	})
end

local function actionButton(name: string, title: any, position: UDim2, size: UDim2, first: Color3, last: Color3, activated: () -> (), visible: any?, interactable: any?)
	return create("ImageButton")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = BUTTON_IMAGE,
		AutoButtonColor = false,
		Position = position,
		Size = size,
		Visible = visible,
		Interactable = interactable,
		Activated = activated,
		useButtonEffect(0.94, 1.05),
		create("UIGradient")({ Color = ColorSequence.new(first, last) }),
		create("UICorner")({ CornerRadius = UDim.new(0, 10) }),
		create("UIStroke")({ Color = Color3.new(1, 1, 1), Thickness = 1.5 }),
		label("Title", title, UDim2.fromScale(0.04, 0.15), UDim2.fromScale(0.92, 0.7), 21),
	})
end

local function overviewCard(mode: string, order: number, description: string)
	local story = mode == "Story"
	return create("ImageButton")({
		Name = mode,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Image = function()
			local mapName = if story then currentStoryMap() else "Raid"
			return (MapData[mapName] and MapData[mapName].MapImage) or CARD_IMAGE
		end,
		AutoButtonColor = false,
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.fromScale(0.49, 1),
		ClipsDescendants = true,
		useButtonEffect(0.98, 1.025),
		Activated = function()
			local targetMap = if story then currentStoryMap() else "Raid"
			local needsMap = modeFor(selectedMap()) ~= mode
			if not canEdit() and needsMap then
				status("Only the party leader can change the stage.")
				return
			end
			selectedMode(mode)
			if canEdit() and needsMap then
				chooseMap(targetMap)
			end
		end,
		create("UICorner")({ CornerRadius = UDim.new(0, 11) }),
		create("UIStroke")({ Color = Color3.fromRGB(10, 10, 10), Thickness = 4 }),
		label("Mode", mode, UDim2.fromScale(0.03, 0.045), UDim2.fromScale(0.38, 0.22), 25, Enum.TextXAlignment.Left, if story then Color3.fromRGB(8, 163, 255) else Color3.fromRGB(255, 45, 60)),
		label("CurrentMapCaption", "Current Map", UDim2.fromScale(0.03, 0.54), UDim2.fromScale(0.35, 0.1), 12, Enum.TextXAlignment.Left, if story then Color3.fromRGB(8, 163, 255) else Color3.fromRGB(255, 45, 60)),
		label("CurrentMap", function()
			return if story then currentStoryMap() else "Raid"
		end, UDim2.fromScale(0.03, 0.64), UDim2.fromScale(0.48, 0.17), 18, Enum.TextXAlignment.Left),
		create("Frame")({
			Name = "PreviewCards",
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.28,
			Position = UDim2.fromScale(0.57, 0.52),
			Size = UDim2.fromScale(0.41, 0.31),
			create("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.025, 0) }),
			create("UIPadding")({ PaddingLeft = UDim.new(0.03, 0), PaddingRight = UDim.new(0.03, 0) }),
			create("ImageLabel")({ Name = "Card1", LayoutOrder = 1, BackgroundTransparency = 1, Image = SMALL_CARD_IMAGE, Size = UDim2.fromScale(0.3, 0.82) }),
			create("ImageLabel")({ Name = "Card2", LayoutOrder = 2, BackgroundTransparency = 1, Image = SMALL_CARD_IMAGE, Size = UDim2.fromScale(0.3, 0.82) }),
			create("ImageLabel")({ Name = "Card3", LayoutOrder = 3, BackgroundTransparency = 1, Image = SMALL_CARD_IMAGE, Size = UDim2.fromScale(0.3, 0.82) }),
		}),
		create("Frame")({
			Name = "InfoStrip",
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.13,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.84),
			Size = UDim2.fromScale(1, 0.16),
			label("Description", description, UDim2.fromScale(0.03, 0), UDim2.fromScale(0.54, 1), 13, Enum.TextXAlignment.Left),
			label("SelectHint", "Click to Select", UDim2.fromScale(0.67, 0), UDim2.fromScale(0.27, 1), 12, Enum.TextXAlignment.Right),
			create("ImageLabel")({ Name = "Arrow", BackgroundTransparency = 1, Image = "rbxassetid://131761289623234", Position = UDim2.fromScale(0.94, 0.18), Size = UDim2.fromScale(0.05, 0.64) }),
		}),
	})
end

local function categoryCard(mapName: string, order: number)
	local definition = MapData[mapName]
	return StageMapCard({
		MapName = mapName,
		DisplayName = definition.MapName or mapName,
		Image = definition.MapImage,
		LayoutOrder = order,
		Visible = function()
			local mode = if selectedMode() ~= "" then selectedMode() else modeFor(selectedMap())
			return mode == definition.Mode and isUnlocked(mapName)
		end,
		Selected = function() return selectedMap() == mapName end,
		Activated = function() chooseMap(mapName) end,
	})
end

local function difficultyButton(difficulty: string, order: number, color: Color3, icon: string)
	return create("ImageButton")({
		Name = difficulty .. "Button",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Image = "rbxassetid://84567654650620",
		AutoButtonColor = false,
		Size = UDim2.fromScale(0.16, 1),
		useButtonEffect(0.92, 1.08),
		Visible = function()
			local definition = MapData[selectedMap()]
			return definition ~= nil and table.find(definition.Difficulties, difficulty) ~= nil
		end,
		Activated = function()
			if canEdit() then
				selectedDifficulty(difficulty)
			end
		end,
		create("UIGradient")({ Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 83)), Rotation = 90 }),
		create("UIStroke")({
			Color = Color3.new(1, 1, 1),
			Thickness = function()
				return if selectedDifficulty() == difficulty then 4 else 1
			end,
		}),
		create("ImageLabel")({ Name = "DifficultyIcon", BackgroundTransparency = 1, Image = icon, Position = UDim2.fromScale(0.12, 0.07), Size = UDim2.fromScale(0.76, 0.67) }),
		label("Title", string.upper(difficulty), UDim2.fromScale(-0.2, 0.76), UDim2.fromScale(1.4, 0.25), 15),
	})
end

local StageSelection = {}

function StageSelection.RenderUI()
	local isVisible = UIController:IsVisible(VIEW_ID)
	Vide.effect(function()
		if isVisible() and party() == nil and selectedMode() == "" and modeFor(selectedMap()) == "Story" then
			local latest = currentStoryMap()
			if selectedMap() ~= latest then selectedMap(latest) end
		end
	end)
	local sceneGeneration = 0
	local sceneView = nil
	local function stopScene()
		sceneGeneration += 1
		if sceneView then
			sceneView:Destroy()
			sceneView = nil
		end
	end
	Vide.effect(function()
		if not isVisible() then
			stopScene()
			return
		end
		sceneGeneration += 1
		local generation = sceneGeneration
		task.spawn(function()
			local assets = ReplicatedStorage:WaitForChild("Assets", 10)
			local source = assets and assets:WaitForChild("PartyMap", 10)
			if generation ~= sceneGeneration or not isVisible() then
				return
			end
			if not source then
				warn("[StageSelection] ReplicatedStorage.Assets.PartyMap was not found.")
				return
			end
			local view, sceneError = LocalSceneView.Mount(source, Config.PartySceneTransform, "Cam")
			if generation ~= sceneGeneration or not isVisible() then
				if view then view:Destroy() end
				return
			end
			if not view then
				warn(`[StageSelection] PartyMap could not be displayed: {sceneError}`)
				return
			end
			sceneView = view
		end)
	end)
	Vide.cleanup(stopScene)
	local menuMotion = useMenuMotion(isVisible, function()
		return UIController:GetActiveView()
	end)
	local isDetailVisible = function()
		return isVisible() and selectedMode() ~= ""
	end
	local detailMotion = useMenuMotion(isDetailVisible, function()
		local active = UIController:GetActiveView()
		return if active == VIEW_ID then nil else active
	end)
	local dialogScale = spring(function()
		return if dialog() ~= "" then 1 else 0.88
	end, 0.3, 0.8)
	local partyConnection = PartyController:ObserveParty(function(snapshot, event)
		local previous = party()
		party(snapshot)
		if snapshot then
			if MapData[snapshot.Settings.Map]
				and (not previous
					or previous.Id ~= snapshot.Id
					or previous.Settings.Map ~= snapshot.Settings.Map
					or previous.Settings.Difficulty ~= snapshot.Settings.Difficulty)
			then
				selectedMap(snapshot.Settings.Map)
				selectedDifficulty(snapshot.Settings.Difficulty)
				if selectedMode() ~= "" then
					selectedMode(modeFor(snapshot.Settings.Map))
				end
			end
			if snapshot.ErrorCode then
				status(ERROR_MESSAGES[snapshot.ErrorCode] or snapshot.ErrorCode)
			end
		elseif event and event.Reason then
			status(if event.Kind == "Disbanded" then "The party was disbanded." else "You left the party.")
		end
	end)
	Vide.cleanup(function()
		partyConnection:Disconnect()
	end)
	return create("CanvasGroup")({
		Name = "StageSelection",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = menuMotion.Transparency,
		Visible = menuMotion.IsMounted,
		Interactable = isVisible,
		ZIndex = 15,

		create("ScrollingFrame")({
			Name = "ScrollingFrame",
			Active = true,
			BackgroundTransparency = 1,
			Position = menuMotion:ContentPosition(UDim2.fromScale(0.53, 0.01)),
			Size = UDim2.fromScale(0.46, 0.3),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 0,
			create("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }),
			create("UIListLayout")({ Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
			label("ProgressiveHeader", "Progressive", UDim2.new(), UDim2.new(1, 0, 0, 35), 29, Enum.TextXAlignment.Left),
			create("Frame")({
				Name = "Modes",
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 150),
				create("UIAspectRatioConstraint")({ AspectRatio = 4.84, DominantAxis = Enum.DominantAxis.Width }),
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0.02, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				overviewCard("Story", 1, "Chapter 1 / Chapter 2"),
				overviewCard("Raid", 2, "Normal"),
			}),
		}),

		create("CanvasGroup")({
			Name = "MainMotion",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = function()
				return if isVisible() then detailMotion.Transparency() else 0
			end,
			Visible = detailMotion.IsMounted,
			Interactable = isDetailVisible,
			create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://111827625474404",
			Position = UDim2.fromScale(0.562, 0.448),
			Size = detailMotion:WindowSize(UDim2.fromScale(0.722, 0.594)),
			-- Keep the scroll clipping stable while the common window spring opens.
			Rotation = 0,
			create("UIAspectRatioConstraint")({ AspectRatio = 1.88 }),
			create("ImageLabel")({
				Name = "Header",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://76930813066161",
				Position = detailMotion:HeaderPosition(UDim2.fromScale(0.283, 0.029)),
				Size = UDim2.fromScale(0.683, 0.283),
				ZIndex = 10,
				create("ImageLabel")({ Name = "Star", BackgroundTransparency = 1, Image = "rbxassetid://122807208018817", Position = UDim2.fromScale(0.04, 0.1), Size = detailMotion:IconSize(UDim2.fromScale(0.185, 0.838)), Rotation = detailMotion:IconRotation() }),
				create("ImageLabel")({ Name = "Cloud", BackgroundTransparency = 1, Image = "rbxassetid://90808825729003", ImageTransparency = detailMotion:Fade(), Position = detailMotion:CloudPosition(UDim2.fromScale(0.53, 0.05)), Size = UDim2.fromScale(0.5, 1) }),
				label("Title", "Selecter", UDim2.fromScale(0.25, 0.35), UDim2.fromScale(0.33, 0.3), 30, nil, nil, detailMotion:Fade()),
			}),
			create("ImageButton")({
				Name = "CancelButton",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Image = "rbxassetid://92651860309635",
				Position = detailMotion:ClosePosition(UDim2.fromScale(0.94, -0.05)),
				Rotation = detailMotion:CloseRotation(),
				Size = UDim2.fromScale(0.08, 0.15),
				useButtonEffect(0.92, 1.1),
				Activated = function()
					selectedMode("")
				end,
			}),
			create("ScrollingFrame")({
				Name = "Category",
				Active = true,
				BackgroundTransparency = 1,
				Position = detailMotion:ContentPosition(UDim2.fromScale(0.015, 0.16)),
				Size = UDim2.fromScale(0.28, 0.72),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 0,
				create("UIPadding")({ PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }),
				create("UIListLayout")({ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
				categoryCard("Chapter 1", 1),
				categoryCard("Chapter 2", 2),
				categoryCard("Raid", 3),
			}),
			label("MapTitle", function()
				local definition = MapData[selectedMap()]
				return if definition then definition.MapName or selectedMap() else selectedMap()
			end, UDim2.fromScale(0.31, 0.18), UDim2.fromScale(0.61, 0.12), 33, Enum.TextXAlignment.Left, Color3.fromRGB(150, 255, 0)),
			label("Chapter", selectedMap, UDim2.fromScale(0.31, 0.29), UDim2.fromScale(0.61, 0.08), 21, Enum.TextXAlignment.Left),
			label("DifficultyLabel", "DIFFICULTY", UDim2.fromScale(0.31, 0.38), UDim2.fromScale(0.59, 0.06), 18, Enum.TextXAlignment.Left),
			create("Frame")({
				Name = "Difficulties",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.31, 0.45),
				Size = UDim2.fromScale(0.59, 0.17),
				create("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
				difficultyButton("Normal", 1, Color3.fromRGB(231, 175, 54), "rbxassetid://87053799690138"),
				difficultyButton("Hard", 2, Color3.fromRGB(255, 73, 67), "rbxassetid://127261433924496"),
				difficultyButton("Eternal", 3, Color3.fromRGB(182, 70, 236), "rbxassetid://130194707767691"),
			}),
			label("RewardLabel", "REWARD", UDim2.fromScale(0.31, 0.62), UDim2.fromScale(0.59, 0.06), 18, Enum.TextXAlignment.Left),
			create("ImageLabel")({
				Name = "Reward",
				BackgroundTransparency = 1,
				Image = "rbxassetid://133525559904889",
				Position = UDim2.fromScale(0.31, 0.68),
				Size = UDim2.fromScale(0.43, 0.18),
				create("Frame")({
					Name = "RewardCards",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					create("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
					create("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
					CurrencyRewardCard({ CurrencyName = "Coins", LayoutOrder = 1, Amount = function() return rewardAmount("Coins") end }),
					CurrencyRewardCard({ CurrencyName = "Gems", LayoutOrder = 2, Amount = function() return rewardAmount("Gems") end }),
					CurrencyRewardCard({ CurrencyName = "Exp", LayoutOrder = 3, Amount = function() return rewardAmount("Exp") end }),
				}),
			}),
			actionButton("PartyCancelButton", "CANCEL", UDim2.fromScale(0.466, 0.89), UDim2.fromScale(0.318, 0.1), Color3.fromRGB(255, 15, 40), Color3.fromRGB(252, 24, 182), function()
				selectedMode("")
			end),
			actionButton("SelectButton", function()
				local current = party()
				return if busy() then "WAIT" elseif current and current.State == "Retryable" then "RETRY" else "START"
			end, UDim2.fromScale(0.78, 0.89), UDim2.fromScale(0.318, 0.1), Color3.fromRGB(32, 255, 88), Color3.fromRGB(230, 255, 1), startSelected, nil, canStart),
			}),
		}),

		create("Frame")({
			Name = "BottomBar",
			BackgroundColor3 = Color3.new(),
			BorderSizePixel = 0,
			Position = menuMotion:ContentPosition(UDim2.fromScale(0, 0.9)),
			Size = UDim2.fromScale(1, 0.1),
			actionButton("Back", "BACK", UDim2.fromScale(0.075, 0.5), UDim2.fromScale(0.125, 0.7), Color3.fromRGB(140, 140, 140), Color3.fromRGB(58, 58, 58), StageSelection.Close),
			label("PartyStatus", function()
				local current = party()
				if status() ~= "" then
					return status()
				end
				if current then
					return `PARTY {#current.Members}/{current.MaxMembers}  •  {current.Settings.Map}  •  {current.Settings.Difficulty}`
				end
				return "Choose Story or Raid to play"
			end, UDim2.fromScale(0.17, 0.19), UDim2.fromScale(0.48, 0.62), 18, Enum.TextXAlignment.Left),
			actionButton("InvitePlayers", "INVITE PLAYERS", UDim2.fromScale(0.78, 0.5), UDim2.fromScale(0.125, 0.7), Color3.fromRGB(55, 255, 0), Color3.fromRGB(255, 238, 1), createInvite),
			actionButton("Play", function()
				return if party() then "LEAVE PARTY" else "JOIN PARTY"
			end, UDim2.fromScale(0.925, 0.5), UDim2.fromScale(0.125, 0.7), Color3.fromRGB(165, 61, 237), Color3.fromRGB(68, 38, 145), function()
				if party() then
					perform(function()
						return PartyController:LeaveParty()
					end)
				else
					dialog("Join")
				end
			end, nil, function()
				local current = party()
				return not busy() and (not current or current.State == "Open" or current.State == "Retryable")
			end),
		}),

		create("TextButton")({
			Name = "ModalBackdrop",
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			Visible = function()
				return dialog() ~= ""
			end,
			ZIndex = 19,
			Activated = function()
				dialog("")
			end,
		}),

		create("Frame")({
			Name = "PartyDialog",
			BackgroundColor3 = Color3.fromRGB(19, 18, 29),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.48),
			Size = function()
				local scale = dialogScale()
				return UDim2.fromScale(0.43 * scale, 0.26 * scale)
			end,
			Visible = function()
				return dialog() ~= ""
			end,
			ZIndex = 20,
			create("UICorner")({ CornerRadius = UDim.new(0, 14) }),
			create("UIStroke")({ Color = Color3.fromRGB(255, 226, 104), Thickness = 3 }),
			label("DialogTitle", function()
				return if dialog() == "Join" then "JOIN PARTY" else "INVITE PLAYERS"
			end, UDim2.fromScale(0.06, 0.09), UDim2.fromScale(0.88, 0.2), 26),
			create("TextBox")({
				Name = "PartyCode",
				BackgroundColor3 = Color3.fromRGB(48, 45, 65),
				Position = UDim2.fromScale(0.08, 0.37),
				Size = UDim2.fromScale(0.84, 0.22),
				ClearTextOnFocus = false,
				PlaceholderText = "Paste a party code",
				Text = function()
					local current = party()
					return if dialog() == "Invite" and current then current.Id else enteredCode()
				end,
				TextEditable = function()
					return dialog() == "Join" and not busy()
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 18,
				Vide.changed("Text", function(value)
					if dialog() == "Join" then
						enteredCode(string.sub(value, 1, 100))
					end
				end),
			}),
			actionButton("DialogCancel", "CLOSE", UDim2.fromScale(0.28, 0.79), UDim2.fromScale(0.35, 0.26), Color3.fromRGB(140, 140, 140), Color3.fromRGB(58, 58, 58), function()
				dialog("")
			end),
			actionButton("DialogJoin", "JOIN", UDim2.fromScale(0.73, 0.79), UDim2.fromScale(0.35, 0.26), Color3.fromRGB(165, 61, 237), Color3.fromRGB(68, 38, 145), function()
				local code = string.match(enteredCode(), "^%s*(.-)%s*$") or ""
				if code ~= "" then
					perform(function()
						return PartyController:JoinParty(code)
					end, function()
						enteredCode("")
						dialog("")
					end)
				end
			end, function()
				return dialog() == "Join"
			end, function()
				return not busy() and enteredCode() ~= ""
			end),
			label("DialogStatus", function()
				if status() ~= "" then
					return status()
				end
				return if dialog() == "Invite" then "Share this code with a friend in this lobby." else ""
			end, UDim2.fromScale(0.05, 0.59), UDim2.fromScale(0.9, 0.13), 15),
		}),
	})
end

function StageSelection.Open()
	if UIController and UIController:OpenExclusive(VIEW_ID) then
		DataClient.FetchMapClears()
		if not PartyController:GetCachedParty() then
			selectedMap(currentStoryMap())
		end
		selectedMode("")
		dialog("")
		status("")
		PartyController:GetParty()
	else
		local icon = partyIcon()
		if icon and icon.isSelected then
			icon:deselect()
		end
	end
end

function StageSelection.Close()
	if UIController then
		UIController:Close(VIEW_ID)
	end
	selectedMode("")
	dialog("")
	local icon = partyIcon()
	if icon and icon.isSelected then
		icon:deselect()
	end
end

function StageSelection.BindTopbarIcon(icon: any)
	partyIcon(icon)
end

function StageSelection.Init()
	PartyController = ServiceRegistry:GetService("PartyController")
	UIController = ServiceRegistry:GetService("UIController")
	DataClient = ServiceRegistry:GetService("DataClient")
end

function StageSelection.Start() end

return StageSelection
