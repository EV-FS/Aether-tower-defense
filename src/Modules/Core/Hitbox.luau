--/Service
local RunService = game:GetService("RunService")

--/Types
export type Hitbox = {
	new: () -> newHitbox,
	Find: (self: newHitbox) -> nil,
	Start: (self: newHitbox, lifeTime: number?) -> nil,
	Stop: (self: newHitbox) -> nil,
}

export type newHitbox = {
	Size: Vector3,
	CFrame: BasePart | CFrame,
	Offset: CFrame,
	Visible: boolean,
	Humanoids: { Humanoid },
	Box: BasePart?,
	Connection: RBXScriptConnection?,
	IsInActor: boolean,
	onTouch: (humanoid: Humanoid) -> (),

	Start: (lifeTime: number?) -> nil,
	Stop: () -> nil,
}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function CFrameConverter(input: CFrame | BasePart): CFrame
	if typeof(input) == "CFrame" then
		return input
	else
		return input.CFrame
	end
end

-------------------------------------------------
--// Hitbox
-------------------------------------------------
local Hitbox = {} :: Hitbox
Hitbox.__index = Hitbox

function Hitbox.new(): newHitbox
	local self = setmetatable({}, Hitbox)
	self.Size = Vector3.new(0, 0, 0)
	self.CFrame = CFrame.new(0, 0, 0)
	self.Offset = CFrame.new(0, 0, 0)
	self.Visible = true

	self.Humanoids = {}
	self.Box = nil
	self.Connection = nil
	self.IsInActor = false

	self.OverlapParams = OverlapParams.new()
	self.OverlapParams.FilterType = Enum.RaycastFilterType.Exclude
	self.OverlapParams.FilterDescendantsInstances = {}

	self.onTouch = function(humanoid: Humanoid)
		print(humanoid)
	end

	return self
end

function Hitbox:Visual()
	if not self.Visible then
		return
	end

	if not self.Box then
		local box = Instance.new("Part")
		box.Name = "HitboxVisual"
		box.Anchored = true
		box.CastShadow = false
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.Material = Enum.Material.Neon
		box.Color = Color3.new(1, 0, 0)
		box.Transparency = 0.5
		box.Parent = workspace
		self.Box = box
	end

	self.Box.Size = self.Size
	self.Box.CFrame = CFrameConverter(self.CFrame) * self.Offset
end

function Hitbox:Find()
	if self.IsInActor then
		task.desynchronize()
	end

	local touchingHumanoids = {}

	local queryCFrame = CFrameConverter(self.CFrame) * self.Offset
	local touchingParts = workspace:GetPartBoundsInBox(queryCFrame, self.Size, self.OverlapParams)
	for _, part in pairs(touchingParts) do
		local enemy = part.Parent
		if not enemy then
			continue
		end

		local humanoid = enemy:FindFirstChildOfClass("Humanoid")

		if humanoid and not table.find(self.Humanoids, humanoid) then
			if self.IsInActor then
				table.insert(touchingHumanoids, humanoid)
			else
				table.insert(self.Humanoids, humanoid)
				self.onTouch(humanoid)
			end
		end
	end

	if self.IsInActor then
		task.synchronize()

		if not self.Connection then
			return
		end

		for _, humanoid in pairs(touchingHumanoids) do
			if table.find(self.Humanoids, humanoid) then
				continue
			end

			table.insert(self.Humanoids, humanoid)
			self.onTouch(humanoid)
		end
	end
end

function Hitbox:Start(lifeTime: number?)
	local passedTime = 0

	if script:GetActor() then
		self.IsInActor = true
	end

	self.Connection = RunService.Heartbeat:Connect(function(dt)
		self:Find()
		self:Visual()

		if not lifeTime then
			return
		end

		passedTime += dt
		if passedTime >= lifeTime then
			self:Stop()
		end
	end)
end

function Hitbox:Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end

	if self.Box then
		self.Box:Destroy()
		self.Connection = nil
	end

	self.onTouch = nil
	setmetatable(self, nil)

	self.Humanoids = {}
end

return Hitbox
