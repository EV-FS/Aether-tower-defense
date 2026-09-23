-- Runtime-bound UnitStatFull layout.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local RarityData = require(ReplicatedStorage.Settings.Data.RarityData)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local TowerDescriptions = require(ReplicatedStorage.Settings.Data.TowerData.TowerDescriptions)
local RarityGradient = require(ReplicatedStorage.Settings.Visuals.RarityGradient)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

local create = Vide.create
local cleanup = Vide.cleanup
local derive = Vide.derive
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring
local untrack = Vide.untrack

export type Props = {
	towerId: () -> string?, towerData: () -> {}?, towerCount: () -> number, playerCash: () -> number,
	isMounted: () -> boolean, isOpen: () -> boolean,
	OnChangeTarget: (step: number) -> (), OnUpgrade: () -> (),
	OnSell: () -> (), OnClose: () -> (),
}

local TITLE_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local ARROW_IMAGE = "rbxassetid://97822781592426"
local PANEL_TINT = ColorSequence.new(Color3.fromRGB(121, 244, 244), Color3.fromRGB(244, 129, 234))
local PASSIVE_TINT = ColorSequence.new(Color3.fromRGB(121, 224, 255), Color3.fromRGB(255, 134, 243))
local ENTER_DURATION = 0.38
local EXIT_DURATION = 0.24

local function solid(color: Color3)
	return ColorSequence.new(color, color)
end

local function formatAnimatedNumber(value: number, target: number)
	local decimalPlaces = 0
	if math.abs(target - math.round(target)) > 0.0001 then
		decimalPlaces = if math.abs(target * 10 - math.round(target * 10)) <= 0.0001 then 1 else 2
	end

	local multiplier = 10 ^ decimalPlaces
	local rounded = math.round(value * multiplier) / multiplier
	if math.abs(value - target) < 0.001 then
		rounded = target
	end

	if decimalPlaces == 0 then
		return NumberUtils.FormatComma(math.round(rounded))
	end

	return string.format("%." .. decimalPlaces .. "f", rounded)
end

local function animatedCounter(target: () -> number, duration: number?)
	local displayed = source(0)

	effect(function()
		local goal = target()
		local initial = untrack(displayed)
		local elapsed = 0
		local connection: RBXScriptConnection

		if math.abs(goal - initial) < 0.0001 then
			displayed(goal)
			return
		end

		connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed += deltaTime
			local progress = math.min(elapsed / (duration or 0.42), 1)
			local eased = TweenService:GetValue(progress, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			displayed(initial + (goal - initial) * eased)

			if progress >= 1 then
				displayed(goal)
				connection:Disconnect()
			end
		end)

		cleanup(connection)
	end)

	return displayed
end

local function stroke(thickness: number?, color: Color3?)
	return create("UIStroke")({ Name = "UIStroke", Color = color or Color3.new(), Thickness = thickness or 1 })
end

local function buttonEffects(hoverScale: number?, pressedScale: number?)
	local hovering = source(false)
	local pressing = source(false)
	return {
		scale = spring(function()
			if pressing() then return pressedScale or 0.92 end
			return if hovering() then hoverScale or 1.045 else 1
		end, 0.14, 0.82),
		enter = function() hovering(true) end,
		leave = function() hovering(false) pressing(false) end,
		down = function() pressing(true) end,
		up = function() pressing(false) end,
	}
end

return function(props: Props)
	local showInfo = source(false)
	local traitHover = source(false)
	local motion = source(0)
	local reveal = source(0)
	local opacity = source(0)
	local levelUpProgress = source(1)
	local upgradeFX = buttonEffects(1.035, 0.94)
	local targetFX = buttonEffects(1.04, 0.93)
	local sellFX = buttonEffects(1.04, 0.93)
	local infoFX = buttonEffects(1.08, 0.9)
	local closeFX = buttonEffects(1.08, 0.88)
	local upgradeShake = source(0)
	local upgradeShakeConnection: RBXScriptConnection? = nil

	local function playUpgradeShake()
		if upgradeShakeConnection then
			upgradeShakeConnection:Disconnect()
		end

		local elapsed = 0
		upgradeShakeConnection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed += deltaTime
			local progress = math.min(elapsed / 0.3, 1)
			upgradeShake(math.sin(progress * math.pi * 6) * (1 - progress))

			if progress >= 1 then
				upgradeShake(0)
				upgradeShakeConnection:Disconnect()
				upgradeShakeConnection = nil
			end
		end)
	end

	cleanup(function()
		if upgradeShakeConnection then
			upgradeShakeConnection:Disconnect()
		end
	end)

	effect(function()
		props.towerId()
		local shouldOpen = props.isOpen()
		if not shouldOpen then
			showInfo(false)
			traitHover(false)
		end

		local target = if shouldOpen then 1 else 0
		local duration = if shouldOpen then ENTER_DURATION else EXIT_DURATION
		local startMotion = untrack(motion)
		local startReveal = untrack(reveal)
		local startOpacity = untrack(opacity)
		local elapsed = 0
		local connection: RBXScriptConnection

		if math.abs(startMotion - target) < 0.0001
			and math.abs(startReveal - target) < 0.0001
			and math.abs(startOpacity - target) < 0.0001
		then
			motion(target)
			reveal(target)
			opacity(target)
			return
		end

		connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed += deltaTime
			local progress = math.min(elapsed / duration, 1)
			local easedMotion = TweenService:GetValue(
				progress,
				if shouldOpen then Enum.EasingStyle.Back else Enum.EasingStyle.Quart,
				if shouldOpen then Enum.EasingDirection.Out else Enum.EasingDirection.In
			)
			local easedOpacity = TweenService:GetValue(
				progress,
				Enum.EasingStyle.Quad,
				if shouldOpen then Enum.EasingDirection.Out else Enum.EasingDirection.In
			)

			motion(startMotion + (target - startMotion) * easedMotion)
			reveal(startReveal + (target - startReveal) * progress)
			opacity(startOpacity + (target - startOpacity) * easedOpacity)

			if progress >= 1 then
				motion(target)
				reveal(target)
				opacity(target)
				connection:Disconnect()
			end
		end)

		cleanup(connection)
	end)

	local previousTowerId: string? = nil
	local previousLevel: number? = nil
	local levelUpConnection: RBXScriptConnection? = nil

	cleanup(function()
		if levelUpConnection then
			levelUpConnection:Disconnect()
		end
	end)

	effect(function()
		local towerId = props.towerId()
		local data = props.towerData()
		local level = if data and type(data.Level) == "number" then data.Level else nil

		if towerId ~= previousTowerId then
			if levelUpConnection then
				levelUpConnection:Disconnect()
				levelUpConnection = nil
			end

			levelUpProgress(1)
			previousTowerId = towerId
			previousLevel = level
			return
		end

		if level ~= nil
			and previousLevel ~= nil
			and level > previousLevel
			and props.isOpen()
		then
			if levelUpConnection then
				levelUpConnection:Disconnect()
			end

			levelUpProgress(0)
			local elapsed = 0
			levelUpConnection = RunService.RenderStepped:Connect(function(deltaTime)
				elapsed += deltaTime
				local progress = math.min(elapsed / 0.78, 1)
				levelUpProgress(progress)

				if progress >= 1 then
					levelUpConnection:Disconnect()
					levelUpConnection = nil
				end
			end)
		end

		previousTowerId = towerId
		previousLevel = level
	end)

	local levelUpImpact = derive(function()
		local progress = levelUpProgress()
		if progress >= 0.6 then return 0 end
		if progress <= 0.16 then
			return TweenService:GetValue(progress / 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
		return 1 - TweenService:GetValue((progress - 0.16) / 0.44, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	end)

	local levelUpFlash = derive(function()
		local progress = levelUpProgress()
		if progress >= 0.68 then return 0 end
		local fadeIn = TweenService:GetValue(math.clamp(progress / 0.06, 0, 1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local fadeOut = 1 - TweenService:GetValue(math.clamp((progress - 0.1) / 0.58, 0, 1), Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		return fadeIn * fadeOut
	end)

	local function stagger(delayTime: number)
		return derive(function()
			local progress = math.clamp((reveal() * ENTER_DURATION - delayTime) / (ENTER_DURATION - delayTime), 0, 1)
			return TweenService:GetValue(progress, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		end)
	end

	local characterReveal = stagger(0.035)
	local statsReveal = stagger(0.075)
	local upgradeReveal = stagger(0.13)
	local actionsReveal = stagger(0.17)

	local towerConfig = derive(function()
		local data = props.towerData()
		return data and TowerData.ByName[data.Name] or nil
	end)
	local nextStats = derive(function()
		local data = props.towerData()
		local config = towerConfig()
		return data and (data.NextStats or (config and config.Stats[data.Level + 1])) or nil
	end)
	local descriptionData = derive(function()
		local data = props.towerData()
		return data and TowerDescriptions[data.Name] or nil
	end)

	local towerName = derive(function()
		local data = props.towerData()
		return data and data.Name or ""
	end)
	local towerRarity = derive(function()
		local config = towerConfig()
		return if config then string.upper(RarityData.DisplayNames[config.Rarity] or config.Rarity) else ""
	end)
	local rarityGradient = derive(function()
		local config = towerConfig()
		return if config
			then RarityGradient.Gradients[config.Rarity] or RarityGradient.Gradients.Common
			else RarityGradient.Gradients.Common
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
	local hasNextLevel = derive(function() return nextStats() ~= nil end)
	local upgradeCost = derive(function()
		local stats = nextStats()
		return stats and (stats.Cost or 0) or 0
	end)
	local animatedUpgradeCost = animatedCounter(upgradeCost, 0.38)
	local canUpgrade = derive(function() return hasNextLevel() and props.playerCash() >= upgradeCost() end)
	local upgradeTitle = derive(function() return if hasNextLevel() then "UPGRADE" else "MAX LEVEL" end)
	local upgradePrice = derive(function()
		return if hasNextLevel() then `$ {NumberUtils.FormatComma(math.max(0, math.round(animatedUpgradeCost())))}` else ""
	end)
	local totalSpent = derive(function()
		local data = props.towerData()
		local config = towerConfig()
		if not data or not config then return 0 end
		local total = 0
		for level = 0, data.Level do
			local stats = config.Stats[level]
			total += stats and stats.Cost or 0
		end
		return total
	end)
	local sellPriceTarget = derive(function() return math.floor(totalSpent() / 2) end)
	local animatedTotalSpent = animatedCounter(totalSpent, 0.42)
	local animatedSellPrice = animatedCounter(sellPriceTarget, 0.42)
	local totalText = derive(function() return `Total {NumberUtils.FormatComma(math.max(0, math.round(animatedTotalSpent())))}$` end)
	local sellPrice = derive(function() return `$ {NumberUtils.FormatComma(math.max(0, math.round(animatedSellPrice())))}` end)
	local targetMode = derive(function()
		local data = props.towerData()
		return string.upper(data and data.Target or "First")
	end)
	local maxQuantity = derive(function()
		local config = towerConfig()
		return config and config.MaxTowers or 0
	end)
	local quantityText = derive(function()
		return if towerConfig() then `{props.towerCount()}/{maxQuantity()}` else "-/-"
	end)
	local dpsValue = derive(function()
		local data = props.towerData()
		local stats = data and data.Stats
		if not stats or not stats.Damage or not stats.Cooldown or stats.Cooldown <= 0 then return 0 end
		return stats.Damage / stats.Cooldown
	end)
	local animatedDps = animatedCounter(dpsValue, 0.4)
	local dpsText = derive(function()
		if not props.towerData() then return "DPS -" end
		return `DPS {formatAnimatedNumber(math.max(0, animatedDps()), dpsValue())}`
	end)
	local passiveName = derive(function()
		local data = descriptionData()
		return data and data.PassiveName or "UNIT INFORMATION"
	end)
	local passiveIcon = derive(function()
		local data = descriptionData()
		return data and data.PassiveIcon or "rbxassetid://74159169499938"
	end)
	local passiveDescription = derive(function()
		local data = descriptionData()
		return data and data.PassiveDescription or "This unit has no passive skill at its current level."
	end)
	local passiveDetails = derive(function()
		local description = descriptionData()
		local data = props.towerData()
		if not description or not description.PassiveDetails or not data or not data.Stats then return "" end
		local details = {}
		for _, detail in description.PassiveDetails do
			local value = data.Stats[detail.Key]
			if value ~= nil then table.insert(details, `{detail.Label}: {value}{detail.Suffix or ""}`) end
		end
		return table.concat(details, "  |  ")
	end)

	local function statValue(key: string, after: boolean)
		local targetValue = derive(function()
			local data = props.towerData()
			local stats = if after then nextStats() else (data and data.Stats)
			local value = stats and stats[key]
			return if type(value) == "number" then value else 0
		end)
		local animatedValue = animatedCounter(targetValue, 0.4)

		return derive(function()
			local data = props.towerData()
			local stats = if after then nextStats() else (data and data.Stats)
			if not stats or type(stats[key]) ~= "number" then return "-" end
			return formatAnimatedNumber(math.max(0, animatedValue()), targetValue())
		end)
	end

	local function statRow(name: string, title: string, image: string, key: string, tint: Color3, order: number)
		return create("ImageLabel")({
			Name = name, BackgroundTransparency = 1, Image = "rbxassetid://97917507828743",
			LayoutOrder = order, Size = UDim2.fromScale(1, 0.3),
			create("UIScale")({ Name = "LevelUpScale", Scale = function() return 1 + 0.025 * levelUpImpact() end }),
			create("UIGradient")({ Name = "UIGradient", Color = solid(tint) }),
			create("ImageLabel")({ Name = "Icon", BackgroundTransparency = 1, Image = image, Position = UDim2.fromScale(-0.000900717, 0.0167455), Size = UDim2.fromScale(0.452262, 0.946338), create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint" }) }),
			create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = BODY_FONT, Position = UDim2.fromScale(0.16303, 0.146973), Size = UDim2.fromScale(0.154098, 0.571764), Text = title, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }),
			create("TextLabel")({ Name = "QuantityBefore", BackgroundTransparency = 1, FontFace = BODY_FONT, Position = UDim2.fromScale(0.506218, 0.0443657), Size = UDim2.fromScale(0.222376, 0.822262), Text = statValue(key, false), TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke() }),
			create("ImageLabel")({ Name = "Arrow", BackgroundTransparency = 1, Image = ARROW_IMAGE, Position = UDim2.fromScale(0.74, 0.28), Size = UDim2.fromScale(0.0360994, 0.373745), Visible = hasNextLevel, create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint" }) }),
			create("TextLabel")({ Name = "QuantityAfter", BackgroundTransparency = 1, FontFace = BODY_FONT, Position = UDim2.fromScale(0.774048, 0.0443651), Size = UDim2.fromScale(0.222376, 0.822263), Text = statValue(key, true), TextColor3 = Color3.new(1, 1, 1), TextScaled = true, Visible = hasNextLevel, stroke() }),
		})
	end

	local function closeMenu()
		showInfo(false)
		traitHover(false)
		props.OnClose()
	end

	local function skillCard()
		return create("ImageLabel")({
			Name = "SkillDescription", BackgroundTransparency = 1, Image = "rbxassetid://100298461783739", LayoutOrder = 1, Size = UDim2.fromScale(1, 0.22),
			create("TextLabel")({ Name = "SkillName", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.146822, 0.162), Size = UDim2.fromScale(0.224, 0.153), Text = passiveName, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, stroke(2) }),
			create("TextLabel")({ Name = "Type", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.891058, 0.162), Size = UDim2.fromScale(0.186117, 0.153), Text = "PASSIVE", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, stroke(2) }),
			create("TextLabel")({ Name = "Description", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.499391, 0.62), Size = UDim2.fromScale(0.956159, 0.56), Text = derive(function() local details = passiveDetails() return if details == "" then passiveDescription() else `{passiveDescription()}\n{details}` end), TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, stroke(2) }),
		})
	end

	return create("Frame")({
		Name = "Container",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 1),
		Visible = props.isMounted,
		ZIndex = 2,
		create("UIScale")({ Name = "OverallScale", Scale = 0.7 }),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 1.467,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		}),

		create("CanvasGroup")({
			Name = "Entrance",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = function() return 1 - opacity() end,

			create("ImageLabel")({
				Name = "Main",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://82538196598442",
				Position = function()
					return UDim2.new(0.125, 0, 0.535, 4):Lerp(UDim2.new(0.285, 0, 0.494076, 4), motion())
				end,
				Size = UDim2.fromScale(0.538258, 0.466683),
				create("UIGradient")({ Name = "UIGradient", Color = PANEL_TINT }),
				create("UIScale")({ Name = "EntranceScale", Scale = function() return (0.92 + 0.08 * motion()) * (1 + 0.012 * levelUpImpact()) end }),

				create("CanvasGroup")({
					Name = "StatFrame",
					BackgroundTransparency = 1,
					GroupTransparency = function() return 1 - statsReveal() end,
					Position = function()
						return UDim2.fromScale(0.585, 0.073):Lerp(UDim2.fromScale(0.515918, 0.0521041), statsReveal())
					end,
					Size = UDim2.fromScale(0.458932, 0.895669),
					create("UIScale")({ Name = "EntranceScale", Scale = function() return (0.92 + 0.08 * statsReveal()) * (1 + 0.018 * levelUpImpact()) end }),
					create("UICorner")({ Name = "LevelUpCorner", CornerRadius = UDim.new(0.05, 0) }),
					create("UIStroke")({ Name = "LevelUpGlow", Color = Color3.fromRGB(208, 255, 91), Thickness = 2.5, Transparency = function() return 1 - 0.9 * levelUpFlash() end }),
					create("UIListLayout")({ Name = "UIListLayout", SortOrder = Enum.SortOrder.LayoutOrder }),

					create("ImageLabel")({
						Name = "Level", BackgroundTransparency = 1, Image = "rbxassetid://97917507828743", LayoutOrder = 1, Size = UDim2.fromScale(1, 0.154185),
						create("UIScale")({ Name = "LevelUpScale", Scale = function() return 1 + 0.055 * levelUpImpact() end }),
						create("UIGradient")({ Name = "UIGradient", Color = solid(Color3.fromRGB(83, 83, 83)) }),
						create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.0384327, 0.270131), Size = UDim2.fromScale(0.215355, 0.459739), Text = "LEVEL", TextColor3 = Color3.new(1, 1, 1), TextScaled = true }),
						create("TextLabel")({ Name = "LevelBefore", BackgroundTransparency = 1, FontFace = BODY_FONT, Position = UDim2.fromScale(0.552502, 0.26972), Size = UDim2.fromScale(0.137595, 0.459739), Text = levelBefore, TextColor3 = Color3.fromRGB(208, 208, 208), TextScaled = true }),
						create("ImageLabel")({ Name = "Arrow", BackgroundTransparency = 1, Image = ARROW_IMAGE, Position = UDim2.fromScale(0.726, 0.4), Size = UDim2.fromScale(0.0754627, 0.26172), Visible = hasNextLevel, create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint" }) }),
						create("TextLabel")({ Name = "LevelAfter", BackgroundTransparency = 1, FontFace = BODY_FONT, Position = UDim2.fromScale(0.787857, 0.26972), Size = UDim2.fromScale(0.137595, 0.459739), Text = levelAfter, TextColor3 = Color3.fromRGB(61, 208, 29), TextScaled = true, Visible = hasNextLevel }),
					}),

					create("ImageLabel")({
						Name = "Stat", BackgroundTransparency = 1, Image = "rbxassetid://73408529218422", LayoutOrder = 2, Size = UDim2.fromScale(1, 0.379095),
						create("UIGradient")({ Name = "UIGradient", Color = solid(Color3.fromRGB(83, 83, 83)) }),
						create("ScrollingFrame")({
							Name = "ScrollingFrame", Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
							CanvasPosition = function() props.towerId() return Vector2.zero end,
							CanvasSize = UDim2.new(), Position = UDim2.fromScale(0.038, 0.06), ScrollBarThickness = 0, Size = UDim2.fromScale(0.933, 0.913),
							create("UIListLayout")({ Name = "UIListLayout", HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
							statRow("Str", "STR", "rbxassetid://80052696005250", "Damage", Color3.fromRGB(255, 39, 68), 1),
							statRow("Rng", "RNG", "rbxassetid://116804997419312", "Range", Color3.fromRGB(244, 255, 37), 2),
							statRow("Clt", "CLT", "rbxassetid://122566686567397", "Cooldown", Color3.fromRGB(94, 217, 255), 3),
						}),
					}),

					create("ImageLabel")({
						Name = "Upgrade", BackgroundTransparency = 1, Image = "rbxassetid://80900769451335", LayoutOrder = 3, Size = UDim2.fromScale(1, 0.287465),
						create("UIScale")({ Name = "EntranceScale", Scale = function() return 0.84 + 0.16 * upgradeReveal() end }),
						create("UIGradient")({ Name = "UIGradient", Color = solid(Color3.fromRGB(83, 83, 83)) }),
						create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.078, 0.08), Size = UDim2.fromScale(0.249588, 0.184453), Text = "UPGRADE", TextColor3 = Color3.new(1, 1, 1), TextScaled = true }),
						create("TextLabel")({ Name = "Total", BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.579, 0.08), Size = UDim2.fromScale(0.351613, 0.184453), Text = totalText, TextColor3 = Color3.fromRGB(208, 208, 208), TextScaled = true }),
						create("ImageButton")({
							Name = "UpgradeButton", AnchorPoint = Vector2.new(0.5, 0.5), Active = props.isOpen, AutoButtonColor = false,
							BackgroundTransparency = 1, Image = "rbxassetid://139274506988816", ImageColor3 = function() return if canUpgrade() then Color3.new(1, 1, 1) else Color3.fromRGB(130, 130, 130) end,
							Position = function() return UDim2.fromScale(0.5 + 0.012 * upgradeShake(), 0.6) end, Size = UDim2.fromScale(0.862, 0.603),
							MouseEnter = upgradeFX.enter, MouseLeave = upgradeFX.leave, MouseButton1Down = upgradeFX.down, MouseButton1Up = upgradeFX.up,
							Activated = function() if canUpgrade() then props.OnUpgrade() else playUpgradeShake() end end,
							create("UIScale")({ Name = "ButtonScale", Scale = function() return upgradeFX.scale() * (1 + 0.025 * levelUpImpact()) end }),
							create("UIGradient")({ Name = "UIGradient", Color = ColorSequence.new(Color3.fromRGB(13, 255, 0), Color3.fromRGB(234, 255, 0)) }),
							stroke(1, Color3.new(1, 1, 1)), create("UICorner")({ Name = "UICorner" }),
							create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.149276, 0.12), Size = UDim2.fromScale(0.68577, 0.45), Text = upgradeTitle, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)) }),
							create("TextLabel")({ Name = "Price", BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.149276, 0.56), Size = UDim2.fromScale(0.68577, 0.3), Text = upgradePrice, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)) }),
						}),
					}),

					create("ImageLabel")({
						Name = "ETC", BackgroundTransparency = 1, Image = "rbxassetid://94721268604753", LayoutOrder = 4, Size = UDim2.fromScale(1, 0.170845),
						create("UIScale")({ Name = "EntranceScale", Scale = function() return 0.8 + 0.2 * actionsReveal() end }),
						create("UIGradient")({ Name = "UIGradient", Color = solid(Color3.fromRGB(83, 83, 83)) }),
						create("UIListLayout")({ Name = "UIListLayout", FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
						create("ImageButton")({
							Name = "TargetButton", AnchorPoint = Vector2.new(0.5, 0.5), Active = props.isOpen, AutoButtonColor = false, BackgroundTransparency = 1, Image = "rbxassetid://104334746624623", LayoutOrder = 1, Size = UDim2.fromScale(0.475784, 0.829346),
							MouseEnter = targetFX.enter, MouseLeave = targetFX.leave, MouseButton1Down = targetFX.down, MouseButton1Up = targetFX.up, Activated = function() props.OnChangeTarget(1) end,
							create("UIScale")({ Name = "ButtonScale", Scale = targetFX.scale }), create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint", AspectRatio = 3.12 }),
							create("TextLabel")({ Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.486522, 0.267308), Size = UDim2.fromScale(0.34705, 0.592226), Text = "TARGET", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)) }),
							create("TextLabel")({ Name = "Target", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.501522, 0.677308), Size = UDim2.fromScale(0.544708, 0.447244), Text = targetMode, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)), create("UIGradient")({ Name = "UIGradient", Color = solid(Color3.fromRGB(255, 193, 48)) }) }),
						}),
						create("ImageButton")({
							Name = "SellButton", AnchorPoint = Vector2.new(0.5, 0.5), Active = props.isOpen, AutoButtonColor = false, BackgroundTransparency = 1, Image = "rbxassetid://101438943406274", LayoutOrder = 2, Size = UDim2.fromScale(0.475784, 0.829346),
							MouseEnter = sellFX.enter, MouseLeave = sellFX.leave, MouseButton1Down = sellFX.down, MouseButton1Up = sellFX.up, Activated = props.OnSell,
							create("UIScale")({ Name = "ButtonScale", Scale = sellFX.scale }), create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint", AspectRatio = 3.12 }), create("UICorner")({ Name = "UICorner" }), stroke(),
							create("TextLabel")({ Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.497, 0.343211), Size = UDim2.fromScale(0.34705, 0.48249), Text = "SELL", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)) }),
							create("TextLabel")({ Name = "Price", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.491805, 0.726347), Size = UDim2.fromScale(0.544708, 0.414551), Text = sellPrice, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2, Color3.fromRGB(56, 41, 20)), create("UIGradient")({ Name = "UIGradient", Color = ColorSequence.new(Color3.fromRGB(255, 6, 10), Color3.fromRGB(115, 3, 5)), Rotation = 90 }) }),
						}),
					}),
				}),

				create("ImageLabel")({
					Name = "BackGround", BackgroundTransparency = 1, Image = "rbxassetid://132098565029195",
					Position = function()
						return UDim2.fromScale(-0.018, 0.125):Lerp(UDim2.fromScale(0.0440123, 0.0935431), characterReveal())
					end,
					Size = UDim2.fromScale(0.439986, 0.812131),
					create("UIScale")({ Name = "EntranceScale", Scale = function() return (0.86 + 0.14 * characterReveal()) * (1 + 0.035 * levelUpImpact()) end }),
					create("UIGradient")({ Name = "UIGradient", Color = rarityGradient }),
					create("ViewportFrame")({ Name = "ViewportFrame", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }),
					create("ImageLabel")({ Name = "TowerImage", BackgroundTransparency = 1, Image = towerImage, Position = UDim2.fromScale(0.08, 0.16), ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(0.84, 0.7) }),
					create("TextLabel")({ Name = "Name", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.603974, 0.00393289), Size = UDim2.fromScale(0.900678, 0.136709), Text = towerName, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, stroke(2) }),
					create("TextLabel")({ Name = "Grade", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.3148, 0.103233), Size = UDim2.fromScale(0.292, 0.079), Text = towerRarity, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, stroke(2), create("UIGradient")({ Name = "UIGradient", Color = rarityGradient }) }),
					create("ImageLabel")({
						Name = "UnitQuantity", BackgroundTransparency = 1, Image = "rbxassetid://135999793953035", Position = UDim2.fromScale(-0.0466121, 0.94055), Size = UDim2.fromScale(0.260067, 0.124021),
						create("UIGradient")({ Name = "UIGradient", Color = solid(Color3.fromRGB(125, 125, 125)) }),
						create("TextLabel")({ Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.538784, 0.301411), Size = UDim2.fromScale(0.430618, 0.518178), Text = "NUM", TextColor3 = Color3.fromRGB(209, 209, 209), TextScaled = true }),
						create("TextLabel")({ Name = "Quantity", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.538784, 0.731357), Size = UDim2.fromScale(0.430618, 0.557653), Text = quantityText, TextColor3 = Color3.new(1, 1, 1), TextScaled = true }),
					}),
					create("ImageButton")({
						Name = "Trait", Active = function() return descriptionData() ~= nil end, AutoButtonColor = false, BackgroundTransparency = 1,
						Image = "rbxassetid://109453145417269", Position = UDim2.fromScale(-0.0456004, -0.0681343), Size = UDim2.fromScale(0.229214, 0.187117), Visible = function() return descriptionData() ~= nil end,
						MouseEnter = function() traitHover(true) end, MouseLeave = function() traitHover(false) end,
						create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint" }), create("UIGradient")({ Name = "UIGradient", Color = PASSIVE_TINT }),
						create("ImageLabel")({ Name = "Trait", BackgroundTransparency = 1, Image = passiveIcon, Position = UDim2.fromScale(0.097, 0.043), Size = UDim2.fromScale(0.797, 0.88), create("UIGradient")({ Name = "UIGradient", Color = PASSIVE_TINT }) }),
						create("ImageLabel")({
							Name = "Description", BackgroundTransparency = 1, Image = "rbxassetid://125331794226335", Position = UDim2.fromScale(0.146233, -2.60654), Size = UDim2.fromScale(5.46668, 2.59433), Visible = traitHover,
							create("UICorner")({ Name = "UICorner", CornerRadius = UDim.new(0, 10) }),
							create("ImageLabel")({ Name = "Icon", BackgroundTransparency = 1, Image = passiveIcon, Position = UDim2.fromScale(0.097, 0.043), Size = UDim2.fromScale(0.186756, 0.352815), create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint", AspectRatio = 0.92 }), create("UIGradient")({ Name = "UIGradient", Color = PASSIVE_TINT }) }),
							create("TextLabel")({ Name = "Name", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = BODY_FONT, Position = UDim2.fromScale(0.550296, 0.144768), Size = UDim2.fromScale(0.421234, 0.303927), Text = passiveName, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, stroke(2), create("UIGradient")({ Name = "UIGradient", Color = PASSIVE_TINT }) }),
							create("TextLabel")({ Name = "Description", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = BODY_FONT, Position = UDim2.fromScale(0.621373, 0.493598), Size = UDim2.fromScale(0.560261, 0.519232), Text = passiveDescription, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, stroke(2) }),
						}),
					}),
				}),

				create("Frame")({
					Name = "LevelUpFlash", BackgroundColor3 = Color3.fromRGB(220, 255, 125),
					BackgroundTransparency = function() return 1 - 0.13 * levelUpFlash() end,
					Position = UDim2.fromScale(0.505, 0.047), Size = UDim2.fromScale(0.471, 0.84), ZIndex = 8,
					create("UICorner")({ Name = "UICorner", CornerRadius = UDim.new(0.05, 0) }),
					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(177, 255, 59)),
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 0.88) }),
					}),
				}),

				create("TextLabel")({
					Name = "DPS", BackgroundTransparency = 1, FontFace = TITLE_FONT,
					Position = UDim2.fromScale(0.0219216, 0.8), Size = UDim2.fromScale(0.25, 0.05),
					Text = dpsText, TextColor3 = Color3.new(1, 1, 1), TextScaled = true,
					TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
					stroke(1.25, Color3.fromRGB(15, 18, 25)),
					create("UITextSizeConstraint")({ Name = "UITextSizeConstraint", MinTextSize = 9, MaxTextSize = 17 }),
				}),
				create("ImageButton")({
					Name = "InfoButton", Active = props.isOpen, AutoButtonColor = false, BackgroundTransparency = 1, Image = "rbxassetid://127157806950055", Position = UDim2.fromScale(0.411337, 0.844093), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.10392, 0.111633), ZIndex = 3,
					MouseEnter = infoFX.enter, MouseLeave = infoFX.leave, MouseButton1Down = infoFX.down, MouseButton1Up = infoFX.up, Activated = function() showInfo(true) end,
					create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint", AspectRatio = 1.36 }), create("UIScale")({ Name = "ButtonScale", Scale = function() return (0.76 + 0.24 * actionsReveal()) * infoFX.scale() end }),
				}),
				create("ImageButton")({
					Name = "CancelButton", AnchorPoint = Vector2.new(0.5, 0.5), Active = props.isOpen, AutoButtonColor = false, BackgroundTransparency = 1, Image = "rbxassetid://92651860309635", Position = UDim2.fromScale(1.015, -0.025), Size = UDim2.fromScale(0.102713, 0.177808), ZIndex = 4,
					MouseEnter = closeFX.enter, MouseLeave = closeFX.leave, MouseButton1Down = closeFX.down, MouseButton1Up = closeFX.up, Activated = closeMenu,
					create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint" }), create("UIScale")({ Name = "ButtonScale", Scale = function() return (0.82 + 0.18 * statsReveal()) * closeFX.scale() end }),
				}),
			}),
		}),

		create("CanvasGroup")({
			Name = "InfoMotion", BackgroundTransparency = 1,
			GroupTransparency = spring(function() return if showInfo() then 0 else 1 end, 0.16, 0.88),
			Position = spring(function() return if showInfo() then UDim2.fromScale(0, 0) else UDim2.fromScale(-0.035, 0) end, 0.2, 0.82),
			Size = UDim2.fromScale(1, 1), Visible = function() return props.isMounted() and showInfo() end, ZIndex = 10,
			create("ImageLabel")({
				Name = "Info", BackgroundTransparency = 1, Image = "rbxassetid://80348302893975", Position = UDim2.fromScale(0.339787, 0.128757), Size = UDim2.fromScale(0.383515, 0.620789),
				create("TextLabel")({ Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = TITLE_FONT, Position = UDim2.fromScale(0.499045, 0.0659309), Size = UDim2.fromScale(0.399295, 0.104367), Text = "Skill Description", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, stroke(2) }),
				create("ScrollingFrame")({ Name = "ScrollingFrame", Active = true, AnchorPoint = Vector2.new(0.5, 0.5), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, CanvasSize = UDim2.new(), Position = UDim2.fromScale(0.5, 0.559865), ScrollBarThickness = 0, Size = UDim2.fromScale(0.966297, 0.827461), create("UIListLayout")({ Name = "UIListLayout", Padding = UDim.new(0.01, 0), SortOrder = Enum.SortOrder.LayoutOrder }), skillCard() }),
				create("ImageButton")({ Name = "CancelButton", AnchorPoint = Vector2.new(0.5, 0.5), AutoButtonColor = false, BackgroundTransparency = 1, Image = "rbxassetid://92651860309635", Position = UDim2.fromScale(0.988307, 0.0160545), Size = UDim2.fromScale(0.157292, 0.13133), Activated = function() showInfo(false) end, create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint" }) }),
			}),
		}),
	})
end
