local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create
local source = Vide.source
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function textLabel(name: string, value: any, position: UDim2, size: UDim2, color: Color3?)
	return create("TextLabel")({
		Name = name,
		BackgroundTransparency = 1,
		FontFace = FONT,
		Position = position,
		Size = size,
		Text = value,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		create("UIStroke")({ Thickness = 1.5, Color = Color3.new() }),
	})
end

local function playerRow(player: Player, order: number, canInvite: (Player) -> boolean, onInvite: (Player) -> ())
	return create("Frame")({
		Name = `Player_{player.UserId}`,
		LayoutOrder = order,
		BackgroundColor3 = Color3.fromRGB(7, 7, 9),
		Size = UDim2.new(0.97, 0, 0, 96),
		create("UICorner")({ CornerRadius = UDim.new(0, 9) }),
		create("UIStroke")({ Color = Color3.fromRGB(75, 75, 75), Thickness = 2 }),
		create("ImageLabel")({
			Name = "Avatar",
			BackgroundColor3 = Color3.fromRGB(30, 30, 40),
			Position = UDim2.fromScale(0.025, 0.1),
			Size = UDim2.fromScale(0.18, 0.8),
			Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`,
			create("UICorner")({ CornerRadius = UDim.new(0, 7) }),
		}),
		textLabel("DisplayName", player.DisplayName, UDim2.fromScale(0.23, 0.22), UDim2.fromScale(0.51, 0.3)),
		textLabel("UserName", `@{player.Name}`, UDim2.fromScale(0.23, 0.57), UDim2.fromScale(0.51, 0.2), Color3.fromRGB(180, 180, 180)),
		create("ImageButton")({
			Name = "Invite",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.88, 0.5),
			Size = UDim2.fromScale(0.18, 0.53),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Image = "rbxassetid://96374261144914",
			Interactable = function() return canInvite(player) end,
			ImageTransparency = function() return if canInvite(player) then 0 else 0.5 end,
			Activated = function() onInvite(player) end,
			useButtonEffect(0.94, 1.08),
			create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(16, 255, 16), Color3.fromRGB(230, 255, 10)), Rotation = 90 }),
			create("UIStroke")({ Color = Color3.new(1, 1, 1), Thickness = 1 }),
			create("UICorner")({ CornerRadius = UDim.new(0, 7) }),
			create("ImageLabel")({ Name = "Deco", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.36, 0.55), BackgroundTransparency = 1, Image = "rbxassetid://107275506784451" }),
		}),
	})
end

return function(props: { Visible: () -> boolean, OnClose: () -> (), OnInvite: (Player) -> (), CanInvite: (Player) -> boolean })
	local players = source({} :: { Player })
	local function refresh()
		local others = {}
		for _, player in Players:GetPlayers() do
			if player ~= Players.LocalPlayer then table.insert(others, player) end
		end
		players(others)
	end
	refresh()
	local added = Players.PlayerAdded:Connect(refresh)
	local removed = Players.PlayerRemoving:Connect(refresh)
	Vide.cleanup(function() added:Disconnect(); removed:Disconnect() end)
	return create("ImageLabel")({
		Name = "InviteList",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.49),
		Size = UDim2.fromScale(0.3156, 0.823),
		BackgroundTransparency = 1,
		Image = "rbxassetid://80348302893975",
		Visible = props.Visible,
		ZIndex = 30,
		create("UIAspectRatioConstraint")({ AspectRatio = 0.7877 }),
		textLabel("Title", "INVITE", UDim2.fromScale(0.3, 0.04), UDim2.fromScale(0.48, 0.065)),
		create("ScrollingFrame")({
			Name = "Players",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.02, 0.14),
			Size = UDim2.fromScale(0.96, 0.81),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			create("UIListLayout")({ HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			Vide.indexes(players, function(player, index)
				return playerRow(player(), index, props.CanInvite, props.OnInvite)
			end),
		}),
		create("TextLabel")({
			Name = "Empty",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.1, 0.46),
			Size = UDim2.fromScale(0.8, 0.1),
			FontFace = FONT,
			Text = "No other players in this lobby.",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Visible = function() return #players() == 0 end,
		}),
		create("ImageButton")({
			Name = "CancelButton",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.98, 0.025),
			Size = UDim2.fromScale(0.15, 0.13),
			BackgroundTransparency = 1,
			Image = "rbxassetid://92651860309635",
			Activated = props.OnClose,
			useButtonEffect(0.92, 1.1),
			create("UIAspectRatioConstraint")({}),
		}),
	})
end
