-- // VARIABLES // --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local DialogueData = require(ReplicatedStorage.Settings.Data.CommanderDialogueData)
local ChapterData = require(ReplicatedStorage.Settings.Data.CommanderChapterData)
local MapData = require(ReplicatedStorage.Settings.Data.MapData)
local MenuMotion = require(ReplicatedStorage.Shared.Modules.UI.MenuMotion)
local GameClient = require(script.Parent.GameClient)
local UIController = require(script.Parent.UIController)

type Message = { Id: string, Caption: string, Priority: number, Lines: { string } }
type Entry = { Message: Message, QueuedAt: number, Wave: number }

local CommanderBattleClient = {}
CommanderBattleClient.IsOpen = Vide.source(false)
CommanderBattleClient.Rig = Vide.source(nil :: Model?)
CommanderBattleClient.Text = Vide.source("")
CommanderBattleClient.VisibleGraphemes = Vide.source(0)
CommanderBattleClient.LineIndex = Vide.source(0)
CommanderBattleClient.Caption = Vide.source("")
CommanderBattleClient.ReadProgress = Vide.source(0)
CommanderBattleClient.AccentColor = Vide.source(DialogueData.Presentation.AccentColor)
CommanderBattleClient.HintText = "AUTO / TAP TO CONTINUE"

local ready = Vide.source(false)
local roundEnded = Vide.source(false)
local cutsceneActive = Vide.source(false)
local towerSelected = Vide.source(false)
local queue: { Entry } = {}
local seen: { [string]: boolean } = {}
local connections: { RBXScriptConnection } = {}
local current: Entry? = nil
local tickConnection: RBXScriptConnection? = nil
local loadThread: thread? = nil
local started = false
local generation = 0
local currentWave = 0
local characterCount = 0
local revealProgress = 0
local readElapsed = 0
local readDuration = 0
local hiddenElapsed = 0
local gapRemaining = 0
local update: (number) -> ()

-- // FUNCTIONS // --
--[[ Identifies the chapter selected by the match server. ]]
local function isSupportedMap(): boolean
	return ReplicatedStorage:GetAttribute("SelectedMap") == ChapterData.Map
end

--[[ Releases the active presentation between transmissions. ]]
local function finishCurrent()
	current = nil
	CommanderBattleClient.IsOpen(false)
	gapRemaining = MenuMotion.ExitDuration + 0.05
end

--[[ Prepares a passage for automatic reading and manual advancement. ]]
local function setLine(index: number)
	local entry = current
	if not entry then
		return
	end
	local text = entry.Message.Lines[index]
	characterCount = 0
	for _ in utf8.graphemes(text) do
		characterCount += 1
	end
	revealProgress = 0
	readElapsed = 0
	hiddenElapsed = 0
	readDuration = math.clamp(
		characterCount / ChapterData.ReadingCharactersPerSecond,
		ChapterData.MinimumReadTime,
		ChapterData.MaximumReadTime
	)
	CommanderBattleClient.ReadProgress(0)
	CommanderBattleClient.VisibleGraphemes(0)
	CommanderBattleClient.Text(text)
	CommanderBattleClient.LineIndex(index)
end

--[[ Starts timed presentation work only while messages need attention. ]]
local function ensureTicking()
	if not tickConnection and ready() then
		tickConnection = RunService.Heartbeat:Connect(update)
	end
end

--[[ Begins the next relevant transmission without retaining stale advice. ]]
local function startNext()
	local now = os.clock()
	for index = #queue, 1, -1 do
		local entry = queue[index]
		if now - entry.QueuedAt > ChapterData.QueueLifetime or currentWave - entry.Wave > ChapterData.MaxWaveLag then
			table.remove(queue, index)
		end
	end
	if not CommanderBattleClient.CanPresent() or #queue == 0 then
		return
	end
	current = table.remove(queue, 1)
	local message = current.Message
	CommanderBattleClient.Caption(message.Caption)
	CommanderBattleClient.AccentColor(if message.Priority > 1 then ChapterData.WarningColor else DialogueData.Presentation.AccentColor)
	setLine(1)
	CommanderBattleClient.IsOpen(true)
end

--[[ Queues each transmission once and gives urgent reports precedence. ]]
local function enqueue(message: Message)
	if roundEnded() or not isSupportedMap() or seen[message.Id] or #message.Lines == 0 then
		return
	end
	seen[message.Id] = true
	local entry = { Message = message, QueuedAt = os.clock(), Wave = currentWave }
	local insertion = #queue + 1
	for index, queued in queue do
		if message.Priority > queued.Message.Priority then
			insertion = index
			break
		end
	end
	table.insert(queue, insertion, entry)
	if #queue > ChapterData.QueueLimit then
		table.remove(queue)
	end
	if current and message.Priority >= 3 and current.Message.Priority < message.Priority then
		finishCurrent()
	end
	ensureTicking()
end

--[[ Clears presentation and deduplication state at match boundaries. ]]
local function resetRound(ended: boolean)
	if tickConnection then
		tickConnection:Disconnect()
		tickConnection = nil
	end
	table.clear(queue)
	table.clear(seen)
	current = nil
	currentWave = 0
	gapRemaining = 0
	towerSelected(false)
	CommanderBattleClient.IsOpen(false)
	roundEnded(ended)
end

--[[ Reads the final wave from the selected difficulty configuration. ]]
local function getFinalWave(): number
	local map = MapData[ChapterData.Map]
	local difficulty = ReplicatedStorage:GetAttribute("SelectedDifficulty") or GameClient.SelectedDifficulty
	return if map then map.DifficultyWaves[difficulty] or 0 else 0
end

--[[ Offers chapter context when a new combat phase begins. ]]
local function onWaveStarted(wave: number)
	if roundEnded() or not isSupportedMap() then
		return
	end
	currentWave = math.max(currentWave, wave)
	if wave == 1 then
		enqueue(ChapterData.Briefing)
	elseif wave == getFinalWave() then
		enqueue(ChapterData.FinalWave)
	end
end

--[[ Offers advice after configured milestones are completed. ]]
local function onWaveCompleted(wave: number)
	if type(wave) ~= "number" or roundEnded() then
		return
	end
	local message = ChapterData.CompletedWaves[wave]
	if message then
		enqueue(message)
	end
end

--[[ Advances timed content while preserving reading time during interruptions. ]]
update = function(deltaTime: number)
	if not current then
		gapRemaining = math.max(0, gapRemaining - deltaTime)
		if gapRemaining == 0 then
			startNext()
		end
		if not current and #queue == 0 and gapRemaining == 0 and tickConnection then
			tickConnection:Disconnect()
			tickConnection = nil
		end
		return
	end
	if currentWave - current.Wave > ChapterData.MaxWaveLag then
		finishCurrent()
		return
	end
	if not CommanderBattleClient.CanPresent() then
		hiddenElapsed += deltaTime
		if hiddenElapsed > ChapterData.QueueLifetime then
			finishCurrent()
		end
		return
	end
	hiddenElapsed = 0
	if CommanderBattleClient.IsTyping() then
		revealProgress = math.min(revealProgress + deltaTime * DialogueData.CharactersPerSecond, characterCount)
		local visible = math.floor(revealProgress)
		if visible ~= CommanderBattleClient.VisibleGraphemes() then
			CommanderBattleClient.VisibleGraphemes(visible)
		end
		return
	end
	readElapsed += deltaTime
	CommanderBattleClient.ReadProgress(math.min(readElapsed / readDuration, 1))
	if readElapsed >= readDuration then
		CommanderBattleClient.Advance()
	end
end

--[[ Reports whether combat overlays can currently receive attention. ]]
function CommanderBattleClient.CanPresent(): boolean
	return ready() and not roundEnded() and not cutsceneActive() and not towerSelected() and UIController:GetActiveView() == nil
end

--[[ Reports whether a transmission is currently visible. ]]
function CommanderBattleClient.IsVisible(): boolean
	return CommanderBattleClient.IsOpen() and CommanderBattleClient.CanPresent()
end

--[[ Reports whether the current passage is still being revealed. ]]
function CommanderBattleClient.IsTyping(): boolean
	return CommanderBattleClient.VisibleGraphemes() < characterCount
end

--[[ Reveals or advances the current transmission without changing gameplay input. ]]
function CommanderBattleClient.Advance()
	if not current or not CommanderBattleClient.IsVisible() then
		return
	end
	if CommanderBattleClient.IsTyping() then
		revealProgress = characterCount
		CommanderBattleClient.VisibleGraphemes(characterCount)
	elseif CommanderBattleClient.LineIndex() < #current.Message.Lines then
		setLine(CommanderBattleClient.LineIndex() + 1)
	else
		finishCurrent()
	end
end

--[[ Dismisses a transmission while leaving future reports enabled. ]]
function CommanderBattleClient.Dismiss()
	if current and CommanderBattleClient.IsVisible() then
		finishCurrent()
	end
end

--[[ Subscribes to the existing match signals and prepares the shared portrait. ]]
function CommanderBattleClient.Start()
	if started or not isSupportedMap() then
		return
	end
	started = true
	generation += 1
	local token = generation
	resetRound(not GameClient.IsGameStarted)
	cutsceneActive(ReplicatedStorage:FindFirstChild("ActiveCutscene") ~= nil)
	table.insert(connections, ClientSignals.WaveStarted:Connect(function(wave)
		if wave == 1 then
			roundEnded(false)
		end
		onWaveStarted(wave)
	end))
	table.insert(connections, ClientSignals.WaveCompleted:Connect(onWaveCompleted))
	table.insert(connections, ClientSignals.BossSpawned:Connect(function()
		enqueue(ChapterData.BossContact)
	end))
	table.insert(connections, ClientSignals.GameEnding:Connect(function()
		resetRound(true)
	end))
	table.insert(connections, ClientSignals.Restarted:Connect(function()
		resetRound(false)
	end))
	table.insert(connections, ClientSignals.TowerSelected:Connect(function()
		towerSelected(true)
	end))
	table.insert(connections, ClientSignals.TowerUnselected:Connect(function()
		towerSelected(false)
	end))
	table.insert(connections, ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "ActiveCutscene" then
			cutsceneActive(true)
		end
	end))
	table.insert(connections, ReplicatedStorage.ChildRemoved:Connect(function(child)
		if child.Name == "ActiveCutscene" then
			cutsceneActive(ReplicatedStorage:FindFirstChild("ActiveCutscene") ~= nil)
		end
	end))
	if GameClient.IsGameStarted and GameClient.CurrentWave > 0 then
		onWaveStarted(GameClient.CurrentWave)
	end
	loadThread = task.defer(function()
		local ok, rig = pcall(function()
			local assets = ReplicatedStorage:WaitForChild("Assets", 15)
			local npcs = assets and assets:WaitForChild("NPC", 15)
			local commander = npcs and npcs:WaitForChild("Commander", 15)
			local model = if commander and commander:IsA("Model") then commander else commander and commander:FindFirstChild("Rig")
			assert(model and model:IsA("Model") and model.Archivable, "Commander rig model is missing or not Archivable")
			return model
		end)
		if token ~= generation then
			return
		end
		if not ok then
			warn(`[CommanderBattleClient] Combat dialogue unavailable: {rig}`)
			table.clear(queue)
			return
		end
		CommanderBattleClient.Rig(rig)
		ready(true)
		if #queue > 0 then
			ensureTicking()
		end
	end)
end

--[[ Cancels outstanding work and releases every combat subscription. ]]
function CommanderBattleClient.Destroy()
	generation += 1
	resetRound(true)
	ready(false)
	if loadThread and coroutine.status(loadThread) ~= "dead" then
		task.cancel(loadThread)
	end
	loadThread = nil
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	CommanderBattleClient.Rig(nil)
	started = false
end

-- // INITIALIZATION // --
return CommanderBattleClient
