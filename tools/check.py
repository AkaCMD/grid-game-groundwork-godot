#!/usr/bin/env python3
"""Run Godot import, public-boundary checks, and optional actual-editor smoke tests."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(command, cwd=ROOT, env=None):
    result = subprocess.run(command, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=180)
    print(result.stdout, end="", flush=True)
    if result.returncode or re.search(r"SCRIPT ERROR:|^ERROR:|[1-9][0-9]* failures", result.stdout, re.M):
        raise SystemExit(result.returncode or 1)
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--editor-smoke", action="store_true")
    parser.add_argument("--screenshot", type=Path)
    args = parser.parse_args()
    executable = shutil.which(args.godot)
    if not executable:
        raise SystemExit("Godot was not found. Pass --godot /path/to/godot or set GODOT.")
    run([executable, "--headless", "--editor", "--import", "--path", str(ROOT), "--quit"])
    for script in ["test_session.gd", "test_authoring.gd", "test_quack.gd", "test_runtime.gd"]:
        output = run([executable, "--headless", "--path", str(ROOT), "--script",
                      "tests/" + script, "--quit-after", "1200"])
        if "0 failures" not in output:
            raise SystemExit("Test runner did not complete: " + script)
    if args.editor_smoke:
        with tempfile.TemporaryDirectory(prefix="ggg-editor-") as directory:
            target = Path(directory)
            for name in ["addons", "examples", "tests"]:
                shutil.copytree(ROOT / name, target / name)
            project = (ROOT / "project.godot").read_text()
            project = project.replace('"res://addons/grid_game_groundwork/plugin.cfg")',
                                      '"res://addons/grid_game_groundwork/plugin.cfg", "res://tests/editor_harness/plugin.cfg")')
            (target / "project.godot").write_text(project)
            environment = os.environ.copy()
            if args.screenshot:
                args.screenshot.parent.mkdir(parents=True, exist_ok=True)
                environment["GGG_EDITOR_SCREENSHOT"] = str(args.screenshot.resolve())
            command = [executable, "--path", str(target), "--editor", "--quit-after", "600"]
            if not args.screenshot:
                command.insert(1, "--headless")
            output = run(command, cwd=target, env=environment)
            if "EDITOR_SMOKE: 0 failures" not in output:
                raise SystemExit("Editor smoke test did not complete")
    if args.editor_smoke and args.screenshot:
        output = run([executable, "--path", str(ROOT), "--script",
                      "tests/test_editor_surfaces.gd", "--quit-after", "1200"])
        if "Surface rendering: 0 failures" not in output:
            raise SystemExit("Surface rendering test did not complete")
    print("All requested checks passed.")


if __name__ == "__main__":
    main()
