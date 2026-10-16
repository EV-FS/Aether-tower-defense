-- Server-owned character auras. Only one template can be active at a time.
local RunService = game:GetService("RunService")
local templates = game:GetService("ServerStorage"):WaitForChild("ETDCharacterAuraTemplates")
local Aura = {}
Aura.GroupId = 486359985
Aura.SpecialUserId = 1265587248 -- qoqo778q (immutable account ID)
local ROOT_TAG = "ETDCharacterAuraRoot"
local rotating = setmetatable({}, { __mode = "k" })

function Aura.Select(userId, rank)
	if userId == Aura.SpecialUserId then
		return "qoqo778q"
	end
	if rank == 255 then
		return "Owner"
	end
	if rank == 200 or rank == 220 then
		return "Dev"
	end
	return nil
end

function Aura.Clear(character)
	for _, node in ipairs(character:GetDescendants()) do
		if node:GetAttribute(ROOT_TAG) then
			for _, descendant in ipairs(node:GetDescendants()) do
				rotating[descendant] = nil
			end
			rotating[node] = nil
			node:Destroy()
		end
	end
	character:SetAttribute("ETDActiveAura", nil)
end

function Aura.Apply(character, auraName)
	Aura.Clear(character)
	if not auraName then
		return true
	end
	local template = templates:FindFirstChild(auraName)
	if not template then
		return false, "Missing aura template: " .. auraName
	end
	for _, host in ipairs(template:GetChildren()) do
		local target = character:FindFirstChild(host.Name)
		if not target or not target:IsA("BasePart") then
			return false, "Missing character body part: " .. host.Name
		end
	end
	-- Clone the complete template together so Beam/Trail attachment references survive.
	local copy = template:Clone()
	for _, host in ipairs(copy:GetChildren()) do
		local target = character:FindFirstChild(host.Name)
		local roots = host:GetChildren()
		local parts = {}
		for _, node in ipairs(host:GetDescendants()) do
			if node:IsA("BasePart") then
				parts[node] = host.CFrame:ToObjectSpace(node.CFrame)
			end
		end
		for part, offset in pairs(parts) do
			part.CFrame = target.CFrame * offset
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Name = "ETDAuraWeld"
			weld.Part0 = target
			weld.Part1 = part
			weld.Parent = part
		end
		for _, root in ipairs(roots) do
			root:SetAttribute(ROOT_TAG, true)
			root.Parent = target
			if root:GetAttribute("ETDAuraSpin") then
				rotating[root] = true
			end
			for _, node in ipairs(root:GetDescendants()) do
				if node:GetAttribute("ETDAuraSpin") then
					rotating[node] = true
				end
			end
		end
	end
	copy:Destroy()
	character:SetAttribute("ETDActiveAura", auraName)
	return true
end

RunService.Heartbeat:Connect(function(dt)
	for attachment in pairs(rotating) do
		if attachment:IsDescendantOf(workspace) then
			attachment.CFrame *= CFrame.Angles(0, math.rad(25) * dt, 0)
		else
			rotating[attachment] = nil
		end
	end
end)
return Aura
