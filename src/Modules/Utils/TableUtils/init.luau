local DeepCopy = require(script.Tools.DeepCopy)
local DeepFreeze = require(script.Tools.DeepFreeze)
local DictionaryLength = require(script.Tools.DictionaryLength)
local DictionaryRandom = require(script.Tools.DictionaryRandom)
local TableUtils = {}

function TableUtils.DeepCopy<T>(newTable): T
	return DeepCopy(newTable)
end

function TableUtils.DeepFreeze<T>(newTable): T
	return DeepFreeze(newTable)
end

function TableUtils.Length(countTable): number
	return DictionaryLength(countTable)
end

function TableUtils.Random(randomTable): (any, any)
	return DictionaryRandom(randomTable)
end

return TableUtils
