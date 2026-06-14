local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

--/Options
export type SharedOptions = {
	Delay: number?,
	Lifetime: number?,
}

export type EmitOptions = SharedOptions & {
	At: string,
	LockToSource: boolean?,
}

export type ProjectileOptions = SharedOptions & {
	From: string,
	To: string,

	Speed: number?,
	TravelTime: number?,

	OnHit: Recipe?,

	CurveHeight: number?,
	CurveOffset: number?,
}

export type BeamOptions = SharedOptions & {
	From: string,
	To: string,
}

--/Steps
export type BaseStep = {
	Type: string,
	Effect: string,

	Delay: number?,
	Lifetime: number?,
}

export type EmitStep = BaseStep & {
	Type: "Emit",
	At: string,
	LockToSource: boolean?,
}

export type ProjectileStep = BaseStep & {
	Type: "Projectile",

	From: string,
	To: string,

	Speed: number?,
	TravelTime: number?,

	OnHit: Recipe?,

	CurveHeight: number?,
	CurveOffset: number?,
}

export type BeamStep = BaseStep & {
	Type: "Beam",

	From: string,
	To: string,
}

export type CustomStep = BaseStep & {
	Type: "Custom",
	Args: { [any]: any }?,
}

export type Step = EmitStep | ProjectileStep | BeamStep | CustomStep
export type Recipe = { Step }

-------------------------------------------------
--// Steps
-------------------------------------------------
local Steps = {}

function Steps.Emit(effect: string, options: EmitOptions): EmitStep
	return TableUtils.DeepFreeze({
		Type = "Emit",
		Effect = effect,

		Delay = options.Delay,
		Lifetime = options.Lifetime,

		At = options.At,
		LockToSource = options.LockToSource,
	})
end

function Steps.Projectile(effect: string, options: ProjectileOptions): ProjectileStep
	return TableUtils.DeepFreeze({
		Type = "Projectile",
		Effect = effect,

		Delay = options.Delay,
		Lifetime = options.Lifetime,

		From = options.From,
		To = options.To,

		Speed = options.Speed,
		TravelTime = options.TravelTime,

		OnHit = options.OnHit,

		CurveHeight = options.CurveHeight,
		CurveOffset = options.CurveOffset,
	})
end

function Steps.Beam(effect: string, options: BeamOptions): BeamStep
	return TableUtils.DeepFreeze({
		Type = "Beam",
		Effect = effect,

		Delay = options.Delay,

		From = options.From,
		To = options.To,
	})
end

function Steps.Custom(handlerName: string, options: (SharedOptions & { Args: { [any]: any }? })?): CustomStep
	return TableUtils.DeepFreeze({
		Type = "Custom",
		Effect = handlerName,

		Delay = options and options.Delay,
		Lifetime = options and options.Lifetime,

		Args = options and options.Args,
	})
end

return Steps
