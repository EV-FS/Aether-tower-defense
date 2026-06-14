local Players = game:GetService("Players")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local BASE_VIEWPORT_WIDTH = 1920

local UIOffsetScaler = {}

local screenStrokes = {}
local activeBillboards = {}

local resolutionScale = 1

local function UpdateResolutionScale()
	local sizeX = camera.ViewportSize.X
	resolutionScale = if sizeX and sizeX > 0 then sizeX / BASE_VIEWPORT_WIDTH else 1
end

local function applyStrokeScale(stroke: UIStroke, sizeScale: number?)
	if not stroke:IsDescendantOf(game) then
		return
	end

	local originalThickness = stroke:GetAttribute("OriginalThickness")
	if not originalThickness then
		originalThickness = stroke.Thickness
		stroke:SetAttribute("OriginalThickness", originalThickness)
	end

	local targetThickness = originalThickness * resolutionScale * (sizeScale or 1)

	if targetThickness < 0.5 then
		stroke.Enabled = false
	else
		stroke.Enabled = true
		stroke.Thickness = math.max(1, targetThickness)
	end
end

local function ProcessNewStroke(stroke: Instance)
	if not stroke:IsA("UIStroke") then
		return
	end

	task.defer(function()
		if not stroke:IsDescendantOf(game) then
			return
		end

		if stroke.StrokeSizingMode ~= Enum.StrokeSizingMode.ScaledSize then
			screenStrokes[stroke] = true
			applyStrokeScale(stroke)
		end
	end)
end

local function applyBillboardScale(billboard: BillboardGui)
	if not billboard:IsDescendantOf(game) then
		return
	end

	local originalSize = billboard:GetAttribute("OriginalSize")
	if not originalSize then
		originalSize = billboard.Size
		billboard:SetAttribute("OriginalSize", originalSize)
	end
	billboard.Size = UDim2.new(
		originalSize.X.Scale,
		originalSize.X.Offset * resolutionScale,
		originalSize.Y.Scale,
		originalSize.Y.Offset * resolutionScale
	)
end

local function ProcessNewBillboard(billboard: Instance)
	if not billboard:IsA("BillboardGui") then
		return
	end

	task.defer(function()
		if not billboard:IsDescendantOf(game) then
			return
		end

		applyBillboardScale(billboard)
		activeBillboards[billboard] = true
	end)
end

local function ProcessDescendant(descendant: Instance)
	if descendant:IsA("UIStroke") then
		ProcessNewStroke(descendant)
	elseif descendant:IsA("BillboardGui") then
		ProcessNewBillboard(descendant)
	end
end

function UIOffsetScaler.Init()
	UpdateResolutionScale()

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		UpdateResolutionScale()

		for stroke in pairs(screenStrokes) do
			if stroke:IsDescendantOf(game) then
				applyStrokeScale(stroke)
			else
				screenStrokes[stroke] = nil
			end
		end

		for billboard in pairs(activeBillboards) do
			if billboard:IsDescendantOf(game) then
				applyBillboardScale(billboard)
			else
				activeBillboards[billboard] = nil
			end
		end
	end)

	playerGui.DescendantAdded:Connect(ProcessDescendant)

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		ProcessDescendant(descendant)
	end
end

return UIOffsetScaler
