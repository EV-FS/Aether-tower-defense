--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

--/Types

export type Data = {}

-------------------------------------------------
--// LootData
-------------------------------------------------
local LootData: { [string]: Data } = {
}

return TableUtils.DeepFreeze(LootData)
