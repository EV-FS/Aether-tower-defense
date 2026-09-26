local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EmojiData = require(ReplicatedStorage.Settings.Data.EmojiData)
local Net = require(ReplicatedStorage.Shared.Net.client)

local ENTER_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local EXIT_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local MAX_DISTANCE = 90

local activeBillboards: { [Player]: BillboardGui } = {}

local EmojiClient = {}

local function destroyBillboard(player: Player)
	local billboard = activeBillboards[player]
	if billboard then
		billboard:Destroy()
		activeBillboards[player] = nil
	end
end

local function createEmojiContent(parent: Instance, emojiConfig: EmojiData.EmojiConfig)
	if emojiConfig.Image == "" then
		local symbol = Instance.new("TextLabel")
		symbol.Name = "EmojiSymbol"
		symbol.BackgroundTransparency = 1
		symbol.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		symbol.Position = UDim2.fromScale(0.1, 0.1)
		symbol.Size = UDim2.fromScale(0.8, 0.8)
		symbol.Text = emojiConfig.Symbol
		symbol.TextColor3 = Color3.fromRGB(54, 117, 231)
		symbol.TextScaled = true
		symbol.Parent = parent
		return
	end
	local image = Instance.new("ImageLabel")
	image.Name = "EmojiImage"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.BackgroundTransparency = 1
	image.Image = emojiConfig.Image
	image.Position = UDim2.fromScale(0.5, 0.46)
	image.ScaleType = Enum.ScaleType.Fit
	image.Size = UDim2.fromScale(0.78, 0.78)
	image.Parent = parent
end

local function showEmojiForPlayer(player: Player, emojiId: string)
	local emojiConfig = EmojiData.ByName[emojiId]
	if not emojiConfig then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not adornee or not adornee:IsA("BasePart") then
		return
	end

	destroyBillboard(player)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EmojiBillboard"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = MAX_DISTANCE
	billboard.Size = UDim2.fromScale(3, 6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	billboard.Parent = character

	local group = Instance.new("CanvasGroup")
	group.Name = "Bubble"
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.BackgroundColor3 = Color3.fromRGB(247, 251, 255)
	group.GroupTransparency = 1
	group.BackgroundTransparency = 1
	group.Position = UDim2.fromScale(0.5, 0.43)
	group.Size = UDim2.fromScale(1, 0.5)
	group.Parent = billboard

	createEmojiContent(group, emojiConfig)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.45
	scale.Parent = group

	activeBillboards[player] = billboard

	TweenService:Create(group, ENTER_TWEEN, { GroupTransparency = 0 }):Play()
	TweenService:Create(scale, ENTER_TWEEN, { Scale = 1 }):Play()
	TweenService:Create(billboard, ENTER_TWEEN, { StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0) }):Play()

	task.delay(emojiConfig.Duration, function()
		if activeBillboards[player] ~= billboard or not billboard.Parent then
			return
		end

		TweenService:Create(group, EXIT_TWEEN, { GroupTransparency = 1 }):Play()
		local exitScale = TweenService:Create(scale, EXIT_TWEEN, { Scale = 0.75 })
		exitScale:Play()
		exitScale.Completed:Wait()

		if activeBillboards[player] == billboard then
			destroyBillboard(player)
		end
	end)
end

function EmojiClient.ShowEmoji(emojiId: string)
	local emojiConfig = EmojiData.ByName[emojiId]
	if not emojiConfig then
		warn(`[EmojiClient] Emoji data not found: {emojiId}`)
		return
	end

	Net.EmojiService.RequestShowEmoji
		.Invoke({ EmojiId = emojiId })
		:andThen(function(success: boolean)
			if not success then
				warn(`[EmojiClient] Server rejected emoji: {emojiId}`)
			end
		end)
		:catch(function(err: any)
			warn(`[EmojiClient] Network error: {err}`)
		end)
end

function EmojiClient.Init() end

function EmojiClient.Start()
	Net.EmojiService.EmojiShown.On(function(data: { Player: unknown, EmojiId: string })
		local targetPlayer = data.Player
		if typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player") then
			return
		end

		showEmojiForPlayer(targetPlayer :: Player, data.EmojiId)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		destroyBillboard(player)
	end)
end

return EmojiClient
