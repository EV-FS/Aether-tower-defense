local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

type Reactive<T> = T | (() -> T)
type Source<T> = (() -> T) & ((T) -> T)

export type Props = {
	Title: Reactive<string>?,
	Text: Reactive<string>?,
	SubText: Reactive<string>?,
	AcceptText: Reactive<string>?,
	AcceptColor: Reactive<Color3 | ColorSequence>?,
	DeclineText: Reactive<string>?,
	DeclineColor: Reactive<Color3 | ColorSequence>?,
	OnAccept: () -> (),
	OnDecline: (() -> ())?,
}

export type Request = {
	Props: Props,
	IsOpen: Source<boolean>,
}

local ConfirmationService = {}
ConfirmationService.__index = ConfirmationService

function ConfirmationService.new()
	return setmetatable({
		_current = source(nil :: Request?),
	}, ConfirmationService)
end

function ConfirmationService:GetCurrent(): Request?
	return self._current()
end

function ConfirmationService:Close(request: Request?)
	if request == nil or self._current() == request then
		self._current(nil)
	end
end

function ConfirmationService:Prompt(props: Props): () -> ()
	local request = table.freeze({
		Props = table.freeze(table.clone(props)),
		IsOpen = source(true),
	})

	self._current(request)
	return function()
		self:Close(request)
	end
end

local function resolve(self, request: Request?, accepted: boolean)
	if request == nil or self._current() ~= request or not request.IsOpen() then
		return
	end

	request.IsOpen(false)
	local callback = if accepted then request.Props.OnAccept else request.Props.OnDecline
	if callback then
		callback()
	end
end

function ConfirmationService:Accept(request: Request?)
	resolve(self, request, true)
end

function ConfirmationService:Decline(request: Request?)
	resolve(self, request, false)
end

function ConfirmationService:CompleteClose(request: Request)
	if not request.IsOpen() then
		self:Close(request)
	end
end

export type Service = typeof(ConfirmationService.new())

return ConfirmationService.new()
