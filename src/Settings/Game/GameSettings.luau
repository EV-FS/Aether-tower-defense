local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	--GameService
	LobbyPlaceId = 82472147389912,
<<<<<<< HEAD
<<<<<<< HEAD
	StartMoney = 100000000,
=======
	StartMoney = 10000000000,
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
=======
	StartMoney = 10000000000,
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
	WaveReward = 100, --(WaveReward * wave + waveBonus)
	SkipBonus = 100, --웨이브 스킵 시에 웨이브 보상

	--BaseService
	BaseHealth = 500, --기지 체력

	--WaveService
	SkipTime = 20, --웨이브 스킵 가능 시간
	WaveDuration = 60, --웨이브 자동 시작 시간

	--EnemyService
	SpawnDelay = 0.4, --기본 스폰 딜레이
})
