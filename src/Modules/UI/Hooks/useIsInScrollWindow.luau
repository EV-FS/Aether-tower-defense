local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local IsInScrollWindow = require(script.Parent.Parent.IsInScrollWindow)

local action = Vide.action
local cleanup = Vide.cleanup
local source = Vide.source

type CacheEntry = {
	isInView: (() -> boolean) & ((boolean) -> boolean),
	users: number,
	disconnect: () -> (),
}

local cache: { [GuiObject]: CacheEntry } = {}

local function createEntry(instance: GuiObject): CacheEntry
	local isInView = source(false)
	local scrollFrame: ScrollingFrame? = nil
	local scrollConnections: { RBXScriptConnection } = {}

	local function clearScrollConnections()
		for _, connection in scrollConnections do
			connection:Disconnect()
		end

		table.clear(scrollConnections)
	end

	local function update()
		isInView(if scrollFrame then IsInScrollWindow(scrollFrame, instance) else false)
	end

	local function connectScrollFrame()
		local ancestor = instance:FindFirstAncestorOfClass("ScrollingFrame")
		if ancestor == scrollFrame then
			update()
			return
		end

		clearScrollConnections()
		scrollFrame = ancestor

		if not scrollFrame then
			update()
			return
		end

		table.insert(scrollConnections, scrollFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(update))

		table.insert(scrollConnections, scrollFrame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(update))

		table.insert(scrollConnections, scrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(update))

		update()
	end

	local connections = {
		instance:GetPropertyChangedSignal("AbsolutePosition"):Connect(update),
		instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(update),
		instance.AncestryChanged:Connect(connectScrollFrame),
	}

	connectScrollFrame()

	local function disconnect()
		clearScrollConnections()

		for _, connection in connections do
			connection:Disconnect()
		end
	end

	return {
		["isInView"] = isInView,
		users = 0,
		disconnect = disconnect,
	}
end

local function useIsInScrollWindow()
	local currentEntry = source(nil :: CacheEntry?)

	local function isInView(): boolean
		local entry = currentEntry()
		return if entry then entry.isInView() else false
	end

	local bind = action(function(instance: GuiObject)
		local entry = cache[instance]
		if not entry then
			entry = createEntry(instance)
			cache[instance] = entry
		end

		entry.users += 1
		currentEntry(entry)

		cleanup(function()
			entry.users -= 1
			if entry.users == 0 then
				entry.disconnect()
				cache[instance] = nil
			end
		end)
	end)

	return isInView, bind
end

return useIsInScrollWindow
