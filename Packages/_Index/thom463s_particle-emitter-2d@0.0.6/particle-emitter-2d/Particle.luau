const Types = require("./Types")
const RANDOM = Random.new()

const function resolveNumber(input: NumberSequence | NumberRange | number)
	if typeof(input) == "NumberSequence" then
		const keypoint = input.Keypoints[1]
		return keypoint.Value
		
	elseif typeof(input) == "NumberRange" then
		return RANDOM:NextNumber(input.Min, input.Max)
		
	elseif typeof(input) == "number" then
		return input
	end
	
	return 0
end

const function resolveColor(input: ColorSequence | Color3)
	if typeof(input) == "ColorSequence" then
		const keypoint = input.Keypoints[1]
		return keypoint.Value
		
	elseif typeof(input) == "Color3" then
		return input
	end
	
	return Color3.new()
end

const function evalColorSequence(sequence: ColorSequence, t: number)
	if t <= 0 then
		return sequence.Keypoints[1].Value
	elseif t >= 1 then
		return sequence.Keypoints[#sequence.Keypoints].Value
	end
	
	for i = 1, #sequence.Keypoints - 1 do
		const thisKeypoint = sequence.Keypoints[i]
		const nextKeypoint = sequence.Keypoints[i + 1]
		if t >= thisKeypoint.Time and t < nextKeypoint.Time then
			const alpha = (t - thisKeypoint.Time) / (nextKeypoint.Time - thisKeypoint.Time)
			return Color3.new(
				(nextKeypoint.Value.R - thisKeypoint.Value.R) * alpha + thisKeypoint.Value.R,
				(nextKeypoint.Value.G - thisKeypoint.Value.G) * alpha + thisKeypoint.Value.G,
				(nextKeypoint.Value.B - thisKeypoint.Value.B) * alpha + thisKeypoint.Value.B
			)
		end
	end
	
	return sequence.Keypoints[#sequence.Keypoints].Value
end

const function evalNumberSequence(sequence: NumberSequence, t: number)
	if t <= 0 then
		return sequence.Keypoints[1].Value
	elseif t >= 1 then
		return sequence.Keypoints[#sequence.Keypoints].Value
	end
	
	for i = 1, #sequence.Keypoints - 1 do
		const currKeypoint = sequence.Keypoints[i]
		const nextKeypoint = sequence.Keypoints[i + 1]
		if t >= currKeypoint.Time and t < nextKeypoint.Time then
			const alpha = (t - currKeypoint.Time) / (nextKeypoint.Time - currKeypoint.Time)
			return currKeypoint.Value + (nextKeypoint.Value - currKeypoint.Value) * alpha
		end
	end
	
	return sequence.Keypoints[#sequence.Keypoints].Value
end

const function mapNumberSequence(sequence: NumberSequence)
	const keypoints = {}
	for _, keypoint in ipairs(sequence.Keypoints) do
		if keypoint.Envelope > 0 then
			const offset = RANDOM:NextNumber(-keypoint.Envelope, keypoint.Envelope)
			const new = NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value + offset)
			table.insert(keypoints, new)
			
			continue
		end
		
		table.insert(keypoints, keypoint)
	end
	
	return NumberSequence.new(keypoints)
end

const function evalDirection(direction: Types.EmissionDirection)
	return if direction == "Top" then -Vector2.yAxis
		elseif direction == "Bottom" then Vector2.yAxis
		elseif direction == "Left" then -Vector2.xAxis
		elseif direction == "Right" then Vector2.xAxis
		else Vector2.zero
end

const function setupParticle(self: Types.Particle)
	const particleEmitter = self._particleEmitter
	
	if typeof(self.Size) == "NumberSequence" then
		self.Size = mapNumberSequence(particleEmitter.Size)
	end
	
	if typeof(self.Transparency) == "NumberSequence" then
		self.Transparency = mapNumberSequence(particleEmitter.Transparency)
	end
	
	const root = particleEmitter.Parent
	const scale = resolveNumber(self.Size)
	const color = resolveColor(self.Color)
	const transparency = resolveNumber(self.Transparency)
	
	const position = UDim2.fromOffset(
		RANDOM:NextNumber(0, root.AbsoluteSize.X),
		RANDOM:NextNumber(0, root.AbsoluteSize.Y)
	)

	const label = Instance.new("ImageLabel")
	label.Name = "Particle"
	label.AnchorPoint = Vector2.one / 2
	label.BackgroundTransparency = 1
	label.Position = position
	label.Rotation = self.Rotation
	label.Size = UDim2.fromOffset(scale, scale)
	label.ZIndex = self.ZOffset
	label.Image = self.Texture
	label.ImageTransparency = transparency
	label.ImageColor3 = color
	label.Parent = particleEmitter.Parent

	const ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Name = "Ratio"
	ratio.AspectRatio = self.AspectRatio
	ratio.Parent = label

	self._position = Vector2.new(position.X.Offset, position.Y.Offset)
	self._label = label
end

const function updatePosition(self: Types.Particle, dt: number): ()
	const base = evalDirection(self.EmissionDirection)
	const theta = math.rad(self.SpreadAngle)

	const direction = Vector2.new(
		base.X * math.cos(theta) - base.Y * math.sin(theta),
		base.X * math.sin(theta) + base.Y * math.cos(theta)
	)

	self._currentAcceleration += self.Acceleration * dt

	if self.Drag > 0 then
		const decay = 0.5 ^ (dt / (1 / self.Drag))
		self._currentSpeed *= decay
	end

	self._position += (direction * self._currentSpeed * dt) + (self._currentAcceleration * dt)
end

const function updateVisual(self: Types.Particle, dt: number): ()
	local alpha = math.min(1, self._elapsed / self.Lifetime)
	local transparency = self.Transparency
	local color = self.Color
	local size = self.Size
	
	if typeof(self.Color) == "ColorSequence" then
		color = evalColorSequence(self.Color, alpha)
	end

	if typeof(self.Size) == "NumberSequence" then
		size = evalNumberSequence(self.Size, alpha)
	end

	if typeof(self.Transparency) == "NumberSequence" then
		transparency = evalNumberSequence(self.Transparency, alpha)
	end

	self._label.Size = UDim2.fromOffset(size, size)
	self._label.Position = UDim2.fromOffset(self._position.X, self._position.Y)
	self._label.ImageTransparency = transparency
	self._label.ImageColor3 = color
	self._label.Rotation += self.RotSpeed * dt
end

const Particle = {}
Particle.__index = Particle

function Particle.new(particleEmitter: Types.ParticleEmitter): Types.Particle
	const self: Types.Particle = {}
	setmetatable(self, Particle)
	
	self.Color = particleEmitter.Color
	self.Size = particleEmitter.Size
	self.Texture = particleEmitter.Texture
	self.Transparency = particleEmitter.Transparency
	self.ZOffset = resolveNumber(particleEmitter.ZOffset)
	
	self.EmissionDirection = particleEmitter.EmissionDirection
	self.Lifetime = resolveNumber(particleEmitter.Lifetime)
	self.Rotation = resolveNumber(particleEmitter.Rotation)
	self.RotSpeed = resolveNumber(particleEmitter.RotSpeed)
	self.Speed = resolveNumber(particleEmitter.Speed)
	
	self.SpreadAngle = RANDOM:NextNumber(
		-particleEmitter.SpreadAngle,
		particleEmitter.SpreadAngle
	)
	
	self.Shape = particleEmitter.Shape
	self.ShapeInOut = particleEmitter.ShapeInOut
	self.ShapeStyle = particleEmitter.ShapeStyle
	
	self.Acceleration = particleEmitter.Acceleration
	self.AspectRatio = particleEmitter.AspectRatio
	self.TimeScale = particleEmitter.TimeScale
	self.Drag = particleEmitter.Drag
	
	self._currentAcceleration = Vector2.zero
	self._particleEmitter = particleEmitter
	self._currentSpeed = self.Speed
	self._position = nil
	self._elapsed = 0
	self._label = nil
	
	setupParticle(self)
	
	return self
end

function Particle.Update(self: Types.Particle, dt: number): ()
	dt *= self.TimeScale
	self._elapsed += dt
	
	updatePosition(self, dt)
	updateVisual(self, dt)
end

function Particle.Destroy(self: Types.Particle): ()
	self._label:Destroy()
	
	table.clear(self)
	setmetatable(self, nil)
end

return Particle
