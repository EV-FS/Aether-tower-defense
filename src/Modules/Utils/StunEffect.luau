local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)

local StunEffect = {}

function StunEffect.Update(target)
	local effect = target.StunEffect
	local model = target.Model
	local rootPart = model.PrimaryPart
	if not effect or not rootPart then
		return
	end

	local head = model:FindFirstChild("Head")
	local targetCFrame
	if head and head:IsA("BasePart") then
		targetCFrame = CFrame.new(head.Position + Vector3.new(0, head.Size.Y, 0))
	else
		targetCFrame = rootPart.CFrame + Vector3.new(0, CharacterUtils.GetHipHeight(model), 0)
	end

	if effect:IsA("Model") then
		effect:PivotTo(targetCFrame)
	elseif effect:IsA("BasePart") then
		effect.CFrame = targetCFrame
	end
end

function StunEffect.Attach(target)
	if target.StunEffect then
		return
	end

	local model = target.Model
	local rootPart = model.PrimaryPart
	local asset = ReplicatedStorage.Assets.Visuals:FindFirstChild("Stun")
	if not rootPart or not asset then
		return
	end

	local effect = asset:Clone()
	local function setupPart(part)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
	if effect:IsA("BasePart") then
		setupPart(effect)
	end
	for _, part in ipairs(effect:GetDescendants()) do
		if part:IsA("BasePart") then
			setupPart(part)
		end
	end

	local head = model:FindFirstChild("Head")
	local scale = if head and head:IsA("BasePart") then head.Size.Y else rootPart.Size.Y / 2
	if effect:IsA("Model") then
		effect:ScaleTo(scale)
	elseif effect:IsA("BasePart") then
		effect.Size *= scale
	end

	target.StunEffect = effect
	StunEffect.Update(target)
	effect.Parent = workspace:FindFirstChild("Visuals") or workspace
end

function StunEffect.Remove(target)
	if target.StunEffect then
		target.StunEffect:Destroy()
		target.StunEffect = nil
	end
end

return StunEffect
