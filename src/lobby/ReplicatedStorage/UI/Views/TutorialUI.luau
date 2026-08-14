local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local source = Vide.source
local spring = Vide.spring

type SpotlightRect = {
	left: number,
	top: number,
	right: number,
	bottom: number,
	width: number,
	height: number,
}

local TutorialUI = {}
local TutorialClient

local spotlightRect = source({
	left = 0,
	top = 0,
	right = 0,
	bottom = 0,
	width = 0,
	height = 0,
} :: SpotlightRect)
local spotlightPulse = source(0)
local cardPop = source(1)
local previousStepIndex = 0

local function getTargetButton(): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local interface = playerGui and playerGui:FindFirstChild("Interface")
	local arrangement = interface and interface:FindFirstChild("ButtonArrangement")
	local step = TutorialClient:GetCurrentStep()

	return if arrangement and step then arrangement:FindFirstChild(step.Target) :: GuiObject? else nil
end

local function syncSpotlight()
	return action(function()
		local elapsed = 0
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			if not TutorialClient:IsVisible()() then
				previousStepIndex = 0
				return
			end
			elapsed += deltaTime
			spotlightPulse((math.sin(elapsed * 3.4) + 1) * 0.5)

			local stepIndex = TutorialClient:GetStepIndex()
			if previousStepIndex ~= stepIndex then
				previousStepIndex = stepIndex
				cardPop(0.9)
				task.delay(0.05, function()
					cardPop(1)
				end)
			end

			local target = getTargetButton()
			if not target then
				return
			end

			local padding = 12
			local position = target.AbsolutePosition
			local size = target.AbsoluteSize
			local focusOffsetY = size.Y * 0.5
			local left = math.max(position.X - padding, 0)
			local top = math.max(position.Y + focusOffsetY - padding + 5, 0)
			local right = position.X + size.X + padding
			local bottom = position.Y + focusOffsetY + size.Y + padding + 5

			spotlightRect({
				left = left,
				top = top,
				right = right,
				bottom = bottom,
				width = right - left,
				height = bottom - top,
			})
		end)

		cleanup(connection)
	end)
end

local function dimPanel(name: string, position: () -> UDim2, size: () -> UDim2)
	return create("Frame")({
		Name = name,
		BackgroundColor3 = Color3.fromRGB(5, 8, 15),
		BackgroundTransparency = spring(function()
			return if TutorialClient:IsVisible()() then 0.28 else 1
		end, 0.25, 0.9),
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		ZIndex = 40,
	})
end

local function getGuideCardPlacement(): (Vector2, UDim2)
	local rect = spotlightRect()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	local cardWidth = 330
	local cardHeight = 198
	local gap = 30
	local edgePadding = 18
	local viewportWidth = math.max(viewport.X, cardWidth + edgePadding * 2)
	local viewportHeight = math.max(viewport.Y, cardHeight + edgePadding * 2)
	local canFitOnRight = rect.right + gap + cardWidth <= viewportWidth - edgePadding
	local anchorPoint = if canFitOnRight then Vector2.new(0, 0) else Vector2.new(1, 0)
	local x = if canFitOnRight then rect.right + gap else rect.left - gap
	local minimumY = edgePadding
	local maximumY = math.max(minimumY, viewportHeight - cardHeight - edgePadding)
	local y = math.clamp(
		rect.top,
		minimumY,
		maximumY
	)

	return anchorPoint, UDim2.fromOffset(x, y)
end

function TutorialUI.RenderUI()
	local cardScale = spring(function()
		return if TutorialClient:IsVisible()() then cardPop() else 0.86
	end, 0.3, 0.72)

	return create("Frame")({
		Name = "TutorialUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = TutorialClient:IsVisible(),
		ZIndex = 40,

		syncSpotlight(),

		dimPanel("TopDim", function()
			local rect = spotlightRect()
			return UDim2.fromOffset(0, 0)
		end, function()
			local rect = spotlightRect()
			return UDim2.new(1, 0, 0, rect.top)
		end),
		dimPanel("LeftDim", function()
			local rect = spotlightRect()
			return UDim2.fromOffset(0, rect.top)
		end, function()
			local rect = spotlightRect()
			return UDim2.fromOffset(rect.left, rect.height)
		end),
		dimPanel("RightDim", function()
			local rect = spotlightRect()
			return UDim2.fromOffset(rect.right, rect.top)
		end, function()
			local rect = spotlightRect()
			return UDim2.new(1, -rect.right, 0, rect.height)
		end),
		dimPanel("BottomDim", function()
			local rect = spotlightRect()
			return UDim2.fromOffset(0, rect.bottom)
		end, function()
			local rect = spotlightRect()
			return UDim2.new(1, 0, 1, -rect.bottom)
		end),

		create("Frame")({
			Name = "SpotlightHalo",
			BackgroundTransparency = 1,
			Position = function()
				local rect = spotlightRect()
				return UDim2.fromOffset(rect.left - 6, rect.top - 6)
			end,
			Size = function()
				local rect = spotlightRect()
				return UDim2.fromOffset(rect.width + 12, rect.height + 12)
			end,
			ZIndex = 41,

			create("UICorner")({
				CornerRadius = UDim.new(0, 16),
			}),
			create("UIStroke")({
				Color = Color3.fromRGB(255, 207, 93),
				Thickness = 2,
				Transparency = function()
					return 0.38 + spotlightPulse() * 0.28
				end,
			}),
		}),

		create("Frame")({
			Name = "Spotlight",
			BackgroundTransparency = 1,
			Position = function()
				local rect = spotlightRect()
				return UDim2.fromOffset(rect.left, rect.top)
			end,
			Size = function()
				local rect = spotlightRect()
				return UDim2.fromOffset(rect.width, rect.height)
			end,
			ZIndex = 41,

			create("UICorner")({
				CornerRadius = UDim.new(0, 12),
			}),
			create("UIStroke")({
				Color = Color3.fromRGB(255, 239, 191),
				Thickness = 1,
				Transparency = function()
					return 0.18 + spotlightPulse() * 0.22
				end,
			}),
		}),

		create("Frame")({
			Name = "GuideCard",
			AnchorPoint = function()
				local anchorPoint = getGuideCardPlacement()
				return anchorPoint
			end,
			BackgroundColor3 = Color3.fromRGB(19, 24, 37),
			BackgroundTransparency = 0.04,
			Position = spring(function()
				local _, position = getGuideCardPlacement()
				return if TutorialClient:IsVisible()()
					then position
					else UDim2.fromScale(0.2, 0.55)
			end, 0.32, 0.82),
			Size = UDim2.fromOffset(330, 198),
			ZIndex = 45,

			create("UICorner")({
				CornerRadius = UDim.new(0, 14),
			}),
			create("UIScale")({
				Name = "EntranceScale",
				Scale = cardScale,
			}),
			create("UIStroke")({
				Color = Color3.fromRGB(255, 219, 133),
				Thickness = 1,
				Transparency = 0.72,
			}),
			create("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 48, 69)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(17, 21, 32)),
				}),
				Rotation = 90,
			}),
			create("Frame")({
				Name = "Accent",
				BackgroundColor3 = Color3.fromRGB(255, 204, 91),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(20, 23),
				Size = UDim2.fromOffset(4, 30),
				ZIndex = 46,
				create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			}),
			create("TextLabel")({
				Name = "Step",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
				Position = UDim2.fromOffset(38, 22),
				Size = UDim2.fromOffset(210, 18),
				Text = function()
					return string.format("GUIDE  %02d / %02d", TutorialClient:GetStepIndex(), TutorialClient:GetStepCount())
				end,
				TextColor3 = Color3.fromRGB(255, 209, 108),
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 46,
			}),
			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
				Position = UDim2.fromOffset(38, 48),
				Size = UDim2.fromOffset(266, 30),
				Text = function()
					return TutorialClient:GetCurrentStep().Title
				end,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 19,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 46,
			}),
			create("TextLabel")({
				Name = "Description",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
				Position = UDim2.fromOffset(38, 82),
				Size = UDim2.fromOffset(266, 54),
				Text = function()
					return TutorialClient:GetCurrentStep().Description
				end,
				TextColor3 = Color3.fromRGB(211, 217, 229),
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 46,
			}),
			create("TextButton")({
				Name = "Next",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(255, 198, 76),
				Position = UDim2.fromOffset(38, 151),
				Size = UDim2.fromOffset(254, 30),
				Text = function()
					return if TutorialClient:GetStepIndex() == TutorialClient:GetStepCount() then "FINISH" else "NEXT"
				end,
				TextColor3 = Color3.fromRGB(36, 28, 16),
				TextSize = 12,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
				ZIndex = 46,
				Activated = function()
					TutorialClient:Next()
				end,
				create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
				useButtonEffect(0.96, 1.02),
			}),
		}),
	})
end

function TutorialUI.Init()
	TutorialClient = ServiceRegistry:GetService("TutorialClient")
end

return TutorialUI
