# Development

[README](../README.md) · [中文说明](../README.zh-CN.md)

## Checks

```sh
python3 tools/check.py --godot /path/to/godot
python3 tools/check.py --godot /path/to/godot --editor-smoke
```

The runner accepts `--godot`, the `GODOT` environment variable, or `godot` on PATH. Use Godot Standard with Compatibility rendering. The project declares Godot 4.7; the documented test version is 4.7.2.

The first command imports/typechecks scripts and runs session, authoring/save-load, editor selection, authoring stroke, QUACK and runtime checks. Selection and stroke checks exercise their modules directly without an editor window, including preview cancellation, atomic group edits, surface fitting, stroke revisits and undo grouping. The optional editor smoke check uses a disposable project to exercise editor operations, navigation, focus recovery, saving/reopening and playtest launch.

On Windows, a Steam installation can be used directly (adjust the Steam library path):

```powershell
$env:PYTHONUTF8 = "1"
python tools/check.py --godot "D:\Applications\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --editor-smoke
```

On a machine with a graphical display, capture the editor and run surface rendering checks too:

```sh
python3 tools/check.py --godot /path/to/godot --editor-smoke --screenshot artifacts/editor.png
```

Surface checks can also run separately after import:

```sh
godot --path . --script tests/test_editor_surfaces.gd --quit-after 1200
```

These checks need a graphical renderer; headless checks alone cannot verify highlight pixels or the shader coverage probe. See [editor surface coverage](editor-surface-coverage.md).

## Export

Install the export templates matching your Godot version, then run:

```sh
mkdir -p build/linux build/web
godot --headless --path . --export-release "Linux Desktop" build/linux/grid-game.x86_64
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server --directory build/web 8000
```

Open `http://localhost:8000` for the web build; opening the HTML directly from disk will not work. The web preset uses single-threaded Compatibility rendering. To ship a different level, change the project's main scene before exporting. Windows/macOS presets can be added in Godot's Export dialog.

## Regenerate examples

Run these only when intentionally replacing the authored example resources:

```sh
godot --headless --path . --script tools/create_examples.gd
godot --headless --path . --script tools/create_quack.gd
```

The first rebuilds Sokoban and pipes; the second rebuilds QUACK definitions and its level without changing the other examples. Re-run checks afterward. Original QUACK assets and licensing are described in the [example guide](quack-example.md#assets-and-rebuilding).

## Movement timing

Movement buffers up to four fresh direction presses during an animation and plays them in order. Rapid taps shorten stage animations from `step_duration` (default 0.12 s) to `buffered_step_duration` (default 0.06 s); held key repeats keep the normal pace without filling the buffer. Undo, redo, and restart clear pending movement and run after the current action finishes. Both durations can be tuned on `GGGame`.

## Scope

The addon focuses on designer authoring and independent levels. Campaigns, progression, player editors, community sharing, and Unity level import belong to future work or consuming games. Implementation scope is tracked in [GitHub issue #1](https://github.com/AkaCMD/grid-game-groundwork-godot/issues/1).
