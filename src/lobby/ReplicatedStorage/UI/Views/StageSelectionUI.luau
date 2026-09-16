local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local MapData = require(ReplicatedStorage.Settings.Data.MapData)
local Config = require(ReplicatedStorage.Settings.Game.PartySettings)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local StageButton = require(script.Parent.Parent.Components.StageButton)

local create = Vide.create
local source = Vide.source
local selectedMap = source("")
local selectedDifficulty = source(Config.DefaultDifficulty)
local party = source(nil)
local busy = source(false)
local status = source("")
local enteredCode = source("")
local partyIcon = source(nil :: any)
local PartyController
local UIController

local VIEW_ID = "StageSelection"
local ERROR_MESSAGES = {
	NOT_LEADER = "Only the party leader can do that.",
	PARTY_FULL = "This party is full.",
	PARTY_NOT_FOUND = "That party no longer exists.",
	ALREADY_IN_PARTY = "Leave your current party first.",
	PARTY_BUSY = "The party is already starting. Please wait.",
	RATE_LIMITED = "Please wait a moment and try again.",
	MAP_UNAVAILABLE = "This map and difficulty are not ready to play.",
	STUDIO_TELEPORT_UNAVAILABLE = "Play in the published experience to teleport.",
	DESTINATION_NOT_CONFIGURED = "The game destination is not configured.",
	RESERVATION_FAILED = "Could not create the match. Try again.",
	TELEPORT_FAILED = "Teleport failed. Retry to join the same match.",
	TELEPORT_PARTIAL = "Some members left the lobby. Retry to join the same match.",
	TELEPORT_TIMEOUT = "Teleport timed out. Retry to join the same match.",
	NETWORK_ERROR = "Could not reach the server. Try again.",
	REQUEST_TIMEOUT = "The request timed out. Check party status and try again.",
	NOT_READY = "The party service is loading. Try again shortly.",
}

local function canEdit(): boolean
	local current = party()
	return not busy()
		and (current == nil or (current.LeaderUserId == Players.LocalPlayer.UserId and current.State == "Open"))
end

local function perform(callback: () -> any)
	if busy() then
		return
	end
	busy(true)
	status("")
	callback()
		:andThen(function(result)
			if not result.Success then
				status(ERROR_MESSAGES[result.Code] or `Could not complete the request ({result.Code}).`)
			end
		end)
		:finally(function()
			busy(false)
		end)
end

local function chooseSettings(mapName: string, difficulty: string)
	if not canEdit() then
		return
	end
	local current = party()
	if current and (current.Settings.Map ~= mapName or current.Settings.Difficulty ~= difficulty) then
		perform(function()
			return PartyController:UpdateSettings({ Map = mapName, Difficulty = difficulty })
		end)
	else
		selectedMap(mapName)
		selectedDifficulty(difficulty)
	end
end

local function difficultyAt(index: number): string?
	local definition = MapData[selectedMap()]
	return definition and definition.Difficulties[index]
end

local function chooseDifficulty(index: number)
	local difficulty = difficultyAt(index)
	if difficulty then
		chooseSettings(selectedMap(), difficulty)
	end
end

local function canStart(): boolean
	local current = party()
	return not busy()
		and selectedMap() ~= ""
		and (
			current == nil
			or (
				current.LeaderUserId == Players.LocalPlayer.UserId
				and (current.State == "Open" or current.State == "Retryable")
			)
		)
end

local StageSelection = {}

local function renderPartyPanel()
	return create("Frame")({
		Name = "Party",
		BackgroundColor3 = Color3.fromRGB(22, 24, 34),
		BackgroundTransparency = 0.12,
		Position = UDim2.fromScale(0.035, 0.22),
		Size = UDim2.fromScale(0.4, 0.55),
		create("UICorner")({ CornerRadius = UDim.new(0, 12) }),
		create("TextLabel")({
			Name = "PartyStatus",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.05, 0.03),
			Size = UDim2.fromScale(0.9, 0.12),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Text = function()
				local current = party()
				if not current then
					return "CREATE OR JOIN A PARTY"
				end
				return `PARTY {#current.Members}/{current.MaxMembers} - {string.upper(current.State)}`
			end,
		}),
		create("TextLabel")({
			Name = "Members",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.05, 0.18),
			Size = UDim2.fromScale(0.9, 0.32),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = function()
				local current = party()
				if not current then
					return "Choose a map and difficulty.\nShare your party code with friends in this lobby."
				end
				local names = {}
				for _, member in current.Members do
					table.insert(
						names,
						(if member.UserId == current.LeaderUserId then "[LEADER] " else "") .. member.DisplayName
					)
				end
				return table.concat(names, "\n")
			end,
		}),
		create("TextBox")({
			Name = "PartyCode",
			BackgroundColor3 = Color3.fromRGB(38, 41, 56),
			Position = UDim2.fromScale(0.05, 0.54),
			Size = UDim2.fromScale(0.9, 0.11),
			ClearTextOnFocus = false,
			PlaceholderText = "Paste a party code to join",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextEditable = function()
				return party() == nil and not busy()
			end,
			Text = function()
				return if party() then party().Id else enteredCode()
			end,
			Vide.changed("Text", function(value)
				if not party() then
					enteredCode(string.sub(value, 1, 64))
				end
			end),
		}),
		create("TextButton")({
			Name = "CreateOrLeave",
			BackgroundColor3 = Color3.fromRGB(62, 128, 88),
			Position = UDim2.fromScale(0.05, 0.7),
			Size = UDim2.fromScale(0.43, 0.12),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Text = function()
				return if party() then "LEAVE" else "CREATE"
			end,
			Interactable = function()
				local current = party()
				return not busy()
					and (
						if current then current.State == "Open" or current.State == "Retryable" else selectedMap() ~= ""
					)
			end,
			Activated = function()
				if not party() and selectedMap() == "" then
					return
				end
				perform(function()
					return if party()
						then PartyController:LeaveParty()
						else PartyController:CreateParty({ Map = selectedMap(), Difficulty = selectedDifficulty() })
				end)
			end,
		}),
		create("TextButton")({
			Name = "Join",
			BackgroundColor3 = Color3.fromRGB(66, 94, 164),
			Position = UDim2.fromScale(0.52, 0.7),
			Size = UDim2.fromScale(0.43, 0.12),
			Text = "JOIN",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Visible = function()
				return party() == nil
			end,
			Interactable = function()
				return not busy() and enteredCode() ~= ""
			end,
			Activated = function()
				perform(function()
					local code = string.match(enteredCode(), "^%s*(.-)%s*$") or ""
					return PartyController:JoinParty(code)
				end)
			end,
		}),
		create("TextLabel")({
			Name = "Result",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.05, 0.85),
			Size = UDim2.fromScale(0.9, 0.12),
			Text = status,
			TextColor3 = Color3.fromRGB(255, 208, 136),
			TextScaled = true,
			TextWrapped = true,
		}),
	})
end

function StageSelection.RenderUI()
	local cameraAnchor = source(nil :: BasePart?)
	local function findCameraAnchor()
		local cams = workspace:FindFirstChild("Cams")
		local anchor = cams and cams:FindFirstChild("StageCamera")
		if anchor and anchor:IsA("BasePart") then
			cameraAnchor(anchor)
		end
	end

	-- Persistent models can arrive after this UI mounts or opens.
	local anchorConnection = workspace.DescendantAdded:Connect(function(instance)
		if instance.Name == "Cams" or instance.Name == "StageCamera" then
			findCameraAnchor()
		end
	end)
	findCameraAnchor()
	Vide.cleanup(function()
		anchorConnection:Disconnect()
	end)

	Vide.effect(function()
		if not UIController:IsOpen(VIEW_ID) then
			return
		end

		local camera = workspace.CurrentCamera
		local stageCamera = cameraAnchor()
		if not camera or not stageCamera then
			return
		end

		local previousType = camera.CameraType
		local previousCFrame = camera.CFrame
		local function updateCamera()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = stageCamera.CFrame
		end

		updateCamera()
		RunService:BindToRenderStep("StageSelectionCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
		-- The effect cleans up on close, switching views, and UI unmount.
		Vide.cleanup(function()
			RunService:UnbindFromRenderStep("StageSelectionCamera")
			if camera.Parent then
				camera.CFrame = previousCFrame
				camera.CameraType = previousType
			end
		end)
	end)

	local partyConnection = PartyController:ObserveParty(function(snapshot, event)
		local previous = party()
		party(snapshot)
		if snapshot then
			-- Keep browsing the map list through unrelated member updates.
			if
				not previous
				or previous.Id ~= snapshot.Id
				or previous.Settings.Map ~= snapshot.Settings.Map
				or previous.Settings.Difficulty ~= snapshot.Settings.Difficulty
				or previous.LeaderUserId ~= snapshot.LeaderUserId
				or snapshot.State ~= "Open"
			then
				selectedMap(snapshot.Settings.Map)
				selectedDifficulty(snapshot.Settings.Difficulty)
			end
			status(if snapshot.ErrorCode then ERROR_MESSAGES[snapshot.ErrorCode] or snapshot.ErrorCode else "")
		elseif event and event.Reason then
			selectedMap("")
			status(
				if event.Reason == "KICKED"
					then "You were removed from the party."
					elseif event.Reason == "MATCH_EXPIRED" then "The match retry window expired. Create a new party."
					elseif event.Kind == "Disbanded" then "The party was disbanded."
					else "You left the party."
			)
		end
	end)
	-- Signal connections reject unknown member lookups used by Vide's object cleanup.
	Vide.cleanup(function()
		partyConnection:Disconnect()
	end)
	Vide.effect(function()
		local icon = partyIcon()
		if not icon then
			return
		end
		if UIController:IsOpen(VIEW_ID) and not icon.isSelected then
			icon:select()
		elseif not UIController:IsOpen(VIEW_ID) and icon.isSelected then
			icon:deselect()
		end
	end)

	local stages = {}

	for mapName, stage in MapData do
		table.insert(
			stages,
			StageButton({
				MapId = mapName,
				MapName = stage.MapName or mapName,
				MapImage = stage.MapImage,
				LayoutOrder = stage.LayoutOrder or 1,
				Interactable = canEdit,
				Activated = function()
					if not canEdit() then
						return
					end
					if selectedMap() == mapName then
						-- Deselecting opens the list locally; the server keeps its valid settings.
						selectedMap("")
						return
					end
					local difficulty = if table.find(stage.Difficulties, selectedDifficulty())
						then selectedDifficulty()
						else stage.Difficulties[1]
					chooseSettings(mapName, difficulty)
				end,
				SelectedMap = selectedMap,
			})
		)
	end

	return create("Frame")({
		Name = "StageSelection",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = UIController:IsVisible(VIEW_ID),
		ZIndex = 15,
		renderPartyPanel(),
		create("TextButton")({
			Name = "Close",
			Position = UDim2.fromScale(0.035, 0.12),
			Size = UDim2.fromScale(0.1, 0.06),
			BackgroundColor3 = Color3.fromRGB(38, 41, 56),
			Text = "CLOSE",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Activated = StageSelection.Close,
		}),

		create("ImageLabel")({
			Name = "Shadow",
			BackgroundTransparency = 1,
			Image = "rbxassetid://129755483688657",
			Position = UDim2.fromScale(0.499804, 0),
			Size = UDim2.fromScale(0.500196, 1),

			create("ScrollingFrame")({
				Name = "ScrollingFrame",
				Active = true,
				BackgroundTransparency = 1,
				ScrollBarImageColor3 = Color3.new(),
				ScrollBarThickness = 0,
				Size = UDim2.fromScale(1, 0.84375),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),

				create("UIListLayout")({
					Name = "UIListLayout",
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0.01, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				create("UIPadding")({
					Name = "UIPadding",
					PaddingRight = UDim.new(0.02, 0),
					PaddingTop = UDim.new(0.01, 0),
				}),

				create("Frame")({
					Name = "DifficultySelection",
					LayoutOrder = 10000,
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.523439, 0.196455),
					Size = UDim2.fromScale(0.47656, 0.3),
					Visible = function()
						return if selectedMap() ~= "" then true else false
					end,

					create("ImageLabel")({
						Name = "ImageLabel",
						BackgroundTransparency = 1,
						Image = "rbxassetid://112900056820081",
						Position = UDim2.fromScale(0, -1.3063e-07),
						Size = UDim2.fromScale(1, 0.298003),

						create("TextLabel")({
							Name = "MapName",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.0210168, 0),
							Size = UDim2.fromScale(0.47478, 0.525728),
							Text = function()
								local definition = MapData[selectedMap()]
								return if definition then definition.MapName or selectedMap() else selectedMap()
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
					}),

					create("ImageButton")({
						Name = "Difficulty1",
						Visible = function()
							return difficultyAt(1) ~= nil
						end,
						Interactable = canEdit,
						Activated = function()
							chooseDifficulty(1)
						end,
						ImageTransparency = function()
							return if selectedDifficulty() == difficultyAt(1) then 0 else 0.5
						end,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://139274506988816",
						Position = UDim2.fromScale(0.5, 0.3),
						Size = UDim2.fromScale(1, 0.24),

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.329973, 0.217917),
							Size = UDim2.fromScale(0.335741, 0.562149),
							Text = function()
								return string.upper(difficultyAt(1) or "")
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 255, 0)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 238, 1)),
							}),
						}),

						create("UICorner")({
							Name = "UICorner",
						}),

						create("UIStroke")({
							Name = "UIStroke",
							Color = Color3.new(1, 1, 1),
						}),

						create("UIShadow")({
							Name = "UIShadow",
							BlurRadius = UDim.new(0, 20),
							Color = Color3.fromRGB(13, 255, 0),
							Transparency = 0.5,
						}),
					}),

					create("ImageButton")({
						Name = "Difficulty2",
						Visible = function()
							return difficultyAt(2) ~= nil
						end,
						Interactable = canEdit,
						Activated = function()
							chooseDifficulty(2)
						end,
						ImageTransparency = function()
							return if selectedDifficulty() == difficultyAt(2) then 0 else 0.5
						end,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://139274506988816",
						Position = UDim2.fromScale(0.5, 0.6),
						Size = UDim2.fromScale(1, 0.24),

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.266923, 0.201712),
							Size = UDim2.fromScale(0.462101, 0.562),
							Text = function()
								return string.upper(difficultyAt(2) or "")
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 190, 26)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 238, 1)),
							}),
						}),

						create("UICorner")({
							Name = "UICorner",
						}),

						create("UIStroke")({
							Name = "UIStroke",
							Color = Color3.new(1, 1, 1),
						}),

						create("UIShadow")({
							Name = "UIShadow",
							BlurRadius = UDim.new(0, 20),
							Color = Color3.fromRGB(255, 216, 23),
							Enabled = false,
							Transparency = 0.5,
						}),
					}),

					create("ImageButton")({
						Name = "Difficulty3",
						Visible = function()
							return difficultyAt(3) ~= nil
						end,
						Interactable = canEdit,
						Activated = function()
							chooseDifficulty(3)
						end,
						ImageTransparency = function()
							return if selectedDifficulty() == difficultyAt(3) then 0 else 0.5
						end,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://139274506988816",
						Position = UDim2.fromScale(0.5, 0.9),
						Size = UDim2.fromScale(1, 0.24),

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.283736, 0.201713),
							Size = UDim2.fromScale(0.428474, 0.562),
							Text = function()
								return string.upper(difficultyAt(3) or "")
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 2, 103)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 98, 213)),
							}),
						}),

						create("UICorner")({
							Name = "UICorner",
						}),

						create("UIStroke")({
							Name = "UIStroke",
							Color = Color3.new(1, 1, 1),
						}),

						create("UIShadow")({
							Name = "UIShadow",
							BlurRadius = UDim.new(0, 20),
							Color = Color3.fromRGB(255, 48, 165),
							Enabled = false,
							Transparency = 0.5,
						}),
					}),
				}),

				unpack(stages),
			}),

			create("ImageButton")({
				Name = "Play",
				Interactable = canStart,
				Activated = function()
					if not canStart() then
						return
					end
					perform(function()
						if party() then
							return PartyController:StartParty()
						end
						return PartyController:CreateParty({ Map = selectedMap(), Difficulty = selectedDifficulty() })
							:andThen(function(result)
								return if result.Success then PartyController:StartParty() else result
							end)
					end)
				end,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://139274506988816",
				Position = UDim2.fromScale(0.74496, 0.922163),
				Size = UDim2.fromScale(0.456107, 0.0966229),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.329973, 0.217917),
					Size = UDim2.fromScale(0.335741, 0.562149),
					Text = function()
						local current = party()
						if busy() or (current and (current.State == "Starting" or current.State == "Teleporting")) then
							return "WAIT"
						end
						if current and current.State == "Retryable" then
							return "RETRY"
						end
						return "PLAY"
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,

					create("UIStroke")({
						Name = "UIStroke",
					}),
				}),

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 255, 0)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 238, 1)),
					}),
				}),

				create("UICorner")({
					Name = "UICorner",
					BottomLeftRadius = UDim.new(0, 11),
					BottomRightRadius = UDim.new(0, 11),
					TopLeftRadius = UDim.new(0, 11),
					TopRightRadius = UDim.new(0, 11),
				}),

				create("UIStroke")({
					Name = "UIStroke",
					Color = Color3.new(1, 1, 1),
				}),

				create("UIShadow")({
					Name = "UIShadow",
					BlurRadius = UDim.new(0, 20),
					Color = Color3.fromRGB(13, 255, 0),
					Transparency = 0.5,
				}),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
					AspectRatio = 3.62,
				}),
			}),
		}),
	})
end

function StageSelection.Open()
	if UIController then
		UIController:Open(VIEW_ID)
		PartyController:GetParty()
	end
end

function StageSelection.Close()
	if UIController then
		UIController:Close(VIEW_ID)
	end
end

function StageSelection.BindTopbarIcon(icon: any)
	partyIcon(icon)
end

function StageSelection.Init()
	PartyController = ServiceRegistry:GetService("PartyController")
	UIController = ServiceRegistry:GetService("UIController")
end

function StageSelection.Start() end

return StageSelection
