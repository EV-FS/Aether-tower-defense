--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Input = require(ReplicatedStorage.Packages.Input)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Fn = require(ReplicatedStorage.Shared.Modules.Utils.Fn)

local Keyboard = Input.Keyboard.new()
local Mouse = Input.Mouse.new()
local Touch = Input.Touch.new()

export type Scope = {
	Name: string,
	Priority: number,
	Sink: boolean,
	Enabled: boolean,

	Actions: { [string]: Action },
	Enable: (self: Scope) -> nil,
	Disable: (self: Scope) -> nil,
}
export type Action = {
	Name: string,
	Scope: Scope,
	ActionInfo: ActionInfo,
	Began: typeof(Signal.new()),
	Ended: typeof(Signal.new()),
}

export type ActionInfo = {
	KeyCodes: { Enum.KeyCode },
	GuiButtons: { GuiButton },
}

type Options = {
	Priority: number?,
	Sink: boolean?,
}
type Keycodes = Enum.KeyCode | Enum.UserInputState | "Touch" | "DoubleTap"

local KeyMap = {}

local lastTapTime = 0
local DOUBLE_TAP_THRESHOLD = 0.25

-------------------------------------------------
--// InputController
-------------------------------------------------
local InputController = {}

function InputController.Scope(scopeName: string, actions: { [string]: Action }, options: Options?): Scope
	local self = {}
	self.Name = scopeName
	self.Priority = (options and options.Priority) or 0
	self.Sink = (options and options.Sink) or false
	self.Enabled = false

	self.Actions = {}
	for _, action in actions do
		self.Actions[action.Name] = action
		action.Scope = self
	end

	self.Enable = function()
		self.Enabled = true

		return self
	end
	self.Disable = function()
		self.Enabled = false

		return self
	end

	self.Enabled = false

	return self
end

function InputController.Action(actionName: string, actionInfo: ActionInfo): Action
	local self = {}
	self.Name = actionName
	self.ActionInfo = actionInfo

	self.Scope = nil

	self.Began = Signal.new()
	self.Ended = Signal.new()

	if actionInfo.KeyCodes then
		for _, keyCode in actionInfo.KeyCodes do
			if not KeyMap[keyCode] then
				KeyMap[keyCode] = {}
			end
			table.insert(KeyMap[keyCode], self)
		end
	end
	if actionInfo.GuiButtons then
		for _, button in actionInfo.GuiButtons do
			button.MouseButton1Down:Connect(Fn.Bind(InputController._HandleButton, self, "Began"))
			button.MouseButton1Up:Connect(Fn.Bind(InputController._HandleButton, self, "Ended"))
		end
	end

	return self
end

function InputController.Info(keyCodes: Keycodes?, guiButtons: { GuiButton }?): ActionInfo
	return { KeyCodes = keyCodes, GuiButtons = guiButtons }
end

function InputController._HandleInput(inputState: string, keyCode: Keycodes, processed: boolean?)
	if processed then
		return
	end

	local keyActions = KeyMap[keyCode]
	if not keyActions then
		return
	end

	local candidates = {}

	for _, action in keyActions do
		if action.Scope and action.Scope.Enabled then
			table.insert(candidates, action)
			--action[inputState]:Fire()
		end
	end

	table.sort(candidates, function(a, b): boolean
		return a.Scope.Priority > b.Scope.Priority
	end)

	local currentPriority = 0
	local sinkEnabled = false
	for _, action in ipairs(candidates) do
		if currentPriority > action.Scope.Priority and sinkEnabled then
			break
		elseif currentPriority < action.Scope.Priority then
			currentPriority = action.Scope.Priority
			sinkEnabled = action.Scope.Sink
		end

		action[inputState]:Fire()
	end
end

function InputController._HandleButton(action: Action, inputState: string)
	if action.Scope and action.Scope.Enabled then
		action[inputState]:Fire()
	end
end

function InputController.Init() end

function InputController.Start()
	Keyboard.KeyDown:Connect(Fn.Bind(InputController._HandleInput, "Began"))
	Keyboard.KeyUp:Connect(Fn.Bind(InputController._HandleInput, "Ended"))

	Mouse.LeftDown:Connect(Fn.Bind(InputController._HandleInput, "Began", Enum.UserInputType.MouseButton1))
	Mouse.LeftUp:Connect(Fn.Bind(InputController._HandleInput, "Ended", Enum.UserInputType.MouseButton1))

	Touch.TouchStarted:Connect(function(_, processed: boolean?)
		InputController._HandleInput("Began", "Touch", processed)

		local currentTime = os.clock()
		if (currentTime - lastTapTime) <= DOUBLE_TAP_THRESHOLD then
			InputController._HandleInput("Began", "DoubleTap", processed)
		end
		lastTapTime = currentTime
	end)

	Touch.TouchEnded:Connect(Fn.Bind(InputController._HandleInput, "Ended", "Touch"))
end

return InputController
