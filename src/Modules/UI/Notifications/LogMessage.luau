local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)

local create = Vide.create
local spring = Vide.spring

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

return function(props)
	local item = if props.ItemName then ItemData.ByName[props.ItemName] else nil
	local rarity = if item then RarityRegistry.Get(item.Rarity).Presentation else nil
	local isError = props.LogType == "Error"

	return create("CanvasGroup")({
		Name = if item then "ItemReward" else "Message",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 101,
		create("CanvasGroup")({
			Name = "AnimatedBanner",
			BackgroundTransparency = 1,
			GroupTransparency = spring(function()
				return if props.State() == "Alive" then 0 else 1
			end, 0.3, 1),
			Position = spring(function()
				local state = props.State()
				if state == "Entering" then
					return UDim2.fromScale(-1, 0)
				elseif state == "Leaving" then
					return UDim2.fromScale(1, 0)
				end
				return UDim2.fromScale(0, 0)
			end, 0.3, 1),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 101,
			create("Frame")({
				Name = "FadedBackground",
				BackgroundColor3 = if isError then Color3.fromRGB(175, 38, 43) else Color3.new(),
				BackgroundTransparency = 0.48,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 101,
				create("UIGradient")({
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.15, 0.35),
						NumberSequenceKeypoint.new(0.3, 0),
						NumberSequenceKeypoint.new(0.7, 0),
						NumberSequenceKeypoint.new(0.85, 0.35),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),
			create("Frame")({
				Name = "Content",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 102,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 7),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				if item then create("ImageLabel")({
					Name = "ItemImage",
					BackgroundTransparency = 1,
					Image = item.ItemImage,
					LayoutOrder = 1,
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromOffset(30, 30),
					ZIndex = 103,
				}) else nil,
				create("TextLabel")({
					Name = if item then "ItemName" else "MessageText",
					BackgroundTransparency = 1,
					FontFace = FONT,
					LayoutOrder = 2,
					AutomaticSize = if item then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
					Size = if item then UDim2.fromOffset(0, 34) else UDim2.fromScale(1, 1),
					Text = if item then item.Name else props.Message or "",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 20,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 103,
					create("UIStroke")({ Color = Color3.new(), Thickness = 2 }),
					if rarity then create("UIGradient")({ Color = rarity.Gradient }) else nil,
				}),
				if item then create("TextLabel")({
					Name = "Quantity",
					BackgroundTransparency = 1,
					FontFace = FONT,
					LayoutOrder = 3,
					Size = UDim2.fromOffset(55, 34),
					Text = `x{props.Amount}`,
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 18,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 103,
					create("UIStroke")({ Color = Color3.new(), Thickness = 2 }),
				}) else nil,
			}),
		}),
	})
end
