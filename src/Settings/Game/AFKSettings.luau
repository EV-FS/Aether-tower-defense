local GameSettings = require(script.Parent.GameSettings)

return table.freeze({
	AFKPlaceId = 85894813807831,
	LobbyPlaceId = GameSettings.LobbyPlaceId,

	ProfileStoreName = "TowerDefenseData_v1",
	RewardInterval = 60,
	CoinsPerInterval = 3000,
	GemsPerInterval = 2500,

	-- Refresh before Roblox's idle disconnect while preserving the AFK session.
	SessionRefreshInterval = 15 * 60,
	TeleportRetryCount = 3,
	TeleportRetryDelay = 2,
	RequestCooldown = 10,

	BGMVolume = 1,
})
