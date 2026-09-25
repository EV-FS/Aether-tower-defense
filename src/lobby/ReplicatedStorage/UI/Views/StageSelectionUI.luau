local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local MapData = require(ReplicatedStorage.Settings.Data.MapData)
local Config = require(ReplicatedStorage.Settings.Game.PartySettings)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)

local create = Vide.create
local source = Vide.source
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local VIEW_ID = "StageSelection"
local BUTTON_IMAGE = "rbxassetid://139274506988816"
local CARD_IMAGE = "rbxassetid://91412212037031"

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

local ERROR_MESSAGES = {
	NOT_LEADER = "Only the party leader can change the stage.",
	PARTY_FULL = "This party is full.",
	PARTY_NOT_FOUND = "That party no longer exists.",
	ALREADY_IN_PARTY = "Leave your current party first.",
	PARTY_BUSY = "The party is starting. Please wait.",
	RATE_LIMITED = "Please wait and try again.",
	MAP_UNAVAILABLE = "This stage is not available yet.",
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
	return if mapName == "Chapter 1" or mapName == "Chapter 2" then "Story" else "Raid"
end

local function canEdit(): boolean
	local current = party()
	return not busy()
		and (current == nil or (current.LeaderUserId == Players.LocalPlayer.UserId and current.State == "Open"))
end

local function canStart(): boolean
	local current = party()
	if busy() or selectedMode() == "" or MapData[selectedMap()] == nil then
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
	if not canEdit() or not MapData[mapName] then
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

local function label(name: string, value: any, position: UDim2, size: UDim2, fontSize: number?, alignment: Enum.TextXAlignment?)
	return create("TextLabel")({
		Name = name,
		BackgroundTransparency = 1,
		FontFace = FONT,
		Position = position,
		Size = size,
		Text = value,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = fontSize or 25,
		TextWrapped = true,
		TextXAlignment = alignment or Enum.TextXAlignment.Center,
		create("UIStroke")({ Thickness = 1.5, Color = Color3.fromRGB(16, 15, 26) }),
	})
end

local function actionButton(name: string, title: any, position: UDim2, size: UDim2, first: Color3, last: Color3, activated: () -> (), visible: any?, interactable: any?)
	return create("ImageButton")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = BUTTON_IMAGE,
		Position = position,
		Size = size,
		Visible = visible,
		Interactable = interactable,
		Activated = activated,
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
		Image = CARD_IMAGE,
		Size = UDim2.new(0.47, 0, 0, 215),
		Activated = function()
			local needsMap = if story then modeFor(selectedMap()) ~= "Story" else selectedMap() ~= "Raid"
			if not canEdit() and needsMap then
				status("Only the party leader can change the stage.")
				return
			end
			selectedMode(mode)
			if canEdit() and needsMap then
				chooseMap(if story then "Chapter 1" else "Raid")
			end
		end,
		create("UICorner")({ CornerRadius = UDim.new(0, 12) }),
		create("UIStroke")({ Color = Color3.fromRGB(245, 227, 147), Thickness = 3 }),
		label("Mode", string.upper(mode), UDim2.fromScale(0.06, 0.07), UDim2.fromScale(0.55, 0.22), 34, Enum.TextXAlignment.Left),
		label("CurrentMap", function()
			return if story then (if modeFor(selectedMap()) == "Story" then selectedMap() else "Chapter 1") else "Raid"
		end, UDim2.fromScale(0.06, 0.54), UDim2.fromScale(0.85, 0.16), 23, Enum.TextXAlignment.Left),
		label("Description", description, UDim2.fromScale(0.06, 0.73), UDim2.fromScale(0.87, 0.16), 17, Enum.TextXAlignment.Left),
	})
end

local function categoryCard(mapName: string, order: number)
	local definition = MapData[mapName]
	return create("ImageButton")({
		Name = mapName,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Image = if mapName == "Chapter 2" then "rbxassetid://124875846241438" else CARD_IMAGE,
		Size = UDim2.new(1, -10, 0, 112),
		Visible = function()
			return selectedMode() == modeFor(mapName)
		end,
		Activated = function()
			chooseMap(mapName)
		end,
		create("UICorner")({ CornerRadius = UDim.new(0, 7) }),
		create("UIStroke")({
			Color = function()
				return if selectedMap() == mapName then Color3.fromRGB(255, 233, 89) else Color3.fromRGB(227, 227, 227)
			end,
			Thickness = function()
				return if selectedMap() == mapName then 4 else 2
			end,
		}),
		label("Map", definition.MapName or mapName, UDim2.fromScale(0.06, 0.38), UDim2.fromScale(0.87, 0.28), 19, Enum.TextXAlignment.Left),
		label("Chapter", mapName, UDim2.fromScale(0.06, 0.68), UDim2.fromScale(0.86, 0.2), 16, Enum.TextXAlignment.Left),
		create("ImageLabel")({
			Name = "SelectArrow",
			BackgroundTransparency = 1,
			Image = "rbxassetid://131761289623234",
			Position = UDim2.fromScale(0.87, 0.07),
			Size = UDim2.fromOffset(20, 20),
		}),
	})
end

local function difficultyButton(difficulty: string, order: number, color: Color3)
	return create("ImageButton")({
		Name = difficulty .. "Button",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Image = "rbxassetid://84567654650620",
		Size = UDim2.fromScale(0.15, 0.9),
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
		label("Title", string.upper(difficulty), UDim2.fromScale(-0.15, 0.78), UDim2.fromScale(1.3, 0.23), 16),
	})
end

local StageSelection = {}

function StageSelection.RenderUI()
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
	return create("Frame")({
		Name = "StageSelection",
		BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = UIController:IsVisible(VIEW_ID),
		ZIndex = 15,

		create("ScrollingFrame")({
			Name = "ScrollingFrame",
			Active = true,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.53, 0.06),
			Size = UDim2.fromScale(0.45, 0.8),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 0,
			Visible = function()
				return selectedMode() == ""
			end,
			create("UIListLayout")({ Padding = UDim.new(0, 20), SortOrder = Enum.SortOrder.LayoutOrder }),
			label("ProgressiveHeader", "PROGRESSIVE", UDim2.new(), UDim2.new(1, 0, 0, 58), 35),
			create("Frame")({
				Name = "Modes",
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 215),
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0.04, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				overviewCard("Story", 1, "Chapter 1  •  Chapter 2"),
				overviewCard("Raid", 2, "Normal difficulty"),
			}),
		}),

		create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://111827625474404",
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromScale(0.72, 0.66),
			Visible = function()
				return selectedMode() ~= ""
			end,
			create("UIAspectRatioConstraint")({ AspectRatio = 1.88 }),
			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://76930813066161",
				Position = UDim2.fromScale(-0.05, -0.09),
				Size = UDim2.fromScale(0.7, 0.26),
				ZIndex = 2,
				label("Title", selectedMode, UDim2.fromScale(0.25, 0.33), UDim2.fromScale(0.45, 0.35), 29),
			}),
			create("ImageButton")({
				Name = "CancelButton",
				BackgroundTransparency = 1,
				Image = "rbxassetid://92651860309635",
				Position = UDim2.fromScale(0.93, -0.06),
				Size = UDim2.fromScale(0.08, 0.15),
				Activated = function()
					selectedMode("")
				end,
			}),
			create("ScrollingFrame")({
				Name = "Category",
				Active = true,
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.02, 0.17),
				Size = UDim2.fromScale(0.29, 0.65),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 0,
				create("UIListLayout")({ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
				categoryCard("Chapter 1", 1),
				categoryCard("Chapter 2", 2),
				categoryCard("Raid", 3),
			}),
			label("MapTitle", function()
				local definition = MapData[selectedMap()]
				return if definition then definition.MapName or selectedMap() else selectedMap()
			end, UDim2.fromScale(0.33, 0.18), UDim2.fromScale(0.61, 0.12), 28, Enum.TextXAlignment.Left),
			label("Chapter", selectedMap, UDim2.fromScale(0.33, 0.31), UDim2.fromScale(0.61, 0.09), 21, Enum.TextXAlignment.Left),
			label("DifficultyLabel", "DIFFICULTY", UDim2.fromScale(0.33, 0.42), UDim2.fromScale(0.59, 0.08), 18, Enum.TextXAlignment.Left),
			create("Frame")({
				Name = "Difficulties",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.33, 0.51),
				Size = UDim2.fromScale(0.59, 0.16),
				create("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder }),
				difficultyButton("Normal", 1, Color3.fromRGB(231, 175, 54)),
				difficultyButton("Hard", 2, Color3.fromRGB(255, 73, 67)),
				difficultyButton("Eternal", 3, Color3.fromRGB(182, 70, 236)),
			}),
			label("RewardLabel", "REWARD", UDim2.fromScale(0.33, 0.69), UDim2.fromScale(0.59, 0.07), 18, Enum.TextXAlignment.Left),
			create("ImageLabel")({
				Name = "Reward",
				BackgroundTransparency = 1,
				Image = "rbxassetid://133525559904889",
				Position = UDim2.fromScale(0.33, 0.76),
				Size = UDim2.fromScale(0.59, 0.12),
				label("Amount", function()
					local definition = MapData[selectedMap()]
					local reward = definition and definition.Rewards[selectedDifficulty()]
					if not reward then
						return "Reward unavailable"
					end
					return `{reward.WinCoins} Coins    {reward.WinExp} EXP    {reward.WinGems} Gems`
				end, UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.92, 0.8), 19),
			}),
			actionButton("PartyCancelButton", "CANCEL", UDim2.fromScale(0.47, 0.94), UDim2.fromScale(0.28, 0.1), Color3.fromRGB(255, 15, 40), Color3.fromRGB(252, 24, 182), function()
				selectedMode("")
			end),
			actionButton("SelectButton", function()
				local current = party()
				return if busy() then "WAIT" elseif current and current.State == "Retryable" then "RETRY" else "START"
			end, UDim2.fromScale(0.8, 0.94), UDim2.fromScale(0.28, 0.1), Color3.fromRGB(32, 255, 88), Color3.fromRGB(230, 255, 1), startSelected, nil, canStart),
		}),

		create("Frame")({
			Name = "BottomBar",
			BackgroundColor3 = Color3.new(),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.9),
			Size = UDim2.fromScale(1, 0.1),
			actionButton("Back", "BACK", UDim2.fromScale(0.08, 0.5), UDim2.fromScale(0.14, 0.7), Color3.fromRGB(140, 140, 140), Color3.fromRGB(58, 58, 58), StageSelection.Close),
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
			actionButton("InvitePlayers", "INVITE PLAYERS", UDim2.fromScale(0.77, 0.5), UDim2.fromScale(0.16, 0.7), Color3.fromRGB(55, 255, 0), Color3.fromRGB(255, 238, 1), createInvite),
			actionButton("Play", function()
				return if party() then "LEAVE PARTY" else "JOIN PARTY"
			end, UDim2.fromScale(0.92, 0.5), UDim2.fromScale(0.14, 0.7), Color3.fromRGB(165, 61, 237), Color3.fromRGB(68, 38, 145), function()
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
			Size = UDim2.fromScale(0.43, 0.26),
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
end

function StageSelection.Start() end

return StageSelection
