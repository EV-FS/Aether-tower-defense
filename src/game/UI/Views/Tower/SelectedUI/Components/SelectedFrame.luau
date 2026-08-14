-- UI/Features/Tower/SelectedUI/Components/SelectedFrame.luau
-- New selected-tower panel, matching the exported "Container" hierarchy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

export type Props = {
	towerId: () -> string?,
	towerData: () -> {}?,
	playerCash: () -> number,
	isMounted: () -> boolean,
	isOpen: () -> boolean,
	OnChangeTarget: (step: number) -> (),
	OnUpgrade: () -> (),
	OnSell: () -> (),
	OnClose: () -> (),
}

local FONT = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local ARROW_IMAGE = "rbxassetid://97822781592426"

local function stroke(thickness: number?, color: Color3?)
	return create("UIStroke")({
		Name = "UIStroke",
		Thickness = thickness,
		Color = color,
	})
end

-- Every actionable control gets the same responsive "squash then bounce" treatment.
-- Keeping the state local means repeated presses remain responsive instead of waiting for
-- a shared tween to finish.
local function buttonEffects(hoverScale: number?, pressedScale: number?)
	local hovering = source(false)
	local pressing = source(false)
	local normalScale = 1
	local hover = hoverScale or 1.055
	local pressed = pressedScale or 0.9

	return {
		scale = spring(function()
			if pressing() then
				return pressed
			end
			return if hovering() then hover else normalScale
	end, 0.16, 0.78),
		enter = function()
			hovering(true)
		end,
		leave = function()
			hovering(false)
			pressing(false)
		end,
		down = function()
			pressing(true)
		end,
		up = function()
			pressing(false)
		end,
	}
end

return function(props: Props)
	local upgradeEffects = buttonEffects(1.045, 0.91)
	local targetEffects = buttonEffects(1.04, 0.92)
	local sellEffects = buttonEffects(1.04, 0.92)
	local closeEffects = buttonEffects(1.08, 0.87)
	local towerConfig = derive(function()
		local data = props.towerData()
		return data and TowerData.ByName[data.Name] or nil
	end)

	local nextStats = derive(function()
		local data = props.towerData()
		local config = towerConfig()
		return data and config and config.Stats[data.Level + 1] or nil
	end)

	local towerName = derive(function()
		local data = props.towerData()
		return data and data.Name or ""
	end)
	local towerRarity = derive(function()
		local config = towerConfig()
		return config and config.Rarity or ""
	end)
	local towerImage = derive(function()
		local config = towerConfig()
		return config and config.TowerImage or ""
	end)
	local levelBefore = derive(function()
		local data = props.towerData()
		return data and `Lv.{data.Level}` or ""
	end)
	local levelAfter = derive(function()
		local data = props.towerData()
		return data and `Lv.{data.Level + 1}` or ""
	end)
	local hasNextLevel = derive(function()
		return nextStats() ~= nil
	end)
	local upgradeCost = derive(function()
		local stats = nextStats()
		return stats and (stats.Cost or 0) or 0
	end)
	local upgradePrice = derive(function()
		return if hasNextLevel() then `${NumberUtils.FormatComma(upgradeCost())}` else "MAX"
	end)
	local canUpgrade = derive(function()
		return hasNextLevel() and props.playerCash() >= upgradeCost()
	end)
	local totalSpent = derive(function()
		local data = props.towerData()
		local config = towerConfig()
		if not data or not config then return 0 end
		local total = 0
		for level = 0, data.Level do
			local levelStats = config.Stats[level]
			total += levelStats and levelStats.Cost or 0
		end
		return total
	end)
	local sellPrice = derive(function()
		return `${NumberUtils.FormatComma(math.floor(totalSpent() / 2))}`
	end)
	local targetMode = derive(function()
		local data = props.towerData()
		return string.upper(data and data.Target or "First")
	end)

	local function statValue(key: string, after: boolean)
		return derive(function()
			local data = props.towerData()
			local stats = if after then nextStats() else (data and data.Stats)
			local value = stats and stats[key]
			return if value ~= nil then NumberUtils.FormatComma(value) else "-"
		end)
	end

	local function statVisible(key: string)
		return derive(function()
			local data = props.towerData()
			return data ~= nil and data.Stats ~= nil and data.Stats[key] ~= nil
		end)
	end

	local function statRow(name: string, title: string, image: string, key: string, order: number)
		return create("ImageLabel")({
			Name = name,
			BackgroundTransparency = 1,
			Image = image,
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0.158139),
			Visible = statVisible(key),

			create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint", AspectRatio = 7.25 }),
			create("TextLabel")({
				Name = "Title", BackgroundTransparency = 1, FontFace = FONT,
				Position = UDim2.fromScale(0.147, 0.11), Size = UDim2.fromScale(0.220651, 0.571764),
				Text = title, TextColor3 = Color3.new(1, 1, 1), TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			create("TextLabel")({
				Name = "QuantityBefore", BackgroundTransparency = 1, FontFace = FONT,
				Position = UDim2.fromScale(0.506218, 0), Size = UDim2.fromScale(0.222, 0.822),
				Text = statValue(key, false), TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(),
			}),
			create("ImageLabel")({
				Name = "Arrow", BackgroundTransparency = 1, Image = ARROW_IMAGE,
				Position = UDim2.fromScale(0.74, 0.28), Size = UDim2.fromScale(0.0360994, 0.373745),
				Visible = hasNextLevel(), create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint" }),
			}),
			create("TextLabel")({
				Name = "QuantityAfter", BackgroundTransparency = 1, FontFace = FONT,
				Position = UDim2.fromScale(0.774048, 0), Size = UDim2.fromScale(0.222, 0.822),
				Text = statValue(key, true), TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(),
			}),
		})
	end

	return create("Frame")({
		Name = "Selected", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		-- Mount only while selected; the hidden pose is still rendered for the entrance spring.
		Visible = props.isMounted, ZIndex = 2,

		create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint", AspectRatio = 1.467, AspectType = Enum.AspectType.ScaleWithParentSize }),
		create("CanvasGroup")({
			Name = "SelectionContent",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			-- A single shared fade keeps the background, text, stats, and buttons in sync.
			GroupTransparency = spring(function()
				return if props.isOpen() then 0 else 1
			end, 0.28, 0.88),

		create("ImageLabel")({
			Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
			Image = "rbxassetid://102689908161049",
			Rotation = spring(function() return if props.isOpen() then 0 else -7 end, 0.34, 0.7),
			Position = spring(function()
				-- Keep the full panel inside the viewport while preserving its left-side layout.
				return if props.isOpen() then UDim2.new(0.21, 0, 0.532712, 4) else UDim2.new(0.01, 0, 0.61, 4)
			end, 0.26, 0.72),
			Size = spring(function()
				return if props.isOpen() then UDim2.fromScale(0.463905, 0.402217) else UDim2.fromScale(0.31, 0.27)
			end, 0.26, 0.72),

			create("ImageLabel")({
				Name = "BackGround", BackgroundTransparency = 1, Image = "rbxassetid://134566959308327",
				Position = UDim2.fromScale(0.0463003, 0.0858005), Size = UDim2.fromScale(0.439986, 0.812131),
				create("UIGradient")({ Name = "UIGradient", Color = ColorSequence.new(Color3.fromRGB(96, 229, 255), Color3.fromRGB(255, 90, 255)) }),
				create("TextLabel")({ Name = "Name", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.143723, 0.0280452), Size = UDim2.fromScale(0.291928, 0.136709), Text = towerName, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2) }),
				create("TextLabel")({ Name = "Grade", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.143723, 0.117617), Size = UDim2.fromScale(0.292, 0.079), Text = towerRarity, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, stroke(2), create("UIGradient")({ Name = "UIGradient", Color = ColorSequence.new(Color3.fromRGB(167, 246, 255), Color3.fromRGB(245, 165, 255)) }) }),
				create("ViewportFrame")({ Name = "ViewportFrame", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }),
				create("ImageLabel")({ Name = "TowerImage", BackgroundTransparency = 1, Image = towerImage, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromScale(0.15, 0.18), Size = UDim2.fromScale(0.7, 0.65) }),
				create("ImageLabel")({ Name = "ImageLabel", BackgroundTransparency = 1, Image = "rbxassetid://132007095532074", Position = UDim2.fromScale(-0.00501101, 0.889016), Size = UDim2.fromScale(0.260067, 0.124021),
					create("TextLabel")({ Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.593341, 0.262976), Size = UDim2.fromScale(0.539731, 0.518178), Text = "LEVEL", TextColor3 = Color3.new(1, 1, 1), TextScaled = true }),
					create("TextLabel")({ Name = "Quantity", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.593341, 0.616051), Size = UDim2.fromScale(0.539731, 0.557653), Text = levelBefore, TextColor3 = Color3.new(1, 1, 1), TextScaled = true }),
				}),
			}),

			create("Frame")({ Name = "StatFrame", BackgroundTransparency = 1, Position = spring(function()
				return if props.isOpen() then UDim2.fromScale(0.515918, 0.0521041) else UDim2.fromScale(0.68, 0.11)
			end, 0.32, 0.72), Size = UDim2.fromScale(0.458932, 0.895669),
				create("ImageLabel")({ Name = "Level", BackgroundTransparency = 1, Image = "rbxassetid://85870147647883", Size = UDim2.fromScale(1, 0.154185),
					create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.0384327, 0.270131), Size = UDim2.fromScale(0.215355, 0.459739), Text = "LEVEL", TextColor3 = Color3.fromRGB(208, 200, 114), TextScaled = true }),
					create("TextLabel")({ Name = "LevelBefore", BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.552502, 0.26972), Size = UDim2.fromScale(0.137595, 0.459739), Text = levelBefore, TextColor3 = Color3.fromRGB(208, 208, 208), TextScaled = true }),
					create("ImageLabel")({ Name = "Arrow", BackgroundTransparency = 1, Image = ARROW_IMAGE, Position = UDim2.fromScale(0.726, 0.4), Size = UDim2.fromScale(0.0754627, 0.26172), Visible = hasNextLevel(), create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint" }) }),
					create("TextLabel")({ Name = "LevelAfter", BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.787857, 0.26972), Size = UDim2.fromScale(0.137595, 0.459739), Text = levelAfter, TextColor3 = Color3.fromRGB(61, 208, 29), TextScaled = true, Visible = hasNextLevel() }),
				}),
				create("ImageLabel")({ Name = "Stat", BackgroundTransparency = 1, Image = "rbxassetid://101111464029748", Position = UDim2.fromScale(0, 0.154185), Size = UDim2.fromScale(1, 0.379095),
					create("ScrollingFrame")({ Name = "ScrollingFrame", Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, CanvasSize = UDim2.new(), Position = UDim2.fromScale(0.0384332, 0.109657), ScrollBarImageColor3 = Color3.new(), ScrollBarThickness = 0, Size = UDim2.fromScale(0.932742, 0.890343),
						create("UIListLayout")({ Name = "UIListLayout", HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
						statRow("Damage", "DMG", "rbxassetid://81529748452567", "Damage", 1),
						statRow("Range", "RNG", "rbxassetid://95872294365618", "Range", 2),
						statRow("Cooldown", "COL", "rbxassetid://99198157761079", "Cooldown", 3),
						statRow("Income", "INC", "rbxassetid://81529748452567", "Income", 4),
						statRow("SplashRange", "SPL", "rbxassetid://95872294365618", "SplashRange", 5),
					}),
				}),
				create("ImageLabel")({ Name = "Upgrade", BackgroundTransparency = 1, Image = "rbxassetid://131324729406108", Position = UDim2.fromScale(0.0384332, 0.529115), Size = UDim2.fromScale(1, 0.287465),
					create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.038, 0.1), Size = UDim2.fromScale(0.249588, 0.184453), Text = "UPGRADE", TextColor3 = Color3.fromRGB(208, 200, 114), TextScaled = true }),
					create("TextLabel")({ Name = "Total", BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.578667, 0.1), Size = UDim2.fromScale(0.351613, 0.184453), Text = derive(function() return `Total ${NumberUtils.FormatComma(totalSpent())}` end), TextColor3 = Color3.fromRGB(208, 208, 208), TextScaled = true }),
					create("ImageButton")({ Name = "UpgradeButton", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://113857982985503",
						Position = spring(function() return if props.isOpen() then UDim2.fromScale(0.5, 0.6) else UDim2.fromScale(-0.8, 0.6) end, 0.32, 0.64),
						Rotation = spring(function() return if props.isOpen() then 0 else -28 end, 0.28, 0.62),
						Size = UDim2.fromScale(0.86228, 0.602873), Active = props.isOpen, AutoButtonColor = false, MouseEnter = upgradeEffects.enter, MouseLeave = upgradeEffects.leave, MouseButton1Down = upgradeEffects.down, MouseButton1Up = upgradeEffects.up, Activated = function() if canUpgrade() then props.OnUpgrade() end end,
						create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint", AspectRatio = 4.17 }),
						create("UIScale")({ Name = "ButtonScale", Scale = upgradeEffects.scale }),
						create("TextLabel")({ Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.496799, 0.275845), Size = UDim2.fromScale(0.404573, 0.592226), Text = "UPGRADE", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)) }),
						create("TextLabel")({ Name = "Price", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.497, 0.658), Size = UDim2.fromScale(0.31247, 0.447244), Text = upgradePrice, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)), create("UIGradient")({ Name = "UIGradient", Color = ColorSequence.new(Color3.fromRGB(25, 255, 21), Color3.fromRGB(228, 255, 55)), Rotation = 90 }) }),
					}),
				}),
				create("ImageLabel")({ Name = "ETC", BackgroundTransparency = 1, Image = "rbxassetid://85870147647883", Position = UDim2.fromScale(0, 0.820745), Size = UDim2.fromScale(1, 0.170845),
					create("ImageButton")({ Name = "TargetButton", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://104334746624623",
						Position = spring(function() return if props.isOpen() then UDim2.fromScale(0.2583, 0.487812) else UDim2.fromScale(-0.85, 0.487812) end, 0.36, 0.64),
						Rotation = spring(function() return if props.isOpen() then 0 else -22 end, 0.3, 0.6),
						Size = UDim2.fromScale(0.475784, 0.829346), Active = props.isOpen, AutoButtonColor = false, MouseEnter = targetEffects.enter, MouseLeave = targetEffects.leave, MouseButton1Down = targetEffects.down, MouseButton1Up = targetEffects.up, Activated = function() props.OnChangeTarget(1) end,
						create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint", AspectRatio = 3.39 }),
						create("UIScale")({ Name = "ButtonScale", Scale = targetEffects.scale }),
						create("TextLabel")({ Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.497, 0.3), Size = UDim2.fromScale(0.34705, 0.592226), Text = "TARGET", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)) }),
						create("TextLabel")({ Name = "Target", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.512, 0.71), Size = UDim2.fromScale(0.544708, 0.447244), Text = targetMode, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)) }),
					}),
					create("ImageButton")({ Name = "SellButton", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://81095831203067",
						Position = spring(function() return if props.isOpen() then UDim2.fromScale(0.738715, 0.487812) else UDim2.fromScale(1.85, 0.487812) end, 0.4, 0.62),
						Rotation = spring(function() return if props.isOpen() then 0 else 24 end, 0.34, 0.58),
						Size = UDim2.fromScale(0.475784, 0.829346), Active = props.isOpen, AutoButtonColor = false, MouseEnter = sellEffects.enter, MouseLeave = sellEffects.leave, MouseButton1Down = sellEffects.down, MouseButton1Up = sellEffects.up, Activated = props.OnSell,
						create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint", AspectRatio = 3.39 }),
						create("UIScale")({ Name = "ButtonScale", Scale = sellEffects.scale }),
						create("TextLabel")({ Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.497, 0.3), Size = UDim2.fromScale(0.34705, 0.592226), Text = "SELL", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)) }),
						create("TextLabel")({ Name = "Price", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = FONT, Position = UDim2.fromScale(0.491805, 0.71), Size = UDim2.fromScale(0.544708, 0.447244), Text = sellPrice, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)) }),
					}),
				}),
			}),
			create("ImageButton")({ Name = "CancelButton", BackgroundTransparency = 1, Image = "rbxassetid://97669663501555",
				Position = spring(function() return if props.isOpen() then UDim2.fromScale(0.958287, 0) else UDim2.fromScale(1.65, -0.28) end, 0.3, 0.62),
				Rotation = spring(function() return if props.isOpen() then 0 else 35 end, 0.28, 0.58),
				Size = UDim2.fromScale(0.0611299, 0.100672), ZIndex = 3, Active = props.isOpen, AutoButtonColor = false, MouseEnter = closeEffects.enter, MouseLeave = closeEffects.leave, MouseButton1Down = closeEffects.down, MouseButton1Up = closeEffects.up, Activated = props.OnClose, create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint" }), create("UIScale")({ Name = "ButtonScale", Scale = closeEffects.scale }) }),
		}),
		}),
	})
end
