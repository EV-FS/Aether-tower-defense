local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useButtonHoverEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonHoverEffect)

local create = Vide.create
local cleanup = Vide.cleanup
local effect = Vide.effect
local spring = Vide.spring
local read = Vide.read

local CLOSE_DURATION = 0.4
local FRAME_SIZE = UDim2.fromScale(0.259539, 0.25)
local FRAME_ASPECT_RATIO = 1.84561

local function color(reactive, default)
	return function()
		local value = read(reactive)
		return if typeof(value) == "Color3" then ColorSequence.new(value) else value or default
	end
end

local ConfirmationUI = {}

function ConfirmationUI.RenderUI(confirmationService)
	local ConfirmationService = confirmationService or ServiceRegistry:GetService("ConfirmationService")

	cleanup(function()
		ConfirmationService:Close()
	end)

	local function property(name, default)
		return function()
			local request = ConfirmationService:GetCurrent()
			return if request then read(request.Props[name]) or default else default
		end
	end

	local animatePos, setFramePos = spring(function()
		return UDim2.fromScale(0.5, 0.5)
	end, 0.5, 0.6)

	local gui = create("Frame")({
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 300,

		create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Image = "rbxassetid://124674653668504",
			Position = animatePos,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 20,

			create("UICorner")({
				Name = "UICorner",
			}),

			create("UIStroke")({
				Name = "UIStroke",
				Color = Color3.fromRGB(112, 112, 112),
				Thickness = 2,
			}),

			create("ImageButton")({
				Name = "CancelButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://92651860309635",
				Position = UDim2.fromScale(0.993563, 0.023711),
				Size = UDim2.fromScale(0.135834, 0.199719),
				ZIndex = 2,

				Activated = function()
					ConfirmationService:Decline(ConfirmationService:GetCurrent())
				end,
				useButtonEffect(),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("TextLabel")({
				Name = "Description",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.166092, 0.255515),
				Size = UDim2.fromScale(0.665851, 0.15),
				Text = property("Text", ""),
				TextWrapped = true,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			}),

			create("TextLabel")({
				Name = "SubText",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.168337, 0.43),
				Size = UDim2.fromScale(0.665851, 0.25),
				Text = property("SubText", ""),
				TextWrapped = true,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			}),

			create("ImageButton")({
				Name = "AcceptButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://83967774994235",
				Position = UDim2.fromScale(0.255305, 0.898949),
				Size = UDim2.fromScale(0.466878, 0.156111),

				Activated = function()
					ConfirmationService:Accept(ConfirmationService:GetCurrent())
				end,
				useButtonEffect(),
				useButtonHoverEffect(),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.265238, 0.268678),
					Size = UDim2.fromScale(0.467855, 0.487941),
					Text = property("AcceptText", "Accept"),
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,

					create("UIStroke")({
						Name = "UIStroke",
					}),
				}),

				create("UICorner")({
					Name = "UICorner",
					BottomLeftRadius = UDim.new(0, 7),
					BottomRightRadius = UDim.new(0, 7),
					TopLeftRadius = UDim.new(0, 7),
					TopRightRadius = UDim.new(0, 7),
				}),

				create("UIGradient")({
					Color = color(
						property("AcceptColor"),
						ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 255, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 238, 1)),
						})
					),
				}),
			}),

			create("ImageButton")({
				Name = "DeclineButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://83967774994235",
				Position = UDim2.fromScale(0.738688, 0.898949),
				Size = UDim2.fromScale(0.468515, 0.156111),

				Activated = function()
					ConfirmationService:Decline(ConfirmationService:GetCurrent())
				end,
				useButtonEffect(),
				useButtonHoverEffect(),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.265238, 0.24534),
					Size = UDim2.fromScale(0.467855, 0.487941),
					Text = property("DeclineText", "Decline"),
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,

					create("UIStroke")({
						Name = "UIStroke",
					}),
				}),

				create("UICorner")({
					BottomLeftRadius = UDim.new(0, 7),
					BottomRightRadius = UDim.new(0, 7),
					TopLeftRadius = UDim.new(0, 7),
					TopRightRadius = UDim.new(0, 7),
				}),

				create("UIGradient")({
					Color = color(
						property("DeclineColor"),
						ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(134, 134, 134)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(134, 134, 134)),
						})
					),
				}),
			}),

			create("Frame")({
				Name = "Top",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(1, 0.17),

				create("TextLabel")({
					Name = "Title",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					LayoutOrder = 1,
					Position = UDim2.fromScale(0.388296, 0.0471816),
					Size = UDim2.fromScale(0.0180609, 0.457516),
					Text = property("Title", "Confirmation"),
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,

					create("UIStroke")({
						Name = "UIStroke",
					}),
				}),

				create("UIListLayout")({
					Name = "UIListLayout",
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.015, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				create("ImageLabel")({
					Name = "Symbol",
					BackgroundTransparency = 1,
					Image = "rbxassetid://116786072942209",
					Position = UDim2.fromScale(0.321198, 0.0298204),
					Size = UDim2.fromScale(0.0339394, 0.669935),
					ZIndex = -1,

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
						AspectRatio = 0.55,
					}),
				}),
			}),
		}),
	})

	local main = gui:FindFirstChild("Main") :: ImageLabel

	local function resetPosition(position: UDim2)
		setFramePos({
			position = position,
			velocity = UDim2.fromScale(0, 0),
		})
		main.Position = position
	end

	effect(function()
		local request = ConfirmationService:GetCurrent()
		if not request then
			return
		end

		if request.IsOpen() then
			gui.Position = UDim2.fromScale(0.5, 0.5)
			gui.Size = UDim2.fromScale(1, 1)
			resetPosition(UDim2.fromScale(0.5, 0.7))
			return
		end

		resetPosition(UDim2.fromScale(0.5, 0.5))

		local positionTween = TweenService:Create(
			gui,
			TweenInfo.new(CLOSE_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Position = UDim2.fromScale(0.5, 3.5) }
		)
		local sizeTween = TweenService:Create(
			gui,
			TweenInfo.new(CLOSE_DURATION, Enum.EasingStyle.Exponential, Enum.EasingDirection.In),
			{ Size = UDim2.fromScale(0, 0) }
		)

		local completed = sizeTween.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				ConfirmationService:CompleteClose(request)
			end
		end)

		cleanup(function()
			completed:Disconnect()
			positionTween:Cancel()
			positionTween:Destroy()
			sizeTween:Cancel()
			sizeTween:Destroy()
		end)

		positionTween:Play()
		sizeTween:Play()
	end)

	local container = create("Frame")({
		Name = "ConfirmationUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 300,
		Visible = function()
			return ConfirmationService:GetCurrent() ~= nil
		end,

		create("TextButton")({
			Name = "InputBlocker",
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Modal = true,
			Selectable = false,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 1,
		}),

		create("Frame")({
			Name = "ConfirmationFrame",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = FRAME_SIZE,
			ZIndex = 300,

			create("UIAspectRatioConstraint")({
				AspectRatio = FRAME_ASPECT_RATIO,
				AspectType = Enum.AspectType.ScaleWithParentSize,
			}),
			create("UISizeConstraint")({ MinSize = Vector2.new(280, 0) }),

			gui,
		}),
	})

	cleanup(container)
	return container
end

return ConfirmationUI
