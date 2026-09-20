-- Shared menu choreography, sampled from the Units window.
-- Period is Vide's spring period in seconds (not a tween duration).
return table.freeze({
	ExitDuration = 0.3,
	WindowWidthRatio = 0.675 / 0.721698,
	IconSizeRatio = 0.346017 / 0.184974,
	Window = table.freeze({ Period = 0.5, Damping = 0.5 }),
	Rotation = table.freeze({ Period = 0.5, Damping = 1 }),
	Header = table.freeze({ Period = 0.5, Damping = 1 }),
	IconRotation = table.freeze({ Period = 0.5, Damping = 0.7 }),
	IconSize = table.freeze({ Period = 0.5, Damping = 0.8 }),
	Cloud = table.freeze({ Period = 0.7, Damping = 0.8 }),
	Fade = table.freeze({ Period = 0.5, Damping = 1 }),
	Visibility = table.freeze({ Period = 0.18, Damping = 1 }),
	ClosePosition = table.freeze({ Period = 1, Damping = 0.85 }),
	CloseRotation = table.freeze({ Period = 1, Damping = 0.8 }),
	Content = table.freeze({ Period = 0.5, Damping = 0.8 }),
	Detail = table.freeze({ Period = 0.4, Damping = 0.5 }),
	Search = table.freeze({ Period = 0.5, Damping = 0.9 }),
	Action = table.freeze({ Period = 0.75, Damping = 0.65 }),
})
