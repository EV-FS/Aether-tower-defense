"""Exercise delayed summon assets and presentation failure isolation."""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
fixture = Path(__file__).with_name("Models.spec.luau").read_text(encoding="utf-8")
for marker, path in {
    "--[[ASSETS]]": "src/Modules/Utils/TowerAssets.luau",
    "--[[BANNER]]": "src/lobby/ServerScriptService/Server/Services/SummonService/Banner.luau",
}.items():
    fixture = fixture.replace(marker, (root / path).read_text(encoding="utf-8"))
world = (root / "src/lobby/ReplicatedStorage/UI/Components/WorldTowerDisplay.luau").read_text(encoding="utf-8")
fixture = fixture.replace("--[[WORLD_DISPLAY]]", world[world.index("return function(props: Props)"):])
with tempfile.TemporaryDirectory(prefix="summon-models-") as directory:
    path = Path(directory) / "Models.luau"
    path.write_text(fixture, encoding="utf-8")
    subprocess.run([args.luau, str(path)], check=True)
