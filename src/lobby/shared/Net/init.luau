local RunService = game:GetService("RunService")

if RunService:IsClient() then
	return require(script.client)
end

return require(script.server)
