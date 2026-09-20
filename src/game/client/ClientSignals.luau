--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Signal = require(ReplicatedStorage.Packages.Signal)

-------------------------------------------------
--// ClientSignals
-------------------------------------------------
local ClientSignals = {
	--/GameEvent
	WaveStarted = Signal.new(),
	WaveCompleted = Signal.new(),

	GameOver = Signal.new(),
	Restarted = Signal.new(),

	ReadyVoted = Signal.new(),
	RestartVoted = Signal.new(),
	SkipVoted = Signal.new(),

	CanSkip = Signal.new(),

	--/GameEvent
	GameSpeedChanged = Signal.new(),

	-- UI -> TowerClient
	SpawnRequested = Signal.new(),
	UpgradeRequested = Signal.new(),
	SellRequested = Signal.new(),
	ChangeTargetRequested = Signal.new(),
	RotateRequested = Signal.new(),
	CancelRequested = Signal.new(),

	-- TowerClient -> UI
	TowerHovered = Signal.new(),
	TowerUnhovered = Signal.new(),

	TowerSelected = Signal.new(),
	TowerUnselected = Signal.new(),

	TowerUpdated = Signal.new(),
	StatsUpdated = Signal.new(),
	SkillsChanged = Signal.new(),
	TowerDestroyed = Signal.new(),
	TowerCountChanged = Signal.new(),

	--/EnemyClient -> UI
	BossSpawned = Signal.new(),
	BossDamaged = Signal.new(),
	BossDestroyed = Signal.new(),

	-- EconomyService -> any
	CashChanged = Signal.new(),
}

return ClientSignals
