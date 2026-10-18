"""Run movement interruption regressions against current Luau code."""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
fixture = Path(__file__).with_name("Interruption.spec.luau").read_text(encoding="utf-8")
paths = {
    "--[[LOCAL_PLAYER]]": "src/Modules/UI/Emote/LocalEmotePlayer.luau",
    "--[[CLIENT]]": "src/lobby/Shared/Controllers/EmoteClient/init.luau",
    "--[[TRACK_STATE]]": "src/lobby/Shared/Controllers/EmoteClient/EmoteTrackState.luau",
    "--[[DASH]]": "src/lobby/Shared/Controllers/DashClient.luau",
}
for marker, path in paths.items():
    fixture = fixture.replace(marker, (root / path).read_text(encoding="utf-8"))
for marker, path in [
    ("--[[LOBBY_SPRINT]]", "src/lobby/Shared/Controllers/SprintClient.luau"),
    ("--[[GAME_SPRINT]]", "src/game/shared/Services/System/SprintClient.luau"),
]:
    source = (root / path).read_text(encoding="utf-8")
    source = source.replace("return SprintClient", "return { Service = SprintClient, Handle = handleSprint, Attach = function(h) currentHumanoid = h end }")
    fixture = fixture.replace(marker, source)
server = (root / "src/lobby/ServerScriptService/Server/Services/EmoteService/init.luau").read_text(encoding="utf-8")
fixture = fixture.replace("--[[SERVER_STATE]]", server[:server.index("local function resolveEmoteName")] + "\nreturn PlayerEmoteState\n")
with tempfile.TemporaryDirectory(prefix="emote-interruption-") as directory:
    path = Path(directory) / "Interruption.luau"
    path.write_text(fixture, encoding="utf-8")
    subprocess.run([args.luau, str(path)], check=True)
