local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local QuestMenuUI = require(script.Parent.QuestMenuUI)

local create = Vide.create
local source = Vide.source
local values = Vide.values

local DataClient
local DialogueClient
local UIController

local QuestUI = {}
local isTrackingExpanded = source(true)

local function createTrackingCard(questId, layoutOrder: number)
	local function getQuest()
		local quest = QuestMenuUI.GetQuestById(questId())
		return quest
	end

	return create("ImageLabel")({
		Name = function()
			return `Tracked_${questId()}`
		end,
		BackgroundTransparency = 1,
		Image = "rbxassetid://108648957028585",
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 96),
		Visible = function()
			return getQuest() ~= nil
		end,

		create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		create("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(255, 221, 92),
			Thickness = 1.5,
			Transparency = 0.18,
		}),

		create("TextLabel")({
			Name = "Theme",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.045, 0.08),
			Size = UDim2.fromScale(0.24, 0.2),
			Text = function()
				local _, category = QuestMenuUI.GetQuestById(questId())
				return category or "QUEST"
			end,
			TextColor3 = Color3.fromRGB(155, 255, 91),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UIStroke")({ Thickness = 1.5 }),
		}),

		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.29, 0.08),
			Size = UDim2.fromScale(0.58, 0.2),
			Text = function()
				local quest = getQuest()
				return if quest then quest.Title else "QUEST"
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UIStroke")({ Thickness = 1.5 }),
		}),

		create("ImageButton")({
			Name = "UnpinButton",
			AnchorPoint = Vector2.new(1, 0),
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Image = "rbxassetid://104073784954292",
			Position = UDim2.fromScale(0.965, 0.055),
			Size = UDim2.fromScale(0.09, 0.24),
			Activated = function()
				QuestMenuUI.UnpinQuest(questId())
			end,
			create("UIAspectRatioConstraint")({}),
			useButtonEffect(0.9, 1.08),
		}),

		create("TextLabel")({
			Name = "Description",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.045, 0.34),
			Size = UDim2.fromScale(0.91, 0.28),
			Text = function()
				local quest = getQuest()
				return if quest then quest.Description else ""
			end,
			TextColor3 = Color3.fromRGB(225, 225, 225),
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UITextSizeConstraint")({ MaxTextSize = 15, MinTextSize = 8 }),
			create("UIStroke")({ Thickness = 1 }),
		}),

		create("Frame")({
			Name = "ProgressTrack",
			BackgroundColor3 = Color3.fromRGB(31, 36, 46),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.045, 0.74),
			Size = UDim2.fromScale(0.72, 0.1),
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			create("Frame")({
				Name = "Fill",
				BackgroundColor3 = Color3.fromRGB(138, 241, 73),
				BorderSizePixel = 0,
				Size = function()
					local quest = getQuest()
					local ratio = if quest then quest.Current / math.max(quest.Target, 1) else 0
					return UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
		}),

		create("TextLabel")({
			Name = "Progress",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.79, 0.69),
			Size = UDim2.fromScale(0.16, 0.2),
			Text = function()
				local quest = getQuest()
				return if quest then quest.Progress else ""
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			create("UIStroke")({ Thickness = 1.5 }),
		}),
	})
end

function QuestUI.RenderUI()
	local trackSFX = useAudio({ Id = UISFX.QuestTrack.Id, Volume = UISFX.QuestTrack.Volume })
	local untrackSFX = useAudio({ Id = UISFX.QuestUntrack.Id, Volume = UISFX.QuestUntrack.Volume })
	local pinnedQuestKeys = QuestMenuUI.GetPinnedQuestKeys()

	return create("Frame")({
		Name = "QuestFrame",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.80, 0, 0, 62),
		Size = UDim2.fromScale(0.195, 0.7),
		ZIndex = 5,
		Visible = function()
			if not QuestMenuUI.HasPinnedQuests() then
				return false
			end
			if UIController and UIController:IsExclusive() then
				return false
			end
			if UIController and (UIController:IsOpen("Quest") or UIController:IsOpen("Dialogue")) then
				return false
			end
			if DialogueClient and DialogueClient.IsOpen() then
				return false
			end
			return true
		end,

		create("ImageLabel")({
			Name = "Header",
			BackgroundTransparency = 1,
			Image = "rbxassetid://90611390853296",
			Size = UDim2.new(1, 0, 0, 42),
			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.18, 0.18),
				Size = UDim2.fromScale(0.64, 0.56),
				Text = "QUEST TRACKING",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				create("UIStroke")({}),
			}),
			create("ImageButton")({
				Name = "ExpandButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://104073784954292",
				Position = UDim2.fromScale(0.09, 0.5),
				Size = UDim2.fromScale(0.09, 0.72),
				Rotation = function()
					return if isTrackingExpanded() then 0 else 180
				end,
				Activated = function()
					isTrackingExpanded(not isTrackingExpanded())
					if isTrackingExpanded() then trackSFX:Play() else untrackSFX:Play() end
				end,
				create("UIAspectRatioConstraint")({}),
			}),
		}),

		create("ScrollingFrame")({
			Name = "TrackedQuests",
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromScale(0, 0),
			ClipsDescendants = false,
			Position = UDim2.new(0, 0, 0, 48),
			ScrollBarThickness = 0,
			Size = UDim2.new(1, 0, 1, -48),
			Visible = isTrackingExpanded,
			create("UIListLayout")({
				Padding = UDim.new(0, 7),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			values(pinnedQuestKeys, function(layoutOrder, questId)
				return createTrackingCard(questId, layoutOrder)
			end),
		}),
	})
end

function QuestUI.Init()
	DataClient = ServiceRegistry:GetService("DataClient")
	DialogueClient = ServiceRegistry:GetService("DialogueClient")
	UIController = ServiceRegistry:GetService("UIController")
end

function QuestUI.Start()
	if DataClient then
		DataClient.FetchQuests()
	end
end

return QuestUI
