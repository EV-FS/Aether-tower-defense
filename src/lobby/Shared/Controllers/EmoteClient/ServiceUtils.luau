--// ServiceUtils
-- Cached service locator for the emote system.
-- Avoids repeated ServiceRegistry:GetService() calls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)

local ServiceUtils = {}

local cachedServices: { [string]: any } = {}

--[[ Returns a cached service from ServiceRegistry. Returns nil if not found. ]]
function ServiceUtils.Get(serviceName: string): any
	local cached = cachedServices[serviceName]
	if cached then
		return cached
	end

	local success, service = pcall(function()
		return ServiceRegistry:GetService(serviceName)
	end)

	if success and service then
		cachedServices[serviceName] = service
		return service
	end

	return nil
end

return ServiceUtils
