local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local QuestData = require(ReplicatedStorage.Settings.Data.QuestData)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local CurrencyRewardCard = require(ReplicatedStorage.UI.Components.CurrencyRewardCard)

local create = Vide.create
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring

local QuestMenuUI = {}
local DataClient
local UIController

local VIEW_ID = "Quest"

local selectedCategory = source("GUIDE")
local selectedQuestIndex = source(1)
local pinnedQuestKeys = source({ Chapter1Clear = 1 } :: { [string]: number })

local isLast = false

type QuestDisplay = {
	Id: string,
	Title: string,
	Description: string,
	Current: number,
	Target: number,
	Progress: string,
	Claimed: boolean,
	Rewards: { [string]: number },
}

local EMPTY_QUEST: QuestDisplay = {
	Id = "",
	Title = "",
	Description = "",
	Current = 0,
	Target = 1,
	Progress = "",
	Claimed = false,
	Rewards = {},
}

local function getQuestState(questId: string, config)
	local state = if DataClient then DataClient.Quests()[questId] else nil
	if state or not config.AutoAccept then
		return state
	end
	-- Auto-accepted quests must render immediately while the initial server
	-- quest fetch is still in flight. Authoritative data replaces this fallback.
	local initialProgress = if config.TargetMap and DataClient
		then math.min(tonumber(DataClient.MapClears()[config.TargetMap]) or 0, config.TargetAmount)
		else 0
	return {
		Active = true,
		Progress = initialProgress,
		Target = config.TargetAmount,
		Completed = initialProgress >= config.TargetAmount,
		Claimed = false,
	}
end

local function getCategoryQuests(category: string): { QuestDisplay }
	local displays = {}
	local playerQuests = if DataClient then DataClient.Quests() else {}
	for questId, config in QuestData.ById do
		local state = playerQuests[questId] or getQuestState(questId, config)
		if
			config.Theme == category
			and state
			and (state.Active or state.Completed or state.Claimed)
		then
			local current = math.clamp(tonumber(state.Progress) or 0, 0, config.TargetAmount)
			table.insert(displays, {
				Id = questId,
				Title = config.Title,
				Description = config.Description,
				Current = current,
				Target = config.TargetAmount,
				Progress = if state.Claimed then "COMPLETED" else `({current}/{config.TargetAmount})`,
				Claimed = state.Claimed == true,
				Rewards = config.Rewards,
			})
		end
	end
	table.sort(displays, function(a, b)
		return a.Id < b.Id
	end)
	return displays
end

local function getQuest(index: number): QuestDisplay
	return getCategoryQuests(selectedCategory())[index] or EMPTY_QUEST
end

local function getQuestKey(index: number): string?
	local questId = getQuest(index).Id
	return if questId ~= "" then questId else nil
end

local function getQuestById(questId: string): (QuestDisplay?, string?)
	local config = QuestData.Get(questId)
	local state = config and getQuestState(questId, config)
	if not config or not state or not (state.Active or state.Completed) or state.Claimed then
		return nil, nil
	end

	for _, quest in getCategoryQuests(config.Theme) do
		if quest.Id == questId then
			return quest, config.Theme
		end
	end
	return nil, nil
end

function QuestMenuUI.GetPinnedQuestKeys()
	return pinnedQuestKeys
end

function QuestMenuUI.GetQuestById(questId: string): (QuestDisplay?, string?)
	return getQuestById(questId)
end

function QuestMenuUI.GetPinnedQuest(): (QuestDisplay?, string?)
	local firstKey: string? = nil
	local firstOrder = math.huge
	for questId, order in pinnedQuestKeys() do
		if order < firstOrder and getQuestById(questId) ~= nil then
			firstKey = questId
			firstOrder = order
		end
	end
	if firstKey then
		return getQuestById(firstKey)
	end
	return nil, nil
end

function QuestMenuUI.HasPinnedQuests(): boolean
	for questId in pinnedQuestKeys() do
		if getQuestById(questId) ~= nil then
			return true
		end
	end
	return false
end

function QuestMenuUI.UnpinQuest(questId: string)
	local current = pinnedQuestKeys()
	if not current[questId] then
		return
	end
	local nextPinned = table.clone(current)
	nextPinned[questId] = nil
	pinnedQuestKeys(nextPinned)
end

local function selectCategory(category: string)
	selectedCategory(category)
	selectedQuestIndex(1)
end

local function createCategoryButton(category: string)
	local isSelected = function()
		return selectedCategory() == category
	end

	return create("ImageButton")({
		Name = `{category}Button`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "rbxassetid://139274506988816",
		Size = UDim2.fromScale(0.235, 0.78),

		Activated = function()
			selectCategory(category)
		end,

		useButtonEffect(0.94, 1.055),

		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.149276, 0.214464),
			Size = UDim2.fromScale(0.68577, 0.527425),
			Text = category,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			create("UIStroke")({ Name = "UIStroke" }),
		}),

		create("UIGradient")({
			Name = "UIGradient",
			Color = function()
				return if isSelected()
					then ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 247, 0)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 133, 11)),
					})
					else ColorSequence.new(Color3.fromRGB(111, 108, 102))
			end,
			Rotation = 40,
		}),

		create("UIStroke")({
			Name = "UIStroke",
			Color = function()
				return if isSelected() then Color3.fromRGB(255, 238, 143) else Color3.fromRGB(106, 106, 106)
			end,
			Thickness = function()
				return if isSelected() then 2 else 1
			end,
		}),
		create("UICorner")({ Name = "UICorner" }),

	})
end

local function createRewardCard(getDisplay: () -> QuestDisplay, rewardName: string, layoutOrder: number)
	return CurrencyRewardCard({
		CurrencyName = rewardName,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(0.30, 0.92),
		Amount = function()
			return getDisplay().Rewards[rewardName] or 0
		end,
	})
end

local function createRewardRow(getDisplay: () -> QuestDisplay, position: UDim2, size: UDim2)
	return create("Frame")({
		Name = "Rewards",
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.025, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		createRewardCard(getDisplay, "Coins", 1),
		createRewardCard(getDisplay, "Gems", 2),
		createRewardCard(getDisplay, "Exp", 3),
	})
end

function QuestMenuUI.RenderUI()
	local isVisible = UIController:IsVisible(VIEW_ID)
	local menuMotion = useMenuMotion(isVisible, function()
		return UIController:GetActiveView()
	end)

	local openSFX = useAudio({
		Id = UISFX.QuestOpen.Id,
		Volume = UISFX.QuestOpen.Volume,
	})
	local closeSFX = useAudio({
		Id = UISFX.Close.Id,
		Volume = UISFX.Close.Volume,
	})
	local trackSFX = useAudio({
		Id = UISFX.QuestTrack.Id,
		Volume = UISFX.QuestTrack.Volume,
	})
	local untrackSFX = useAudio({
		Id = UISFX.QuestUntrack.Id,
		Volume = UISFX.QuestUntrack.Volume,
	})

	local function togglePinnedQuest(index: number)
		if getQuest(index).Claimed then return end
		local key = getQuestKey(index)
		if not key then
			return
		end
		local nextPinned = table.clone(pinnedQuestKeys())
		if nextPinned[key] then
			nextPinned[key] = nil
			pinnedQuestKeys(nextPinned)
			untrackSFX:Play()
		else
			local nextOrder = 1
			for _, order in nextPinned do
				nextOrder = math.max(nextOrder, order + 1)
			end
			nextPinned[key] = nextOrder
			pinnedQuestKeys(nextPinned)
			trackSFX:Play()
		end
	end


	local function createQuestCard(index: number)
		local display = function()
			return getQuest(index)
		end
		return create("ImageButton")({
			Name = `Quest{index}`,
			LayoutOrder = index,
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(255, 210, 52),
			BackgroundTransparency = function()
				return if selectedQuestIndex() == index then 0.42 else 1
			end,
			Image = "rbxassetid://103014172048487",
			Size = UDim2.fromScale(0.95, 0.48),
			create("UIAspectRatioConstraint")({
				AspectRatio = 3.4,
				AspectType = Enum.AspectType.ScaleWithParentSize,
				DominantAxis = Enum.DominantAxis.Width,
			}),
			Visible = function()
				return display().Id ~= ""
			end,
			ImageTransparency = function()
				return if selectedQuestIndex() == index then 0 else 0.12
			end,
			ImageColor3 = function()
				return if selectedQuestIndex() == index
					then Color3.fromRGB(255, 215, 75)
					else Color3.fromRGB(255, 255, 255)
			end,
			Activated = function()
				selectedQuestIndex(index)
			end,
			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			create("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = function()
					return if selectedQuestIndex() == index
						then Color3.fromRGB(255, 239, 139)
						else Color3.fromRGB(65, 60, 78)
				end,
				Thickness = function()
					return if selectedQuestIndex() == index then 3 else 1
				end,
			}),
			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.04, 0.05),
				Size = UDim2.fromScale(0.77, 0.18),
				Text = function() return display().Title end,
				TextColor3 = Color3.fromRGB(255, 236, 148),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				create("UIStroke")({ Thickness = 1.5 }),
			}),
			create("TextLabel")({
				Name = "Description",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.04, 0.25),
				Size = UDim2.fromScale(0.91, 0.22),
				Text = function() return display().Description end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				create("UITextSizeConstraint")({ MaxTextSize = 18, MinTextSize = 8 }),
				create("UIStroke")({ Thickness = 1 }),
			}),
			create("ImageButton")({
				Name = "PinButton",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(0.96, 0.05),
				Size = UDim2.fromScale(0.09, 0.22),
				BackgroundTransparency = 1,
				Image = "rbxassetid://128325259577735",
				Visible = function() return not display().Claimed end,
				ImageColor3 = function()
					local key = getQuestKey(index)
					return if key and pinnedQuestKeys()[key]
						then Color3.fromRGB(255, 227, 75) else Color3.fromRGB(155, 155, 155)
				end,
				Activated = function()
					selectedQuestIndex(index)
					togglePinnedQuest(index)
				end,
				create("UIAspectRatioConstraint")({}),
				useButtonEffect(0.94, 1.04),
			}),
			createRewardRow(display, UDim2.fromScale(0.04, 0.51), UDim2.fromScale(0.57, 0.44)),
			create("TextLabel")({
				Name = "Progress",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.64, 0.60),
				Size = UDim2.fromScale(0.30, 0.18),
				Text = function() return display().Progress end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				create("UIStroke")({ Thickness = 1.5 }),
			}),
			create("Frame")({
				Name = "ProgressTrack",
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.fromRGB(40, 35, 57),
				Position = UDim2.fromScale(0.64, 0.83),
				Size = UDim2.fromScale(0.30, 0.055),
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				create("Frame")({
					Name = "Fill",
					BorderSizePixel = 0,
					BackgroundColor3 = Color3.fromRGB(162, 234, 89),
					Size = function()
						local quest = display()
						return UDim2.fromScale(math.clamp(quest.Current / math.max(quest.Target, 1), 0, 1), 1)
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				}),
			}),
		})
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
		Name = "Container", GroupTransparency = menuMotion.Transparency, Interactable = isVisible,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.753032, 1),
		Visible = menuMotion.IsMounted,

		create("ImageLabel")({
			Name = "Main", AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://140081374666771",
			Position = UDim2.fromScale(0.498839, 0.20195),
			Rotation = menuMotion:WindowRotation(),
			Size = menuMotion:WindowSize(UDim2.fromScale(0.721698, 0.593865)),

			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://107093261949144",
				Position = menuMotion:HeaderPosition(UDim2.fromScale(-0.0573612, -0.111321)),
				Size = UDim2.fromScale(0.683091, 0.28349),
				ZIndex = 10,

				create("ImageLabel")({
					Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://99846717806579",
					Position = UDim2.fromScale(0.1372727, 0.4869791),
					Rotation = menuMotion:IconRotation(),
					Size = menuMotion:IconSize(UDim2.fromScale(0.224464, 0.918458)),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
					}),
				}),

				create("ImageLabel")({
					Name = "Cloud",
					BackgroundTransparency = 1,
					Image = "rbxassetid://128371081570035",
					ImageTransparency = menuMotion:Fade(),
					Position = menuMotion:CloudPosition(UDim2.fromScale(0.529887, 0.0551715)),
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
					Size = UDim2.fromScale(0.354292, 0.290134),
					Text = "QUEST",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextTransparency = menuMotion:Fade(),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
					AspectRatio = 4.53,
				}),
			}),

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 1.88,
			}),

			create("ImageButton")({
				Name = "CancelButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://92651860309635",
				Position = menuMotion:ClosePosition(UDim2.fromScale(0.980096, 0.0289194)),
				Rotation = menuMotion:CloseRotation(),
				Size = UDim2.fromScale(0.0822234, 0.15458),

				Activated = function()
					UIController:Close(VIEW_ID)
				end,

				useButtonEffect(nil, 1.1),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("CanvasGroup")({
				Name = "QuestsClip",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromScale(0.04, 0.31),
				Size = UDim2.fromScale(0.615, 0.63),
				ZIndex = 1,
				create("ScrollingFrame")({
					Name = "Quests", AnchorPoint = Vector2.new(0, 0),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 1),
					CanvasSize = UDim2.fromScale(0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ScrollBarThickness = 3,
					ScrollBarImageColor3 = Color3.fromRGB(255, 225, 130),
					ClipsDescendants = true,
					create("UIPadding")({
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
					}),
					create("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					createQuestCard(1),
					createQuestCard(2),
				}),
			}),

			-- Match UnitUI's empty search result: centered, independent of the
			-- scrolling list layout, and outlined for readability.
			create("TextLabel")({
				Name = "EmptyQuestResult",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.355792, 0.48),
				Size = UDim2.fromScale(0.50, 0.14),
				Text = function()
					return if selectedCategory() == "EVENT"
						then "NO ACTIVE EVENT QUESTS\nTalk to the Wandering Merchant."
						else "NO QUESTS FOUND"
				end,
				TextWrapped = true,
				create("UITextSizeConstraint")({ MaxTextSize = 20, MinTextSize = 8 }),
				TextColor3 = Color3.fromRGB(218, 218, 226),
				TextScaled = true,
				Visible = function()
					return #getCategoryQuests(selectedCategory()) == 0
				end,
				ZIndex = 4,

				create("UIStroke")({
					Color = Color3.fromRGB(32, 28, 60),
					Thickness = 2,
				}),
			}),

			create("CanvasGroup")({
				Name = "CategoryCanvasGroup",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = menuMotion:Spring(UDim2.fromScale(0.04044, 0.16577), UDim2.fromScale(0.04044, 0.1), "Content"),
				Size = UDim2.fromScale(0.609926, 0.127536),

				create("ScrollingFrame")({
					Name = "Category",
					Active = true,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.fromScale(0, 0),
					ScrollingEnabled = false,
					BorderSizePixel = 0,
					ClipsDescendants = true,
					ScrollBarImageColor3 = Color3.new(),
					ScrollBarThickness = 0,
					Size = UDim2.fromScale(1, 1),

				create("UIListLayout")({
					Name = "UIListLayout",
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0.01, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				createCategoryButton("GUIDE"),
				createCategoryButton("WEEK"),
				createCategoryButton("DAILY"),
				createCategoryButton("EVENT"),
					create("UIPadding")({ Name = "UIPadding", PaddingLeft = UDim.new(0, 2) }),
				}),
			}),

			create("ImageLabel")({
				Name = "Information",
				BackgroundTransparency = 1,
				Image = "rbxassetid://86773350223025",
				Position = menuMotion:Spring(UDim2.fromScale(0.674872, 0.184204), UDim2.fromScale(0.74, 0.184204), "Content"),
				Size = UDim2.fromScale(0.300221, 0.76429),

				create("ImageLabel")({
					Name = "Header",
					BackgroundTransparency = 1,
					Image = "rbxassetid://131328421366367",
					Position = UDim2.fromScale(0.0274306, 0.0694542),
					Size = UDim2.fromScale(0.937, 0.079),

					create("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.0431852, 0.193485),
						Size = UDim2.fromScale(0.570817, 0.564427),
						Text = selectedCategory,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 255, 47)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(172, 255, 39)),
							}),
							Rotation = 90,
						}),
					}),
				}),

				create("TextLabel")({
					Name = "Description",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.0483644, 0.185836),
					Size = UDim2.fromScale(0.90, 0.38),
					Text = function()
						local quest = getQuest(selectedQuestIndex())
						return if quest.Id ~= "" then quest.Description else "SELECT A QUEST TO VIEW ITS DETAILS"
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					create("UITextSizeConstraint")({ MaxTextSize = 19, MinTextSize = 8 }),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),

				create("ImageLabel")({
					Name = "Header",
					BackgroundTransparency = 1,
					Image = "rbxassetid://131328421366367",
					Position = UDim2.fromScale(0.0274306, 0.643204),
					Size = UDim2.fromScale(0.937, 0.079),

					create("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.0431852, 0.193485),
						Size = UDim2.fromScale(0.570817, 0.564427),
						Text = function()
							return if getQuest(selectedQuestIndex()).Claimed then "REWARD CLAIMED" else "REWARD"
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				}),

				createRewardRow(function()
					return getQuest(selectedQuestIndex())
				end, UDim2.fromScale(0.04, 0.74), UDim2.fromScale(0.92, 0.22)),

			}),
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 1.547,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		}),
	})
end

function QuestMenuUI.Init()
	DataClient = ServiceRegistry:GetService("DataClient")
	UIController = ServiceRegistry:GetService("UIController")
end

return QuestMenuUI
