--!strict

export type View = {
	Init: (() -> ())?,
	Start: (() -> ())?,
	Destroy: (() -> ())?,
	RenderUI: () -> Instance,
}

local views: { View } = {
	require(script.EmoteUI),
	require(script.EmojiUI),
}

local ViewRegistry = {}

function ViewRegistry.GetAll(): { View }
	return table.clone(views)
end

return ViewRegistry
