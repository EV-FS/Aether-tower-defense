local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerViewport = require(script.Parent.TowerViewport)

local create = Vide.create
local mount = Vide.mount
local source = Vide.source
local spring = Vide.spring

return function(target: Instance)
	local container = Instance.new("Frame")
	container.Name = "TowerViewportStoryContainer"
	container.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = target

	local towerName = source("Wizard Noob")
	local rotated = source(false)

	local destroyVide = mount(function()
		local leftRotation = spring(function()
			return if rotated() then 45 else -20
		end, 0.6, 0.75)
		local rightRotation = spring(function()
			return if rotated() then -45 else 20
		end, 0.6, 0.75)

		return create("Frame")({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),

			TowerViewport({
				Name = "LeftTower",
				TowerName = towerName,
				AnimationName = "Idle",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.3, 0.45),
				Size = UDim2.fromScale(0.38, 0.65),
				ModelRotation = leftRotation,
			}),

			TowerViewport({
				Name = "RightTower",
				TowerName = towerName,
				AnimationName = "Idle",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.7, 0.45),
				Size = UDim2.fromScale(0.38, 0.65),
				ModelRotation = rightRotation,
			}),

			create("TextButton")({
				Name = "ToggleRotation",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(82, 120, 255),
				Position = UDim2.fromScale(0.5, 0.95),
				Size = UDim2.fromOffset(180, 42),
				Text = function()
					return if rotated() then "Rotate Back" else "Rotate Towers"
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 18,

				MouseButton1Click = function()
					rotated(not rotated())
				end,

				create("UICorner")({
					CornerRadius = UDim.new(0, 8),
				}),
			}),
		})
	end, container)

	return function()
		destroyVide()
		container:Destroy()
	end
end
