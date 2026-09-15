--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Promise = require(ReplicatedStorage.Packages.Promise)

--/Types
type Service = {
	Init: (registry: any) -> ()?,
	Start: () -> ()?,
	Dependencies: { string }?,
	[string]: any,
}

export type ServiceRegistry = {
	RegisterServices: (self: ServiceRegistry, moduleList: { ModuleScript }) -> nil,
	GetService: (self: ServiceRegistry, serviceName: string) -> any,
	Start: (self: ServiceRegistry) -> any,
}

-------------------------------------------------
--// ServiceRegistry
-------------------------------------------------
local ServiceRegistry = {} :: ServiceRegistry
ServiceRegistry._modulesToLoad = {} :: { ModuleScript }
ServiceRegistry._services = {} :: { [string]: Service }
ServiceRegistry._isStarted = false

function ServiceRegistry:RegisterServices(moduleList: { ModuleScript })
	assert(not self._isStarted, "이미 시작된 후에는 서비스를 등록할 수 없음.")

	for _, moduleScript in ipairs(moduleList) do
		if moduleScript:IsA("ModuleScript") then
			table.insert(self._modulesToLoad, moduleScript)
		else
			warn(`{moduleScript.Name}은 ModuleScript가 아님.`)
		end
	end
end

function ServiceRegistry:GetService(serviceName: string): any
	local service = self._services[serviceName]
	assert(service, `"{serviceName}" 서비스를 찾을 수 없음.`)

	return service
end

local function sortServices(services: { [string]: Service }): { string }
	local sorted = {}
	local visited = {}
	local temp = {}

	local function visit(name: string)
		if temp[name] then
		end
		if not visited[name] then
			temp[name] = true
			local service = services[name]
			if service.Dependencies then
				for _, depName in ipairs(service.Dependencies) do
					if services[depName] then
						visit(depName)
					end
				end
			end
			temp[name] = nil
			visited[name] = true
			table.insert(sorted, name)
		end
	end

	for name in pairs(services) do
		visit(name)
	end
	return sorted
end

function ServiceRegistry:Start()
	assert(not self._isStarted, "프레임워크가 이미 가동 중임.")
	self._isStarted = true

	return Promise.new(function(resolve, reject)
		--/1. Require
		for _, moduleScript in ipairs(self._modulesToLoad) do
			local serviceName = moduleScript.Name
			local success, result = Promise.try(require, moduleScript):await()

			if not success then
				reject(`{serviceName} 모듈 스크립트 로드 실패: {result}`)
				return
			end

			if type(result) == "table" then
				self._services[serviceName] = result :: Service
			else
				warn(`{serviceName}이 테이블을 반환하지 않음.`)
			end
		end

		local sortedServiceNames = sortServices(self._services)

		--/2. Init
		for _, serviceName in ipairs(sortedServiceNames) do
			local service = self._services[serviceName]
			if type(service.Init) == "function" then
				local success, err = Promise.try(service.Init, self):await()

				if not success then
					reject(`{serviceName} Initialize 실행 중 에러: {err}`)
					return
				end
			end
		end

		--/3. Start
		for _, serviceName in ipairs(sortedServiceNames) do
			local service = self._services[serviceName]
			if type(service.Start) == "function" then
				task.spawn(function()
					Promise.try(service.Start):catch(function(err)
						warn(`{serviceName} Start 실행 중 에러: {err}`)
					end)
				end)
			end
		end

		resolve()
	end)
end

return ServiceRegistry
