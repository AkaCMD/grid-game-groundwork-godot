#!/usr/bin/env python3
"""Repeat the Paint tool-switch regression in a disposable actual editor.

Graphical runs move the native cursor and require exclusive input on the chosen
screen. Headless runs use synthetic input and do not require a desktop.
"""
import argparse
import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import shutil
import sys
import tempfile
import subprocess
import time
import re
import threading

from check import ROOT, run


ENTRY = '''func run() -> void:
	for frame in range(30): await get_tree().process_frame
	print("EDITOR_INPUT_ENV: backend=%s window=%s screen=%s" % [DisplayServer.get_name(), get_window().position, get_window().current_screen])
	EditorInterface.set_main_screen_editor("Grid Levels")
	var panel = find_panel(EditorInterface.get_editor_main_screen())
	check(panel != null, "Grid Levels panel exists in the actual editor")
	if panel: await check_paint_mode_preview(panel)
	print("PAINT_MODE_PREVIEW: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

'''


def native_window_api():
    """Configure the Windows bridge only when a graphical Windows run needs it."""
    user32 = ctypes.windll.user32
    callback = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    signatures = {
        "EnumWindows": ([callback, wintypes.LPARAM], wintypes.BOOL),
        "GetWindowThreadProcessId": ([wintypes.HWND, ctypes.POINTER(wintypes.DWORD)], wintypes.DWORD),
        "IsWindowVisible": ([wintypes.HWND], wintypes.BOOL),
        "GetClientRect": ([wintypes.HWND, ctypes.POINTER(wintypes.RECT)], wintypes.BOOL),
        "GetWindowRect": ([wintypes.HWND, ctypes.POINTER(wintypes.RECT)], wintypes.BOOL),
        "ClientToScreen": ([wintypes.HWND, ctypes.POINTER(wintypes.POINT)], wintypes.BOOL),
        "SetCursorPos": ([ctypes.c_int, ctypes.c_int], wintypes.BOOL),
        "ShowWindow": ([wintypes.HWND, ctypes.c_int], wintypes.BOOL),
        "SetWindowPos": ([wintypes.HWND, wintypes.HWND, ctypes.c_int, ctypes.c_int,
                          ctypes.c_int, ctypes.c_int, ctypes.c_uint], wintypes.BOOL),
        "SetProcessDPIAware": ([], wintypes.BOOL),
    }
    for name, (argtypes, restype) in signatures.items():
        function = getattr(user32, name)
        function.argtypes = argtypes
        function.restype = restype
    user32.SetProcessDPIAware()
    return user32


def visible_process_windows(user32, process_id):
    """Return (client area, handle) pairs for readable visible process windows."""
    windows = []
    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def collect(hwnd, _):
        pid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        if pid.value == process_id and user32.IsWindowVisible(hwnd):
            rect = wintypes.RECT()
            if user32.GetClientRect(hwnd, ctypes.byref(rect)):
                width, height = rect.right - rect.left, rect.bottom - rect.top
                # Exclude splash/tool windows for both placement and pointer conversion.
                if width > 500 and height > 400:
                    windows.append((width * height, hwnd))
        return True
    if not user32.EnumWindows(collect, 0):
        raise SystemExit("INPUT_SETUP: could not enumerate Godot native windows")
    return windows


def select_editor_window(user32, process_id):
    """Use the largest eligible client area, with the handle breaking area ties."""
    windows = visible_process_windows(user32, process_id)
    return max(windows)[1] if windows else None


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--warp-cursor":
        user32 = native_window_api()
        hwnd = select_editor_window(user32, os.getppid())
        if hwnd is None:
            raise SystemExit("Godot native window was not found")
        x, y = int(sys.argv[2]), int(sys.argv[3])
        point = wintypes.POINT(x, y)
        if not user32.ClientToScreen(hwnd, ctypes.byref(point)):
            raise SystemExit("ClientToScreen failed")
        if not user32.SetCursorPos(point.x, point.y):
            raise SystemExit("SetCursorPos failed")
        return
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--screen", type=int, help="Godot screen index for graphical runs")
    parser.add_argument("--position", help="Godot window position X,Y for graphical runs")
    args = parser.parse_args()
    executable = shutil.which(args.godot)
    if not executable:
        parser.error("Godot was not found")
    if args.repeat < 1:
        parser.error("--repeat must be positive")
    if args.position is not None and not re.fullmatch(r"-?\d+,-?\d+", args.position):
        parser.error("--position must be X,Y integer coordinates")
    if args.headless and (args.screen is not None or args.position is not None):
        parser.error("--screen/--position require a graphical run")
    if not args.headless:
        print("Native input prerequisite: leave the test screen's cursor and focus alone.", flush=True)
    for attempt in range(args.repeat):
        print(f"Editor input run {attempt + 1}/{args.repeat}", flush=True)
        with tempfile.TemporaryDirectory(prefix="ggg-input-") as directory:
            target = Path(directory)
            for name in ["addons", "examples", "tests"]:
                shutil.copytree(ROOT / name, target / name)
            project = (ROOT / "project.godot").read_text(encoding="utf-8")
            project = project.replace('"res://addons/grid_game_groundwork/plugin.cfg")',
                                      '"res://addons/grid_game_groundwork/plugin.cfg", "res://tests/editor_harness/plugin.cfg")')
            (target / "project.godot").write_text(project, encoding="utf-8")
            plugin = target / "tests/editor_harness/plugin.gd"
            harness = plugin.read_text(encoding="utf-8")
            start = harness.index("func run() -> void:")
            end = harness.index("func mode_key(", start)
            plugin.write_text(harness[:start] + ENTRY + harness[end:], encoding="utf-8")
            command = [executable, "--path", str(target), "--editor", "--quit-after", "1200"]
            if args.headless:
                command.append("--headless")
            elif args.screen is not None:
                command.extend(["--screen", str(args.screen)])
            if args.position is not None:
                command.extend(["--position", args.position])
            environment = os.environ.copy()
            if os.name == "nt" and not args.headless:
                environment["GGG_POINTER_HELPER"] = str(Path(__file__).resolve())
                environment["GGG_POINTER_PYTHON"] = sys.executable
            if args.position is not None and os.name == "nt":
                user32 = native_window_api()
                process = subprocess.Popen(command, cwd=target, env=environment,
                                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                           text=True, encoding="utf-8")
                captured = []
                reader = threading.Thread(target=lambda: captured.extend(process.stdout), daemon=True)
                reader.start()
                x, y = map(int, args.position.split(","))
                placed = False
                try:
                    for attempt in range(600):
                        hwnd = select_editor_window(user32, process.pid)
                        if hwnd is not None:
                            user32.ShowWindow(hwnd, 9)  # Restore before moving.
                            user32.SetWindowPos(hwnd, 0, x, y, 1500, 900, 0x4004)
                            time.sleep(0.1)
                            rect = wintypes.RECT()
                            user32.GetWindowRect(hwnd, ctypes.byref(rect))
                            if abs(rect.left - x) < 10 and abs(rect.top - y) < 10:
                                print(f"NATIVE_WINDOW: desktop=({rect.left},{rect.top})", flush=True)
                                placed = True
                                break
                        if process.poll() is not None:
                            break
                        time.sleep(0.05)
                    if not placed:
                        process.kill()
                        process.wait()
                        reader.join()
                        print("".join(captured), flush=True)
                        raise SystemExit("INPUT_SETUP: could not place Godot on the requested display")
                    process.wait(timeout=180)
                    reader.join()
                    output = "".join(captured)
                    print(output, end="", flush=True)
                    if process.returncode or re.search(r"SCRIPT ERROR:|^ERROR:|[1-9][0-9]* failures", output, re.M):
                        raise SystemExit(process.returncode or 1)
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait()
                        reader.join()
            else:
                output = run(command, cwd=target, env=environment)
            if "PAINT_MODE_PREVIEW: 0 failures" not in output:
                raise SystemExit("Editor input test did not complete")
    print("All editor input runs passed.")


if __name__ == "__main__":
    main()
