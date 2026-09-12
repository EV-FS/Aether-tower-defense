--!strict

-- Folder names are only resolved when loading a map or starting a spawn group.
-- Enemies and network packets keep the resulting u8 ID.
local PathCatalog = {}

export type Catalog = {
	Names: { string },
	IdByName: { [string]: number },
	DefaultIds: { number },
	IsLegacy: boolean,
}

function PathCatalog.new(folderNames: { string }, isLegacy: boolean): Catalog
	local seen = {}
	local numberedCount = 0
	local namedPaths = {}
	for _, name in ipairs(folderNames) do
		assert(name ~= "" and not seen[name], `경로 폴더 이름이 비어 있거나 중복됩니다: {name}`)
		seen[name] = true
		local id = tonumber(name)
		if id then
			assert(not isLegacy, "Waypoints에 직접 배치한 기존 경로 노드와 번호 경로 폴더를 함께 사용할 수 없습니다.")
			assert(
				id >= 1 and id <= 255 and id % 1 == 0 and tostring(id) == name,
				"번호 경로 폴더 이름은 1, 2, 3, ... 형식이어야 합니다. 최대 255까지 지원합니다."
			)
			numberedCount += 1
		else
			table.insert(namedPaths, name)
		end
	end

	local defaultCount = isLegacy and 1 or numberedCount
	assert(defaultCount > 0, "Waypoints에 기본 경로가 필요합니다. Start/End 노드 또는 1번 폴더를 추가하세요.")
	assert(defaultCount + #namedPaths <= 255, "맵 하나에 기본 경로와 전용 경로를 합쳐 최대 255개까지 사용할 수 있습니다.")

	local names = {}
	local defaultIds = {}
	for id = 1, defaultCount do
		local name = tostring(id)
		assert(isLegacy or seen[name], `{id}번 경로 폴더가 없습니다. 번호는 1부터 빠짐없이 지정하세요.`)
		names[id] = name
		defaultIds[id] = id
	end

	-- Keep the same IDs even if GetChildren/replication returns folders in another order.
	table.sort(namedPaths)
	for _, name in ipairs(namedPaths) do
		table.insert(names, name)
	end

	local idByName = {}
	for id, name in ipairs(names) do
		idByName[name] = id
	end

	return table.freeze({
		Names = table.freeze(names),
		IdByName = table.freeze(idByName),
		DefaultIds = table.freeze(defaultIds),
		IsLegacy = isLegacy,
	})
end

function PathCatalog.resolve(catalog: Catalog, path: string | number): number
	local id = if type(path) == "number" then path else catalog.IdByName[path]
	assert(id and catalog.Names[id], `존재하지 않는 경로입니다: {path}. 맵의 Waypoints 폴더를 확인하세요.`)
	return id
end

function PathCatalog.selectSpawnPaths(catalog: Catalog, isBoss: boolean?, path: (string | number)?): { number }
	if path ~= nil then
		return { PathCatalog.resolve(catalog, path) }
	end
	if isBoss then
		return { 1 }
	end

	return catalog.DefaultIds
end

return PathCatalog
