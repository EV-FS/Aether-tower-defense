local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

local tpOptions = Instance.new("TeleportOptions")
tpOptions.ShouldReserveServer = true

return {
	NPCRig = Matter.component("NPCRig", {
		Model = nil,
		HumanoidRootPart = nil,
		Head = nil,
		Neck = nil,
		BaseC0 = nil,
		RigType = Enum.HumanoidRigType.R6,
		LookRadius = 30,
	}),

	Leaf = Matter.component("Leaf", {
		LeafModel = nil,
	}),

	Rotator = Matter.component("Rotator", {
		TargetPart = nil,
		DegreePerSecond = 0,
		X = nil,
		Y = nil,
		Z = nil,
	}),

	Mover = Matter.component("Mover", {
		TargetPart = nil,
		StartPosition = Vector3.new(),
		EndPosition = Vector3.new(),
		Speed = 1, -- Units per second
		Progress = 0, -- 0 to 1
		Direction = 1, -- 1 for forward, -1 for backward
	}),

	TPArea = Matter.component("TPArea", {
		Model = nil,
		Cam = nil,
		TouchPart = nil,
		PlaceId = 0,
		PlayerLimit = 5,
		StartCount = 30,
		TeleportOptions = tpOptions,

		InPlayers = {},
		CurrentCount = 30,
		TimerAccumulator = 0,
	}),
}
