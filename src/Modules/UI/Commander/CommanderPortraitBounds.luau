-- // VARIABLES // --
local CommanderPortraitBounds = {}

-- // FUNCTIONS // --
--[[ Adds the visible extent of a selected body region to the portrait. ]]
local function appendCorners(points: { Vector3 }, part: BasePart, bottom: number, top: number)
	local halfSize = part.Size * 0.5
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			table.insert(points, part.CFrame:PointToWorldSpace(Vector3.new(halfSize.X * x, bottom, halfSize.Z * z)))
			table.insert(points, part.CFrame:PointToWorldSpace(Vector3.new(halfSize.X * x, top, halfSize.Z * z)))
		end
	end
end

--[[ Selects the face, headwear, and upper chest without framing the full body. ]]
function CommanderPortraitBounds.GetPoints(model: Model, torsoFraction: number): { Vector3 }?
	local descendants = model:GetDescendants()
	local bodyParts: { [string]: BasePart } = {}
	for _, descendant in descendants do
		if descendant:IsA("BasePart")
			and not descendant:FindFirstAncestorWhichIsA("Accessory")
			and not descendant:FindFirstAncestorWhichIsA("Tool")
		then
			bodyParts[descendant.Name] = descendant
		end
	end
	local head = bodyParts.Head
	if not head then
		return nil
	end
	local points = {}
	local framedParts = { [head] = true }
	appendCorners(points, head, -head.Size.Y * 0.5, head.Size.Y * 0.5)
	local torso = bodyParts.UpperTorso or bodyParts.Torso
	if torso then
		framedParts[torso] = true
		local top = torso.Size.Y * 0.5
		appendCorners(points, torso, top - torso.Size.Y * math.clamp(torsoFraction, 0.1, 1), top)
	end
	for _, name in { "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" } do
		local arm = bodyParts[name]
		if arm then
			framedParts[arm] = true
			local top = arm.Size.Y * 0.5
			appendCorners(points, arm, top - arm.Size.Y * math.clamp(torsoFraction, 0.1, 1), top)
		end
	end
	for _, descendant in descendants do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			local part = if descendant.Part0 == head then descendant.Part1
				elseif descendant.Part1 == head then descendant.Part0 else nil
			if part and not framedParts[part] and part.Transparency < 1 then
				framedParts[part] = true
				appendCorners(points, part, -part.Size.Y * 0.5, part.Size.Y * 0.5)
			end
		end
	end
	return points
end

-- // INITIALIZATION // --
return CommanderPortraitBounds
