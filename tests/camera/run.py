"""Run camera ownership regressions using current source and engine mocks."""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
fixture = Path(__file__).with_name("Ownership.spec.luau").read_text(encoding="utf-8")
for marker, path in {
    "--[[FOV]]": "src/lobby/Shared/Controllers/FOVController.luau",
    "--[[SHAKE]]": "src/Modules/Utils/ForgeVFX/effects/camera_shake.luau",
}.items():
    fixture = fixture.replace(marker, (root / path).read_text(encoding="utf-8"))
with tempfile.TemporaryDirectory(prefix="camera-ownership-") as directory:
    path = Path(directory) / "Ownership.luau"
    path.write_text(fixture, encoding="utf-8")
    subprocess.run([args.luau, str(path)], check=True)
