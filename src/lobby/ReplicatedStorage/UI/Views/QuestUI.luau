local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local QuestData = require(ReplicatedStorage.Settings.Data.QuestData)

local create = Vide.create
local derive = Vide.derive
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring

local DataClient
local DialogueClient
local UIController

local QuestUI = {}

local isTrackingExpanded = source(true)

local function playQuestAcceptSound()
	task.spawn(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://9069609268"
		sound.Volume = 0.55
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end)
end

function QuestUI.RenderUI()
	local targetAmount = 1500

	local isAccepted = derive(function()
		local quests = DataClient and DataClient.Quests() or {}
		local q = quests["BlossomCollector"]
		return q and (q.Active or q.Completed) and not q.Claimed or false
	end)

	local isHovered = source(false)
	local isEntered = source(false)

	-- 퀘스트 수락 시 자연스러운 슬라이드 & 팝업 연출 트리거
	local prevAccepted = false
	effect(function()
		local cur = isAccepted()
		if cur and not prevAccepted then
			prevAccepted = true
			isEntered(false)
			playQuestAcceptSound()
			task.delay(0.05, function()
				isEntered(true)
			end)
		elseif not cur then
			prevAccepted = false
			isEntered(false)
		end
	end)

	-- 1. 자연스럽고 부드러운 진입 애니메이션 (35px 슬라이드 + 부드러운 스케일)
	local entranceScale = spring(function()
		return if isEntered() then 1 else 0.85
	end, 0.28, 0.78)

	local entranceSlide = spring(function()
		return if isEntered() then 0 else 35
	end, 0.26, 0.80)

	local entranceAlpha = spring(function()
		return if isEntered() then 0 else 1
	end, 0.22, 0.85)

	-- 2. 호버 상호작용: 좌상단 기준(0, 0)에서 1.065배로 쫀득하게 커짐
	local hoverScale = spring(function()
		return if isHovered() then 1.065 else 1
	end, 0.16, 0.72)

	-- 3. 호버 시 테두리(UIStroke) 발광 연출
	local hoverStrokeThickness = spring(function()
		return if isHovered() then 2.2 else 1
	end, 0.16, 0.75)

	local hoverStrokeColor = spring(function()
		return if isHovered() then Color3.fromRGB(115, 255, 145) else Color3.fromRGB(75, 88, 100)
	end, 0.18, 0.75)

	local hoverStrokeTransparency = spring(function()
		return if isHovered() then 0.05 else 0.85
	end, 0.18, 0.75)

	local targetBlossom = derive(function()
		local blossom = DataClient and DataClient.Blossom() or 0
		return math.min(blossom, targetAmount)
	end)

	-- 4. 숫자는 천천히 부드럽게 카운트업 (period 0.45, damping 0.85)
	local animatedBlossom = spring(targetBlossom, 0.45, 0.85)

	local targetRatio = derive(function()
		local blossom = targetBlossom()
		return math.clamp(blossom / targetAmount, 0, 1)
	end)

	-- 5. 게이지 바는 쫀득하고 탄력있게 스프링 이동 (period 0.32, damping 0.70)
	local animatedRatio = spring(targetRatio, 0.32, 0.70)

	local descText = function()
		local rawCur = targetBlossom()
		local animCur = math.clamp(math.round(animatedBlossom()), 0, targetAmount)
		if rawCur >= targetAmount then
			return "벚꽃 수집 완료! 방랑 상인에게 보고하세요."
		end
		return string.format(
			"키츠네 정화를 위해 벚꽃 수집 (%s/1,500)",
			DataClient and DataClient.FormatNumber(animCur) or tostring(animCur)
		)
	end

	return create("Frame")({
		Name = "QuestFrame",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.819361, 0),
		Size = UDim2.fromScale(0.180105, 1),
		ZIndex = 5,
		Visible = function()
			if DialogueClient and DialogueClient.IsOpen() then
				return false
			end
			if UIController and UIController:IsOpen("Dialogue") then
				return false
			end
			return true
		end,

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 0.37,
		}),

		create("Frame")({
			Name = "main",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.0205005, -0.000629893),
			Size = UDim2.fromScale(0.981832, 0.363278),

			-- 상단 헤더 (항상 표시)
			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://90611390853296",
				Size = UDim2.fromScale(1, 0.115507),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.1601, 0.177398),
					Size = UDim2.fromScale(0.498479, 0.564427),
					Text = "QUEST TRACKING",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,

					create("UIStroke")({
						Name = "UIStroke",
					}),
				}),

				create("ImageButton")({
					Name = "CancelButton",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://104073784954292",
					Position = UDim2.fromScale(0.1, 0.5),
					Size = UDim2.fromScale(0.0955804, 0.860585),
					Activated = function()
						isTrackingExpanded(not isTrackingExpanded())
					end,

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
					}),
				}),
			}),

			-- 퀘스트 목록 스크롤 프레임
			create("ScrollingFrame")({
				Name = "ScrollingFrame",
				Active = true,
				BackgroundTransparency = 1,
				ClipsDescendants = false,
				Position = UDim2.fromScale(0, 0.135388),
				ScrollBarImageColor3 = Color3.new(),
				ScrollBarThickness = 0,
				Size = UDim2.fromScale(1, 0.958303),
				Visible = function()
					return isTrackingExpanded()
				end,

				create("UIListLayout")({
					Name = "UIListLayout",
					Padding = UDim.new(0, 5),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				-- 퀘스트 카드
				create("ImageLabel")({
					Name = "Quest",
					AnchorPoint = Vector2.new(0.5, 0.5), -- 좌상단 기준 스케일링
					BackgroundTransparency = 1,
					Image = "rbxassetid://108648957028585",
					ImageTransparency = entranceAlpha,
					Position = function()
						return UDim2.new(0, entranceSlide(), 0, 0)
					end,
					Size = UDim2.fromScale(1, 0.38),
					Visible = isAccepted,

					MouseEnter = function()
						isHovered(true)
					end,
					MouseLeave = function()
						isHovered(false)
					end,

					-- 좌상단(0, 0) 기준 스케일
					create("UIScale")({
						Name = "CardScale",
						Scale = function()
							return entranceScale() * hoverScale()
						end,
					}),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
						AspectRatio = 3.28375,
					}),

					-- 퀘스트 카드 테두리 (호버 시 발광)
					create("UIStroke")({
						Name = "CardStroke",
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = hoverStrokeColor,
						Thickness = hoverStrokeThickness,
						Transparency = function()
							return math.max(entranceAlpha(), hoverStrokeTransparency())
						end,
					}),

					create("UICorner")({
						Name = "CardCorner",
						CornerRadius = UDim.new(0, 8),
					}),

					-- 테마 태그
					create("TextLabel")({
						Name = "Theme",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.0501823, 0.144756),
						Size = UDim2.fromScale(0.20, 0.232207),
						Text = "EVENT",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextTransparency = entranceAlpha,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							Transparency = entranceAlpha,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)),
								ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
							}),
							Rotation = 90,
						}),
					}),

					-- 퀘스트 제목 (EVENT와 겹치지 않게 여백 배치)
					create("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.280, 0.135084),
						Size = UDim2.fromScale(0.66, 0.232207),
						Text = "벚꽃 수집가",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextTransparency = entranceAlpha,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							Transparency = entranceAlpha,
						}),
					}),

					-- 퀘스트 설명 및 진행도 (부드럽게 롤링되는 숫자)
					create("TextLabel")({
						Name = "Description",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.0549613, 0.373248),
						Size = UDim2.fromScale(0.876041, 0.241573),
						Text = descText,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextTransparency = entranceAlpha,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							Transparency = entranceAlpha,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(216, 216, 216)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(216, 216, 216)),
							}),
						}),
					}),

					-- 진행도 프로그레스 바
					create("Folder")({
						Name = "ProgessBar",

						create("Frame")({
							Name = "barDeco",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Position = UDim2.fromScale(0.496465, 0.776035),
							Size = UDim2.fromScale(0.878371, -0.126087),
							ZIndex = 10,

							create("UIListLayout")({
								Name = "UIListLayout",
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0.15, 0),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							create("ImageLabel")({
								Name = "SeparateLine",
								BackgroundTransparency = 1.02,
								Image = "rbxassetid://96127352288701",
								ImageTransparency = entranceAlpha,
								Position = UDim2.fromScale(0.0102451, 0),
								Size = UDim2.fromScale(0.005, 1),

								create("UIGradient")({
									Name = "UIGradient",
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
									}),
								}),
							}),

							create("ImageLabel")({
								Name = "SeparateLine",
								BackgroundTransparency = 1.02,
								Image = "rbxassetid://96127352288701",
								ImageTransparency = entranceAlpha,
								Position = UDim2.fromScale(0.0102451, 0),
								Size = UDim2.fromScale(0.005, 1),

								create("UIGradient")({
									Name = "UIGradient",
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
									}),
								}),
							}),

							create("ImageLabel")({
								Name = "SeparateLine",
								BackgroundTransparency = 1.02,
								Image = "rbxassetid://96127352288701",
								ImageTransparency = entranceAlpha,
								Position = UDim2.fromScale(0.0102451, 0),
								Size = UDim2.fromScale(0.005, 1),

								create("UIGradient")({
									Name = "UIGradient",
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
									}),
								}),
							}),

							create("ImageLabel")({
								Name = "SeparateLine",
								BackgroundTransparency = 1.02,
								Image = "rbxassetid://96127352288701",
								ImageTransparency = entranceAlpha,
								Position = UDim2.fromScale(0.0102451, 0),
								Size = UDim2.fromScale(0.005, 1),

								create("UIGradient")({
									Name = "UIGradient",
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
									}),
								}),
							}),

							create("ImageLabel")({
								Name = "SeparateLine",
								BackgroundTransparency = 1.02,
								Image = "rbxassetid://96127352288701",
								ImageTransparency = entranceAlpha,
								Position = UDim2.fromScale(0.0102451, 0),
								Size = UDim2.fromScale(0.005, 1),

								create("UIGradient")({
									Name = "UIGradient",
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
									}),
								}),
							}),

							create("ImageLabel")({
								Name = "SeparateLine",
								BackgroundTransparency = 1.02,
								Image = "rbxassetid://96127352288701",
								ImageTransparency = entranceAlpha,
								Position = UDim2.fromScale(0.0102451, 0),
								Size = UDim2.fromScale(0.005, 1),

								create("UIGradient")({
									Name = "UIGradient",
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
									}),
								}),
							}),
						}),

						create("ImageLabel")({
							Name = "barBG",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = "rbxassetid://123614945790793",
							ImageTransparency = entranceAlpha,
							Position = UDim2.fromScale(0.496465, 0.776035),
							Size = UDim2.fromScale(0.877999, -0.126578),
						}),

						-- 왼쪽 기준점(AnchorPoint 0, 0.5)으로 왼쪽에서부터 오른쪽으로 차오름
						create("ImageLabel")({
							Name = "barFill",
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundTransparency = 1,
							Image = "rbxassetid://87566142417575",
							ImageTransparency = entranceAlpha,
							Position = UDim2.fromScale(0.061, 0.776035),
							Size = function()
								local r = math.clamp(animatedRatio(), 0, 1)
								return UDim2.fromScale(0.870005 * r, -0.0840578)
							end,
							ZIndex = 2,

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(132, 255, 123)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 255, 34)),
								}),
							}),
						}),
					}),
				}),
			}),
		}),
	})
end

function QuestUI.Init()
	DataClient = ServiceRegistry:GetService("DataClient")
	DialogueClient = ServiceRegistry:GetService("DialogueClient")
	UIController = ServiceRegistry:GetService("UIController")
end

function QuestUI.Start()
	if DataClient then
		DataClient.FetchQuests()
	end
end

return QuestUI
