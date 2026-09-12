-- Keys use the same 0..840 timeline as RaidIntroFOV.
-- Each path is relative to the server-cloned cutscene scene.
return {
	[0] = { Emit = { { "FX" }, { "FX2" } } },
	[21] = {
		Emit = { { "Explode" }, { "dA", "bowlight2" } },
		AbsoluteEmit = { { "LightningParticle" } },
	},
	[105] = {
		Emit = { { "Part2" }, { "raidbossda", "bowlight2" } },
		AbsoluteEmit = { { "LightningParticle" } },
	},
	[174] = { Emit = { { "raidbossda", "bowlight2" }, { "Meshes2" } } },
	[213] = { Emit = { { "Dash" } } },
	[238] = { Emit = { { "FX1" }, { "raidbossda", "bowlight2" }, { "ScreenEffect" } } },
	[302] = { Emit = { { "Explosion" }, { "startup" } } },
	[313] = { Emit = { { "emit 1" }, { "ScreenEffect2" } } },
	[321] = { Emit = { { "emit 2" } } },
	[329] = { Emit = { { "emit 3" } } },
	[335] = { Emit = { { "emit 4" } } },
	[378] = { Emit = { { "HL" } } },
	[390] = { Emit = { { "Slashcv" } } },
	[433] = { Emit = { { "Wall" }, { "ScreenEffect3" }, { "HL" } } },
	[462] = { Emit = { { "C4" }, { "Meshes" } } },
}
