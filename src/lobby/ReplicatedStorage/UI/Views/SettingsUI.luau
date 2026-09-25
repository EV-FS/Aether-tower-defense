local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local NotificationFeed = require(ReplicatedStorage.Shared.Modules.UI.Notifications.NotificationFeed)
local SettingsMotion = require(ReplicatedStorage.Shared.Modules.UI.SettingsMotion)
local AutoSellConfig = require(ReplicatedStorage.Settings.Data.AutoSellConfig)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)

local create = Vide.create
local cleanup = Vide.cleanup
local changed = Vide.changed
local source = Vide.source
local spring = Vide.spring
local action = Vide.action
local effect = Vide.effect

local VIEW_ID = "Settings"
local BACKDROP_BLUR_SIZE = 10
local BLUR_IN_DURATION = 0.26
local BLUR_OUT_DURATION = SettingsMotion.BlurOutDuration

local SettingsClient
local UIController
local settingsIcon = source(nil :: any)

--// Reactive States
local activeTab = source("Sound") -- "Gameplay", "Sound", "Graphics"
local isCodeFrameOpen = source(false)

local musicVolume = source(50)
local sfxVolume = source(50)

local night = source(false)
local shadows = source(true)
local vfx = source(true)

local autoSkip = source(false)
local trade = source(true)
local autoSellStates = {}
for _, entry in AutoSellConfig.Rarities do
	autoSellStates[entry.SettingName] = source(false)
end

local isLast = false

--// Gradients
local SELECTED_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 103, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 42, 255)),
})

local UNSELECTED_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(208, 208, 208)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(107, 105, 172)),
})

local ICON_ON = "rbxassetid://134433670594759"
local ICON_OFF = "rbxassetid://137473012886337"
local AUTO_SELL_ROW_HEIGHT = 92
local AUTO_SELL_ROW_GAP = 8
local AUTO_SELL_VERTICAL_PADDING = 16

-------------------------------------------------
--// Helper Functions
-------------------------------------------------
local function bindSlider(volSource: any, settingName: string)
	return action(function(bg: GuiObject)
		local isDragging = false

		local function updateFromInput(inputPosition: Vector3)
			local bgAbsPos = bg.AbsolutePosition.X
			local bgAbsSize = bg.AbsoluteSize.X
			if bgAbsSize <= 0 then
				return
			end

			local percentage = math.clamp((inputPosition.X - bgAbsPos) / bgAbsSize, 0, 1)
			local newVol = math.round(percentage * 100)
			volSource(newVol)

			if SettingsClient then
				SettingsClient.ApplySetting(settingName, newVol)
			end
		end

		local beganConn = bg.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				isDragging = true
				updateFromInput(input.Position)
			end
		end)

		local changedConn = UserInputService.InputChanged:Connect(function(input)
			if
				isDragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				updateFromInput(input.Position)
			end
		end)

		local endedConn = UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				isDragging = false
			end
		end)

		Vide.cleanup(function()
			beganConn:Disconnect()
			changedConn:Disconnect()
			endedConn:Disconnect()
		end)
	end)
end

local function autoSellCard(entry)
	local enabled = autoSellStates[entry.SettingName]
	local rarityStyle = RarityRegistry.Get(entry.Name).Presentation

	return create("ImageLabel")({
		Name = `{entry.Name}AutoSell`,
		BackgroundTransparency = 1,
		Image = "rbxassetid://100233894637143",
		LayoutOrder = entry.Order,
		Size = UDim2.new(0.876982, 0, 0, AUTO_SELL_ROW_HEIGHT),
		ZIndex = 10,
		create("Frame")({
			Name = "RarityAccent",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.028, 0.5),
			Size = UDim2.fromScale(0.012, 0.62),
			create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			create("UIGradient")({ Color = rarityStyle.Gradient, Rotation = 90 }),
		}),
		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.06, 0.13),
			Size = UDim2.fromScale(0.56, 0.31),
			Text = string.upper(entry.Name),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UIStroke")({}),
			create("UIGradient")({ Color = rarityStyle.Gradient }),
		}),
		create("TextLabel")({
			Name = "Description",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.06, 0.5),
			Size = UDim2.fromScale(0.66, 0.24),
			Text = `AUTO SELL FOR {entry.Price} COINS`,
			TextColor3 = Color3.fromRGB(167, 167, 167),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UIStroke")({ Transparency = 0.35 }),
		}),
		create("ImageButton")({
			Name = "Toggle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = function()
				return if enabled() then ICON_ON else ICON_OFF
			end,
			Position = UDim2.fromScale(0.910334, 0.492328),
			Size = UDim2.fromScale(0.122286, 0.594306),
			ZIndex = 12,
			Activated = function()
				local newValue = not enabled()
				enabled(newValue)
				if SettingsClient then
					SettingsClient.ApplySetting(entry.SettingName, newValue)
				end
			end,
			useButtonEffect(0.9, 1.1),
			create("UIAspectRatioConstraint")({}),
		}),
	})
end

-------------------------------------------------
--// SettingsUI
-------------------------------------------------
local SettingsUI = {}

function SettingsUI.RenderUI()
	effect(function()
		local icon = settingsIcon()
		if not icon or not UIController then
			return
		end

		local isOpen = UIController:IsOpen(VIEW_ID) or UIController:IsOpen("Setting")
		if isOpen and not icon.isSelected then
			icon:select()
		elseif not isOpen and icon.isSelected then
			icon:deselect()
		end
	end)

	local isVisible = function()
		if not UIController then
			return false
		end
		return UIController:IsOpen("Settings") or UIController:IsOpen("Setting")
	end
	local enteredCode = source("")
	local isRedeemingCode = source(false)
	local codeTextBoxInstance: TextBox? = nil

	local function submitCode()
		if isRedeemingCode() or not isCodeFrameOpen() or not isVisible() then
			return
		end

		local code = string.match(enteredCode(), "^%s*(.-)%s*$") or ""
		if code == "" then
			NotificationFeed.Pull("Enter a code first.", "Error")
			return
		end

		isRedeemingCode(true)
		task.spawn(function()
			local ok, result = pcall(function()
				local folder = ReplicatedStorage:WaitForChild("RuntimeRemotes", 5)
				local remote = folder and folder:WaitForChild("RedeemCode", 5)
				if not remote or not remote:IsA("RemoteFunction") then
					error("RedeemCode remote is unavailable")
				end
				return remote:InvokeServer(code)
			end)

			isRedeemingCode(false)
			if not ok or type(result) ~= "table" then
				NotificationFeed.Pull("Could not redeem the code. Please try again.", "Error")
				return
			end

			local succeeded = result.Success == true
			NotificationFeed.Pull(
				result.Message or (if succeeded then "Code redeemed!" else "Code could not be redeemed."),
				if succeeded then "Normal" else "Error"
			)
			if succeeded then
				enteredCode("")
			end
		end)
	end

	effect(function()
		if not isCodeFrameOpen() then
			return
		end

		task.defer(function()
			if isCodeFrameOpen() and codeTextBoxInstance then
				codeTextBoxInstance:CaptureFocus()
			end
		end)
	end)

	local menuMotion = useMenuMotion(isVisible, function()
		return UIController:GetActiveView()
	end)
	local isWindowMounted = menuMotion.IsMounted
	local isWindowOpen = menuMotion.IsOpen
	effect(function()
		if not isVisible() then
			isCodeFrameOpen(false)
		end
	end)

	local backdropBlur = Instance.new("BlurEffect")
	backdropBlur.Name = "SettingsBackdropBlur"
	backdropBlur.Size = 0
	backdropBlur.Enabled = false
	backdropBlur.Parent = Lighting
	cleanup(function()
		backdropBlur:Destroy()
	end)

	effect(function()
		local shouldBlur = isWindowOpen()
		if shouldBlur then
			backdropBlur.Enabled = true
		end

		local tween = TweenService:Create(
			backdropBlur,
			TweenInfo.new(
				if shouldBlur then BLUR_IN_DURATION else BLUR_OUT_DURATION,
				Enum.EasingStyle.Quint,
				if shouldBlur then Enum.EasingDirection.Out else Enum.EasingDirection.InOut
			),
			{ Size = if shouldBlur then BACKDROP_BLUR_SIZE else 0 }
		)
		local completed = tween.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed and not shouldBlur then
				backdropBlur.Enabled = false
			end
		end)
		tween:Play()

		cleanup(function()
			completed:Disconnect()
			tween:Cancel()
		end)
	end)

	local codeFrameScale = spring(function()
		return if isCodeFrameOpen() then SettingsMotion.CodeFrameScale.Open else SettingsMotion.CodeFrameScale.Closed
	end, SettingsMotion.CodeFrameScale.Speed, SettingsMotion.CodeFrameScale.Damping)
	local codeFramePosition = spring(function()
		return if isCodeFrameOpen()
			then SettingsMotion.CodeFramePosition.Open
			else SettingsMotion.CodeFramePosition.Closed
	end, SettingsMotion.CodeFramePosition.Speed, SettingsMotion.CodeFramePosition.Damping)
	local codeFrameRotation = spring(function()
		return if isCodeFrameOpen()
			then SettingsMotion.CodeFrameRotation.Open
			else SettingsMotion.CodeFrameRotation.Closed
	end, SettingsMotion.CodeFrameRotation.Speed, SettingsMotion.CodeFrameRotation.Damping)
	local codeFrameTransparency = spring(function()
		return if isCodeFrameOpen()
			then SettingsMotion.CodeFrameTransparency.Open
			else SettingsMotion.CodeFrameTransparency.Closed
	end, SettingsMotion.CodeFrameTransparency.Speed, SettingsMotion.CodeFrameTransparency.Damping)

	local openSFX = useAudio({
		Id = UISFX.SettingsOpen.Id,
		Volume = UISFX.SettingsOpen.Volume,
	})
	local closeSFX = useAudio({
		Id = UISFX.Close.Id,
		Volume = UISFX.Close.Volume,
	})
	local autoSellCards = {}
	for _, entry in AutoSellConfig.Rarities do
		table.insert(autoSellCards, autoSellCard(entry))
	end

	effect(function()
		if UIController:IsVisible(VIEW_ID)() then
			isLast = true
			openSFX:Play()
		elseif isLast then
			isLast = false
			closeSFX:Play()
		end
	end)

	return create("CanvasGroup")({
		Name = "Setting",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = menuMotion.Transparency,
		Interactable = isVisible,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Visible = isWindowMounted,

		create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://129320583643853",
			Position = UDim2.fromScale(0.498839, 0.536386),
			Rotation = menuMotion:WindowRotation(),
			Size = menuMotion:WindowSize(UDim2.fromScale(0.721698, 0.668872)),

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 1.88,
			}),

			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://96923630520876",
				Position = menuMotion:HeaderPosition(UDim2.fromScale(-0.0573612, -0.111321)),
				Size = UDim2.fromScale(0.692821, 0.28349),
				ZIndex = 10,

				create("ImageLabel")({
					Name = "Gear",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://131771458383625",
					Position = UDim2.fromScale(0.129065, 0.438255),
					Rotation = menuMotion:IconRotation(),
					Size = menuMotion:IconSize(UDim2.fromScale(0.168507, 0.766167)),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
					}),
				}),

				create("ImageLabel")({
					Name = "Cloud",
					BackgroundTransparency = 1,
					Image = "rbxassetid://108560268349568",
					Position = menuMotion:CloudPosition(UDim2.fromScale(0.529887, 0.0551715)),
					ImageTransparency = menuMotion:Fade(),
					Size = UDim2.fromScale(0.537766, 1.06417),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
						AspectRatio = 2.16,
					}),
				}),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.265238, 0.435573),
					Size = UDim2.fromScale(0.283423, 0.290134),
					Text = "SETTINGS",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextTransparency = menuMotion:Fade(),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
						AspectRatio = 4.53,
					}),
				}),
			}),

			create("ImageButton")({
				Name = "CancelButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://92651860309635",
				Position = menuMotion:ClosePosition(UDim2.fromScale(0.980096, 0.0289194)),
				Rotation = menuMotion:CloseRotation(),
				Size = UDim2.fromScale(0.102144, 0.15458),

				Activated = function()
					if UIController then
						UIController:Close("Settings")
						UIController:Close("Setting")
					end
				end,

				useButtonEffect(0.9, 1.1),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("ImageLabel")({
				Name = "Buttons",
				BackgroundTransparency = 1,
				Image = "rbxassetid://130249132653728",
				Position = menuMotion:ContentPosition(UDim2.fromScale(0.019, 0.142896)),
				Rotation = menuMotion:Spring(0, -5, "Rotation"),
				Size = UDim2.fromScale(0.248173, 0.824884),

				create("Frame")({
					Name = "Frame",
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0, 0.0354881),
					Size = UDim2.fromScale(1, 0.964512),

					create("UIListLayout")({
						Name = "UIListLayout",
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.01, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					-- Gameplay Tab Button
					create("ImageButton")({
						Name = "GameplayButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://139274506988816",
						LayoutOrder = 1,
						Position = UDim2.fromScale(0.550869, 0.0709128),
						Size = UDim2.fromScale(0.863567, 0.141826),

						Activated = function()
							activeTab("Gameplay")
						end,

						useButtonEffect(0.95, 1.03),

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.342902, 0.288148),
							Size = UDim2.fromScale(0.588089, 0.384318),
							Text = "GAMEPLAY",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = function()
								return if activeTab() == "Gameplay" then SELECTED_GRADIENT else UNSELECTED_GRADIENT
							end,
							Rotation = 90,
						}),

						create("ImageLabel")({
							Name = "Icon",
							BackgroundTransparency = 1,
							Image = "rbxassetid://123487386657532",
							Position = UDim2.fromScale(0.0852872, 0.272446),
							Size = UDim2.fromScale(0.159332, 0.609755),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
								AspectRatio = 1.33,
							}),
						}),
					}),

					-- Sound Tab Button
					create("ImageButton")({
						Name = "SoundButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://139274506988816",
						LayoutOrder = 2,
						Position = UDim2.fromScale(0.550869, 0.0709128),
						Size = UDim2.fromScale(0.863567, 0.141826),

						Activated = function()
							activeTab("Sound")
						end,

						useButtonEffect(0.95, 1.03),

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.342902, 0.288148),
							Size = UDim2.fromScale(0.588089, 0.384318),
							Text = "SOUND",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = function()
								return if activeTab() == "Sound" then SELECTED_GRADIENT else UNSELECTED_GRADIENT
							end,
							Rotation = 90,
						}),

						create("ImageLabel")({
							Name = "Icon",
							BackgroundTransparency = 1,
							Image = "rbxassetid://140260312690510",
							Position = UDim2.fromScale(0.0852872, 0.190309),
							Size = UDim2.fromScale(0.159332, 0.609755),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),
						}),
					}),

					-- Graphics Tab Button
					create("ImageButton")({
						Name = "GraphicButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://139274506988816",
						LayoutOrder = 3,
						Position = UDim2.fromScale(0.550869, 0.0709128),
						Size = UDim2.fromScale(0.863567, 0.141826),

						Activated = function()
							activeTab("Graphics")
						end,

						useButtonEffect(0.95, 1.03),

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.342902, 0.288148),
							Size = UDim2.fromScale(0.588089, 0.384318),
							Text = "GRAPHICS",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("ImageLabel")({
							Name = "Icon",
							BackgroundTransparency = 1,
							Image = "rbxassetid://112062966976512",
							Position = UDim2.fromScale(0.0852872, 0.272445),
							Size = UDim2.fromScale(0.159332, 0.609755),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
								AspectRatio = 1.1,
							}),
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = function()
								return if activeTab() == "Graphics" then SELECTED_GRADIENT else UNSELECTED_GRADIENT
							end,
							Rotation = 90,
						}),
					}),

					-- Auto Sell Tab Button
					create("ImageButton")({
						Name = "AutoSellButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://139274506988816",
						LayoutOrder = 4,
						Position = UDim2.fromScale(0.550869, 0.0709128),
						Size = UDim2.fromScale(0.863567, 0.141826),
						Activated = function()
							activeTab("AutoSell")
						end,
						useButtonEffect(0.95, 1.03),
						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.25, 0.288148),
							Size = UDim2.fromScale(0.68, 0.384318),
							Text = "AUTO SELL",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							create("UIStroke")({}),
						}),
						create("ImageLabel")({
							Name = "Icon",
							BackgroundTransparency = 1,
							Image = "rbxassetid://117112996963807",
							Position = UDim2.fromScale(0.075, 0.19),
							Size = UDim2.fromScale(0.17, 0.62),
							create("UIAspectRatioConstraint")({}),
						}),
						create("UIGradient")({
							Color = function()
								return if activeTab() == "AutoSell" then SELECTED_GRADIENT else UNSELECTED_GRADIENT
							end,
							Rotation = 90,
						}),
					}),
				}),
			}),

			-- Sound Tab Content
			create("CanvasGroup")({
				Name = "SoundScrollingFrameClip",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AnchorPoint = Vector2.new(0, 0),
				Position = menuMotion:ContentPosition(UDim2.fromScale(0.262, 0.172)),
				Size = UDim2.fromScale(0.714, 0.799),
				ZIndex = 1,

				create("ScrollingFrame")({
					Name = "SoundScrollingFrame", AnchorPoint = Vector2.new(0, 0),
					Active = true,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0),
					ScrollBarImageColor3 = Color3.new(),
					Size = UDim2.fromScale(1, 1),
					Visible = function()
						return activeTab() == "Sound"
					end,

					create("UIListLayout")({
						Name = "UIListLayout",
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.01, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					-- Background Music Slider
					create("ImageLabel")({
						Name = "SettingSubFrame",
						BackgroundTransparency = 1,
						Image = "rbxassetid://100233894637143",
						LayoutOrder = 1,
						Position = UDim2.fromScale(0.0680607, 0.026384),
						Size = UDim2.fromScale(0.876982, 0.40148),
						ZIndex = 10,

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336405, 0.142266),
							Size = UDim2.fromScale(0.494039, 0.290134),
							Text = "BACKGROUND MUSIC",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
							AspectRatio = 4.8,
						}),

						create("TextLabel")({
							Name = "Description",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336405, 0.424292),
							Size = UDim2.fromScale(0.477107, 0.276873),
							Text = "Adjust Background Music Volume.",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(167, 167, 167)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(167, 167, 167)),
								}),
							}),
						}),

						create("ImageLabel")({
							Name = "BarBG",
							BackgroundTransparency = 1,
							Image = "rbxassetid://111497714681866",
							Position = UDim2.fromScale(0.550592, 0.424999),
							Size = UDim2.fromScale(0.428057, 0.133863),

							bindSlider(musicVolume, "MusicVolume"),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 36, 28)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(44, 36, 28)),
								}),
							}),
						}),

						create("ImageLabel")({
							Name = "BarFill",
							BackgroundTransparency = 1,
							Image = "rbxassetid://111497714681866",
							Position = UDim2.fromScale(0.550592, 0.424999),
							Size = function()
								local ratio = math.clamp(musicVolume() / 100, 0, 1)
								return UDim2.fromScale(0.428057 * ratio, 0.133863)
							end,

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(62, 73, 147)),
									ColorSequenceKeypoint.new(0.517007, Color3.fromRGB(52, 58, 147)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(202, 197, 255)),
								}),
							}),
						}),

						create("ImageLabel")({
							Name = "BarToggle",
							BackgroundTransparency = 1,
							Image = "rbxassetid://116700506653527",
							Position = function()
								local ratio = math.clamp(musicVolume() / 100, 0, 1)
								return UDim2.fromScale(0.550592 + (0.95 - 0.550592) * ratio, 0.398)
							end,
							Size = UDim2.fromScale(0.0431976, 0.184385),
							ZIndex = 12,

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),
						}),
					}),

					-- SFX Sound Slider
					create("ImageLabel")({
						Name = "SettingSubFrame",
						BackgroundTransparency = 1,
						Image = "rbxassetid://100233894637143",
						LayoutOrder = 2,
						Position = UDim2.fromScale(0.0680607, 0.026384),
						Size = UDim2.fromScale(0.876982, 0.40148),
						ZIndex = 10,

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336405, 0.142266),
							Size = UDim2.fromScale(0.494039, 0.290134),
							Text = "SFX SOUND",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
							AspectRatio = 4.8,
						}),

						create("TextLabel")({
							Name = "Description",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336405, 0.424292),
							Size = UDim2.fromScale(0.477107, 0.276873),
							Text = "Adjust Every SFX Sound of Game.",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(167, 167, 167)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(167, 167, 167)),
								}),
							}),
						}),

						create("ImageLabel")({
							Name = "BarBG",
							BackgroundTransparency = 1,
							Image = "rbxassetid://111497714681866",
							Position = UDim2.fromScale(0.550592, 0.424999),
							Size = UDim2.fromScale(0.428057, 0.133863),

							bindSlider(sfxVolume, "SFXVolume"),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 36, 28)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(44, 36, 28)),
								}),
							}),
						}),

						create("ImageLabel")({
							Name = "BarFill",
							BackgroundTransparency = 1,
							Image = "rbxassetid://111497714681866",
							Position = UDim2.fromScale(0.550592, 0.424999),
							Size = function()
								local ratio = math.clamp(sfxVolume() / 100, 0, 1)
								return UDim2.fromScale(0.428057 * ratio, 0.133863)
							end,

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(62, 73, 147)),
									ColorSequenceKeypoint.new(0.517007, Color3.fromRGB(52, 58, 147)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(202, 197, 255)),
								}),
							}),
						}),

						create("ImageLabel")({
							Name = "BarToggle",
							BackgroundTransparency = 1,
							Image = "rbxassetid://116700506653527",
							Position = function()
								local ratio = math.clamp(sfxVolume() / 100, 0, 1)
								return UDim2.fromScale(0.550592 + (0.95 - 0.550592) * ratio, 0.398)
							end,
							Size = UDim2.fromScale(0.0431976, 0.184385),
							ZIndex = 12,

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),
						}),
					}),
				}),
			}),

			-- Graphics Tab Content
			create("CanvasGroup")({
				Name = "GraphicsScrollingFrameClip",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AnchorPoint = Vector2.new(0, 0),
				Position = menuMotion:ContentPosition(UDim2.fromScale(0.262, 0.172)),
				Size = UDim2.fromScale(0.714, 0.799),
				ZIndex = 1,

				create("ScrollingFrame")({
					Name = "GraphicsScrollingFrame", AnchorPoint = Vector2.new(0, 0),
					Active = true,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0),
					ScrollBarImageColor3 = Color3.new(),
					Size = UDim2.fromScale(1, 1),
					Visible = function()
						return activeTab() == "Graphics"
					end,

					create("UIListLayout")({
						Name = "UIListLayout",
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.01, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					-- Set Night Toggle
					create("ImageLabel")({
						Name = "SettingSubFrame",
						BackgroundTransparency = 1,
						Image = "rbxassetid://100233894637143",
						LayoutOrder = 1,
						Position = UDim2.fromScale(0.0527731, 0.00586313),
						Size = UDim2.fromScale(0.876982, 0.40148),
						ZIndex = 10,

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336405, 0.142266),
							Size = UDim2.fromScale(0.494039, 0.290134),
							Text = "Set Night",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
							AspectRatio = 4.8,
						}),

						create("TextLabel")({
							Name = "Description",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336404, 0.424292),
							Size = UDim2.fromScale(0.322276, 0.276873),
							Text = "Set Game Time Night.",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(167, 167, 167)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(167, 167, 167)),
								}),
							}),
						}),

						create("ImageButton")({
							Name = "NightToggle",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = function()
								return if night() then ICON_ON else ICON_OFF
							end,
							Position = UDim2.fromScale(0.910334, 0.492328),
							Size = UDim2.fromScale(0.122286, 0.594306),
							ZIndex = 12,

							Activated = function()
								local newNight = not night()
								night(newNight)
								if SettingsClient then
									SettingsClient.ApplySetting("Night", newNight)
								end
							end,

							useButtonEffect(0.9, 1.1),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),
						}),
					}),

					-- Set Shadow Toggle
					create("ImageLabel")({
						Name = "SettingSubFrame",
						BackgroundTransparency = 1,
						Image = "rbxassetid://100233894637143",
						LayoutOrder = 2,
						Position = UDim2.fromScale(0.0527731, 0.00586313),
						Size = UDim2.fromScale(0.876982, 0.40148),
						ZIndex = 10,

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336405, 0.142266),
							Size = UDim2.fromScale(0.494039, 0.290134),
							Text = "Set Shadow",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
							AspectRatio = 4.8,
						}),

						create("TextLabel")({
							Name = "Description",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336404, 0.424292),
							Size = UDim2.fromScale(0.477107, 0.276873),
							Text = "Turn on/off Shadow in Games.",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(167, 167, 167)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(167, 167, 167)),
								}),
							}),
						}),

						create("ImageButton")({
							Name = "ShadowToggle",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = function()
								return if shadows() then ICON_ON else ICON_OFF
							end,
							Position = UDim2.fromScale(0.910334, 0.492328),
							Size = UDim2.fromScale(0.122286, 0.594306),
							ZIndex = 12,

							Activated = function()
								local newShadows = not shadows()
								shadows(newShadows)
								if SettingsClient then
									SettingsClient.ApplySetting("Shadows", newShadows)
								end
							end,

							useButtonEffect(0.9, 1.1),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),
						}),
					}),

					-- Set VFX Toggle
					create("ImageLabel")({
						Name = "SettingSubFrame",
						BackgroundTransparency = 1,
						Image = "rbxassetid://100233894637143",
						LayoutOrder = 3,
						Position = UDim2.fromScale(0.0527731, 0.00586313),
						Size = UDim2.fromScale(0.876982, 0.40148),
						ZIndex = 10,

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336405, 0.142266),
							Size = UDim2.fromScale(0.494039, 0.290134),
							Text = "Set VFX",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
							AspectRatio = 4.8,
						}),

						create("TextLabel")({
							Name = "Description",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336404, 0.424292),
							Size = UDim2.fromScale(0.459675, 0.276873),
							Text = "Turn on/off VFX in Games.",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(167, 167, 167)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(167, 167, 167)),
								}),
							}),
						}),

						create("ImageButton")({
							Name = "VFXToggle",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = function()
								return if vfx() then ICON_ON else ICON_OFF
							end,
							Position = UDim2.fromScale(0.910334, 0.492328),
							Size = UDim2.fromScale(0.122286, 0.594306),
							ZIndex = 12,

							Activated = function()
								local newVfx = not vfx()
								vfx(newVfx)
								if SettingsClient then
									SettingsClient.ApplySetting("VFX", newVfx)
								end
							end,

							useButtonEffect(0.9, 1.1),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),
						}),
					}),
				}),
			}),

			-- Gameplay Tab Content
			create("CanvasGroup")({
				Name = "GameplayScrollingFrameClip",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AnchorPoint = Vector2.new(0, 0),
				Position = menuMotion:ContentPosition(UDim2.fromScale(0.262, 0.172)),
				Size = UDim2.fromScale(0.714, 0.799),
				ZIndex = 1,

				create("ScrollingFrame")({
					Name = "GameplayScrollingFrame", AnchorPoint = Vector2.new(0, 0),
					Active = true,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0),
					ScrollBarImageColor3 = Color3.new(),
					Size = UDim2.fromScale(1, 1),
					Visible = function()
						return activeTab() == "Gameplay"
					end,

					create("UIListLayout")({
						Name = "UIListLayout",
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.01, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					-- Auto Skip Toggle
					create("ImageLabel")({
						Name = "SettingSubFrame",
						BackgroundTransparency = 1,
						Image = "rbxassetid://100233894637143",
						LayoutOrder = 1,
						Position = UDim2.fromScale(0.0527731, 0.00586313),
						Size = UDim2.fromScale(0.876982, 0.40148),
						ZIndex = 10,

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336405, 0.142266),
							Size = UDim2.fromScale(0.494039, 0.290134),
							Text = "Auto Skip",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
							AspectRatio = 4.8,
						}),

						create("TextLabel")({
							Name = "Description",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336404, 0.424292),
							Size = UDim2.fromScale(0.368069, 0.378335),
							Text = "Turn on/off Auto skip in Games.",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(167, 167, 167)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(167, 167, 167)),
								}),
							}),
						}),

						create("ImageButton")({
							Name = "AutoSkipToggle",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = function()
								return if autoSkip() then ICON_ON else ICON_OFF
							end,
							Position = UDim2.fromScale(0.910334, 0.492328),
							Size = UDim2.fromScale(0.122286, 0.594306),
							ZIndex = 12,

							Activated = function()
								local newAutoSkip = not autoSkip()
								autoSkip(newAutoSkip)
								if SettingsClient then
									SettingsClient.ApplySetting("AutoSkip", newAutoSkip)
								end
							end,

							useButtonEffect(0.9, 1.1),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),
						}),
					}),

					-- Trade Enable Toggle
					create("ImageLabel")({
						Name = "SettingSubFrame",
						BackgroundTransparency = 1,
						Image = "rbxassetid://100233894637143",
						LayoutOrder = 2,
						Position = UDim2.fromScale(0.0527731, 0.00586313),
						Size = UDim2.fromScale(0.876982, 0.40148),
						ZIndex = 10,

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336405, 0.142266),
							Size = UDim2.fromScale(0.494039, 0.290134),
							Text = "Trade enable",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
							AspectRatio = 4.8,
						}),

						create("TextLabel")({
							Name = "Description",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0336404, 0.424292),
							Size = UDim2.fromScale(0.459675, 0.276873),
							Text = "Turn on/off Trade in Games.",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(167, 167, 167)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(167, 167, 167)),
								}),
							}),
						}),

						create("ImageButton")({
							Name = "TradeToggle",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = function()
								return if trade() then ICON_ON else ICON_OFF
							end,
							Position = UDim2.fromScale(0.910334, 0.492328),
							Size = UDim2.fromScale(0.122286, 0.594306),
							ZIndex = 12,

							Activated = function()
								local newTrade = not trade()
								trade(newTrade)
								if SettingsClient then
									SettingsClient.ApplySetting("Trade", newTrade)
								end
							end,

							useButtonEffect(0.9, 1.1),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),
						}),
					}),
				}),
			}),

			-- Auto Sell Tab Content
			create("CanvasGroup")({
				Name = "AutoSellScrollingFrameClip",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = menuMotion:ContentPosition(UDim2.fromScale(0.262, 0.172)),
				Size = UDim2.fromScale(0.714, 0.799),
				ZIndex = 1,
				create("ScrollingFrame")({
					Name = "AutoSellScrollingFrame",
					Active = true,
					AutomaticCanvasSize = Enum.AutomaticSize.None,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromOffset(
						0,
						#AutoSellConfig.Rarities * AUTO_SELL_ROW_HEIGHT
							+ (#AutoSellConfig.Rarities - 1) * AUTO_SELL_ROW_GAP
							+ AUTO_SELL_VERTICAL_PADDING
					),
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ScrollBarImageColor3 = Color3.fromRGB(120, 115, 180),
					ScrollBarThickness = 5,
					Size = UDim2.fromScale(1, 1),
					Visible = function()
						return activeTab() == "AutoSell"
					end,
					create("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, AUTO_SELL_ROW_GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					create("UIPadding")({
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 7),
					}),
					table.unpack(autoSellCards)
				}),
			}),

			-- Code Button
			create("ImageButton")({
				Name = "CodeButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://110509589182931",
				Position = spring(function()
					return if isWindowOpen()
						then SettingsMotion.CodeButtonPosition.Open
						else SettingsMotion.CodeButtonPosition.Closed
				end, SettingsMotion.CodeButtonPosition.Speed, SettingsMotion.CodeButtonPosition.Damping),
				Size = UDim2.fromScale(0.0773201, 0.138996),
				ZIndex = 11,

				Activated = function()
					if not isWindowOpen() then
						return
					end
					local willOpen = not isCodeFrameOpen()
					if willOpen then
						enteredCode("")
					end
					isCodeFrameOpen(willOpen)
				end,

				useButtonEffect(0.9, 1.1),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			-- Dim the settings behind the code popup and let players click outside to close it.
			create("TextButton")({
				Name = "CodeBackdrop",
				Active = isCodeFrameOpen,
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(9, 10, 24),
				BackgroundTransparency = spring(function()
					return if isCodeFrameOpen() then 0.38 else 1
				end, 0.22, 0.9),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				Visible = function()
					return isCodeFrameOpen() or codeFrameTransparency() < 0.995
				end,
				ZIndex = 19,

				Activated = function()
					isCodeFrameOpen(false)
				end,
			}),

			-- Code Frame Popup
			create("CanvasGroup")({
				Name = "CodeFrame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				GroupTransparency = codeFrameTransparency,
				Interactable = function()
					return isWindowOpen() and isCodeFrameOpen()
				end,
				Position = codeFramePosition,
				Rotation = codeFrameRotation,
				Size = UDim2.fromScale(0.721978, 0.581701),
				Visible = function()
					return isCodeFrameOpen() or codeFrameTransparency() < 0.995
				end,
				ZIndex = 20,

				create("UIScale")({
					Name = "PopupScale",
					Scale = codeFrameScale,
				}),

				create("ImageLabel")({
					Name = "Background",
					BackgroundTransparency = 1,
					Image = "rbxassetid://89682027301608",
					Size = UDim2.fromScale(1, 1),
					ZIndex = 20,
				}),

				create("ImageLabel")({
					Name = "Textbox",
					BackgroundTransparency = 1,
					Image = "rbxassetid://75576176520621",
					Position = UDim2.fromScale(0.118315, 0.487708),
					Size = UDim2.fromScale(0.756126, 0.447473),
					ZIndex = 21,

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
						AspectRatio = 5.2,
					}),

					create("TextBox")({
						Name = "TextBox",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						ClearTextOnFocus = false,
						FontFace = Font.new(
							"rbxasset://fonts/families/FredokaOne.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						PlaceholderText = "Input your code..",
						PlaceholderColor3 = Color3.fromRGB(177, 177, 177),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.904278, 0.333969),
						Text = enteredCode,
						TextColor3 = Color3.new(1, 1, 1),
						TextEditable = function()
							return not isRedeemingCode()
						end,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 22,

						changed("Text", function(value: string)
							if #value > 40 then
								value = string.sub(value, 1, 40)
							end
							enteredCode(value)
						end),

						action(function(textBox: TextBox)
							codeTextBoxInstance = textBox
							local connection = textBox.FocusLost:Connect(function(enterPressed)
								if enterPressed then
									submitCode()
								end
							end)
							cleanup(function()
								connection:Disconnect()
								if codeTextBoxInstance == textBox then
									codeTextBoxInstance = nil
								end
							end)
						end),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(177, 177, 177)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(177, 177, 177)),
							}),
							Rotation = 90,
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0.6),
								NumberSequenceKeypoint.new(1, 0.6),
							}),
						}),
					}),
				}),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.295266, 0.270847),
					Size = UDim2.fromScale(0.397777, 0.112524),
					Text = "Input Code for Gift!",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 21,
				}),

				create("ImageButton")({
					Name = "RedeemButton",
					Active = function()
						return not isRedeemingCode()
					end,
					AnchorPoint = Vector2.new(0.5, 0.5),
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					Image = "rbxassetid://139274506988816",
					ImageColor3 = function()
						return if isRedeemingCode() then Color3.fromRGB(145, 145, 160) else Color3.new(1, 1, 1)
					end,
					Position = UDim2.fromScale(0.5, 0.82),
					Size = UDim2.fromScale(0.34, 0.13),
					ZIndex = 22,

					Activated = submitCode,
					useButtonEffect(0.95, 1.04),

					create("UIGradient")({
						Color = SELECTED_GRADIENT,
						Rotation = 90,
					}),
					create("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Size = UDim2.fromScale(1, 1),
						Text = function()
							return if isRedeemingCode() then "CHECKING..." else "REDEEM"
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						ZIndex = 23,

						create("UIStroke")({ Thickness = 1.2 }),
						create("UITextSizeConstraint")({ MinTextSize = 9, MaxTextSize = 22 }),
					}),
				}),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
					AspectRatio = 2.4,
				}),

				create("ImageButton")({
					Name = "CancelButton",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://92651860309635",
					Position = UDim2.fromScale(0.945849, 0.0981555),
					Size = UDim2.fromScale(0.161544, 0.416873),
					ZIndex = 22,

					Activated = function()
						isCodeFrameOpen(false)
					end,

					useButtonEffect(0.9, 1.1),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
					}),
				}),

				create("ImageLabel")({
					Name = "DiscordIcon",
					BackgroundTransparency = 1,
					Image = "rbxassetid://135568147050223",
					Position = UDim2.fromScale(0.0646933, 0.143722),
					Size = UDim2.fromScale(0.0782418, 0.0915552),
					ZIndex = 21,

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
						AspectRatio = 1.33,
					}),
				}),
			}),
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 1.547,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		}),
	})
end

function SettingsUI.Init()
	SettingsClient = ServiceRegistry:GetService("SettingsClient")
	UIController = ServiceRegistry:GetService("UIController")
end

function SettingsUI.BindTopbarIcon(icon: any)
	settingsIcon(icon)
end

function SettingsUI.Open()
	if UIController and not (UIController:IsOpen(VIEW_ID) or UIController:IsOpen("Setting")) then
		UIController:Open(VIEW_ID)
	end
end

function SettingsUI.Close()
	if UIController and (UIController:IsOpen(VIEW_ID) or UIController:IsOpen("Setting")) then
		UIController:Close(VIEW_ID)
		UIController:Close("Setting")
	end
end

function SettingsUI.Start()
	-- Sync state from SettingsClient if available
	task.spawn(function()
		if SettingsClient then
			local currentSettings = SettingsClient.GetSettings() or {}
			if currentSettings.MusicVolume ~= nil then
				musicVolume(currentSettings.MusicVolume)
			end
			if currentSettings.SFXVolume ~= nil then
				sfxVolume(currentSettings.SFXVolume)
			end
			if currentSettings.Night ~= nil then
				night(currentSettings.Night)
			end
			if currentSettings.Shadows ~= nil then
				shadows(currentSettings.Shadows)
			end
			if currentSettings.VFX ~= nil then
				vfx(currentSettings.VFX)
			end
			if currentSettings.AutoSkip ~= nil then
				autoSkip(currentSettings.AutoSkip)
			end
			if currentSettings.Trade ~= nil then
				trade(currentSettings.Trade)
			end
			for _, entry in AutoSellConfig.Rarities do
				local savedValue = currentSettings[entry.SettingName]
				if savedValue ~= nil then
					autoSellStates[entry.SettingName](savedValue == true)
				end
			end
		end
	end)
end

return SettingsUI
