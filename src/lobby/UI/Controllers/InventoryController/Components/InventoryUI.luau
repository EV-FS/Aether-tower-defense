local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
--local Net = require(ReplicatedStorage.Shared.Net.client)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)

local State = require(script.Parent.Parent.State)
local RarityBar = require(script.Parent.RarityBar)
local RarityList = require(script.Parent.RarityList)
local HoverViewUI = require(script.Parent.HoverViewUI)

return function(props)
	local rarityChildren = {
		Vide.create("UIPadding")({
			PaddingBottom = UDim.new(0, 5),
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 5),
		}),
		Vide.create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			ItemLineAlignment = Enum.ItemLineAlignment.End,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
	}
	for _, rarity in ipairs(State.RARITY_NAMES) do
		table.insert(
			rarityChildren,
			RarityBar({
				Rarity = rarity,
				LayoutOrder = State.RARITY_CONFIG[rarity].Order * 2 - 1,
				GradientColors = State.RARITY_CONFIG[rarity].Colors,
				Exist = State.RarityState[rarity].Exist,
				Opened = State.RarityState[rarity].Opened,
			})
		)
		table.insert(
			rarityChildren,
			RarityList({
				Rarity = rarity,
				LayoutOrder = State.RARITY_CONFIG[rarity].Order * 2,
				Exist = State.RarityState[rarity].Exist,
				Opened = State.RarityState[rarity].Opened,
				ListSource = State.RarityEntries[rarity],
			})
		)
	end

	local selectedInfo = Vide.derive(function()
		local selected = State.SelectedTower()
		return selected and TowerData.ByName[selected.Name] or nil
	end)

	return Vide.create("Frame")({
		Name = "Inventory",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 10,

		Vide.create("Frame")({
			Name = "ImageLabel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(18, 18, 18),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.566851, 0.479213),

			Vide.create("ScrollingFrame")({
				Name = "ElementList",
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BottomImage = "rbxassetid://3062505976",
				CanvasSize = UDim2.new(),
				MidImage = "rbxassetid://3062506202",
				Position = UDim2.fromScale(0.319227, 0.610595),
				ScrollBarThickness = 6,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.fromScale(0.609036, 0.720216),
				TopImage = "rbxassetid://3062506445",
				unpack(rarityChildren),
			}),

			Vide.create("TextButton")({
				Name = "Close",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.944553, 0.0174442),
				Size = UDim2.fromScale(0.076923, 0.0826413),
				Text = "X",
				TextColor3 = Color3.fromRGB(255, 73, 76),
				TextScaled = true,
				Vide.create("UIAspectRatioConstraint")({}),
				Activated = function()
					if props.OnClose then
						props.OnClose()
					end
				end,
			}),

			Vide.create("Frame")({
				Name = "Bar",
				BackgroundColor3 = Color3.fromRGB(39, 251, 255),
				BackgroundTransparency = 0.95,
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(-0.00162145, -0.00278845),
				Size = UDim2.fromScale(1, 0.1144),
				Vide.create("UIGradient")({
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 17, 17)),
						ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
					}),
					Rotation = 90,
				}),
			}),

			Vide.create("ImageButton")({
				Name = "SpaceLeft",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.823218, 0.0593113),
				Size = UDim2.fromScale(0.117634, 0.0534737),
				ZIndex = 2,
				Vide.create("TextLabel")({
					Name = "TextLabel",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Size = UDim2.fromScale(0.879203, 0.98437),
					Text = function()
						local total = 0
						for _, entry in pairs(State.ButtonEntries()) do
							total += entry.Count()
						end
						return `{total}/200`
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					Vide.create("UIStroke")({}),
					Vide.create("UITextSizeConstraint")({ MaxTextSize = 35 }),
				}),
				Vide.create("UIAspectRatioConstraint")({ AspectRatio = 3.63914 }),
			}),

			Vide.create("ImageButton")({
				Name = "AddSpace",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://126658240760406",
				Position = UDim2.fromScale(0.891425, 0.0589843),
				Size = UDim2.fromScale(0.0314488, 0.0524517),
				ZIndex = 2,
				Vide.create("UIAspectRatioConstraint")({ AspectRatio = 0.99186 }),
			}),

			Vide.create("TextLabel")({
				Name = "TowerName",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/FredokaOne.json",
					Enum.FontWeight.Regular,
					Enum.FontStyle.Italic
				),
				Position = UDim2.fromScale(0.645826, 0.13982),
				Size = UDim2.fromScale(0.333976, 0.0675328),
				Text = function()
					return (State.SelectedTower() or {}).Name or "Select a Tower"
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Vide.create("UIStroke")({}),
				Vide.create("UIGradient")({
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(158, 158, 158)),
					}),
					Rotation = 90,
				}),
			}),

			Vide.create("TextLabel")({
				Name = "Rarity",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/FredokaOne.json",
					Enum.FontWeight.Regular,
					Enum.FontStyle.Italic
				),
				Position = UDim2.fromScale(0.645826, 0.21105),
				Size = UDim2.fromScale(0.333976, 0.0543422),
				Text = function()
					return (selectedInfo() or {}).Rarity or ""
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Vide.create("UIStroke")({}),
				Vide.create("UIGradient")({
					Color = function()
						local rarity = (selectedInfo() or {}).Rarity
						return State.RARITY_CONFIG[rarity] and State.RARITY_CONFIG[rarity].Colors
							or ColorSequence.new(State.COLORS.DEFAULT)
					end,
					Offset = Vector2.new(0, 0.1),
					Rotation = 90,
				}),
			}),

			Vide.create("TextLabel")({
				Name = "TextLabel",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.0213847, 0.0234661),
				Size = UDim2.fromScale(0.328111, 0.0634287),
				Text = "Items",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Vide.create("ImageLabel")({
				Name = "TowerImage",
				BackgroundTransparency = 1,
				Image = function()
					return (selectedInfo() or {}).TowerImage or ""
				end,
				Position = UDim2.fromScale(0.679574, 0.282279),
				Size = UDim2.fromScale(0.294533, 0.457471),
				Visible = function()
					return State.SelectedTower() ~= nil
				end,
				Vide.create("UIAspectRatioConstraint")({}),
			}),

			HoverViewUI(),

			Vide.create("Frame")({
				Name = "ScollBar",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.612558, 0.23),
				Size = UDim2.fromScale(0.0159151, 0.754916),
				Vide.create("UICorner")({
					BottomLeftRadius = UDim.new(1, 0),
					BottomRightRadius = UDim.new(1, 0),
					TopLeftRadius = UDim.new(1, 0),
					TopRightRadius = UDim.new(1, 0),
				}),
				Vide.create("UIStroke")({
					Color = Color3.fromRGB(30, 30, 30),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.18,
				}),
				Vide.create("UIAspectRatioConstraint")({ AspectRatio = 0.0362554 }),
			}),

			Vide.create("UIStroke")({
				Color = Color3.fromRGB(65, 65, 65),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.007,
				ZIndex = 2,
			}),
			Vide.create("UIStroke")({ StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Thickness = 0.012 }),
			Vide.create("UICorner")({}),

			Vide.create("TextButton")({
				Name = "ToggleEquip",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(85, 255, 0),
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.812858, 0.91225),
				RichText = true,
				Size = UDim2.fromScale(0.333887, 0.06334),
				Text = "",
				TextColor3 = Color3.new(),
				TextScaled = true,
				ZIndex = 2,
				Visible = function()
					return State.SelectedTower() ~= nil
				end,
				Activated = function()
					if props.OnToggleEquip then
						props.OnToggleEquip()
					end
				end,
				Vide.create("Frame")({
					Name = "Frame",
					BackgroundColor3 = Color3.fromRGB(21, 143, 0),
					BackgroundTransparency = 0.5,
					Position = UDim2.fromScale(0, 0.473923),
					Size = UDim2.fromScale(1, 0.526077),
					Vide.create("UICorner")({
						BottomLeftRadius = UDim.new(0.2, 0),
						BottomRightRadius = UDim.new(0.2, 0),
						TopLeftRadius = UDim.new(0.2, 0),
						TopRightRadius = UDim.new(0.2, 0),
					}),
				}),
				Vide.create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
					Position = UDim2.fromScale(0.145287, 0.215392),
					Size = UDim2.fromScale(0.702747, 0.553866),
					Text = function()
						local selected = State.SelectedTower()
						if not selected then
							return "Equip"
						end
						local id = State.generateTowerId(selected.Name, selected.Key)
						return id and State.EquippedSlots()[id] and "Unequip" or "Equip"
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					Vide.create("UIStroke")({ StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Thickness = 0.15 }),
				}),
				Vide.create("UICorner")({
					BottomLeftRadius = UDim.new(0.1, 0),
					BottomRightRadius = UDim.new(0.1, 0),
					TopLeftRadius = UDim.new(0.1, 0),
					TopRightRadius = UDim.new(0.1, 0),
				}),
				Vide.create("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.06,
				}),
			}),

			Vide.create("UIAspectRatioConstraint")({ AspectRatio = 1.71973 }),

			Vide.create("Frame")({
				Name = "Stroke",
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.64, 0.770025),
				Size = UDim2.fromScale(0.341336, 0.214883),
				Vide.create("UICorner")({
					BottomLeftRadius = UDim.new(0.02, 0),
					BottomRightRadius = UDim.new(0.02, 0),
					TopLeftRadius = UDim.new(0.02, 0),
					TopRightRadius = UDim.new(0.02, 0),
				}),
				Vide.create("UIStroke")({
					Color = Color3.fromRGB(94, 94, 94),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.008,
					ZIndex = 2,
				}),
				Vide.create("UIStroke")({
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					Color = Color3.fromRGB(34, 34, 34),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.01,
				}),
				Vide.create("UIStroke")({ StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Thickness = 0.02 }),
			}),

			Vide.create("ImageLabel")({
				Name = "ImageLabel",
				BackgroundTransparency = 1,
				Image = "rbxassetid://105048264604047",
				Position = UDim2.fromScale(0.720736, 0.0253587),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.0354121, 0.0585812),
				ZIndex = 2,
				Vide.create("UIAspectRatioConstraint")({}),
			}),

			Vide.create("ImageLabel")({
				Name = "Search",
				BackgroundTransparency = 1,
				Image = "rbxassetid://127656522059242",
				ImageColor3 = Color3.fromRGB(61, 61, 61),
				Position = UDim2.fromScale(0.0147086, 0.133625),
				Size = UDim2.fromScale(0.415508, 0.101514),
				Vide.create("UIAspectRatioConstraint")({ AspectRatio = 7.03907 }),

				Vide.create("TextBox")({
					Name = "TextBox",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					PlaceholderColor3 = Color3.new(1, 1, 1),
					PlaceholderText = "Search...",
					Position = UDim2.fromScale(0.568541, 0.5),
					Size = UDim2.fromScale(0.855, 0.623706),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					Vide.create("UITextSizeConstraint")({ MaxTextSize = 18 }),
					Vide.create("UIStroke")({
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.1,
						Transparency = 0.5,
					}),
					Vide.action(function(inst)
						inst:GetPropertyChangedSignal("Text"):Connect(function()
							State.SearchText(inst.Text)
						end)
					end),
				}),

				Vide.create("ImageLabel")({
					Name = "Image",
					BackgroundTransparency = 1,
					Image = "rbxassetid://108219456206729",
					Position = UDim2.fromScale(0.0499999, 0.207902),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.0716623, 0.5867),
					Vide.create("UIAspectRatioConstraint")({ AspectRatio = 0.894737 }),
				}),
			}),

			Vide.create("ImageButton")({
				Name = "Categori",
				BackgroundTransparency = 1,
				Image = "rbxassetid://104904576284153",
				Position = UDim2.fromScale(0.440217, 0.142297),
				Size = UDim2.fromScale(0.182342, 0.0859372),
				Vide.create("TextLabel")({
					Name = "Shadow",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/GothamSSm.json",
						Enum.FontWeight.ExtraBold,
						Enum.FontStyle.Italic
					),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.851064, 0.614035),
					Text = "Units",
					TextColor3 = Color3.new(),
					TextScaled = true,
					ZIndex = 2,
					Vide.create("UIStroke")({
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.0882353,
					}),
				}),
				Vide.create("TextLabel")({
					Name = "Title",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/GothamSSm.json",
						Enum.FontWeight.ExtraBold,
						Enum.FontStyle.Italic
					),
					Position = UDim2.fromScale(0.5, 0.45),
					Size = UDim2.fromScale(0.851064, 0.614035),
					Text = "Units",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 3,
					Vide.create("UIStroke")({
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.0882353,
					}),
				}),
			}),

			Vide.create("TextButton")({
				Name = "Sell",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 0, 4),
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.723387, 0.831384),
				RichText = true,
				Size = UDim2.fromScale(0.154944, 0.06334),
				Text = "",
				TextColor3 = Color3.new(),
				TextScaled = true,
				ZIndex = 2,
				Visible = function()
					return State.SelectedTower() ~= nil
				end,
				Activated = function()
					local selected = State.SelectedTower()
					if selected then
						-- Net.DataService.SellTower:Fire(selected.Key)
					end
				end,
				Vide.create("Frame")({
					Name = "Frame",
					BackgroundColor3 = Color3.fromRGB(143, 0, 2),
					BackgroundTransparency = 0.5,
					Position = UDim2.fromScale(0, 0.473923),
					Size = UDim2.fromScale(1, 0.526077),
					Vide.create("UICorner")({
						BottomLeftRadius = UDim.new(0.2, 0),
						BottomRightRadius = UDim.new(0.2, 0),
						TopLeftRadius = UDim.new(0.2, 0),
						TopRightRadius = UDim.new(0.2, 0),
					}),
				}),
				Vide.create("TextLabel")({
					Name = "TextLabel",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
					Position = UDim2.fromScale(0.145287, 0.215392),
					Size = UDim2.fromScale(0.702747, 0.553866),
					Text = "Delete",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					Vide.create("UIStroke")({ StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Thickness = 0.15 }),
				}),
				Vide.create("UICorner")({
					BottomLeftRadius = UDim.new(0.1, 0),
					BottomRightRadius = UDim.new(0.1, 0),
					TopLeftRadius = UDim.new(0.1, 0),
					TopRightRadius = UDim.new(0.1, 0),
				}),
				Vide.create("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.06,
				}),
			}),

			Vide.create("TextButton")({
				Name = "Lock",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(170, 85, 255),
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.901095, 0.831384),
				RichText = true,
				Size = UDim2.fromScale(0.157415, 0.06334),
				Text = "",
				TextColor3 = Color3.new(),
				TextScaled = true,
				ZIndex = 2,
				Visible = function()
					return State.SelectedTower() ~= nil
				end,
				Activated = function()
					local selected = State.SelectedTower()
					if selected then
						-- Net.DataService.LockTower:Fire(selected.Key)
					end
				end,
				Vide.create("Frame")({
					Name = "Frame",
					BackgroundColor3 = Color3.fromRGB(81, 41, 122),
					BackgroundTransparency = 0.5,
					Position = UDim2.fromScale(0, 0.473923),
					Size = UDim2.fromScale(1, 0.526077),
					Vide.create("UICorner")({
						BottomLeftRadius = UDim.new(0.2, 0),
						BottomRightRadius = UDim.new(0.2, 0),
						TopLeftRadius = UDim.new(0.2, 0),
						TopRightRadius = UDim.new(0.2, 0),
					}),
				}),
				Vide.create("TextLabel")({
					Name = "TextLabel",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
					Position = UDim2.fromScale(0.145287, 0.215392),
					Size = UDim2.fromScale(0.702747, 0.553866),
					Text = "Lock",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					Vide.create("UIStroke")({ StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Thickness = 0.15 }),
				}),
				Vide.create("UICorner")({
					BottomLeftRadius = UDim.new(0.1, 0),
					BottomRightRadius = UDim.new(0.1, 0),
					TopLeftRadius = UDim.new(0.1, 0),
					TopRightRadius = UDim.new(0.1, 0),
				}),
				Vide.create("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.06,
				}),
			}),
		}),
	})
end
