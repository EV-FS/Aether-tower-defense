local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local TouchZone = require(ReplicatedStorage.Shared.Modules.Utils.TouchZone)
local Net = require(ReplicatedStorage.Shared.Net)
local SummonConfig = require(ReplicatedStorage.Settings.Data.SummonConfig)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local CutscenePlayer = require(ReplicatedStorage.Shared.Modules.Cutscene.CutscenePlayer)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)
local EmitModule = require(ReplicatedStorage.Shared.Modules.Utils.EmitModule)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local SummonResultUI = require(script.Parent.SummonResultUI)

local cleanup = Vide.cleanup
local create = Vide.create
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring
local untrack = Vide.untrack

local UIController
local DataClient
local InventoryClient
local summonZone
local cutsceneSFX
local bookTurnSFX

local VIEW_ID = "Summon"
local ENTER_DURATION = 0.42
local EXIT_DURATION = 0.18
local ONE_PULL_COST = SummonConfig.Prices[1]
local TEN_PULL_COST = SummonConfig.Prices[10]
local BANNER_TIMER_DURATION = SummonConfig.BannerTimerDuration
local MYTHIC_PITY_LIMIT = SummonConfig.Pity.Mythic.Limit
local ABSOLUTE_PITY_LIMIT = SummonConfig.Pity.Absolute.Limit
local MYTHIC_PITY_ATTRIBUTE = SummonConfig.Pity.Mythic.Attribute
local ABSOLUTE_PITY_ATTRIBUTE = SummonConfig.Pity.Absolute.Attribute
local RESULT_REVEAL_FRAMES = { 142, 158, 171, 183, 193, 203, 214, 223, 233, 243 }

local DISPLAY_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local PLAIN_DISPLAY_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local MAIN_IMAGE = "rbxassetid://101796292394413"
local HEADER_IMAGE = "rbxassetid://106553153352559"
local HELMET_IMAGE = "rbxassetid://109351985581707"
local CLOUD_IMAGE = "rbxassetid://71168710355974"
local SWORD_IMAGE = "rbxassetid://131831557828351"
local CLOSE_IMAGE = "rbxassetid://92651860309635"
local BANNER_IMAGE = "rbxassetid://98737132035258"
local CARD_SHADOW_IMAGE = "rbxassetid://99201276937983"
local NAME_PLATE_IMAGE = "rbxassetid://116700116064149"
local PURCHASE_BUTTON_IMAGE = "rbxassetid://139274506988816"
local CURRENCY_IMAGE = "rbxassetid://117112996963807"
local PROBABILITY_BUTTON_IMAGE = "rbxassetid://120545788069786"

local RARITY_GRADIENTS = SummonConfig.RarityGradients
local FEATURED_RARITIES = SummonConfig.FeaturedRarities
local RATE_RARITIES = SummonConfig.RateDisplayOrder
local PURCHASE_AVAILABLE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 255, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 238, 1)),
})
local PURCHASE_UNAVAILABLE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(108, 108, 108)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 48, 48)),
})

type UnitBannerInfo = {
	Name: string,
	RateText: string,
}

type UnitsPool = {
	[string]: UnitBannerInfo,
}

local DEFAULT_UNITS_POOL: UnitsPool = {
	Common = { Name = "", RateText = "" },
	Rare = { Name = "", RateText = "" },
	Epic = { Name = "", RateText = "" },
	Legendary = { Name = "", RateText = "" },
	Mythic = { Name = "", RateText = "" },
	Absolute = { Name = "", RateText = "" },
}

local currentUnitsPool = source(DEFAULT_UNITS_POOL)
local isProbabilityOpen = source(false)
local summonInProgress = source(false)
local isCutscenePlaying = source(false)
local nextBannerTimerResetAt = source(0)
local bannerSecondsRemaining = source(BANNER_TIMER_DURATION)
local mythicPity = source(0)
local absolutePity = source(0)

local SummonUI = {}

local function isOpen(): boolean
	return UIController ~= nil and UIController:IsOpen(VIEW_ID)
end

function SummonUI.Open(): boolean
	return UIController ~= nil and UIController:OpenExclusive(VIEW_ID)
end

local function copyDefaultUnitsPool(): UnitsPool
	local pool = {}
	for rarity, info in DEFAULT_UNITS_POOL do
		pool[rarity] = {
			Name = info.Name,
			RateText = info.RateText,
		}
	end
	return pool
end

local function getUnitInfo(rarity: string): UnitBannerInfo
	return currentUnitsPool()[rarity] or DEFAULT_UNITS_POOL[rarity] or { Name = "", RateText = "" }
end

local function formatTimer(seconds: number): string
	local roundedSeconds = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(roundedSeconds / 60), roundedSeconds % 60)
end

local function canPurchase(cost: number): boolean
	return DataClient ~= nil and not summonInProgress() and DataClient.Coins() >= cost
end

local function emitCutsceneVFX(targetName: string)
	local target = workspace:FindFirstChild(targetName)
	if not target then
		warn(`[SummonUI] Cutscene VFX target "{targetName}" was not found in Workspace.`)
		return
	end

	if not EmitModule.setup then
		EmitModule.init()
	end
	local vfx = shared.vfx
	if not vfx or type(vfx.emit) ~= "function" then
		warn("[SummonUI] shared.vfx is unavailable for the summon cutscene.")
		return
	end

	vfx.emit(target)
end

local function createRarityGradient(rarity: string)
	local colors = RARITY_GRADIENTS[rarity] or RARITY_GRADIENTS.Common
	return create("UIGradient")({
		Name = "UIGradient",
		Color = colors,
	})
end

local function createUnitCard(rarity: string, layoutOrder: number, reveal: () -> number)
	return create("Frame")({
		Name = "Frame",
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(0.290764, 1),

		create("ImageLabel")({
			Name = "Shadow",
			BackgroundTransparency = 1,
			Image = CARD_SHADOW_IMAGE,
			Position = UDim2.fromScale(0.00631904, 0.106321),
			Size = UDim2.fromScale(1, 1),
			ZIndex = -1,

			create("UIAspectRatioConstraint")({}),
		}),

		TowerViewport({
			Name = "UnitViewport",
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			TowerName = function()
				return if isOpen() then getUnitInfo(rarity).Name else ""
			end,
			AnimationName = "Idle",
			UseViewportModel = true,
			UseCharacterBounds = true,
			FitPadding = 1.1,
			Position = function()
				return UDim2.fromScale((layoutOrder - 2) * 0.08 * (1 - reveal()), 0.1 * (1 - reveal()))
			end,
			ImageTransparency = function()
				return 1 - reveal()
			end,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}),

		create("ImageLabel")({
			Name = "Name",
			BackgroundTransparency = 1,
			Image = NAME_PLATE_IMAGE,
			Position = function()
				return UDim2.fromScale(0.176933, 0.647593 + 0.08 * (1 - reveal()))
			end,
			Size = UDim2.fromScale(0.652453, 0.178427),
			ZIndex = 2,

			create("TextLabel")({
				Name = "Name",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.4),
				Text = function()
					return getUnitInfo(rarity).Name
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTruncate = Enum.TextTruncate.AtEnd,

				create("UIStroke")({}),
				create("UITextSizeConstraint")({ MinTextSize = 8, MaxTextSize = 22 }),
			}),

			create("TextLabel")({
				Name = "Grade",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Position = UDim2.fromScale(0.5, 0.757312),
				Size = UDim2.fromScale(1, 0.3),
				Text = string.upper(rarity),
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({}),
				create("UITextSizeConstraint")({ MinTextSize = 7, MaxTextSize = 14 }),

				createRarityGradient(rarity),
			}),

			create("UIListLayout")({
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		}),
	})
end

local function createRateRow(rarity: string, layoutOrder: number)
	return create("Frame")({
		Name = rarity,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(1, 0.145),
		ZIndex = 22,

		create("TextLabel")({
			Name = "Grade",
			BackgroundTransparency = 1,
			FontFace = BODY_FONT,
			LayoutOrder = 1,
			Size = UDim2.fromScale(0.55, 0.72),
			Text = rarity,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,

			create("UIStroke")({
				Color = Color3.fromRGB(25, 20, 38),
				Thickness = 1.2,
			}),

			createRarityGradient(rarity),
		}),

		create("TextLabel")({
			Name = "Probability",
			BackgroundTransparency = 1,
			FontFace = BODY_FONT,
			LayoutOrder = 2,
			Size = UDim2.fromScale(0.3, 0.72),
			Text = function()
				return getUnitInfo(rarity).RateText
			end,
			TextColor3 = Color3.fromRGB(255, 238, 185),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 22,

			create("UIStroke")({
				Color = Color3.fromRGB(40, 30, 20),
				Thickness = 1,
			}),
		}),

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.06, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
end

local function createPurchaseButton(
	name: string,
	amount: number,
	title: string,
	cost: number,
	position: UDim2 | (() -> UDim2)
)
	return create("ImageButton")({
		Name = name,
		Active = function()
			return isOpen() and canPurchase(cost)
		end,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = PURCHASE_BUTTON_IMAGE,
		Position = position,
		Size = UDim2.fromScale(0.238867, 0.113861),

		Activated = function()
			SummonUI.Summon(amount)
		end,

		useButtonEffect(0.97, 1.025),

		create("UICorner")({}),

		create("UIStroke")({
			Color = function()
				return if canPurchase(cost) then Color3.new(1, 1, 1) else Color3.fromRGB(121, 121, 121)
			end,
		}),

		create("UIGradient")({
			Color = function()
				return if canPurchase(cost) then PURCHASE_AVAILABLE_GRADIENT else PURCHASE_UNAVAILABLE_GRADIENT
			end,
		}),

		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = PLAIN_DISPLAY_FONT,
			Position = if amount == 1
				then UDim2.fromScale(0.0483483, 0.168285)
				else UDim2.fromScale(0.0483484, 0.253242),
			Size = if amount == 1 then UDim2.fromScale(0.402995, 0.699418) else UDim2.fromScale(0.547652, 0.473445),
			Text = title,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,

			create("UIStroke")({}),
		}),

		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = PLAIN_DISPLAY_FONT,
			Position = UDim2.fromScale(0.596, 0.278),
			Size = UDim2.fromScale(0.164253, 0.498891),
			Text = tostring(cost),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,

			create("UIStroke")({}),
		}),

		create("ImageLabel")({
			Name = "ImageLabel",
			BackgroundTransparency = 1,
			Image = CURRENCY_IMAGE,
			Position = UDim2.fromScale(0.7598, 0.0835799),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.226426, 0.784124),

			create("UIAspectRatioConstraint")({}),
		}),
	})
end

local function createStatusBar(
	name: string,
	fillName: string,
	title: string,
	getRatio: () -> number,
	getValueText: () -> string,
	colors: ColorSequence,
	position: UDim2,
	size: UDim2
)
	local animatedRatio = spring(function()
		return math.clamp(getRatio(), 0, 1)
	end, 0.34, 0.82)

	return create("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(26, 24, 43),
		BackgroundTransparency = 0.08,
		Position = position,
		Size = size,
		ZIndex = 10,

		create("UICorner")({
			CornerRadius = UDim.new(0.22, 0),
		}),

		create("UIStroke")({
			Color = Color3.fromRGB(153, 146, 196),
			Thickness = 1,
			Transparency = 0.42,
		}),

		create("Frame")({
			Name = "Track",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(48, 44, 67),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.025, 0.5),
			Size = UDim2.fromScale(0.95, 0.72),
			ZIndex = 10,

			create("UICorner")({
				CornerRadius = UDim.new(0.28, 0),
			}),

			create("Frame")({
				Name = fillName,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Size = function()
					return UDim2.fromScale(animatedRatio(), 1)
				end,
				ZIndex = 11,

				create("UICorner")({
					CornerRadius = UDim.new(0.28, 0),
				}),

				create("UIGradient")({
					Color = colors,
					Rotation = 12,
				}),
			}),
		}),

		create("TextLabel")({
			Name = "Label",
			BackgroundTransparency = 1,
			FontFace = DISPLAY_FONT,
			Position = UDim2.fromScale(0.065, 0.08),
			Size = UDim2.fromScale(0.61, 0.84),
			Text = title,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,

			create("UIStroke")({
				Color = Color3.fromRGB(31, 25, 46),
				Thickness = 1.2,
			}),

			create("UITextSizeConstraint")({
				MaxTextSize = 14,
				MinTextSize = 6,
			}),
		}),

		create("TextLabel")({
			Name = "Value",
			BackgroundTransparency = 1,
			FontFace = DISPLAY_FONT,
			Position = UDim2.fromScale(0.66, 0.08),
			Size = UDim2.fromScale(0.275, 0.84),
			Text = getValueText,
			TextColor3 = Color3.fromRGB(255, 246, 205),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 12,

			create("UIStroke")({
				Color = Color3.fromRGB(38, 30, 48),
				Thickness = 1.1,
			}),

			create("UITextSizeConstraint")({
				MaxTextSize = 14,
				MinTextSize = 6,
			}),
		}),
	})
end

function SummonUI.UpdateBanner(bannerData)
	if bannerData and type(bannerData.NextRerollTime) == "number" then
		nextBannerTimerResetAt(bannerData.NextRerollTime)
	end

	if not bannerData or type(bannerData.Units) ~= "table" then
		warn("[SummonUI] Banner data is missing its unit list.")
		return
	end

	local unitsByRarity = copyDefaultUnitsPool()
	local units = bannerData.Units

	if units[1] then
		for _, unit in ipairs(units) do
			if unit.Rarity and unitsByRarity[unit.Rarity] then
				unitsByRarity[unit.Rarity] = {
					Name = unit.Name or "",
					RateText = unit.RateText or "",
				}
			end
		end
	else
		for rarity, info in units do
			if unitsByRarity[rarity] and type(info) == "table" then
				unitsByRarity[rarity] = {
					Name = info.Name or "",
					RateText = info.RateText or "",
				}
			end
		end
	end

	local previousPool = currentUnitsPool()
	local lineupChanged = false
	for rarity, unitInfo in unitsByRarity do
		local previousInfo = previousPool[rarity]
		if not previousInfo or previousInfo.Name ~= unitInfo.Name or previousInfo.RateText ~= unitInfo.RateText then
			lineupChanged = true
			break
		end
	end

	if lineupChanged then
		currentUnitsPool(unitsByRarity)
	end
end

function SummonUI.Summon(number: number)
	local cost = SummonConfig.Prices[number]
	if not cost or not canPurchase(cost) then
		return
	end
	summonInProgress(true)

	task.spawn(function()
		local ok, success, result = pcall(function()
			return Net.SummonService.DoSummon.Invoke(number):await()
		end)
		summonInProgress(false)

		if not ok then
			warn("[SummonUI] Summon request failed: " .. tostring(success))
			return
		end

		if not success or not result or not result.Success then
			return
		end

		-- The server also pushes OwnedTowersAdded, but a refresh here makes the
		-- inventory deterministic even if that event arrives before UI startup.
		InventoryClient.RefreshTowers():catch(function(err)
			warn(`[SummonUI] Failed to refresh units after summon: {err}`)
		end)

		local pulledUnits = result.PulledUnits
		if type(pulledUnits) == "table" and #pulledUnits > 0 then
			isProbabilityOpen(false)
			local revealedResults = {}
			local frameCallbacks = {
				[0] = function()
					if cutsceneSFX then
						cutsceneSFX:Play()
					end
				end,
				[19] = function()
					emitCutsceneVFX("Book VFX")
				end,
				[34] = function()
					emitCutsceneVFX("Book Catch")
				end,
				[85] = function()
					emitCutsceneVFX("Shine")
				end,
			}
			local pauseFrames = {}

			for resultIndex = 1, math.min(#pulledUnits, #RESULT_REVEAL_FRAMES) do
				local capturedIndex = resultIndex
				local revealFrame = RESULT_REVEAL_FRAMES[capturedIndex]
				pauseFrames[revealFrame] = true
				frameCallbacks[revealFrame] = function()
					if bookTurnSFX then
						bookTurnSFX:Play()
					end
					emitCutsceneVFX("OpenBook")
					local didOpen = SummonResultUI.ShowResults({ pulledUnits[capturedIndex] }, function()
						-- Keep an exclusive view active while the cutscene is hidden so the
						-- regular HUD cannot flash between consecutive results.
						SummonUI.Open()
						CutscenePlayer.Resume()
					end, false)

					if didOpen then
						revealedResults[capturedIndex] = true
					else
						CutscenePlayer.Resume()
					end
				end
			end

			isCutscenePlaying(true)
			local didPlay = CutscenePlayer.Play("Summon", {
				FrameCallbacks = frameCallbacks,
				PauseFrames = pauseFrames,
			})
			isCutscenePlaying(false)

			local remainingUnits = {}
			for resultIndex, unit in pulledUnits do
				if not revealedResults[resultIndex] then
					table.insert(remainingUnits, unit)
				end
			end

			if not didPlay or #remainingUnits > 0 then
				SummonResultUI.ShowResults(remainingUnits, function()
					if summonZone and summonZone:IsTouching(Players.LocalPlayer) then
						SummonUI.Open()
					end
				end, true)
			elseif summonZone and summonZone:IsTouching(Players.LocalPlayer) then
				SummonUI.Open()
			elseif isOpen() then
				UIController:Close(VIEW_ID)
			end
		end
	end)
end

function SummonUI.RenderUI()
	local isMounted = source(false)
	local motion = source(0)
	local reveal = source(0)
	local opacity = source(0)

	local openSFX = useAudio({
		Id = UISFX.SummonOpen.Id,
		Volume = UISFX.SummonOpen.Volume,
	})

	local closeSFX = useAudio({
		Id = UISFX.Close.Id,
		Volume = UISFX.Close.Volume,
	})

	-- Frame callbacks only play audio; Vide owns its creation and cleanup here.
	cutsceneSFX = useAudio({
		Id = UISFX.SummonSceneStart.Id,
		Volume = UISFX.SummonSceneStart.Volume,
	})
	bookTurnSFX = useAudio({
		Id = UISFX.SummonBookTurn.Id,
		Volume = UISFX.SummonBookTurn.Volume,
	})
	cleanup(function()
		cutsceneSFX = nil
		bookTurnSFX = nil
	end)

	local wasOpen = false
	effect(function()
		local shouldOpen = isOpen()
		if shouldOpen == wasOpen then
			return
		end
		wasOpen = shouldOpen

		-- Results switch views while the summon menu stays hidden behind the cutscene.
		-- Track those switches silently; ending the cutscene must not replay a menu sound.
		if untrack(isCutscenePlaying) then
			return
		end

		if shouldOpen then
			openSFX:Play()
		else
			closeSFX:Play()
		end
	end)

	effect(function()
		local shouldOpen = isOpen()
		if not shouldOpen then
			isProbabilityOpen(false)
		end
		if not shouldOpen and not untrack(isMounted) then
			return
		end

		-- Resume from the current frame when a transition is interrupted.
		-- Disconnecting the previous animation also prevents a stale close from hiding a reopened window.
		local startMotion = untrack(motion)
		local startReveal = untrack(reveal)
		local startOpacity = untrack(opacity)
		local target = if shouldOpen then 1 else 0
		local duration = if shouldOpen then ENTER_DURATION else EXIT_DURATION
		local elapsed = 0
		isMounted(true)

		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed += deltaTime
			local progress = math.min(elapsed / duration, 1)
			local eased = TweenService:GetValue(
				progress,
				if shouldOpen then Enum.EasingStyle.Back else Enum.EasingStyle.Quad,
				if shouldOpen then Enum.EasingDirection.Out else Enum.EasingDirection.In
			)
			motion(startMotion + (target - startMotion) * eased)
			reveal(startReveal + (target - startReveal) * progress)
			local fade = if shouldOpen then math.min(elapsed / 0.14, 1) else progress
			opacity(startOpacity + (target - startOpacity) * fade)

			if progress == 1 then
				connection:Disconnect()
				isMounted(shouldOpen)
			end
		end)
		cleanup(connection)
	end)

	local function stagger(delay: number): () -> number
		return function()
			local progress = math.clamp((reveal() * ENTER_DURATION - delay) / (ENTER_DURATION - delay), 0, 1)
			return TweenService:GetValue(progress, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end
	end
	local headerReveal = stagger(0.025)
	local ornamentReveal = stagger(0.06)
	local footerReveal = stagger(0.1)
	local ratesTransparency = spring(function()
		return if isOpen() and isProbabilityOpen() then 0 else 1
	end, 0.2, 0.9)
	local ratesScale = spring(function()
		return if isOpen() and isProbabilityOpen() then 1 else 0.82
	end, 0.28, 0.74)

	return create("CanvasGroup")({
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = function()
			return 1 - opacity()
		end,
		Interactable = function()
			return isOpen() and not isCutscenePlaying()
		end,
		Visible = function()
			return isMounted() and not isCutscenePlaying()
		end,

		create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = MAIN_IMAGE,
			Position = function()
				return UDim2.fromScale(0.5, 0.5 + 0.06 * (1 - motion()))
			end,
			Rotation = function()
				return -4 * (1 - motion())
			end,
			Size = UDim2.fromScale(0.721698, 0.668872),

			create("UIScale")({
				Scale = function()
					return 0.88 + 0.12 * motion()
				end,
			}),

			create("UIAspectRatioConstraint")({
				AspectRatio = 1.88,
			}),

			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = HEADER_IMAGE,
				Position = function()
					return UDim2.fromScale(-0.0573612 - 0.065 * (1 - headerReveal()), -0.111321)
				end,
				Size = UDim2.fromScale(0.692821, 0.28349),
				ZIndex = 10,

				create("UIAspectRatioConstraint")({
					AspectRatio = 4.53,
				}),

				create("ImageLabel")({
					Name = "Helmet",
					AnchorPoint = Vector2.new(0, 0),
					BackgroundTransparency = 1,
					Image = HELMET_IMAGE,
					Rotation = function()
						return -18 * (1 - ornamentReveal())
					end,
					Position = UDim2.fromScale(0.0623672, 0.17661),
					Size = UDim2.fromScale(0.125872, 0.58156),

					create("UIAspectRatioConstraint")({}),
				}),

				create("ImageLabel")({
					Name = "Cloud",
					BackgroundTransparency = 1,
					Image = CLOUD_IMAGE,
					Position = function()
						return UDim2.fromScale(0.529887 - 0.15 * (1 - ornamentReveal()), 0.0551715)
					end,
					ImageTransparency = function()
						return 1 - ornamentReveal()
					end,
					Size = UDim2.fromScale(0.537766, 1.06417),

					create("UIAspectRatioConstraint")({
						AspectRatio = 2.16,
					}),
				}),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = PLAIN_DISPLAY_FONT,
					Position = UDim2.fromScale(0.265238, 0.435573),
					Size = UDim2.fromScale(0.283423, 0.290134),
					Text = "SUMMON",
					TextTransparency = function()
						return 1 - headerReveal()
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				create("ImageLabel")({
					Name = "Sword",
					BackgroundTransparency = 1,
					Image = SWORD_IMAGE,
					Rotation = function()
						return -24 * (1 - ornamentReveal())
					end,
					Position = function()
						return UDim2.fromScale(0.01, -0.312 - 0.15 * (1 - ornamentReveal()))
					end,
					Size = UDim2.fromScale(0.251814, 1.53914),

					create("UIAspectRatioConstraint")({
						AspectRatio = 0.77,
					}),
				}),
			}),

			create("ImageButton")({
				Name = "CancelButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = CLOSE_IMAGE,
				Position = UDim2.fromScale(0.980096, 0.0289194),
				Size = UDim2.fromScale(0.102144, 0.15458),

				Activated = function()
					isProbabilityOpen(false)
					UIController:Close(VIEW_ID)
				end,

				useButtonEffect(0.88, 1.08),

				create("UIAspectRatioConstraint")({}),
			}),

			create("ImageLabel")({
				Name = "Banner",
				BackgroundTransparency = 1,
				Image = BANNER_IMAGE,
				Position = UDim2.fromScale(0.0334857, 0.172169),
				Size = UDim2.fromScale(0.932419, 0.666445),

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				createUnitCard(FEATURED_RARITIES[1], 1, stagger(0.045)),
				createUnitCard(FEATURED_RARITIES[2], 2, stagger(0.085)),
				createUnitCard(FEATURED_RARITIES[3], 3, stagger(0.125)),
			}),

			createPurchaseButton("PurchaseButton", 1, "SUMMON", ONE_PULL_COST, function()
				return UDim2.fromScale(0.152616, 0.905 + 0.035 * (1 - footerReveal()))
			end),

			createPurchaseButton("PurchaseButton", 10, "X10", TEN_PULL_COST, function()
				return UDim2.fromScale(0.406167, 0.905 + 0.035 * (1 - footerReveal()))
			end),

			createStatusBar(
				"BannerTimer",
				"BannerTimerFill",
				"TIMER",
				function()
					return bannerSecondsRemaining() / BANNER_TIMER_DURATION
				end,
				function()
					return formatTimer(bannerSecondsRemaining())
				end,
				ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(67, 211, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 103, 255)),
				}),
				UDim2.fromScale(0.8, 0.105),
				UDim2.fromScale(0.26, 0.036)
			),

			createStatusBar("MythicFloorBar", "Fill", "MYTHIC PITY", function()
				return mythicPity() / MYTHIC_PITY_LIMIT
			end, function()
				return `{mythicPity()}/{MYTHIC_PITY_LIMIT}`
			end, RARITY_GRADIENTS.Mythic, UDim2.fromScale(0.7, 0.875), UDim2.fromScale(0.26, 0.036)),

			createStatusBar("AbsoluteFloorBar", "Fill", "ABSOLUTE PITY", function()
				return absolutePity() / ABSOLUTE_PITY_LIMIT
			end, function()
				return `{absolutePity()}/{ABSOLUTE_PITY_LIMIT}`
			end, RARITY_GRADIENTS.Absolute, UDim2.fromScale(0.7, 0.935), UDim2.fromScale(0.26, 0.036)),

			create("ImageButton")({
				Name = "DropRateButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Image = PROBABILITY_BUTTON_IMAGE,
				Position = UDim2.fromScale(0.91, 0.895),
				Rotation = spring(function()
					return if isProbabilityOpen() then -6 else 0
				end, 0.28, 0.72),
				Size = UDim2.fromScale(0.052, 0.078),
				ZIndex = 15,

				Activated = function()
					if isOpen() then
						isProbabilityOpen(not isProbabilityOpen())
					end
				end,

				useButtonEffect(0.94, 1.06),

				create("UIAspectRatioConstraint")({}),

				create("TextLabel")({
					Name = "Label",
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = DISPLAY_FONT,
					Position = UDim2.fromScale(0.5, 1.26),
					Size = UDim2.fromScale(1.8, 0.3),
					Text = "DROP RATE",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 16,

					create("UIStroke")({
						Color = Color3.fromRGB(35, 28, 54),
						Thickness = 1.2,
					}),
				}),
			}),

			create("CanvasGroup")({
				Name = "DropRateFrame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(24, 23, 45),
				BackgroundTransparency = 0.06,
				GroupTransparency = ratesTransparency,
				Interactable = isProbabilityOpen,
				Visible = function()
					return isMounted() and (isProbabilityOpen() or ratesTransparency() < 0.995)
				end,
				Position = spring(function()
					return if isProbabilityOpen() then UDim2.fromScale(0.78, 0.475) else UDim2.fromScale(0.82, 0.475)
				end, 0.3, 0.74),
				Size = UDim2.fromScale(0.3, 0.54),
				ZIndex = 20,

				create("UIScale")({
					Scale = ratesScale,
				}),

				create("UICorner")({
					CornerRadius = UDim.new(0.055, 0),
				}),

				create("UIStroke")({
					Color = Color3.fromRGB(126, 119, 255),
					Thickness = 2,
					Transparency = ratesTransparency,
				}),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = DISPLAY_FONT,
					Position = UDim2.fromScale(0.09, 0.035),
					Size = UDim2.fromScale(0.82, 0.11),
					Text = "DROP RATES",
					TextColor3 = Color3.fromRGB(255, 244, 196),
					TextScaled = true,
					ZIndex = 22,

					create("UIStroke")({
						Color = Color3.fromRGB(35, 27, 55),
						Thickness = 1.4,
					}),
				}),

				create("Frame")({
					Name = "Rows",
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.08, 0.17),
					Size = UDim2.fromScale(0.84, 0.77),
					ZIndex = 21,

					create("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.012, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),

					createRateRow(RATE_RARITIES[1], 1),
					createRateRow(RATE_RARITIES[2], 2),
					createRateRow(RATE_RARITIES[3], 3),
					createRateRow(RATE_RARITIES[4], 4),
					createRateRow(RATE_RARITIES[5], 5),
					createRateRow(RATE_RARITIES[6], 6),
				}),
			}),
		}),
	})
end

function SummonUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
	DataClient = ServiceRegistry:GetService("DataClient")
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
end

function SummonUI.Start()
	local player = Players.LocalPlayer
	task.spawn(function()
		CutscenePlayer.Preload("Summon")
	end)

	local function updatePitySources()
		mythicPity(
			math.clamp(math.floor(tonumber(player:GetAttribute(MYTHIC_PITY_ATTRIBUTE)) or 0), 0, MYTHIC_PITY_LIMIT - 1)
		)
		absolutePity(
			math.clamp(
				math.floor(tonumber(player:GetAttribute(ABSOLUTE_PITY_ATTRIBUTE)) or 0),
				0,
				ABSOLUTE_PITY_LIMIT - 1
			)
		)
	end

	updatePitySources()
	player:GetAttributeChangedSignal(MYTHIC_PITY_ATTRIBUTE):Connect(updatePitySources)
	player:GetAttributeChangedSignal(ABSOLUTE_PITY_ATTRIBUTE):Connect(updatePitySources)

	Net.SummonService.BannerUpdated.On(SummonUI.UpdateBanner)

	task.spawn(function()
		while true do
			local serverTime = workspace:GetServerTimeNow()
			local resetAt = nextBannerTimerResetAt()

			if resetAt <= 0 then
				resetAt = serverTime + (BANNER_TIMER_DURATION - (serverTime % BANNER_TIMER_DURATION))
				nextBannerTimerResetAt(resetAt)
			elseif resetAt <= serverTime then
				local elapsedIntervals = math.floor((serverTime - resetAt) / BANNER_TIMER_DURATION) + 1
				resetAt += elapsedIntervals * BANNER_TIMER_DURATION
				nextBannerTimerResetAt(resetAt)
			end

			bannerSecondsRemaining(math.max(0, resetAt - serverTime))
			task.wait(0.2)
		end
	end)

	task.spawn(function()
		local ok, success, bannerData = pcall(function()
			return Net.SummonService.GetBanner.Invoke():await()
		end)

		if ok and success and bannerData then
			SummonUI.UpdateBanner(bannerData)
		elseif not ok then
			warn("[SummonUI] GetBanner failed: " .. tostring(success))
		end
	end)

	local summonTouch = workspace:WaitForChild("TouchZone"):WaitForChild("SummonTouch")
	summonZone = TouchZone.new(summonTouch)
	summonZone:Start()

	summonZone.Touched:Connect(function(player: Player)
		if player ~= Players.LocalPlayer then
			return
		end

		SummonUI.Open()
	end)

	summonZone.TouchEnded:Connect(function(player: Player)
		if player ~= Players.LocalPlayer then
			return
		end

		isProbabilityOpen(false)
		UIController:Close(VIEW_ID)
	end)
end

return SummonUI
