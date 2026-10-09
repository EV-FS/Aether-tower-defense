local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Settings.Game.AFKSettings)
local DataService = require(ServerScriptService.Server.Services.DataService)

local function getOrCreateRequestEvent(): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild("RequestAFKTeleport")
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local event = Instance.new("RemoteEvent")
	event.Name = "RequestAFKTeleport"
	event.Parent = ReplicatedStorage
	return event
end

local requestEvent = getOrCreateRequestEvent()

type TeleportState = {
	Attempts: number,
	RetryQueued: boolean,
}

local pending: { [Player]: TeleportState } = {}
local lastRequest: { [Player]: number } = {}

local attemptTeleport: (Player) -> ()

local function queueRetry(player: Player, state: TeleportState)
	if pending[player] ~= state or state.RetryQueued then
		return
	end

	if state.Attempts >= Config.TeleportRetryCount then
		pending[player] = nil
		return
	end

	state.RetryQueued = true
	task.delay(Config.TeleportRetryDelay, function()
		if pending[player] ~= state then
			return
		end

		state.RetryQueued = false
		attemptTeleport(player)
	end)
end

attemptTeleport = function(player: Player)
	local state = pending[player]
	if not state or not player:IsDescendantOf(Players) then
		pending[player] = nil
		return
	end

	state.Attempts += 1
	local playerData = DataService:GetData(player)
	if not playerData or DataService:IsLocked(player) then
		pending[player] = nil
		return
	end
	DataService:SaveData(player)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		ReturnPlaceId = Config.LobbyPlaceId,
		HandoffVersion = 1,
		CoinsSnapshot = if playerData then playerData.Coins else nil,
		GemsSnapshot = if playerData then playerData.Gems else nil,
	})

	local success, err = pcall(function()
		TeleportService:TeleportAsync(Config.AFKPlaceId, { player }, options)
	end)
	if success then
		return
	end

	warn(`[AFK] Teleport attempt {state.Attempts} failed for {player.Name}: {err}`)
	queueRetry(player, state)
end

local function requestTeleport(player: Player)
	if pending[player] or DataService:IsLocked(player) then
		return
	end

	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < Config.RequestCooldown then
		return
	end

	lastRequest[player] = now
	if RunService:IsStudio() then
		warn(`[AFK] {player.Name}: AFK 이동 요청 확인. 실제 이동은 게시된 게임에서 가능합니다.`)
		return
	end
	pending[player] = { Attempts = 0, RetryQueued = false }
	attemptTeleport(player)
end

requestEvent.OnServerEvent:Connect(requestTeleport)

-- Resolve the exact map target when triggered, including prompts under Attachments.
-- This also supports the part/prompt being inserted after this script starts.
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
	local folder = workspace:FindFirstChild("ProximityPrompts")
	local part = folder and folder:FindFirstChild("Part")
	if not part or not part:IsA("BasePart") or not prompt:IsDescendantOf(part) or not prompt.Enabled then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end

	local parent = prompt.Parent
	local position = if parent and parent:IsA("Attachment") then parent.WorldPosition
		elseif parent and parent:IsA("BasePart") then parent.Position else part.Position
	if (root.Position - position).Magnitude > prompt.MaxActivationDistance + 3 then
		return
	end
	requestTeleport(player)
end)

TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage, placeId)
	local state = pending[player]
	if not state or placeId ~= Config.AFKPlaceId then
		return
	end

	warn(`[AFK] Teleport initialization failed for {player.Name}: {result.Name} ({errorMessage})`)
	queueRetry(player, state)
end)

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
	lastRequest[player] = nil
end)
