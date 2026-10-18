# Emote action interruptions

```powershell
python tests/emotes/run.py --luau C:\path\to\luau.exe
```

The fixture executes the current shared local player, both sprint handlers,
lobby dash, lobby emote controller, track-effect lifecycle, and server character
state with engine mocks. It checks cancellation before action playback, sprint
activation while an emote owns movement, duplicate cancellation, incompatible
humanoid states, tools, death, respawn, control locks, failed animation loads,
intro transitions, delayed play confirmations, speed restoration, and sound
cleanup without waiting indefinitely for an animation's length.

Root cause: dash never stopped the Action4 emote, and sprint rejected input while
emotes disabled its controller. Shared `LocalEmotePlayer.Interrupt(character)`
now cancels via the existing auto-stop callback, which also notifies the lobby
server. Action versions invalidate play confirmations superseded by movement.
The original humanoid owns speed restoration, so replacing a character cannot
apply an old speed to its replacement. Walking emotes retain configured movement.

Run Studio review for actual animation blending, network latency, props/VFX,
desktop and mobile sprint, dash cooldown, summon locks, and repeated respawns.
Mocks and Rojo builds do not prove live engine replication or input ordering.
