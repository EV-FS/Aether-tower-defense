# Cutscene authoring

1. Put scene objects under ReplicatedStorage.Assets.Cutscenes.<Name>.<Shot>.Workspace.
2. Add a definition in Settings.Data.CutsceneData: ScenePath, Animations (model name to animation ID), Camera.Model and Camera.Part.
3. Put zero-based numeric FOV samples in Settings.Data.CutsceneTracks and reference them with Camera.FOV.Samples.
4. Set MapData[mapName].IntroCutscene to the definition name for an automatic intro before the server loads the map. Omit it to load directly. All maps use the same Path initialization.

Any cloned cutscene can set `SceneTransform = CFrame.new(10000, 0, 0)` in CutsceneData. The same world-space transform is applied to the complete off-world clone before it becomes visible, including the map, rigs, and camera. `SceneTransform.Apply` checks every BasePart and Model pivot against the expected transform and aborts a misaligned scene. This works for local lobby and server cutscenes. Workspace-backed scenes such as Summon are not moved because they use live lobby objects. A rotational CFrame can be supplied when a future scene needs both translation and rotation. Keep all authored scene parts in the source folder and animate rigs relative to their roots; scripts that assign absolute world coordinates cannot inherit this transform automatically.

The local player clones the source folder as one tree so references between its children remain valid. All animation model names must be unique in that tree. Before mounting, cloned scenery is anchored, animated rig roots are anchored, collisions/touches are disabled, and copied scripts are disabled so physics or authored scripts cannot move the scene away from the shared staging. Camera, rig, and effect animation tracks use one playback clock; the camera track sets the duration unless `MaxDuration` specifies an authored timeline. `PreloadScene = false` skips blocking on every texture and mesh in a large scene; animation tracks must still load before playback. DragonSlayer uses this path after a successful craft. Its source is `ReplicatedStorage.Assets.Cutscenes.DragonSlayer_Cutscenes`, with models named `Cam`, `PlayerRig`, `OrbFracture`, and `DragonSlayer`. The camera uses `Cam.CamPart`, or `Cam.PrimaryPart` when CamPart is absent. A failed source, camera, placement, or animation load logs its name in Output and restores the lobby view.

DragonSlayer's FOV export has frames 0-1526 in `Settings/Data/CutsceneTracks/DragonSlayerFOV.luau`. The export contains no camera CFrames; Cam's animation supplies camera pose. DragonSlayer plays those samples at the Moon export's 60 FPS so FOV and Lighting.VFX share the authored timeline.

## Cutscene lighting

Set `Lighting = require(script.Parent.CutsceneLighting.ProfileName)` on a cutscene definition to apply a scene-specific profile. DragonSlayer's profile contains its ambient light, fog, sky, atmosphere, bloom, color correction, blur, and depth of field values. `LightingSession` snapshots the named Lighting properties, temporarily removes the current Sky, Atmosphere, and post-processing children, then mounts the profile effects. It holds the profile's Lighting properties during playback so lobby settings or a day/night tween cannot change the shot. Completion, Stop, replacement, and playback errors destroy the profile effects and restore the original values and instances. If another cutscene starts, its lighting session retires the previous owner before taking a fresh snapshot. The local player runs this for lobby cutscenes; `CameraRuntime` runs it for replicated cutscenes.

Profiles may contain only scriptable properties and the supported visual child classes listed in `LightingSession`. Roblox restricts `LightingStyle` and `PrioritizeLightingQuality` to engine/Studio code; the supplied `RBX_*` migration attributes are internal. Those values remain controlled by the experience's published Lighting settings. See the [Lighting API](https://create.roblox.com/docs/reference/engine/classes/Lighting).

DragonSlayer also plays the supplied Moon Animator 2 Lighting Exporter v1.0.0 `game.Lighting.VFX` ColorCorrectionEffect track. The unmodified data is in `CutsceneTracks/DragonSlayerMoonLighting.luau`; `MoonLightingTracks.ColorCorrection` validates the export's target, types, counts, frames, and times and adapts its `Default`/`Keyframes` fields to `ScreenEffects`. This creates a separate `VFX` effect over the static DragonSlayer profile, preserving the exported contrast and saturation values including peaks of 12 and 6. Its 0–1526 frame span uses the export's 60 FPS (25.433 seconds); DragonSlayer's FOV uses that same rate, while the camera animation controls completion. One sampled elapsed time drives both, including pauses. If Cam's uploaded animation length differs by more than 0.25 seconds, playback logs the mismatch so the authored rig timing can be corrected. The effect is disabled before playback and destroyed on every cleanup path. `PropertyTrack` uses the exported default before the first key and the last key after the final one. Outgoing Moon easing is retained when present. Only the exported `ColorCorrectionEffect` target is supported by this adapter; other item classes require an explicit renderer.

DragonSlayer plays SoundId `129406672557005` from SoundService through `LocalAudio`. The lobby preloader requests the asset in advance. Once loaded, playback seeks to the same elapsed time as the cutscene, so late loading does not start the music from the beginning. Interactive pauses pause the sound, resume continues at the timeline position, and every cutscene cleanup stops and destroys it. A persistent load failure logs an asset-permission warning.

DragonSlayer's Moon Animator 2 event export is transcribed into `CutsceneTracks/DragonSlayerVFX.luau`: 15 events and 17 `shared.vfx.emit` calls at their original frames (26–1241) on the 60 FPS, 1526-frame timeline. `LocalVFX` resolves the first path segment among direct children of the cloned `DragonSlayer_Cutscenes` folder. Later segments follow direct children only; for example `{ "OrbFracture", "bowlight2" }` targets that child of the top-level OrbFracture model. An `FX` deep inside Map cannot conflict with the top-level `FX`. Effects follow the same off-map transform as the camera and rigs. The playback clock dispatches each crossed frame once, including after a render skip; a pause holds the event cursor. Stop, completion, replacement, and errors clear owned Forge handles before removing the cloned scene. Missing or duplicate targets at the specified level are reported individually and do not stop the cutscene. The source folder must contain all named top-level VFX targets, including the numeric names `1`–`4`.

DragonSlayer sets `Actors = { PlayerRig = "Self" }`. `LocalActorView` follows RaidIntro's visual replacement: it creates a local avatar from the player's HumanoidDescription using the authored PlayerRig's R6/R15 type and scale, aligns its HumanoidRootPart to the authored root, and plays the same animation on the shared playback clock. It resolves the rig root inside nested models and hides only that rig's body and accessories while leaving its joints, props, and VFX in place. A failure to read the authored rig's scale description does not abort avatar creation; an unavailable avatar animation leaves the personal avatar visible in its default pose. Avatar creation has a bounded wait, falls back to the authored rig on model failure, and destroys late results after Stop/replacement. The actual Player.Character is never moved or reassigned. Cleanup restores the authored rig's appearance and destroys the local avatar before removing the cloned scene.

DragonSlayer's `Presentation` fades from the crafting page to black before closing that page or changing the scene. Scene cloning, avatar creation, animation readiness, Lighting/effect setup, and a bounded `ContentProvider:PreloadAsync` pass happen under the black cover. Once ready, it reveals the cutscene as the shared playback clock starts. The entrance and reveal take about 0.55 seconds each. At the authored ending, it freezes the last camera frame, eases FOV to 88% of that shot's value and fades audio while returning to black. This relative zoom avoids the abrupt 1-degree tunnel effect across different authored FOVs. Camera, Lighting, and scene are restored while covered; after a one-second hold, the black cover fades away to reveal the lobby. Failure/timeout also restores the lobby under black. Stop or replacement cancels the transition and cleans up its ScreenGui. The regular LoadingScreen is not used by this cutscene.

Camera.FOV.FPS is optional. Without it, the highest sample frame aligns with the server-loaded camera animation length. With FPS, exported frames retain their original timing. Fractional frames are linearly interpolated; values before/after the track hold its endpoints. Optional Cuts = { [75] = true } preserves a hard cut at that frame.

RaidIntro uses all 841 supplied samples (0 through 840). The export contains no CFrame values, so position and orientation continue to follow the animated CamPart.

The server owns scene cloning, rig animations, completion and subsequent map loading. Clients acknowledge only after every rig has a loaded playback track. ClientRigTracks normally uses replicated tracks, but creates a local rendering fallback after two seconds if an Animator's paused track has not arrived. Late matching replicated tracks join the same sampling list, and readiness counts rigs rather than track copies. The server publishes a start timestamp 0.5 seconds ahead. PlaybackClock samples that timeline in PreAnimation and seeks every paused rig track to the same time on both server and client (TimePosition does not replicate). FOV rendering uses the exact client pose sample rather than reading a later clock value. Completion follows the camera animation length, capped by MaxDuration (default 60s), not a longer character animation's idle tail. Clients cannot end the server timeline except by reporting a playback failure, which aborts/cleans the session.

Preparation/playback errors report a stage in ReplicatedStorage.CutscenePhase and detail in CutsceneError; animation load timeouts list model names and asset IDs. Rendering callback errors are forwarded to the server instead of repeatedly failing outside the bootstrap's error handler. Cleanup protects each independent resource so a broken track cannot prevent models, effects or camera restoration from being attempted. Avatar ownership is registered before yielding; timeout/cancellation/state removal destroys its local models, and late API results cannot recreate them. Only owned runtime clones are removed; ReplicatedStorage.Assets.Cutscenes remains the reusable source. Animation asset permission failures and missing/duplicate authored rig names still require fixing the source; the fallback does not bypass those errors. See [Animator APIs](https://create.roblox.com/docs/reference/engine/classes/Animator) for loading tracks and observing AnimationPlayed.

This is absolute-time pose sampling: animations stay at speed zero and are advanced by TimePosition. Do not rely on animation markers/Ended for gameplay events; schedule such events on the server timeline. Wall-clock synchronization between separate computers still depends on Roblox's clock estimation and frame rate.

The camera is a Matter ECS entity:
- Session: replicated server state/timing.
- CameraTarget: ObjectValue referencing the server's camera part.
- FOVTrack: samples, sorted keys, optional FPS and cuts.

CameraSystem evaluates these components after Roblox's normal camera update. CameraRuntime creates/despawns the entity. CutsceneBootstrap handles readiness and restores camera settings, including FOV, when the server removes the session.

Rig positioning and scale must match the authored animation. FOV data does not fix disconnected joints or incorrect rig roots.

## Per-viewer actors

`Actors = { PlayerRig = "Self", PlayerFriendRig = "Friend" }` personalizes only these visual actors. The source folder must contain exactly one model for each configured animation name. For RaidIntro, **rename the old model to PlayerFriendRig** and name the newly authored model **PlayerRig** in Studio; asset models are not stored in this repository. The old animation currently in the project (117994110297108) is assigned to PlayerFriendRig; PlayerRig uses 93026790768176. Duplicate/missing model names produce an explicit server setup error instead of silently animating the wrong rig.

CutsceneProfiles starts server-side identity lookup while the scene is prepared. Self uses the loaded character's applied description when available, otherwise the account avatar. Friend is randomly selected from the first nonempty valid page of that viewer's actual `Players:GetFriendsAsync` result (including offline friends). It advances empty pages, filters invalid/self/duplicate IDs, and never substitutes a stranger. Selection is independent per viewer; shared friend lists may select the same friend. Only the selected identity/description is published, not the complete list. A disconnected player's profile is discarded; joining players get their own profile.

ActorView creates client-only avatar models. Self follows the authored actor's R6/R15 type; Friend is forced to R6. It retains the scene's description scale values and Model scale to limit changes to camera staging, while applying personal body assets, colors, clothing and accessories. Avatar packages with very different geometry can still change silhouette/reach; custom bone skeletons require a separate adapter. Humanoid physics/state evaluation is disabled, only HumanoidRootPart is anchored, and collisions are disabled. It never assigns Player.Character or changes the actual player's health/position. Original rig body/accessory visuals are hidden locally only after the replacement and its animation are ready; source joints, authored props and VFX targets remain in place.

`Friend` actors are always created as R6 regardless of the friend's account avatar or the authored placeholder's Humanoid rig type. `Self` continues to follow the authored R6/R15 skeleton. Friend animations therefore must be authored and published for R6. The local model still follows the authored PlayerFriendRig root transform and model scale.

Avatar tracks join CameraRuntime's existing PreAnimation sampling list, sharing StartedAt with all original rigs, camera, sound and effects. No extra playback clock is created. Profiles have an 8-second limit per role and local avatar preparation a shared 12-second limit, concurrent with other cinematic preloads. Friends absent, Studio negative user IDs, unavailable accounts/API/assets, unsupported rigs and timeout all retain the authored actor instead of blocking map entry. Late API results are destroyed, not applied mid-cutscene. Session completion/error restores hidden parts and destroys local actors, tracks and listeners.

See Roblox's [Players API](https://create.roblox.com/docs/reference/engine/classes/Players) for friend pages and avatar-description/model APIs, and [Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid) for the rig/state controls. Validate avatar packages, animation permissions, scale and multi-client playback in Studio; CLI tests do not exercise Roblox rendering or live friend services.

## Batched scene lifecycle

RaidIntro now explicitly opts into `Lifecycle = { FastMount = true, FastCleanup = true }`: complete top-level model trees are assembled in an off-world owned container, then that container is parented to Workspace in one operation. On finish/failure the container is destroyed as a whole, followed by owned-root cleanup for anything detached from it. This avoids the long leaf-by-leaf mount/deletion and visible empty-model tail, at the cost of a potentially larger frame/replication spike. Other cutscenes/maps keep the batched path unless configured otherwise. Original ReplicatedStorage assets are never deleted. Phase transitions print elapsed times; client-readiness waits print pending player stages every five seconds. Missing VFX targets only disable that target and are not a fatal animation error.

The server's SceneLifecycle utility shares a 2ms soft Lua budget between scanning/preparation and live changes. Live mutations cost one operation (up to 256); cheap scans/off-world preparation cost 1/8 (up to 2048), instead of forcing every phase to wait after 128 nodes. When a sampled server frame exceeds 25ms, both the work quota and time budget halve. Teardown counts scanning separately from actual destruction. It clones once off-world to preserve cross-object references, detaches container children off-world, then mounts the same instances parent-first in batches. Animated cutscene rigs stay atomic; folders/static models are split. During mounting, unanchored parts and enabled scripts are temporarily held until assembly completes. Teardown destroys descendants before parents rather than recursively removing a large root in one call.

Cutscene cleanup completes before map mounting starts. MapReady is published only after mounting, terrain paste and server Path initialization; the client waits for it, and CharacterGuard releases players only after successful map preparation. A failed map load clears its loading state and reports LoadError. Only roots owned by MapService are removed, and old wave-BGM connections are disconnected.

Engine Clone, individual atomic rigs and Terrain:PasteRegion cannot be interrupted by this budget. Clone/Terrain operations taking more than 16ms report their duration for further profiling. This reduces concentrated script/replication work but is not a guarantee of a fixed client FPS; verify on the actual map/device.

The game no longer gates loading completion on PreloadAsync of all ReplicatedStorage/Workspace/PlayerGui assets. Cutscene-critical preloads remain; other content uses Roblox's normal demand loading, so a slow connection may still cause first-use texture pop-in. In-game loading skips the cosmetic minimum hold while keeping its exit animation. Bootstrap loading-art preloading is capped at 3s. Workspace.Map.MapLoadSeconds records server map load wall time (not client download time or intro duration).

## Fullscreen impact images

Set `ImpactFrames = { Events = require(...), EndFrame = 840 }` in a cutscene definition. Like FOV, the separate event module is a zero-based frame dictionary:

```lua
return {
	[220] = 119558621791086, -- show this image
	[223] = 90994462921654, -- replace the previous image
	[225] = false, -- hide
}
```

Use `false`, not `nil`, for hide events. Each image holds until the next event or session cleanup. `EndFrame` is the full authored timeline length, not the last impact event. Omit `FPS` to fit to CameraDuration, matching RaidIntro's FOV/VFX timeline; an explicit FPS overrides this mapping.

Optionally add `PersistentImage = { ImageId = 228322184, ImageTransparency = 0.12 }` inside `ImpactFrames`. This separately preloaded fullscreen layer has BackgroundTransparency = 1 and remains above the timed images from the scheduled start until session cleanup. Hide events affect only timed images. Its transparency does not change other images; the overlay stays hidden during preparation.

The Matter ImpactTrack/ImpactSystem samples the same PreAnimation elapsed time as poses and FOV and switches pre-created ImageLabels synchronously in the camera render callback. There are no waits, tweens, or deferred tasks during image changes. Dropped frames select only the currently applicable image; short flashes wholly between rendered frames cannot be displayed without breaking synchronization. Images are stretched fullscreen in a noninteractive ScreenGui with IgnoreGuiInset enabled and ScreenInsets.None ([Roblox ScreenGui documentation](https://create.roblox.com/docs/reference/engine/classes/ScreenGui)).

All impact images preload before readiness. A failed/timed-out preload logs a warning and disables the impact overlay for that playback instead of showing late images or blocking the entire map. Ensure the experience has permission to use each image. The GUI is destroyed when the cutscene ends or its state is removed. Exact cross-device display timing still depends on clock estimation, FPS, and rendering.

## Color correction tracks

Both local `CutscenePlayer.Play` (lobby Summon / local tests) and the replicated
ECS `CameraRuntime` now create and sample the same `ScreenEffects` module.
Previously the local player ignored this configuration entirely.
Local playback samples the already paused/resumed `currentElapsed` used for rig
poses and FOV, so opening summon results at a pause frame also freezes the screen
effect at that frame. It removes its owned effect on completion, Stop, replacement,
and playback errors. Existing Lighting effects are left intact.

Current Summon uses 60 FPS and 300 frames (5 seconds of timeline time, excluding
pauses): brightness reaches 1 at frame 83, returns to 0 at 97, holds around 0.15
from frame 124, and fades from 0.14 at 284 to 0 at 300. The source is
`Settings/Data/CutsceneTracks/SummonScreen.luau`.

Track rate precedence is per-track `FPS`, then cutscene `FPS`. If both are absent,
ECS uses `EndFrame / CameraDuration`; local ScreenEffects uses
`EndFrame / MaxDuration` (60 seconds if omitted). RaidIntro intentionally omits
global and per-track FPS, so FOV/screen/VFX/impact tracks fit the replicated camera
animation duration. Summon intentionally uses fixed 60 FPS.

Roblox API references checked for this implementation:

- [ColorCorrectionEffect](https://create.roblox.com/docs/reference/engine/classes/ColorCorrectionEffect):
  enabled effects under Lighting or CurrentCamera affect the rendered world;
  multiple effects compose. Brightness 1 makes the scene white. Saturation above
  1 is supported, so forcing all exported numbers into [-1, 1] is incorrect.
  Finite exported values are preserved, including Contrast 2/4/12/15.
- [TweenService.GetValue](https://create.roblox.com/docs/reference/engine/classes/TweenService#GetValue):
  supplies standard easing without starting independent Tween clocks.
- [Moon object exporter author's post](https://devforum.roblox.com/t/want-to-export-object-animations-you-made-in-moon-animator-2-now-you-can/2515950):
  object/property playback needs a runtime/export path beyond rig playback.
  Moon export formats vary by exporter; `Default/Sequence` below describes this
  project's accepted adapter format, not a universal Moon Animator 2 API.

The sampler accepts old arrays and `Default/Sequence`, numeric/Color3 interpolation,
boolean switches, standard easing and cubic Bezier. Easing may use `Type`, `Style`,
or `EasingStyle`; direction may use `Direction`, `EasingDirection`, or the older
`Params.Direction` form. EnumItems and names are both accepted. `None`/`Constant`
in this adapter
hold the left value until the next key. Keys past EndFrame fail preparation instead
of silently losing the return-to-neutral key. Do not run an exporter's separate
`Play`/`CreatePlayer` timer alongside this timeline.

Regression cases live in `tests/CutsceneScreen.spec.luau`. CLI engine stubs verify
sampling/cleanup logic, not visual fidelity; use Studio to compare against the
Moon preview and confirm existing Lighting effects and editor quality settings.

`ScreenEffects = { Tracks = require(...CutsceneTracks.RaidIntroScreen), EndFrame = 840 }` adds a local, session-owned ColorCorrectionEffect without modifying existing Lighting effects. The Tracks module contains `Saturation`, `Contrast`, `Brightness`, `TintColor` and `Enabled` arrays:

```lua
return {
	Contrast = {
		{ Frame = 0, Value = 0, Ease = { Type = "Sine", Params = { Direction = "InOut" } } },
		{ Frame = 8, Value = 4 },
		{ Frame = 20, Value = 0 },
	},
	Enabled = {},
}
```

Numeric/Color3 keys interpolate; booleans switch at key boundaries. An absent Ease means linear interpolation; easing belongs to the outgoing segment. Empty tracks leave neutral defaults (Enabled becomes true only during playback). Invalid properties/types/duplicate key frames are reported during preparation. Export data is copied/sorted without mutating it.

Updated Moon exports may use `Contrast = { Default = 0, Sequence = { { Frame = 0, Value = 0 }, ... } }`; the old array format remains supported. An empty Sequence uses its explicit Default (including false); otherwise the first/last key values hold at the endpoints. `Ease.Type = "Bezier"` or `"CubicBezier"` accepts X1/Y1/X2/Y2 or lowercase equivalents and defaults to (0.25, 0.1, 0.25, 1). X controls must be in [0, 1]; Y overshoot is preserved. Standard Roblox easing accepts either Params.Direction or Params.Dir. Unknown/invalid easing falls back to Linear during preparation. Exporter CreatePlayer/Play timers are intentionally not started alongside the ECS clock.

Omit FPS to map 0..EndFrame to the server's CameraDuration, like the other RaidIntro tracks. Optional FPS = 60 preserves fixed export timing instead. The ECS ScreenEffectSystem samples the same Session.Elapsed as camera/FOV/impact images; it does not create its own clock, RenderStepped listener or Tween playback. Last values hold until cleanup. The effect is disabled before the scheduled start and destroyed on completion/cancellation. Supplied contrast peaks (including 12 and 15) are passed through unchanged; visual output depends on Roblox's renderer and existing effects. See [ColorCorrectionEffect](https://create.roblox.com/docs/reference/engine/classes/ColorCorrectionEffect).

## Frame-based VFX

VFX.Events points to a zero-based frame dictionary, just like FOV samples:

```lua
return {
	[0] = { Emit = { { "FX" }, { "FX2" } } },
	[21] = {
		Emit = { { "dA", "bowlight2" } },
		AbsoluteEmit = { { "LightningParticle" } },
	},
}
```

Paths resolve within the server-cloned SceneRoots, not arbitrary Workspace objects. Exact root paths win; a unique nested first name is also supported (for example `{"FX"}` inside an Effects folder). Duplicate matches require an explicit path such as `{"Effects", "FX"}`. The server resolves each unique path once and publishes ObjectValues in ActiveCutscene.VFXTargets. Clients wait for those references and their descendants before initializing VFX. Truly missing/ambiguous paths are diagnosed during preparation and disabled individually, not retried at every frame. A replication timeout disables VFX for that playback with a distinct warning.

Non-rig scene parts are anchored to prevent them falling during preparation; animated rigs keep root-only anchoring. With streaming enabled, a temporary Persistent Model holds the scene so loose Parts/Folders are not streamed away. Original scene-root references remain valid. See [Roblox streaming modes](https://create.roblox.com/docs/reference/engine/enums/ModelStreamingMode). Without streaming, roots remain direct Workspace children.

Emit uses the unified `Shared.Modules.Utils.EmitModule` (an alias of ForgeVFX, with one cache/runtime). AbsoluteEmit still calls ReplicatedStorage.Part_Icles:Activate() then :AbsoluteEmit(target); that external module must be present in Studio. Audio, VFX preparation and impact images prepare concurrently. Animation readiness checks actual replicated tracks with positive Length instead of a second, 8-second PreloadAsync of duplicate Animation instances. Forge emit handles are cleared when the cutscene ends without deinitializing the global VFX engine.

Set VFX.EndFrame to the full authored timeline length (RaidIntro: 840), not the last effect frame (462). Omitting VFX.FPS fits this timeline to CameraDuration, matching the FOV timing. Each event is dispatched once in frame order; skipped rendering frames dispatch all crossed events. VFX runs locally for each viewer on the shared server timeline; the server continues to own the scene, animations and map loading. Third-party effects may have their own internal delays.
