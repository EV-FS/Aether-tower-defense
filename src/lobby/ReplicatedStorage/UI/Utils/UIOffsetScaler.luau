local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BASE_VIEWPORT_WIDTH = 1920

local UIOffsetScaler = {}

local initialized = false
local playerGui
local camera
local connections: { RBXScriptConnection } = {}
local cameraConnection
local screenStrokes = setmetatable({}, { __mode = "k" })
local activeBillboards = setmetatable({}, { __mode = "k" })
local resolutionScale = 1

local function addConnection(connection: RBXScriptConnection)
	connections[#connections + 1] = connection
end

local function updateResolutionScale()
	if not camera then
		resolutionScale = 1
		return
	end

	local viewportWidth = camera.ViewportSize.X
	resolutionScale = if viewportWidth > 0 then viewportWidth / BASE_VIEWPORT_WIDTH else 1
end

local function applyStrokeScale(stroke: UIStroke, sizeScale: number?)
	if not stroke:IsDescendantOf(game) then
		return
	end

	local originalThickness = stroke:GetAttribute("OriginalThickness") :: number?
	if originalThickness == nil then
		originalThickness = stroke.Thickness
		stroke:SetAttribute("OriginalThickness", originalThickness)
	end

	local targetThickness = originalThickness * resolutionScale * (sizeScale or 1)
	stroke.Enabled = targetThickness >= 0.5
	if stroke.Enabled then
		stroke.Thickness = math.max(1, targetThickness)
	end
end

local function applyBillboardScale(billboard: BillboardGui)
	if not billboard:IsDescendantOf(game) then
		return
	end

	local originalSize = billboard:GetAttribute("OriginalSize") :: UDim2?
	if originalSize == nil then
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

local function refreshTrackedElements()
	for stroke in pairs(screenStrokes) do
		applyStrokeScale(stroke)
	end

	for billboard in pairs(activeBillboards) do
		applyBillboardScale(billboard)
	end
end

local function processStroke(stroke: UIStroke)
	task.defer(function()
		if not initialized or not stroke:IsDescendantOf(game) then
			return
		end

		if stroke.StrokeSizingMode == Enum.StrokeSizingMode.ScaledSize then
			return
		end

		screenStrokes[stroke] = true
		applyStrokeScale(stroke)
	end)
end

local function processBillboard(billboard: BillboardGui)
	task.defer(function()
		if not initialized or not billboard:IsDescendantOf(game) then
			return
		end

		activeBillboards[billboard] = true
		applyBillboardScale(billboard)
	end)
end

local function processDescendant(descendant: Instance)
	if descendant:IsA("UIStroke") then
		processStroke(descendant)
	elseif descendant:IsA("BillboardGui") then
		processBillboard(descendant)
	end
end

local function observeCamera(nextCamera: Camera?)
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	camera = nextCamera
	updateResolutionScale()
	refreshTrackedElements()

	if not camera then
		return
	end

	cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		updateResolutionScale()
		refreshTrackedElements()
	end)
end

function UIOffsetScaler.Init()
	if initialized then
		return
	end

	initialized = true
	playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	addConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		observeCamera(Workspace.CurrentCamera)
	end))
	observeCamera(Workspace.CurrentCamera)

	addConnection(playerGui.DescendantAdded:Connect(processDescendant))
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		processDescendant(descendant)
	end
end

function UIOffsetScaler.Destroy()
	if not initialized then
		return
	end

	initialized = false
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	camera = nil
	playerGui = nil

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(screenStrokes)
	table.clear(activeBillboards)
end

return UIOffsetScaler
