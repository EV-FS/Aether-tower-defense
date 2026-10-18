# Camera write conflicts

Run `python tests/camera/run.py --luau C:\path\to\luau.exe`.

The fixture executes the normal FOV controller and ForgeVFX camera shake module.
Normal and instant FOV writes yield to Scriptable cameras. VFX does not restore
stale Heartbeat poses onto scripted or replaced cameras. Authored shake offsets
continue to render, and controller connections own cleanup.

The earlier camera-rig cloning, anchoring, and shake suppression were reverted
after the user reported that Summon no longer played. CutscenePlayer,
CutsceneData, and CutsceneValidator match their prior versions. The original
Workspace rig and animation/FOV tracks are used again. Previous helper mocks
passed but did not exercise the actual rig. A helper test is not evidence of
successful animation playback.

Studio review remains necessary for playback, result pauses, and camera
smoothness. Stop and restart the playtest to reload required modules. No live
Studio connection was available for this repair.
