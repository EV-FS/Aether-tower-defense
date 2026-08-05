local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cmdr = require(ReplicatedStorage.Packages.Cmdr)

local CmdrService = {}

function CmdrService.Init() end

function CmdrService.Start()
	Cmdr:RegisterDefaultCommands()
	Cmdr:RegisterHooksIn(script:WaitForChild("Hooks"))
	Cmdr:RegisterCommandsIn(script:WaitForChild("Commands"))
end

return CmdrService
