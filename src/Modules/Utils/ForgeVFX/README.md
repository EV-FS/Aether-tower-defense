# Unified Emit runtime

`Shared.Modules.Utils.EmitModule` and `Shared.Modules.Utils.ForgeVFX` return the same API. Initialize once (init is idempotent); existing `shared.vfx.emit(...)` calls continue to work.

```lua
local Emit = require(game.ReplicatedStorage.Shared.Modules.Utils.EmitModule)
Emit.init()
local playback = Emit.emit(effect) -- includes eligible descendant effects
-- Emit.emit(2, effect) scales legacy mesh sizes / beam widths.
-- playback.Finished is a Promise; playback:Clear() cancels this emission.
```

Integration notes for the supplied root `EmitModule/`:

- Keep the existing Forge runtime as the implementation: it already contains the older module's Particle, Beam, Mesh, Bezier, Spin, Screen, CameraShake and Shockwave effects, plus Lightning, Sound, attribute animation/randomization and cancellation.
- Restore the older module's default particle burst of 1 when EmitCount is absent. Explicit EmitCount = 0 still means no burst; positive EmitDuration can enable a timed emission.
- Forward the numeric legacy scale through the emit context, including nested emissions.
- Preserve recursive Screen effects inside a Folder/Model without double-emitting their descendants; release screen locks on rejected/failed setup.
- Correct the attribute-tweener dispatch signature while keeping property-tweener compatibility.
- Zero EmitDelay no longer calls task.wait(0). Positive authored delays and game-speed-aware lifetime timers remain intact. This removes an artificial frame of delay, not all renderer/network latency.
- Respect the existing exclude tag on directly emitted objects and descendants.

Do not initialize the supplied old engine alongside this module: it would create duplicate caches, listeners and competing shared.vfx globals. The supplied source directory is left untouched as a reference and is not added to Rojo mappings. Existing embedded license notices are retained; this ForgeVFX derivative remains under its existing VFX-DL terms. This module is for normal Roblox game runtime only.
