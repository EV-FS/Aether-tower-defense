--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local ObjectCache = require(ReplicatedStorage.Packages.ObjectCache)

--/Folder
local Caches = workspace:WaitForChild("Caches")

--/Templates
local IndicatorPartTemplate =
	ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Visuals"):WaitForChild("IndicatorPart")
local SplashTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Visuals"):WaitForChild("Splash")

local CONSTANTS = {
	STORAGE_SIZE = 100,
	GROUND_OFFSET = 0.05,

	LINE_WIDTH = 0.2,

	CYLINDER_COLOR = Color3.fromRGB(255, 255, 255),
	CYLINDER_TRANSPARENCY = 0,

	BEAM_TEXTURE = "rbxassetid://118670921452598",
	BEAM_COLOR = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
	BEAM_WIDTH = 6,
	BEAM_TRANSPARENCY = NumberSequence.new(0.5),
	BEAM_LIGHT_EMISSION = 1,
	BEAM_TEXTURE_LENGTH = 5,
	BEAM_TEXTURE_SPEED = 2,

	CURVE_TANGENT_ANGLE = math.rad(30),
	CURVE_DISTANCE_RATIO = 0.3,
}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function projectToGround(pos: Vector3 | CFrame): CFrame
	if typeof(pos) == "Vector3" then
		return CFrame.new(pos + Vector3.new(0, CONSTANTS.GROUND_OFFSET, 0))
	else
		return pos + Vector3.new(0, CONSTANTS.GROUND_OFFSET, 0)
	end
end

local function getCorrectedWidthLength(radius: number, halfWidth: number): number
	return math.sqrt(math.max(0, radius ^ 2 - halfWidth ^ 2))
end

local function getAngleCFrames(center: CFrame, radius: number, angle: number): (CFrame, CFrame)
	local angleOffset = math.rad(angle / 2)
	local left = center * CFrame.Angles(0, -angleOffset, 0) * CFrame.new(0, 0, -radius / 2)
	local right = center * CFrame.Angles(0, angleOffset, 0) * CFrame.new(0, 0, -radius / 2)
	return left, right
end

local function getWidthCFrames(center: CFrame, halfWidth: number, correctedLength: number): (CFrame, CFrame)
	local left = center * CFrame.new(-halfWidth, 0, -correctedLength / 2)
	local right = center * CFrame.new(halfWidth, 0, -correctedLength / 2)
	return left, right
end

local function setPartVisible(part: BasePart, visible: boolean)
	part.Transparency = visible and IndicatorPartTemplate.Transparency or 1

	local surfaceGui = part:FindFirstChildOfClass("SurfaceGui")
	if surfaceGui then
		surfaceGui.Enabled = visible
	end
end

local function updateBezierBeam(
	beam: Beam,
	att0: Attachment,
	att1: Attachment,
	towerPos: Vector3,
	targetPos: Vector3,
	dist: number
)
	if dist > 0.1 then
		att0.WorldCFrame = CFrame.lookAt(towerPos, targetPos)
			* CFrame.Angles(0, 0, math.rad(90))
			* CFrame.Angles(0, CONSTANTS.CURVE_TANGENT_ANGLE, 0)
		att1.WorldCFrame = CFrame.lookAt(targetPos, towerPos)
			* CFrame.Angles(0, 0, math.rad(-90))
			* CFrame.Angles(0, -CONSTANTS.CURVE_TANGENT_ANGLE, 0)

		beam.CurveSize0 = dist * CONSTANTS.CURVE_DISTANCE_RATIO
		beam.CurveSize1 = dist * CONSTANTS.CURVE_DISTANCE_RATIO
	else
		att0.WorldPosition = towerPos
		att1.WorldPosition = targetPos
		beam.CurveSize0 = 0
		beam.CurveSize1 = 0
	end
end

-------------------------------------------------
--// CreateRangeIndicator
-------------------------------------------------
local CreateRangeIndicator = {}
CreateRangeIndicator.__index = CreateRangeIndicator

local activeRanges = {}
local PartStorage
local currentStorageSize = CONSTANTS.STORAGE_SIZE

function CreateRangeIndicator.newRange(
	radius: number?,
	centerPosition: Vector3 | CFrame,
	towerStats: { [string]: any }?,
	towerCenterPosition: Vector3?
)
	if typeof(radius) ~= "number" or radius <= 0 then
		return nil
	end

	if not PartStorage then
		CreateRangeIndicator.Init()
	end

	local projectedCenter = projectToGround(centerPosition)

	local segmentLength = IndicatorPartTemplate.Size.X * 2
	local circumference = 2 * math.pi * radius
	local numberOfParts = math.max(1, math.floor(circumference / segmentLength))
	local angleStep = 360 / numberOfParts

	local totalActiveParts = 0
	for _, rangeData in pairs(activeRanges) do
		totalActiveParts += #rangeData.Parts
	end

	if numberOfParts + totalActiveParts > currentStorageSize then
		local amountToExpand = (numberOfParts + totalActiveParts) - currentStorageSize
		PartStorage:ExpandCache(amountToExpand)
		currentStorageSize = totalActiveParts + numberOfParts
	end

	local self = setmetatable({}, CreateRangeIndicator)
	self.Parts = {}
	self.BoundaryParts = {}
	self.CenterPosition = projectedCenter
	self.Radius = radius
	self.TowerStats = towerStats
	self.LastSplashPosition = nil
	self.SplashCylinder = nil
	self.SplashAttachment0 = nil
	self.SplashAttachment1 = nil
	self.SplashBeam = nil

	for i = 1, numberOfParts do
		local angle = math.rad(i * angleStep)
		local partCFrame = CFrame.new(projectedCenter.Position) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)

		local newPart = PartStorage:GetPart(partCFrame)
		newPart.Anchored = true
		newPart.CanCollide = false
		newPart.CanQuery = false
		newPart.CanTouch = false
		setPartVisible(newPart, true)

		table.insert(self.Parts, newPart)
	end

	if towerStats then
		local visualsFolder = workspace:FindFirstChild("Visuals") or Instance.new("Folder")
		if not visualsFolder.Parent then
			visualsFolder.Name = "Visuals"
			visualsFolder.Parent = workspace
		end

		local function spawnBoundaryPart(cframe: CFrame, size: Vector3)
			local newPart = IndicatorPartTemplate:Clone()
			newPart.Size = size
			newPart.CFrame = cframe
			newPart.Anchored = true
			newPart.CanCollide = false
			newPart.CanQuery = false
			newPart.CanTouch = false
			newPart.Parent = visualsFolder
			table.insert(self.BoundaryParts, newPart)
		end

		local lineHeight = IndicatorPartTemplate.Size.Y

		if towerStats.Angle and towerStats.Angle > 0 then
			local size = Vector3.new(CONSTANTS.LINE_WIDTH, lineHeight, radius)
			local leftCF, rightCF = getAngleCFrames(projectedCenter, radius, towerStats.Angle)
			spawnBoundaryPart(leftCF, size)
			spawnBoundaryPart(rightCF, size)
		elseif towerStats.Width and towerStats.Width > 0 then
			local halfWidth = towerStats.Width / 2
			local correctedLength = getCorrectedWidthLength(radius, halfWidth)
			local size = Vector3.new(CONSTANTS.LINE_WIDTH, lineHeight, correctedLength)

			local leftCF, rightCF = getWidthCFrames(projectedCenter, halfWidth, correctedLength)
			spawnBoundaryPart(leftCF, size)
			spawnBoundaryPart(rightCF, size)
		end

		if towerStats.SplashRange and towerStats.SplashRange > 0 then
			local splashRange = towerStats.SplashRange

			local cylinder = SplashTemplate:Clone()
			cylinder.Name = "SplashCylinder"
			cylinder.Size = Vector3.new(0.05, splashRange * 2, splashRange * 2)
			cylinder.Transparency = 1
			cylinder.Anchored = true
			cylinder.CanCollide = false
			cylinder.CanQuery = false
			cylinder.CanTouch = false

			local surfaceGui = cylinder:FindFirstChildOfClass("SurfaceGui")
			if surfaceGui then
				surfaceGui.Enabled = true
				local imageLabel = surfaceGui:FindFirstChildOfClass("ImageLabel")
				if imageLabel then
					imageLabel.ImageColor3 = CONSTANTS.CYLINDER_COLOR
					imageLabel.ImageTransparency = CONSTANTS.CYLINDER_TRANSPARENCY
					local uiStroke = imageLabel:FindFirstChildOfClass("UIStroke")
					if uiStroke then
						uiStroke.Color = CONSTANTS.CYLINDER_COLOR
						uiStroke.Transparency = CONSTANTS.CYLINDER_TRANSPARENCY
					end
				end
			end

			cylinder.CFrame = projectedCenter * CFrame.Angles(0, 0, math.rad(90))
			cylinder.Parent = visualsFolder
			self.SplashCylinder = cylinder

			local att0 = Instance.new("Attachment")
			att0.Name = "SplashBeamAtt0"
			att0.WorldPosition = towerCenterPosition or (projectedCenter.Position + Vector3.new(0, 2, 0))
			att0.Parent = workspace.Terrain
			self.SplashAttachment0 = att0

			local att1 = Instance.new("Attachment")
			att1.Name = "SplashBeamAtt1"
			att1.Parent = cylinder
			self.SplashAttachment1 = att1

			local beam = Instance.new("Beam")
			beam.Name = "SplashBeam"
			beam.Segments = 30
			beam.Attachment0 = att0
			beam.Attachment1 = att1
			beam.Color = CONSTANTS.BEAM_COLOR
			beam.Width0 = CONSTANTS.BEAM_WIDTH
			beam.Width1 = CONSTANTS.BEAM_WIDTH
			beam.FaceCamera = false
			beam.Transparency = CONSTANTS.BEAM_TRANSPARENCY
			beam.Brightness = 3
			beam.LightEmission = CONSTANTS.BEAM_LIGHT_EMISSION
			beam.LightInfluence = 0
			beam.Texture = CONSTANTS.BEAM_TEXTURE
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = CONSTANTS.BEAM_TEXTURE_LENGTH
			beam.TextureSpeed = CONSTANTS.BEAM_TEXTURE_SPEED
			beam.Enabled = true
			beam.Parent = cylinder
			self.SplashBeam = beam
		end
	end

	if
		towerStats
		and towerStats.Secondary
		and typeof(towerStats.Secondary) == "table"
		and towerStats.Secondary.Range
	then
		self.SecondaryIndicator = CreateRangeIndicator.newRange(
			towerStats.Secondary.Range,
			centerPosition,
			towerStats.Secondary,
			towerCenterPosition
		)
		if self.SecondaryIndicator then
			self.SecondaryIndicator:SetColor(Color3.fromRGB(0, 170, 255))
		end
	end

	table.insert(activeRanges, self)
	return self
end

function CreateRangeIndicator:Destroy()
	if self.SecondaryIndicator then
		self.SecondaryIndicator:Destroy()
		self.SecondaryIndicator = nil
	end

	for _, part in ipairs(self.Parts) do
		setPartVisible(part, false)
		PartStorage:ReturnPart(part)
	end
	self.Parts = {}

	if self.BoundaryParts then
		for _, part in ipairs(self.BoundaryParts) do
			part:Destroy()
		end
		self.BoundaryParts = {}
	end

	if self.SplashCylinder then
		self.SplashCylinder:Destroy()
		self.SplashCylinder = nil
	end

	if self.SplashAttachment0 then
		self.SplashAttachment0:Destroy()
		self.SplashAttachment0 = nil
	end

	local index = table.find(activeRanges, self)
	if index then
		table.remove(activeRanges, index)
	end
end

function CreateRangeIndicator:UpdateRange(
	newCenterPosition: Vector3 | CFrame,
	targetPosition: Vector3?,
	towerCenterPosition: Vector3?
)
	if self.SecondaryIndicator then
		self.SecondaryIndicator:UpdateRange(newCenterPosition, targetPosition, towerCenterPosition)
	end

	local projectedCenter = projectToGround(newCenterPosition)
	self.CenterPosition = projectedCenter

	local radius = self.Radius
	local numberOfParts = #self.Parts
	local angleStep = 360 / numberOfParts

	local unrotatedCenter = CFrame.new(projectedCenter.Position)
	for i, part in ipairs(self.Parts) do
		local angle = math.rad(i * angleStep)
		part.CFrame = unrotatedCenter * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
	end

	local towerStats = self.TowerStats
	if towerStats and self.BoundaryParts and #self.BoundaryParts > 0 then
		local lineHeight = IndicatorPartTemplate.Size.Y

		if towerStats.Angle and towerStats.Angle > 0 then
			local size = Vector3.new(CONSTANTS.LINE_WIDTH, lineHeight, radius)
			local leftCF, rightCF = getAngleCFrames(projectedCenter, radius, towerStats.Angle)

			if self.BoundaryParts[1] then
				self.BoundaryParts[1].Size = size
				self.BoundaryParts[1].CFrame = leftCF
			end
			if self.BoundaryParts[2] then
				self.BoundaryParts[2].Size = size
				self.BoundaryParts[2].CFrame = rightCF
			end
		elseif towerStats.Width and towerStats.Width > 0 then
			local halfWidth = towerStats.Width / 2
			local correctedLength = getCorrectedWidthLength(radius, halfWidth)
			local size = Vector3.new(CONSTANTS.LINE_WIDTH, lineHeight, correctedLength)
			local leftCF, rightCF = getWidthCFrames(projectedCenter, halfWidth, correctedLength)

			if self.BoundaryParts[1] then
				self.BoundaryParts[1].Size = size
				self.BoundaryParts[1].CFrame = leftCF
			end
			if self.BoundaryParts[2] then
				self.BoundaryParts[2].Size = size
				self.BoundaryParts[2].CFrame = rightCF
			end
		end
	end

	if self.SplashCylinder then
		local groundY = projectedCenter.Position.Y
		local finalTargetPos: Vector3

		if targetPosition then
			finalTargetPos = Vector3.new(targetPosition.X, groundY, targetPosition.Z)
			self.LastSplashPosition = finalTargetPos
		else
			finalTargetPos = self.LastSplashPosition or projectedCenter.Position
		end

		self.SplashCylinder.CFrame = CFrame.new(finalTargetPos) * CFrame.Angles(0, 0, math.rad(90))

		if self.SplashAttachment0 and self.SplashAttachment1 then
			local towerPos = towerCenterPosition or (projectedCenter.Position + Vector3.new(0, 2, 0))
			local dist = (finalTargetPos - towerPos).Magnitude
			updateBezierBeam(
				self.SplashBeam,
				self.SplashAttachment0,
				self.SplashAttachment1,
				towerPos,
				finalTargetPos,
				dist
			)
		end
	end
end

function CreateRangeIndicator:SetColor(color: Color3)
	for _, part in ipairs(self.Parts) do
		part.SurfaceGui.Frame.BackgroundColor3 = color
	end
	if self.BoundaryParts then
		for _, part in ipairs(self.BoundaryParts) do
			part.SurfaceGui.Frame.BackgroundColor3 = color
		end
	end
	if self.SplashCylinder then
		local surfaceGui = self.SplashCylinder:FindFirstChildOfClass("SurfaceGui")
		if surfaceGui then
			local imageLabel = surfaceGui:FindFirstChildOfClass("ImageLabel")
			if imageLabel then
				imageLabel.ImageColor3 = color
				local uiStroke = imageLabel:FindFirstChildOfClass("UIStroke")
				if uiStroke then
					uiStroke.Color = color
				end
			end
		end
	end

	if self.SecondaryIndicator then
		local secondaryColor = color
		if color == Color3.new(1, 1, 1) then
			secondaryColor = Color3.fromRGB(0, 170, 255)
		elseif color == Color3.new(0, 1, 0) or color == Color3.fromRGB(0, 255, 0) then
			secondaryColor = Color3.fromRGB(0, 200, 100)
		end
		self.SecondaryIndicator:SetColor(secondaryColor)
	end
end

function CreateRangeIndicator.clearAllRanges()
	for _, rangeData in pairs(activeRanges) do
		rangeData:Destroy()
	end
	table.clear(activeRanges)
end

function CreateRangeIndicator.Init()
	PartStorage = ObjectCache.new(IndicatorPartTemplate, CONSTANTS.STORAGE_SIZE, Caches)
end

return CreateRangeIndicator
