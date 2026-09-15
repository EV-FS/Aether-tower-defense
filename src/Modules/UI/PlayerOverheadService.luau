local Players = game:GetService("Players")

local GROUP_ID = 492293332
local DEVELOPER_MIN_RANK = 250
local DEFAULT_LEVEL = 1

local DISPLAY_DISTANCE = 100
-- Scale components on a BillboardGui are measured in world-space studs.
-- This makes the whole tag naturally shrink as the camera moves away.
local BILLBOARD_SIZE = UDim2.new(3.4, 0, 1.2, 0)
local BILLBOARD_OFFSET = Vector3.new(0, 2.55, 0)
local DISPLAY_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

type PlayerState = {
	billboard: BillboardGui?,
	titleLabel: TextLabel?,
	levelLabel: TextLabel?,
	titleConnection: RBXScriptConnection?,
	levelConnection: RBXScriptConnection?,
	leaderstatsConnection: RBXScriptConnection?,
	playerChildConnection: RBXScriptConnection?,
	characterConnection: RBXScriptConnection?,
}

local PlayerOverheadService = {}
local playerStates: { [Player]: PlayerState } = {}

local function disconnect(connection: RBXScriptConnection?)
	if connection then
		connection:Disconnect()
	end
end

local function addTextStroke(label: TextLabel, thicknessScale: number)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.fromRGB(12, 10, 18)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = thicknessScale
	stroke.Transparency = 0
	stroke.Parent = label
end

local function createLabel(name: string, heightScale: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, heightScale)
	label.FontFace = DISPLAY_FONT
	label.TextScaled = true
	label.RichText = true
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center

	return label
end

local function escapeRichText(value: string): string
	return value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function refreshTitle(player: Player)
	local state = playerStates[player]
	if not state or not state.titleLabel then return end
	local title = player:GetAttribute("ChatRoleTag")
	local visible = type(title) == "string" and title ~= ""
	state.titleLabel.Text = if visible then escapeRichText(title) else ""
	state.titleLabel.Visible = visible
end

local function currentLevel(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	if levelValue and levelValue:IsA("IntValue") then
		return math.max(1, levelValue.Value)
	end

	return DEFAULT_LEVEL
end

local function refreshLevel(player: Player)
	local state = playerStates[player]
	if state and state.levelLabel then
		state.levelLabel.Text = `Level {currentLevel(player)}`
	end
end

local function bindLevelValue(player: Player, levelValue: Instance?)
	local state = playerStates[player]
	if not state then
		return
	end

	disconnect(state.levelConnection)
	state.levelConnection = nil

	if levelValue and levelValue:IsA("IntValue") then
		state.levelConnection = levelValue:GetPropertyChangedSignal("Value"):Connect(function()
			refreshLevel(player)
		end)
	end

	refreshLevel(player)
end

local function bindLeaderstats(player: Player, leaderstats: Instance?)
	local state = playerStates[player]
	if not state then
		return
	end

	disconnect(state.leaderstatsConnection)
	state.leaderstatsConnection = nil

	if leaderstats then
		bindLevelValue(player, leaderstats:FindFirstChild("Level"))
		state.leaderstatsConnection = leaderstats.ChildAdded:Connect(function(child)
			if child.Name == "Level" then
				bindLevelValue(player, child)
			end
		end)
	else
		bindLevelValue(player, nil)
	end
end

local function createOverhead(player: Player, character: Model)
	local state = playerStates[player]
	if not state then
		return
	end

	local head = character:WaitForChild("Head", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not head or not head:IsA("BasePart") or not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	if player.Character ~= character then
		return
	end

	if state.billboard then
		state.billboard:Destroy()
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlayerOverhead"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = DISPLAY_DISTANCE
	-- Keep the BillboardGui itself fully world-scaled. A positive upper limit
	-- freezes its minimum screen size and makes distant tags look pixel-fixed.
	billboard.DistanceLowerLimit = 0
	billboard.DistanceUpperLimit = -1
	billboard.DistanceStep = 0
	billboard.Size = BILLBOARD_SIZE
	billboard.SizeOffset = Vector2.zero
	billboard.StudsOffsetWorldSpace = BILLBOARD_OFFSET
	billboard.Parent = head

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = billboard

	local layout = Instance.new("UIListLayout")
	layout.Name = "Layout"
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(-0.02, 0)
	layout.Parent = container

	local titleLabel = createLabel("Title", 0.26)
	titleLabel.LayoutOrder = 0
	-- These belong to the actual title, not only the shared name/level labels.
	titleLabel.TextScaled = true
	titleLabel.RichText = true
	titleLabel.TextColor3 = Color3.fromRGB(207, 139, 255)
	addTextStroke(titleLabel, 0.15)
	local titleGradient = Instance.new("UIGradient")
	titleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 191, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(156, 104, 255)),
	})
	titleGradient.Parent = titleLabel
	titleLabel.Parent = container

	local levelLabel = createLabel("Level", 0.3)
	levelLabel.LayoutOrder = 1
	levelLabel.TextScaled = true
	levelLabel.RichText = true
	levelLabel.Text = `Level {currentLevel(player)}`
	levelLabel.TextColor3 = Color3.fromRGB(255, 182, 43)
	addTextStroke(levelLabel, 0.145)

	local levelGradient = Instance.new("UIGradient")
	levelGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 237, 106)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 169, 35)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 116, 24)),
	})
	levelGradient.Rotation = 90
	levelGradient.Parent = levelLabel
	levelLabel.Parent = container

	local nameLabel = createLabel("PlayerName", 0.37)
	nameLabel.LayoutOrder = 2
	nameLabel.TextScaled = true
	nameLabel.RichText = true
	nameLabel.Text = escapeRichText(player.DisplayName)
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	addTextStroke(nameLabel, 0.14)
	nameLabel.Parent = container

	state.billboard = billboard
	state.titleLabel = titleLabel
	state.levelLabel = levelLabel
	refreshTitle(player)
end

local function resolveDeveloperRole(player: Player)
	local success, rank = pcall(player.GetRankInGroupAsync, player, GROUP_ID)
	local isDeveloper = success and type(rank) == "number" and rank >= DEVELOPER_MIN_RANK
	player:SetAttribute("IsDeveloper", isDeveloper)

	if isDeveloper then
		local roleSuccess, roleName = pcall(player.GetRoleInGroupAsync, player, GROUP_ID)
		player:SetAttribute(
			"ChatRoleTag",
			if roleSuccess and type(roleName) == "string" and roleName ~= "" then roleName else "Developer"
		)
	else
		player:SetAttribute("ChatRoleTag", nil)
	end
	refreshTitle(player)

end

local function playerAdded(player: Player)
	if playerStates[player] then
		return
	end

	local state: PlayerState = {}
	playerStates[player] = state

	state.playerChildConnection = player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			bindLeaderstats(player, child)
		end
	end)
	state.titleConnection = player:GetAttributeChangedSignal("ChatRoleTag"):Connect(function()
		refreshTitle(player)
	end)

	state.characterConnection = player.CharacterAdded:Connect(function(character)
		task.spawn(createOverhead, player, character)
	end)

	bindLeaderstats(player, player:FindFirstChild("leaderstats"))
	task.spawn(resolveDeveloperRole, player)

	if player.Character then
		task.spawn(createOverhead, player, player.Character)
	end
end

local function playerRemoving(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end

	disconnect(state.levelConnection)
	disconnect(state.titleConnection)
	disconnect(state.leaderstatsConnection)
	disconnect(state.playerChildConnection)
	disconnect(state.characterConnection)
	if state.billboard then
		state.billboard:Destroy()
	end
	playerStates[player] = nil
end

function PlayerOverheadService.Start()
	for _, player in Players:GetPlayers() do
		playerAdded(player)
	end

	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(playerRemoving)
end

return PlayerOverheadService
