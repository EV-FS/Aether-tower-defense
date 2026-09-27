local SceneTransform = {}

local POSITION_TOLERANCE = 0.025
local AXIS_DOT_TOLERANCE = 0.99999

local function move(instance: Instance, transform: CFrame)
	if instance:IsA("PVInstance") then
		instance:PivotTo(transform * instance:GetPivot())
		return
	end
	for _, child in instance:GetChildren() do
		move(child, transform)
	end
end

-- Apply one world-space transform while the complete clone is still off-world.
-- A folder can contain several unrelated models, so moving only its camera or
-- a single model pivot would change the authored staging.
function SceneTransform.Apply(scene: Instance, transform: CFrame?): number
	if transform == nil then
		return 0
	end
	assert(typeof(transform) == "CFrame", "SceneTransform must be a CFrame")
	for _, component in { transform:GetComponents() } do
		assert(component == component and math.abs(component) < math.huge, "SceneTransform must be finite")
	end
	local originalParts = {}
	local originalModels = {}
	local partCount = 0
	local function capture(instance: Instance)
		if instance:IsA("BasePart") then
			originalParts[instance] = instance.CFrame
			partCount += 1
		elseif instance:IsA("Model") then
			originalModels[instance] = instance:GetPivot()
		end
	end
	capture(scene)
	for _, descendant in scene:GetDescendants() do
		capture(descendant)
	end
	assert(partCount > 0, `Scene "{scene.Name}" has no BaseParts to place`)

	move(scene, transform)

	local function matches(actual: CFrame, expected: CFrame): boolean
		return (actual.Position - expected.Position).Magnitude <= POSITION_TOLERANCE
			and actual.RightVector:Dot(expected.RightVector) >= AXIS_DOT_TOLERANCE
			and actual.UpVector:Dot(expected.UpVector) >= AXIS_DOT_TOLERANCE
	end
	for part, original in originalParts do
		assert(matches(part.CFrame, transform * original),
			`Scene placement changed the position of "{part:GetFullName()}"`)
	end
	for model, original in originalModels do
		assert(matches(model:GetPivot(), transform * original),
			`Scene placement changed the pivot of "{model:GetFullName()}"`)
	end
	return partCount
end

return SceneTransform
