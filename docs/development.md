# Development

**English** | [简体中文](development.zh-CN.md) · [README](../README.md)

Run commands from the repository root. Use Godot Standard with Compatibility rendering, as configured in [project.godot](../project.godot). The checks below passed with Godot 4.7.2 (`ed1daf0bf`) on 2026-10-25.

## Checks

```sh
python3 tools/check.py --godot /path/to/godot
python3 tools/check.py --godot /path/to/godot --editor-smoke
```

[The runner](../tools/check.py) imports and typechecks scripts, then checks gameplay, authoring/save-load, selection, strokes, QUACK, runtime, the generic model and three extension examples. `--editor-smoke` also checks the editor workflow in a disposable project. Executable lookup uses `--godot`, then `GODOT`, then `godot` on PATH. On Windows, use `python` and set `PYTHONUTF8=1` if output encoding fails.

For screenshots and surface rendering checks, use a graphical display:

```sh
python3 tools/check.py --godot /path/to/godot --editor-smoke --screenshot artifacts/editor.png
```

Headless checks cannot verify highlight pixels or shader coverage. See [editor surface coverage](editor-surface-coverage.md).

For focused Paint input checks, run [tools/check_editor_input.py](../tools/check_editor_input.py) with `--help` for options. Graphical input checks move the OS cursor: run them sequentially and leave mouse, keyboard and focus alone. `INPUT_SETUP` identifies setup failures. [tests/test_editor_input_runner.py](../tests/test_editor_input_runner.py) checks the native-window runner without native input.

## Export

Install export templates matching your Godot version, then run:

```sh
mkdir -p build/linux build/web
godot --headless --path . --export-release "Linux Desktop" build/linux/grid-game.x86_64
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server --directory build/web 8000
```

Open [localhost:8000](http://localhost:8000) for the Web build. The [Web preset](../export_presets.cfg) uses single-threaded Compatibility rendering and requires HTTP serving. Change the project's main scene to export another level. Add Windows/macOS presets through Godot's Export dialog.

## Regenerate examples

These commands overwrite authored example resources:

```sh
godot --headless --path . --script tools/create_examples.gd
godot --headless --path . --script tools/create_quack.gd
godot --headless --path . --script tools/create_generality_examples.gd
```

[create_examples.gd](../tools/create_examples.gd) rebuilds Sokoban and pipes; [create_quack.gd](../tools/create_quack.gd) rebuilds QUACK. [create_generality_examples.gd](../tools/create_generality_examples.gd) rebuilds rolling, gravity and linked mechanisms. Re-run checks afterward. Sprite licensing is in the [third-party notices](../THIRD_PARTY_NOTICES.md#quack-on-ice-sprites).

## Movement timing

[GGGame](../addons/grid_game_groundwork/runtime/game.gd) buffers up to four fresh direction presses during animation. Set `step_duration` (default 0.12 s) and `buffered_step_duration` (default 0.06 s) to tune normal and rapid-input animations. Held repeats do not fill the buffer; undo/redo/restart clear it and wait for the current action to finish.
