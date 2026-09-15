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
	Actions: { [string]: Action },
	Enable: (self: Scope) -> nil,
	Disable: (self: Scope) -> nil,
}
export type Action = {
	Name: string,
	Scope: string?,
	ActionInfo: ActionInfo,
	Began: typeof(Signal.new()),
	Ended: typeof(Signal.new()),
}
export type ActionInfo = {
	KeyCodes: { Enum.KeyCode },
	GuiButtons: { GuiButton },
}

type Keycodes = Enum.KeyCode | Enum.UserInputState | "Touch" | "DoubleTap"

local KeyMap = {}
local ActivatedScopes = {}

local lastTapTime = 0
local DOUBLE_TAP_THRESHOLD = 0.25

-------------------------------------------------
--// InputService
-------------------------------------------------
local InputService = {}

function InputService.NewScope(scopeName: string, actions: { [string]: Action }): Scope
	local self = {}
	self.Name = scopeName

	self.Actions = {}
	for _, action in actions do
		self.Actions[action.Name] = action
		action.Scope = self.Name
	end

	self.Enable = function()
		ActivatedScopes[self.Name] = true

		return self
	end
	self.Disable = function()
		ActivatedScopes[self.Name] = false

		return self
	end

	ActivatedScopes[self.Name] = false

	return self
end

function InputService.NewAction(actionName: string, actionInfo: ActionInfo): Action
	local self = {}
	self.Name = actionName
	self.ActionInfo = actionInfo

	self.Scope = nil

	self.Began = Signal.new()
	self.Ended = Signal.new()

	if actionInfo.KeyCodes then
		for _, keyCode in ipairs(actionInfo.KeyCodes) do
			if not KeyMap[keyCode] then
				KeyMap[keyCode] = {}
			end
			table.insert(KeyMap[keyCode], self)
		end
	end
	if actionInfo.GuiButtons then
		for _, button in ipairs(actionInfo.GuiButtons) do
			button.MouseButton1Down:Connect(Fn.Bind(InputService._HandleButton, self, "Began"))
			button.MouseButton1Up:Connect(Fn.Bind(InputService._HandleButton, self, "Ended"))
		end
	end

	return self
end

function InputService.NewInfo(keyCodes: Keycodes?, guiButtons: { GuiButton }?): ActionInfo
	return { KeyCodes = keyCodes, GuiButtons = guiButtons }
end

function InputService._HandleInput(inputState: string, keyCode: Keycodes, processed: boolean?)
	if processed then
		return
	end

	local keyActions = KeyMap[keyCode]
	if not keyActions then
		return
	end

	for _, action in ipairs(keyActions) do
		if action.Scope and ActivatedScopes[action.Scope] == true then
			action[inputState]:Fire()
		end
	end
end

function InputService._HandleButton(action: Action, inputState: string)
	if action.Scope and ActivatedScopes[action.Scope] == true then
		action[inputState]:Fire()
	end
end

function InputService.Init() end

function InputService.Start()
	Keyboard.KeyDown:Connect(Fn.Bind(InputService._HandleInput, "Began"))
	Keyboard.KeyUp:Connect(Fn.Bind(InputService._HandleInput, "Ended"))

	Mouse.LeftDown:Connect(Fn.Bind(InputService._HandleInput, "Began", Enum.UserInputType.MouseButton1))
	Mouse.LeftUp:Connect(Fn.Bind(InputService._HandleInput, "Ended", Enum.UserInputType.MouseButton1))

	Touch.TouchStarted:Connect(function(_, processed: boolean?)
		InputService._HandleInput("Began", "Touch", processed)

		local currentTime = os.clock()
		if (currentTime - lastTapTime) <= DOUBLE_TAP_THRESHOLD then
			InputService._HandleInput("Began", "DoubleTap", processed)
		end
		lastTapTime = currentTime
	end)

	Touch.TouchEnded:Connect(Fn.Bind(InputService._HandleInput, "Ended", "Touch"))
end

return InputService
