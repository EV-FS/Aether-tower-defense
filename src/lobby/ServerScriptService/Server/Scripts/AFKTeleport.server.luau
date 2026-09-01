local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Settings.Game.AFKSettings)

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
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ ReturnPlaceId = Config.LobbyPlaceId })

	local success, err = pcall(function()
		TeleportService:TeleportAsync(Config.AFKPlaceId, { player }, options)
	end)
	if success then
		return
	end

	warn(`[AFK] Teleport attempt {state.Attempts} failed for {player.Name}: {err}`)
	queueRetry(player, state)
end

requestEvent.OnServerEvent:Connect(function(player: Player)
	if RunService:IsStudio() or pending[player] then
		return
	end

	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < Config.RequestCooldown then
		return
	end

	lastRequest[player] = now
	pending[player] = { Attempts = 0, RetryQueued = false }
	attemptTeleport(player)
end)

TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
	local state = pending[player]
	if not state then
		return
	end

	warn(`[AFK] Teleport initialization failed for {player.Name}: {result.Name} ({errorMessage})`)
	queueRetry(player, state)
end)

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
	lastRequest[player] = nil
end)
