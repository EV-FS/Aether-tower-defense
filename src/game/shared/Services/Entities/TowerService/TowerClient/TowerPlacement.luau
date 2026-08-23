--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)
local MouseRayCast = require(ReplicatedStorage.Shared.Modules.Utils.MouseRayCast)
local CreateRangeIndicator = require(ReplicatedStorage.Shared.Services.Entities.TowerService.Utils.CreateRangeIndicator)
local PlaceValidator = require(ReplicatedStorage.Shared.Services.Entities.TowerService.Utils.PlaceValidator)
local AnimationService

local currentRotation = 0
local GROUND_VISUAL_OFFSET = 0.05

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function ToggleExistingBorders(isVisible)
	local placedBordersFolder = workspace.Visuals:FindFirstChild("Borders")

	if placedBordersFolder then
		for _, border in ipairs(placedBordersFolder:GetChildren()) do
			if border:FindFirstChild("SurfaceGui") then
				border.SurfaceGui.Enabled = isVisible
			end
		end
	end
end

-------------------------------------------------
--// TowerPlacement
-------------------------------------------------
local TowerPlacement = {}
TowerPlacement.__index = TowerPlacement

function TowerPlacement.Init(services, getTowerCountFunc: (towerName: string) -> number)
	AnimationService = services:GetService("AnimationService")
	TowerPlacement.GetCountTower = getTowerCountFunc
end

function TowerPlacement.new(towerName: string, towerKey: string?)
	local self = setmetatable({}, TowerPlacement)

	self.TowerName = towerName
	self.TowerKey = towerKey
	self.Config = TowerData.ByName[towerName]
	self.Stats = self.Config.Stats[0]
	self.Model = nil
	self.Rotation = currentRotation
	self.RangeIndicator = nil
	self.IsActive = false
	self.HeightOffset = 0
	self.LastTargetPosition = nil

	return self
end

function TowerPlacement:Start()
	local asset = ReplicatedStorage.Assets.Towers:FindFirstChild(self.TowerName)
	if not asset then
		warn(`{self.TowerName}을 가진 모델이 존재하지 않음.`)
		return
	end

	self.Model = asset:Clone()
	self.Model.Parent = workspace.CurrentCamera
	CharacterUtils.SetCollisionGroup(self.Model, "Tower", function(part)
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end)

	AnimationService.Load(self.Model, self.TowerName)
	AnimationService.Play(self.Model, "Idle", 0, 0)

	self.IsActive = true

	self.BorderRadius = self.Model.PrimaryPart.Size.X * 1.5
	self.HeightOffset = CharacterUtils.GetHipHeight(self.Model)

	self:_CreateVisuals()

	ToggleExistingBorders(true)
end

function TowerPlacement:Update()
	if not self.IsActive or not self.Model then
		return
	end

	local result = MouseRayCast(true)
	if not result or not result.Position then
		return
	end

	local targetPos = result.Position
	self.LastTargetPosition = targetPos

	local finalCFrame = CFrame.new(targetPos + Vector3.new(0, self.HeightOffset, 0))
		* CFrame.Angles(0, math.rad(self.Rotation), 0)

	self.Model:PivotTo(finalCFrame)

	if self.Border then
		self.Border.Position = targetPos + Vector3.new(0, GROUND_VISUAL_OFFSET, 0)
	end
	if self.RangeIndicator then
		self.RangeIndicator:UpdateRange(
			self.Model:GetPivot() - Vector3.new(0, self.HeightOffset, 0),
			nil,
			self.Model:GetPivot().Position
		)
	end

	self:_CheckValidation(targetPos)
end

function TowerPlacement:Rotate()
	if not self.IsActive then
		return
	end
	local rotateAngle = (self.Rotation + 90) % 360

	self.Rotation = rotateAngle
	currentRotation = rotateAngle
end

function TowerPlacement:Destroy()
	self.IsActive = false

	if self.Model then
		self.Model:Destroy()
	end
	if self.Border then
		self.Border:Destroy()
	end
	if self.RangeIndicator then
		self.RangeIndicator:Destroy()
	end

	self.Model = nil
	self.Highlight = nil
	self.Border = nil
	self.RangeIndicator = nil

	ToggleExistingBorders(false)
end

function TowerPlacement:GetPlacementData()
	if not self.Model then
		return nil
	end

	local result = MouseRayCast(true)
	local spawnPosition = if result and result.Position then result.Position else self.LastTargetPosition

	if not spawnPosition then
		return nil
	end

	return {
		TowerName = self.TowerName,
		Position = spawnPosition,
		Rotation = self.Rotation,
		BorderRadius = self.Model.PrimaryPart.Size.X * 1.5,
	}
end

function TowerPlacement:_CreateVisuals()
	self.Highlight = Instance.new("Highlight")
	self.Highlight.Parent = self.Model

	self.Border = ReplicatedStorage.Assets.Visuals.Border:Clone()
	self.Border.Size = Vector3.new(0.001, self.BorderRadius * 2, self.BorderRadius * 2)
	self.Border.Position = Vector3.new(0, GROUND_VISUAL_OFFSET, 0)
	self.Border.Parent = workspace.Visuals.Borders

	self.RangeIndicator = CreateRangeIndicator.newRange(
		self.Stats.Range,
		self.Model:GetPivot() - Vector3.new(0, self.HeightOffset, 0),
		self.Stats,
		self.Model:GetPivot().Position
	)
end

function TowerPlacement:_CheckValidation(targetPos)
	local checkData = {
		["TowerName"] = self.TowerName,
		["SpawnPosition"] = targetPos,
		["BorderRadius"] = self.BorderRadius,
		["CurrentCount"] = TowerPlacement.GetCountTower(self.TowerName),
	}

	local canSpawn = PlaceValidator.CheckSpawn(checkData, true)

	local mainColor = canSpawn and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
	local subColor = canSpawn and Color3.new(1, 1, 1) or Color3.new(1, 0.2, 0.2)

	if self.Highlight then
		self.Highlight.FillColor = mainColor
	end
	if self.Border then
		self.Border.SurfaceGui.ImageLabel.ImageColor3 = subColor
		self.Border.SurfaceGui.ImageLabel.UIStroke.Color = subColor
	end

	if self.RangeIndicator then
		self.RangeIndicator:SetColor(subColor)
	end
end

return TowerPlacement
