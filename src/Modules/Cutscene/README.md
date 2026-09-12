# Cutscene authoring

1. Put scene objects under ReplicatedStorage.Assets.Cutscenes.<Name>.<Shot>.Workspace.
2. Add a definition in Settings.Data.CutsceneData: ScenePath, Animations (model name to animation ID), Camera.Model and Camera.Part.
3. Put zero-based numeric FOV samples in Settings.Data.CutsceneTracks and reference them with Camera.FOV.Samples.
4. Set MapData[mapName].IntroCutscene to the definition name for an automatic intro before the server loads the map. Omit it to load directly. All maps use the same Path initialization.

Camera.FOV.FPS is optional. Without it, the highest sample frame aligns with the server-loaded camera animation length. With FPS, exported frames retain their original timing. Fractional frames are linearly interpolated; values before/after the track hold its endpoints. Optional Cuts = { [75] = true } preserves a hard cut at that frame.

RaidIntro uses all 841 supplied samples (0 through 840). The export contains no CFrame values, so position and orientation continue to follow the animated CamPart.

The server owns scene cloning, rig animations, completion and subsequent map loading. Clients acknowledge only after every replicated, paused animation track is available. The server publishes a start timestamp 0.5 seconds ahead. PlaybackClock samples that timeline in PreAnimation and seeks every paused rig track to the same time on both server and client (TimePosition does not replicate). FOV rendering uses the exact client pose sample rather than reading a later clock value. Clients cannot end the server timeline.

This is absolute-time pose sampling: animations stay at speed zero and are advanced by TimePosition. Do not rely on animation markers/Ended for gameplay events; schedule such events on the server timeline. Wall-clock synchronization between separate computers still depends on Roblox's clock estimation and frame rate.

The camera is a Matter ECS entity:
- Session: replicated server state/timing.
- CameraTarget: ObjectValue referencing the server's camera part.
- FOVTrack: samples, sorted keys, optional FPS and cuts.

CameraSystem evaluates these components after Roblox's normal camera update. CameraRuntime creates/despawns the entity. CutsceneBootstrap handles readiness and restores camera settings, including FOV, when the server removes the session.

Rig positioning and scale must match the authored animation. FOV data does not fix disconnected joints or incorrect rig roots.

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

Paths resolve within the server-cloned SceneRoots, not arbitrary Workspace objects. Emit uses ForgeVFX; AbsoluteEmit calls ReplicatedStorage.Part_Icles:Activate() then :AbsoluteEmit(target). The external Part_Icles module must be present in Studio. Dependencies initialize before camera readiness is acknowledged.

Set VFX.EndFrame to the full authored timeline length (RaidIntro: 840), not the last effect frame (462). Omitting VFX.FPS fits this timeline to CameraDuration, matching the FOV timing. Each event is dispatched once in frame order; skipped rendering frames dispatch all crossed events. VFX runs locally for each viewer on the shared server timeline; the server continues to own the scene, animations and map loading. Third-party effects may have their own internal delays.
