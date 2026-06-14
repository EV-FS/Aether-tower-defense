local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

if RunService:IsClient() then
	return require(script.client)
end

local NetServer = require(script.server)

return NetServer
