-- Shared by the lobby sender and the game receiver. Map content stays in MapData/WaveData.
return table.freeze({
	GamePlaceId = 112297866024001,
	MaxMembers = 4, -- Same capacity as the existing lobby TPArea.
	MinMembers = 1,
	DefaultMap = "Chapter 1",
	DefaultDifficulty = "Normal",
	StudioMap = "Kitsune Raid", -- Preserve the existing game-place Studio preview.
	StudioDifficulty = "Normal",
	ArrivalTimeout = 25,
	RequestBurst = 8,
	RequestsPerSecond = 4,
	TeleportMaxAttempts = 3,
	TeleportRetryDelay = 3,
	TeleportAttemptTimeout = 25,
	ReservationTimeout = 20,
	MatchRetryLifetime = 180,
})
