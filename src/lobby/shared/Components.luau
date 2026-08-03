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
