-- // VARIABLES // --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CommanderPortrait = require(script.Parent.CommanderPortrait)
local DialogueData = require(ReplicatedStorage.Settings.Data.CommanderDialogueData)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)

local create = Vide.create
local CommanderDialogueView = {}

-- // FUNCTIONS // --
--[[ Presents commander messages through a shared responsive layout. ]]
function CommanderDialogueView.RenderUI(CommanderClient, layout)
	layout = layout or {}
	local panelTarget = layout.PanelPosition or UDim2.fromScale(0.507615, 0.644336)
	local portraitTarget = layout.PortraitPosition or UDim2.fromScale(0.41271, 0.62202)
	local accentColor = CommanderClient.AccentColor or DialogueData.Presentation.AccentColor
	local motion = useMenuMotion(CommanderClient.IsVisible, function()
		return if CommanderClient.CanPresent() then nil else "OtherInterface"
	end)
	local fade = motion:Fade()
	local panelPosition = motion:Spring(
		panelTarget,
		panelTarget + UDim2.fromScale(0, DialogueData.Presentation.SlideDistance),
		"Content"
	)
	local portraitPosition = motion:Spring(
		portraitTarget,
		portraitTarget + UDim2.fromScale(-0.02, DialogueData.Presentation.SlideDistance),
		"Header"
	)
	local panelScale = motion:Spring(1, DialogueData.Presentation.ClosedScale, "Window")
	return create("ScreenGui")({
		Name = "CommanderDialogueGui",
		ResetOnSpawn = false,
		DisplayOrder = 49,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = function()
			return motion.IsMounted() and CommanderClient.CanPresent()
		end,
		Vide.show(motion.IsMounted, function()
			local textScale = Vide.source(1)
			--[[ Limits enlargement while preserving fitting within the available space. ]]
			local function createTextLimit(maximumSize: number)
				return create("UITextSizeConstraint")({
					MinTextSize = 1,
					MaxTextSize = function()
						return math.max(1, math.floor(maximumSize * textScale()))
					end,
				})
			end
			local rig = Vide.untrack(CommanderClient.Rig)
			local portrait = CommanderPortrait(rig, { Fade = fade, Position = portraitPosition, Size = layout.PortraitSize })
			local volumeScale = DialogueData.Presentation.SoundVolumeScale
			local openSound = useAudio({ Id = UISFX.QuestOpen.Id, Volume = UISFX.QuestOpen.Volume * volumeScale })
			local closeSound = useAudio({ Id = UISFX.Close.Id, Volume = UISFX.Close.Volume * volumeScale })
			local advanceSound = useAudio({ Id = UISFX.Click.Id, Volume = UISFX.Click.Volume * volumeScale })
			local previousLine = Vide.untrack(CommanderClient.LineIndex)
			local previousOpen = true
			openSound:Play()
			Vide.effect(function()
				local isOpen = CommanderClient.IsOpen()
				if previousOpen and not isOpen then
					closeSound:Play()
				end
				previousOpen = isOpen
			end)
			Vide.effect(function()
				local index = CommanderClient.LineIndex()
				if index ~= previousLine and CommanderClient.IsVisible() then
					advanceSound:Play()
				end
				previousLine = index
			end)
			local hintFade = Vide.spring(function()
				return if CommanderClient.IsTyping() then 1 else 0
			end, 0.2, 1)
			local passageProgress = Vide.spring(function()
				if CommanderClient.ReadProgress then
					return CommanderClient.ReadProgress()
				end
				return CommanderClient.LineIndex() / math.max(#DialogueData.Introduction, 1)
			end, 0.35, 1)
			return create("Frame")({
				Name = "Presentation",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				portrait,
				create("Frame")({
					Name = "Frame",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = function()
						return 0.05 + 0.95 * fade()
					end,
					BorderSizePixel = 0,
					Position = panelPosition,
					Size = layout.PanelSize or UDim2.fromScale(0.304154, 0.220809),
					ZIndex = 2,
					Vide.action(function(frame: Frame)
						--[[ Keeps typography proportional as the available space changes. ]]
						local function updateTextScale()
							local height = frame.AbsoluteSize.Y
							if height > 0 then
								textScale(math.min(height / DialogueData.Typography.ReferencePanelHeight, 1))
							end
						end
						Vide.cleanup(frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTextScale))
						updateTextScale()
					end),
					create("UIScale")({ Scale = panelScale }),
					create("UIStroke")({
						Color = accentColor,
						Thickness = 1,
						Transparency = function()
							return 0.78 + 0.22 * fade()
						end,
					}),
					create("UICorner")({ CornerRadius = UDim.new(0.0425532, 0) }),
					create("UIGradient")({
						Color = ColorSequence.new(Color3.fromRGB(13, 13, 13), Color3.new()),
						Rotation = 90,
					}),
					create("UIAspectRatioConstraint")({ AspectRatio = 2.82979 }),
					create("TextLabel")({
						Name = "NameText",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.0488722, -0.0159574),
						Size = UDim2.fromScale(0.278196, 0.196809),
						Text = DialogueData.SpeakerName,
						TextColor3 = Color3.fromRGB(243, 243, 243),
						TextScaled = true,
						TextTransparency = fade,
						ZIndex = 3,
						create("UIStroke")({ Transparency = fade }),
						createTextLimit(DialogueData.Typography.NameMaxSize),
					}),
					create("TextLabel")({
						Name = "TextLabel",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.84, 0.62),
						Text = CommanderClient.Text,
						MaxVisibleGraphemes = CommanderClient.VisibleGraphemes,
						TextColor3 = Color3.fromRGB(243, 243, 243),
						TextScaled = true,
						TextTransparency = fade,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						ClipsDescendants = true,
						ZIndex = 3,
						createTextLimit(DialogueData.Typography.BodyMaxSize),
					}),
					create("TextButton")({
						Name = "Advance",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = "",
						AutoButtonColor = false,
						ZIndex = 4,
						Activated = CommanderClient.Advance,
					}),
					CommanderClient.Caption and create("TextLabel")({
						Name = "TransmissionCaption",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.36, 0.03),
						Size = UDim2.fromScale(0.54, 0.12),
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Text = CommanderClient.Caption,
						TextColor3 = accentColor,
						TextTransparency = fade,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Right,
						ZIndex = 3,
						createTextLimit(DialogueData.Typography.HintMaxSize),
					}),
					CommanderClient.Dismiss and create("TextButton")({
						Name = "DismissTransmission",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.91, 0),
						Size = UDim2.fromScale(0.09, 0.2),
						Text = "X",
						TextColor3 = Color3.fromRGB(170, 170, 170),
						TextTransparency = fade,
						TextScaled = true,
						ZIndex = 5,
						Activated = CommanderClient.Dismiss,
						createTextLimit(DialogueData.Typography.HintMaxSize),
					}),
					create("TextLabel")({
						Name = "ContinueHint",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.92),
						Size = UDim2.fromScale(0.47, 0.07),
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Text = CommanderClient.HintText or "Tap / Enter / A",
						TextColor3 = Color3.fromRGB(170, 170, 170),
						TextTransparency = function()
							return 1 - (1 - fade()) * (1 - hintFade())
						end,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Right,
						ZIndex = 3,
						createTextLimit(DialogueData.Typography.HintMaxSize),
					}),
					create("Frame")({
						Name = "TransmissionProgress",
						BackgroundColor3 = accentColor,
						BackgroundTransparency = fade,
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.04, 0.985),
						Size = function()
							return UDim2.new(0.92 * passageProgress(), 0, 0, 1)
						end,
						ZIndex = 3,
					}),
				}),
			})
		end),
	})
end

-- // INITIALIZATION // --
return CommanderDialogueView
