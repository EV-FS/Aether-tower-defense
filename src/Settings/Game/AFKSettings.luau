local GameSettings = require(script.Parent.GameSettings)

return table.freeze({
	AFKPlaceId = 83902769155002,
	LobbyPlaceId = GameSettings.LobbyPlaceId,

	ProfileStoreName = "TowerDefenseData_v1",
	CoinRewardInterval = 60,
	CoinsPerReward = 10,
	GemRewardInterval = 3 * 60,
	GemsPerReward = 1,
	StateUpdateInterval = 1,

	-- Refresh before Roblox's idle disconnect while preserving the AFK session.
	SessionRefreshInterval = 15 * 60,
	TeleportRetryCount = 3,
	TeleportRetryDelay = 2,
	RequestCooldown = 10,

	BGMVolume = 1,
})
