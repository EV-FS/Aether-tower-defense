local Players = game:GetService("Players")

export type Id = number | string

export type View<T> = {
	Gui: GuiObject,
	SetContent: (content: T) -> (),
	Destroy: () -> (),
}

export type Config<T> = {
	Name: string?,
	Parent: Instance?,
	DisplayOrder: number?,
	CreateView: (content: T) -> View<T>,
}

export type Options = {
	Adornee: BasePart,
	Offset: Vector3?,
	Size: Vector2,
	MinHeight: number?,
	Enabled: boolean?,
}

export type Renderer<T> = {
	Attach: (self: Renderer<T>, id: Id, options: Options, content: T) -> (),
	Update: (self: Renderer<T>, id: Id, content: T) -> (),
	SetEnabled: (self: Renderer<T>, id: Id, enabled: boolean) -> (),
	Remove: (self: Renderer<T>, id: Id) -> (),
	Render: (self: Renderer<T>, camera: Camera?) -> (),
	Destroy: (self: Renderer<T>) -> (),
}

type Entry<T> = {
	Adornee: BasePart,
	Offset: Vector3,
	Size: Vector2,
	MinHeight: number,
	Enabled: boolean,
	Content: T,
	Dirty: boolean,
	View: View<T>?,
}

local function getScreenBounds<T>(entry: Entry<T>, camera: Camera, projectionScale: number): (Vector2?, Vector2?, number?)
	if not entry.Enabled or not entry.Adornee.Parent then
		return nil, nil, nil
	end

	local position = camera:WorldToViewportPoint(entry.Adornee.Position + entry.Offset)
	if position.Z <= 0 then
		return nil, nil, nil
	end

	local size = entry.Size * (projectionScale / position.Z)
	if size.Y < entry.MinHeight then
		return nil, nil, nil
	end

	local viewport = camera.ViewportSize
	if
		position.X + size.X / 2 < 0
		or position.X - size.X / 2 > viewport.X
		or position.Y + size.Y / 2 < 0
		or position.Y - size.Y / 2 > viewport.Y
	then
		return nil, nil, nil
	end

	return Vector2.new(position.X, position.Y), size, position.Z
end

local UIBillboard = {}

function UIBillboard.new<T>(config: Config<T>): Renderer<T>
	local entries: { [Id]: Entry<T> } = {}
	local availableViews: { View<T> } = {}
	local destroyed = false

	local container = Instance.new("ScreenGui")
	container.Name = config.Name or "UIBillboards"
	container.IgnoreGuiInset = true
	container.ResetOnSpawn = false
	container.DisplayOrder = config.DisplayOrder or 0
	container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	container.Enabled = false
	container.Parent = config.Parent or Players.LocalPlayer:WaitForChild("PlayerGui")

	local function releaseView(entry: Entry<T>)
		local view = entry.View
		if view then
			view.Gui.Visible = false
			entry.View = nil
			table.insert(availableViews, view)
		end
	end

	local function clearViews()
		for _, view in availableViews do
			view.Destroy()
		end
		table.clear(availableViews)
	end

	local renderer = {} :: Renderer<T>

	function renderer:Attach(id: Id, options: Options, content: T)
		assert(not destroyed, "Destroyed 된 UIBillboard 개체임.")
		self:Remove(id)
		entries[id] = {
			Adornee = options.Adornee,
			Offset = options.Offset or Vector3.zero,
			Size = options.Size,
			MinHeight = options.MinHeight or 0,
			Enabled = options.Enabled ~= false,
			Content = content,
			Dirty = true,
		}
	end

	function renderer:Update(id: Id, content: T)
		local entry = entries[id]
		if entry then
			entry.Content = content
			entry.Dirty = true
		end
	end

	function renderer:SetEnabled(id: Id, enabled: boolean)
		local entry = entries[id]
		if entry then
			entry.Enabled = enabled
			if not enabled then
				releaseView(entry)
			end
		end
	end

	function renderer:Remove(id: Id)
		local entry = entries[id]
		if not entry then
			return
		end

		releaseView(entry)
		entries[id] = nil
		if next(entries) == nil then
			container.Enabled = false
			clearViews()
		end
	end

	function renderer:Render(camera: Camera?)
		if destroyed then
			return
		end

		local currentCamera = camera or workspace.CurrentCamera
		container.Enabled = currentCamera ~= nil and next(entries) ~= nil
		if not currentCamera or not container.Enabled then
			return
		end

		local projectionScale = currentCamera.ViewportSize.Y / (2 * math.tan(math.rad(currentCamera.FieldOfView) * 0.5))
		for _, entry in entries do
			local position, size, depth = getScreenBounds(entry, currentCamera, projectionScale)
			if not position or not size or not depth then
				releaseView(entry)
				continue
			end

			local view = entry.View
			if not view then
				view = table.remove(availableViews) or config.CreateView(entry.Content)
				view.Gui.Visible = false
				view.Gui.AnchorPoint = Vector2.new(0.5, 0.5)
				view.Gui.Parent = container
				entry.View = view
				entry.Dirty = true
			end

			if entry.Dirty then
				view.SetContent(entry.Content)
				entry.Dirty = false
			end

			local gui = view.Gui
			local guiPosition = UDim2.fromOffset(position.X, position.Y)
			local guiSize = UDim2.fromOffset(size.X, size.Y)
			local guiIndex = -depth * 2
			if gui.Position ~= guiPosition then
				gui.Position = guiPosition
			end
			if gui.Size ~= guiSize then
				gui.Size = guiSize
			end
			if gui.ZIndex ~= guiIndex then
				gui.ZIndex = guiIndex
			end
			gui.Visible = true
		end
	end

	function renderer:Destroy()
		if destroyed then
			return
		end
		destroyed = true
		for _, entry in entries do
			releaseView(entry)
		end
		table.clear(entries)
		clearViews()
		container:Destroy()
	end

	return renderer
end

return UIBillboard
