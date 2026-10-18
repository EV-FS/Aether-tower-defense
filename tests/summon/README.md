# Summon model recovery

```powershell
python tests/summon/run.py --luau C:\path\to\luau.exe
```

The runner executes the current asset resolver/observer, server banner, and world
display ownership code with engine mocks. It checks delayed folders and model
geometry, batched updates, non-Archivable templates, replacements, cancellation
of deferred work, listener cleanup, banner cache invalidation within an interval,
and model survival when optional animation or VFX preparation fails.

Previously both lobby displays used a single FindFirstChild lookup and never
retried when that failed. The server also retained its available-model roster
until the next banner interval. Displays now observe asset availability; source
geometry updates invalidate cached card templates. The server revalidates its
cache and broadcasts asset availability changes through the existing banner API.
World models are published before optional effects are prepared, own cleanup
before preparation, and normalize their root pivot like viewport cards do.
The result view uses the actual unit image while the 3D model is unavailable.

Missing templates are still missing: no alternate unit model or guessed alias
is substituted. A unit requires a Model named exactly as its catalogue entry at
ReplicatedStorage.Assets.Towers, with Archivable enabled and BasePart geometry.
Warnings now distinguish missing/invalid templates after a loading grace period.

Studio review is required for the actual asset hierarchy, source model pivots,
mesh/texture permissions, rendering, VFX, and multi-result transitions. No live
Studio connection was available; the mocks cannot confirm that the user's model
assets actually exist or that Roblox has approved their content.
