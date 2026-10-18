-- // VARIABLES // --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CommanderPortrait = require(script.Parent.CommanderPortrait)
local DialogueData = require(ReplicatedStorage.Settings.Data.CommanderDialogueData)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)

local create = Vide.create
local PANEL_ASPECT_RATIO = 2.82979
local MINIMUM_PANEL_WIDTH = 280
local MAXIMUM_PANEL_WIDTH = 680
local CommanderDialogueView = {}

-- // FUNCTIONS // --
--[[ Presents commander messages through a shared responsive layout. ]]
function CommanderDialogueView.RenderUI(CommanderClient, layout)
	layout = layout or {}
	local panelTarget = layout.PanelPosition or UDim2.fromScale(0.507615, 0.644336)
	local portraitTarget = layout.PortraitPosition or UDim2.fromScale(0.18, 0.2)
	local portraitSize = layout.PortraitSize or UDim2.fromScale(0.32, 0.9)
	local configuredSize = layout.PanelSize or UDim2.fromScale(0.304154, 0.220809)
	local viewportSize = Vide.source(Vector2.zero)
	local leftOverflow = math.max(portraitSize.X.Scale - portraitTarget.X.Scale + 0.05, 0)
	local topOverflow = math.max(portraitSize.X.Scale * PANEL_ASPECT_RATIO - portraitTarget.Y.Scale, 0)
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
		portraitTarget + UDim2.fromScale(-0.05, 0.05),
		"Header"
	)
	local panelScale = motion:Spring(1, DialogueData.Presentation.ClosedScale, "Window")
	local panelSize = Vide.derive(function()
		local size = viewportSize()
		if size.X <= 0 or size.Y <= 0 then
			return configuredSize
		end
		local padding = math.min(12, size.X * 0.04, size.Y * 0.04)
		local maximumWidth = math.min(
			MAXIMUM_PANEL_WIDTH,
			(size.X - 2 * padding) / (1 + leftOverflow),
			(size.Y - 2 * padding) * PANEL_ASPECT_RATIO / (1 + topOverflow)
		)
		local requestedWidth = size.X * configuredSize.X.Scale + configuredSize.X.Offset
		local width = math.clamp(requestedWidth, math.min(MINIMUM_PANEL_WIDTH, maximumWidth), maximumWidth)
		return UDim2.fromOffset(width, width / PANEL_ASPECT_RATIO)
	end)
	--[[ Keeps the complete portrait and panel within the usable display area. ]]
	local function getPanelPosition(): UDim2
		local size = viewportSize()
		local requested = panelPosition()
		if size.X <= 0 or size.Y <= 0 then
			return requested
		end
		local dimensions = panelSize()
		local width, height = dimensions.X.Offset, dimensions.Y.Offset
		local padding = math.min(12, size.X * 0.04, size.Y * 0.04)
		local minimumX = padding + width * (0.5 + leftOverflow)
		local minimumY = padding + height * (0.5 + topOverflow)
		local maximumX = math.max(minimumX, size.X - padding - width * 0.5)
		local maximumY = math.max(minimumY, size.Y - padding - height * 0.5)
		local x = math.clamp(size.X * requested.X.Scale + requested.X.Offset, minimumX, maximumX)
		local y = math.clamp(size.Y * requested.Y.Scale + requested.Y.Offset, minimumY, maximumY)
		return UDim2.fromOffset(x, y)
	end
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
			local portrait = CommanderPortrait(rig, {
				IsDanger = CommanderClient.IsDanger,
				Fade = fade,
				Position = portraitPosition,
				Size = portraitSize,
			})
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
			--[[ Reflects the authoritative passage progress without visual delay. ]]
			local function passageProgress(): number
				local progress = if CommanderClient.ReadProgress then CommanderClient.ReadProgress()
					else CommanderClient.LineIndex() / math.max(#DialogueData.Introduction, 1)
				return math.clamp(progress, 0, 1)
			end
			return create("Frame")({
				Name = "Presentation",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Vide.action(function(frame: Frame)
					--[[ Updates the responsive layout when its usable display area changes. ]]
					local function updateViewportSize()
						viewportSize(frame.AbsoluteSize)
					end
					Vide.cleanup(frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateViewportSize))
					updateViewportSize()
				end),
				create("Frame")({
					Name = "CommanderAnchor",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = getPanelPosition,
					Size = panelSize,
					create("UIScale")({ Scale = panelScale }),
					create("UIAspectRatioConstraint")({ AspectRatio = PANEL_ASPECT_RATIO }),
					portrait,
					create("Frame")({
						Name = "Frame",
						AnchorPoint = Vector2.zero,
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = function()
							return 0.05 + 0.95 * fade()
						end,
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
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
						create("TextLabel")({
							Name = "ContinueHint",
							AnchorPoint = Vector2.new(1, 0.5),
							BackgroundTransparency = 1,
							Position = UDim2.fromScale(0.94, 0.86),
							Size = UDim2.fromScale(0.6, 0.07),
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
							Name = "TransmissionTrack",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.new(1, 1, 1),
							BackgroundTransparency = function()
								return 0.9 + 0.1 * fade()
							end,
							BorderSizePixel = 0,
							Position = UDim2.fromScale(0.5, 0.94),
							Size = UDim2.new(0.88, 0, 0, 3),
							ClipsDescendants = true,
							ZIndex = 3,
							create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
							create("Frame")({
								Name = "TransmissionProgress",
								BackgroundColor3 = Color3.new(1, 1, 1),
								BackgroundTransparency = fade,
								BorderSizePixel = 0,
								Size = function()
									return UDim2.fromScale(passageProgress(), 1)
								end,
								ZIndex = 3,
								create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
							}),
						}),
					}),
				}),
			})
		end),
	})
end

-- // INITIALIZATION // --
return CommanderDialogueView
