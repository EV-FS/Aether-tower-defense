local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local QuestData = require(ReplicatedStorage.Settings.Data.QuestData)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring

local QuestMenuUI = {}
local DataClient
local UIController

local VIEW_ID = "Quest"

local selectedCategory = source("EVENT")
local selectedQuestIndex = source(1)
local pinnedQuestKey = source(nil :: string?)

local isLast = false

type QuestDisplay = {
	Id: string,
	Title: string,
	Description: string,
	Current: number,
	Target: number,
	Progress: string,
	RewardName: string,
	RewardQuantity: string,
}

local EMPTY_QUEST: QuestDisplay = {
	Id = "",
	Title = "",
	Description = "",
	Current = 0,
	Target = 1,
	Progress = "",
	RewardName = "",
	RewardQuantity = "",
}

local function formatRewards(rewards): (string, string)
	local names = {}
	local amounts = {}
	for _, rewardName in ipairs({ "Coins", "Gems", "Exp" }) do
		local amount = rewards[rewardName]
		if type(amount) == "number" and amount > 0 then
			table.insert(names, if rewardName == "Exp" then "EXP" else rewardName)
			table.insert(amounts, tostring(amount))
		end
	end
	return table.concat(names, " / "), table.concat(amounts, " / ")
end

local function getCategoryQuests(category: string): { QuestDisplay }
	local displays = {}
	local playerQuests = if DataClient then DataClient.Quests() else {}
	for questId, config in QuestData do
		local state = playerQuests[questId]
		if
			config.Theme == category
			and state
			and (state.Active or state.Completed)
			and not state.Claimed
		then
			local current = math.clamp(tonumber(state.Progress) or 0, 0, config.TargetAmount)
			local rewardName, rewardQuantity = formatRewards(config.Rewards)
			table.insert(displays, {
				Id = questId,
				Title = config.Title,
				Description = config.Description,
				Current = current,
				Target = config.TargetAmount,
				Progress = `({current}/{config.TargetAmount})`,
				RewardName = rewardName,
				RewardQuantity = rewardQuantity,
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

function QuestMenuUI.GetPinnedQuest(): (QuestDisplay?, string?)
	local key = pinnedQuestKey()
	if not key then
		return nil, nil
	end

	local config = QuestData[key]
	local state = DataClient and DataClient.Quests()[key]
	if config and state and (state.Active or state.Completed) and not state.Claimed then
		for _, quest in getCategoryQuests(config.Theme) do
			if quest.Id == key then
				return quest, config.Theme
			end
		end
	end
	return nil, nil
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
		Size = UDim2.fromScale(0.0941507, 0.710921),

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
		create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint", AspectRatio = 3.9 }),
	})
end

function QuestMenuUI.RenderUI()
	local isVisible = UIController:IsVisible(VIEW_ID)

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
		local key = getQuestKey(index)
		if not key then
			return
		end
		if pinnedQuestKey() == key then
			pinnedQuestKey(nil)
			untrackSFX:Play()
		else
			pinnedQuestKey(key)
			trackSFX:Play()
		end
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

	return create("Frame")({
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.753032, 1),
		Visible = isVisible,

		create("ImageLabel")({
			Name = "Main",
			BackgroundTransparency = 1,
			Image = "rbxassetid://140081374666771",
			Position = UDim2.fromScale(0.13799, 0.20195),
			Rotation = spring(function()
				return if isVisible() then 0 else -4
			end, 0.5, 1),
			Size = spring(function()
				return if isVisible() then UDim2.fromScale(0.721698, 0.593865) else UDim2.fromScale(0.68, 0.56)
			end, 0.5, 0.55),

			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://107093261949144",
				Position = spring(function()
					return if isVisible()
						then UDim2.fromScale(-0.0573612, -0.111321)
						else UDim2.fromScale(-0.12, -0.111321)
				end, 0.5, 0.8),
				Size = UDim2.fromScale(0.683091, 0.28349),
				ZIndex = 10,

				create("ImageLabel")({
					Name = "Icon",
					BackgroundTransparency = 1,
					Image = "rbxassetid://99846717806579",
					Position = UDim2.fromScale(0.0250407, 0.0277501),
					Rotation = spring(function()
						return if isVisible() then 0 else -90
					end, 0.5, 0.7),
					Size = spring(function()
						return if isVisible() then UDim2.fromScale(0.224464, 0.918458) else UDim2.fromScale(0.32, 1.25)
					end, 0.5, 0.8),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
					}),
				}),

				create("ImageLabel")({
					Name = "Cloud",
					BackgroundTransparency = 1,
					Image = "rbxassetid://128371081570035",
					ImageTransparency = spring(function()
						return if isVisible() then 0 else 1
					end, 0.5, 1),
					Position = spring(function()
						return if isVisible()
							then UDim2.fromScale(0.529887, 0.0551715)
							else UDim2.fromScale(0.375, 0.0551715)
					end, 0.7, 0.8),
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
					TextTransparency = spring(function()
						return if isVisible() then 0 else 1
					end, 0.5, 1),
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
				Position = spring(function()
					return if isVisible() then UDim2.fromScale(0.980096, 0.0289194) else UDim2.fromScale(0.2, 0.0289194)
				end, 1, 0.85),
				Rotation = spring(function()
					return if isVisible() then 0 else -1800
				end, 1, 0.8),
				Size = UDim2.fromScale(0.0822234, 0.15458),

				Activated = function()
					UIController:Close(VIEW_ID)
				end,

				useButtonEffect(nil, 1.1),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("ScrollingFrame")({
				Name = "Quests",
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = spring(function()
					return if isVisible() then UDim2.fromScale(0.355792, 0.622506) else UDim2.fromScale(0.31, 0.622506)
				end, 0.5, 0.8),
				ScrollBarImageColor3 = Color3.new(),
				ScrollBarThickness = 0,
				Size = UDim2.fromScale(0.663523, 0.633252),

				create("UIListLayout")({
					Name = "UIListLayout",
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.01, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				create("TextLabel")({
					Name = "EmptyState",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					LayoutOrder = -1,
					Size = UDim2.fromScale(0.92, 0.16),
					Text = "진행 중인 퀘스트가 없습니다.",
					TextColor3 = Color3.fromRGB(161, 161, 161),
					TextScaled = true,
					Visible = function()
						return #getCategoryQuests(selectedCategory()) == 0
					end,

					create("UIStroke")({ Transparency = 0.5 }),
				}),

				create("ImageButton")({
					Name = "Quest",
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					Image = "rbxassetid://103014172048487",
					Position = UDim2.fromScale(0.0475516, 0),
					Size = UDim2.fromScale(0.949, 0.16),
					Visible = function()
						return getQuest(1).Id ~= ""
					end,
					ImageTransparency = function()
						return if selectedQuestIndex() == 1 then 0 else 0.12
					end,
					Activated = function()
						selectedQuestIndex(1)
					end,
					useButtonEffect(0.985, 1.012),

					create("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.0212704, 0.047321),
						Size = UDim2.fromScale(0.485076, 0.191573),
						Text = function()
							return getQuest(1).Title
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							Thickness = 3,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 255, 47)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(172, 255, 39)),
							}),
							Rotation = 90,
						}),
					}),

					create("TextLabel")({
						Name = "Description",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.0192173, 0.263003),
						Size = UDim2.fromScale(0.770465, 0.149422),
						Text = function()
							return getQuest(1).Description
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							Thickness = 2,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Rotation = 90,
						}),
					}),

					create("ImageButton")({
						Name = "PinButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = function()
							return if pinnedQuestKey() == getQuestKey(1)
								then Color3.fromRGB(255, 213, 35)
								else Color3.fromRGB(91, 91, 91)
						end,
						BackgroundTransparency = 0,
						Image = "rbxassetid://128325259577735",
						ImageColor3 = function()
							return if pinnedQuestKey() == getQuestKey(1)
								then Color3.fromRGB(255, 241, 84)
								else Color3.fromRGB(91, 91, 91)
						end,
						Position = UDim2.fromScale(0.934471, 0.193828),
						Size = UDim2.fromScale(0.228367, 0.249376),
						Activated = function()
							selectedQuestIndex(1)
							togglePinnedQuest(1)
						end,
						useButtonEffect(0.9, 1.08),

						create("UIStroke")({
							Name = "UIStroke",
						}),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
						}),

						create("UICorner")({
							Name = "UICorner",
							BottomLeftRadius = UDim.new(0, 5),
							BottomRightRadius = UDim.new(0, 5),
							TopLeftRadius = UDim.new(0, 5),
							TopRightRadius = UDim.new(0, 5),
						}),
					}),

					create("ScrollingFrame")({
						Name = "ScrollingFrame",
						Active = true,
						BackgroundTransparency = 1,
						CanvasSize = UDim2.fromScale(2, 0),
						Position = UDim2.fromScale(0.024, 0.55),
						ScrollBarImageColor3 = Color3.new(),
						ScrollBarThickness = 0,
						Size = UDim2.fromScale(0.949939, 0.428425),

						create("ImageButton")({
							Name = "ImageButton",
							BackgroundTransparency = 1,
							Image = "rbxassetid://87496848270095",
							LayoutOrder = 6,
							Position = UDim2.fromScale(7.53632e-08, 0),
							Size = UDim2.fromScale(0.126464, 1.03237),

							useButtonEffect(0.94, 1.04),

							create("ViewportFrame")({
								Name = "ViewportFrame",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.11, 0.102),
								Size = UDim2.fromScale(0.784, 0.781),
								ZIndex = 5,
							}),

							create("CanvasGroup")({
								Name = "CanvasGroup",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.489217, 0.489218),
								Size = UDim2.fromScale(0.935304, 0.935304),

								create("LocalScript")({
									Name = "LocalScript",
								}),
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(69, 154, 69)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 128, 154)),
								}),
								Rotation = 45,
							}),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),

							create("ImageLabel")({
								Name = "Quantity",
								BackgroundTransparency = 1,
								Image = "rbxassetid://104083646922843",
								Position = UDim2.fromScale(-0.0129994, -0.05),
								Size = UDim2.fromScale(0.653434, 0.238322),
								ZIndex = 10,

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
									AspectRatio = 3.2,
								}),

								create("TextLabel")({
									Name = "TextLabel",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									FontFace = Font.new(
										"rbxasset://fonts/families/SourceSansPro.json",
										Enum.FontWeight.Bold,
										Enum.FontStyle.Normal
									),
									Position = UDim2.fromScale(0.364926, 0.399472),
									Size = UDim2.fromScale(0.607627, 0.888569),
									Text = function()
										return getQuest(1).RewardQuantity
									end,
									TextColor3 = Color3.new(1, 1, 1),
									TextScaled = true,

									create("UIStroke")({
										Name = "UIStroke",
										Thickness = 2,
									}),

									create("UIGradient")({
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(188, 188, 255)),
										}),
										Rotation = 90,
									}),
								}),
							}),

							create("TextLabel")({
								Name = "Name",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.076095, 0.730419),
								Size = UDim2.fromScale(0.84887, 0.172688),
								Text = function()
									return getQuest(1).RewardName
								end,
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 10,

								create("UIStroke")({
									Name = "UIStroke",
									Thickness = 2,
								}),
							}),
						}),

						create("UIListLayout")({
							Name = "UIListLayout",
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
					}),

					create("TextLabel")({
						Name = "Description",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.661288, 0.372631),
						Size = UDim2.fromScale(0.316076, 0.149422),
						Text = function()
							return getQuest(1).Progress
						end,
						TextColor3 = Color3.fromRGB(161, 161, 161),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Right,

						create("UIStroke")({
							Name = "UIStroke",
							Thickness = 2,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Rotation = 90,
						}),
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = function()
							local color = if pinnedQuestKey() == getQuestKey(1)
								then Color3.fromRGB(255, 241, 84)
								else Color3.fromRGB(91, 91, 91)
							return ColorSequence.new(color)
						end,
					}),
				}),

				create("ImageButton")({
					Name = "Quest",
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					Image = "rbxassetid://103014172048487",
					Position = UDim2.fromScale(0.0475516, 0),
					Size = UDim2.fromScale(0.949, 0.16),
					Visible = function()
						return getQuest(2).Id ~= ""
					end,
					ImageTransparency = function()
						return if selectedQuestIndex() == 2 then 0 else 0.12
					end,
					Activated = function()
						selectedQuestIndex(2)
					end,
					useButtonEffect(0.985, 1.012),

					create("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.0212704, 0.047321),
						Size = UDim2.fromScale(0.485076, 0.191573),
						Text = function()
							return getQuest(2).Title
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							Thickness = 3,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 255, 47)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(172, 255, 39)),
							}),
							Rotation = 90,
						}),
					}),

					create("TextLabel")({
						Name = "Description",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.0192173, 0.263003),
						Size = UDim2.fromScale(0.770465, 0.149422),
						Text = function()
							return getQuest(2).Description
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							Thickness = 2,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Rotation = 90,
						}),
					}),

					create("ImageButton")({
						Name = "PinButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = function()
							return if pinnedQuestKey() == getQuestKey(2)
								then Color3.fromRGB(255, 213, 35)
								else Color3.fromRGB(91, 91, 91)
						end,
						BackgroundTransparency = 0,
						Image = "rbxassetid://128325259577735",
						ImageColor3 = function()
							return if pinnedQuestKey() == getQuestKey(2)
								then Color3.fromRGB(255, 241, 84)
								else Color3.fromRGB(91, 91, 91)
						end,
						Position = UDim2.fromScale(0.934471, 0.193828),
						Size = UDim2.fromScale(0.228367, 0.249376),
						Activated = function()
							selectedQuestIndex(2)
							togglePinnedQuest(2)
						end,
						useButtonEffect(0.9, 1.08),

						create("UIStroke")({
							Name = "UIStroke",
						}),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
						}),

						create("UICorner")({
							Name = "UICorner",
							BottomLeftRadius = UDim.new(0, 5),
							BottomRightRadius = UDim.new(0, 5),
							TopLeftRadius = UDim.new(0, 5),
							TopRightRadius = UDim.new(0, 5),
						}),
					}),

					create("ScrollingFrame")({
						Name = "ScrollingFrame",
						Active = true,
						BackgroundTransparency = 1,
						CanvasSize = UDim2.fromScale(2, 0),
						Position = UDim2.fromScale(0.024, 0.55),
						ScrollBarImageColor3 = Color3.new(),
						ScrollBarThickness = 0,
						Size = UDim2.fromScale(0.949939, 0.428425),

						create("ImageButton")({
							Name = "ImageButton",
							BackgroundTransparency = 1,
							Image = "rbxassetid://87496848270095",
							LayoutOrder = 6,
							Position = UDim2.fromScale(7.53632e-08, 0),
							Size = UDim2.fromScale(0.126464, 1.03237),

							useButtonEffect(0.94, 1.04),

							create("ViewportFrame")({
								Name = "ViewportFrame",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.11, 0.102),
								Size = UDim2.fromScale(0.784, 0.781),
								ZIndex = 5,
							}),

							create("CanvasGroup")({
								Name = "CanvasGroup",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.489217, 0.489218),
								Size = UDim2.fromScale(0.935304, 0.935304),

								create("LocalScript")({
									Name = "LocalScript",
								}),
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(69, 154, 69)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 128, 154)),
								}),
								Rotation = 45,
							}),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),

							create("ImageLabel")({
								Name = "Quantity",
								BackgroundTransparency = 1,
								Image = "rbxassetid://104083646922843",
								Position = UDim2.fromScale(-0.0129994, -0.05),
								Size = UDim2.fromScale(0.653434, 0.238322),
								ZIndex = 10,

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
									AspectRatio = 3.2,
								}),

								create("TextLabel")({
									Name = "TextLabel",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									FontFace = Font.new(
										"rbxasset://fonts/families/SourceSansPro.json",
										Enum.FontWeight.Bold,
										Enum.FontStyle.Normal
									),
									Position = UDim2.fromScale(0.364926, 0.399472),
									Size = UDim2.fromScale(0.607627, 0.888569),
									Text = function()
										return getQuest(2).RewardQuantity
									end,
									TextColor3 = Color3.new(1, 1, 1),
									TextScaled = true,

									create("UIStroke")({
										Name = "UIStroke",
										Thickness = 2,
									}),

									create("UIGradient")({
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(188, 188, 255)),
										}),
										Rotation = 90,
									}),
								}),
							}),

							create("TextLabel")({
								Name = "Name",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.076095, 0.730419),
								Size = UDim2.fromScale(0.84887, 0.172688),
								Text = function()
									return getQuest(2).RewardName
								end,
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 10,

								create("UIStroke")({
									Name = "UIStroke",
									Thickness = 2,
								}),
							}),
						}),

						create("UIListLayout")({
							Name = "UIListLayout",
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
					}),

					create("TextLabel")({
						Name = "Description",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.661288, 0.372631),
						Size = UDim2.fromScale(0.316076, 0.149422),
						Text = function()
							return getQuest(2).Progress
						end,
						TextColor3 = Color3.fromRGB(161, 161, 161),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Right,

						create("UIStroke")({
							Name = "UIStroke",
							Thickness = 2,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Rotation = 90,
						}),
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = function()
							local color = if pinnedQuestKey() == getQuestKey(2)
								then Color3.fromRGB(255, 241, 84)
								else Color3.fromRGB(91, 91, 91)
							return ColorSequence.new(color)
						end,
					}),
				}),
			}),

			create("ScrollingFrame")({
				Name = "Category",
				Active = true,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.fromScale(2, 0),
				Position = spring(function()
					return if isVisible() then UDim2.fromScale(0.04044, 0.16577) else UDim2.fromScale(0.04044, 0.1)
				end, 0.55, 0.75),
				ScrollBarImageColor3 = Color3.new(),
				ScrollBarThickness = 0,
				Size = UDim2.fromScale(0.609926, 0.127536),

				create("UIListLayout")({
					Name = "UIListLayout",
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0.01, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				createCategoryButton("EVENT"),
				create("UIPadding")({ Name = "UIPadding", PaddingLeft = UDim.new(0, 2) }),
			}),

			create("ImageLabel")({
				Name = "Information",
				BackgroundTransparency = 1,
				Image = "rbxassetid://86773350223025",
				Visible = function()
					return getQuest(selectedQuestIndex()).Id ~= ""
				end,
				Position = spring(function()
					return if isVisible() then UDim2.fromScale(0.674872, 0.184204) else UDim2.fromScale(0.74, 0.184204)
				end, 0.55, 0.78),
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
					Size = UDim2.fromScale(0.916066, 0.290032),
					Text = function()
						return getQuest(selectedQuestIndex()).Description
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
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
						Text = "REWARD",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				}),

				create("ScrollingFrame")({
					Name = "ScrollingFrame",
					Active = true,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.fromScale(2, 0),
					Position = UDim2.fromScale(0.0239999, 0.760075),
					ScrollBarImageColor3 = Color3.new(),
					ScrollBarThickness = 0,
					Size = UDim2.fromScale(0.949939, 0.209524),

					create("ImageButton")({
						Name = "ImageButton",
						BackgroundTransparency = 1,
						Image = "rbxassetid://87496848270095",
						LayoutOrder = 6,
						Position = UDim2.fromScale(7.53632e-08, 0),
						Size = UDim2.fromScale(0.126464, 1.03237),

						useButtonEffect(0.94, 1.04),

						create("ViewportFrame")({
							Name = "ViewportFrame",
							BackgroundTransparency = 1,
							Position = UDim2.fromScale(0.11, 0.102),
							Size = UDim2.fromScale(0.784, 0.781),
							ZIndex = 5,
						}),

						create("CanvasGroup")({
							Name = "CanvasGroup",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Position = UDim2.fromScale(0.489217, 0.489218),
							Size = UDim2.fromScale(0.935304, 0.935304),

							create("LocalScript")({
								Name = "LocalScript",
							}),
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(69, 154, 69)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 128, 154)),
							}),
							Rotation = 45,
						}),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
						}),

						create("ImageLabel")({
							Name = "Quantity",
							BackgroundTransparency = 1,
							Image = "rbxassetid://104083646922843",
							Position = UDim2.fromScale(-0.0129994, -0.05),
							Size = UDim2.fromScale(0.653434, 0.238322),
							ZIndex = 10,

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
								AspectRatio = 3.2,
							}),

							create("TextLabel")({
								Name = "TextLabel",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.364926, 0.399472),
								Size = UDim2.fromScale(0.607627, 0.888569),
								Text = function()
									return getQuest(selectedQuestIndex()).RewardQuantity
								end,
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,

								create("UIStroke")({
									Name = "UIStroke",
									Thickness = 2,
								}),

								create("UIGradient")({
									Name = "UIGradient",
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(188, 188, 255)),
									}),
									Rotation = 90,
								}),
							}),
						}),

						create("TextLabel")({
							Name = "Name",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.076095, 0.730419),
							Size = UDim2.fromScale(0.84887, 0.172688),
							Text = function()
								return getQuest(selectedQuestIndex()).RewardName
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 10,

							create("UIStroke")({
								Name = "UIStroke",
								Thickness = 2,
							}),
						}),
					}),

					create("UIListLayout")({
						Name = "UIListLayout",
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
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

function QuestMenuUI.Init()
	DataClient = ServiceRegistry:GetService("DataClient")
	UIController = ServiceRegistry:GetService("UIController")
end

return QuestMenuUI
