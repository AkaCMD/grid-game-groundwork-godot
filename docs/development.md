# Development

[README](../README.md) · [中文说明](../README.zh-CN.md)

## Checks

```sh
python3 tools/check.py --godot /path/to/godot
python3 tools/check.py --godot /path/to/godot --editor-smoke
```

The first command imports/typechecks scripts, runs simulation and authoring/save-load checks, and smoke-tests both runtime scenes. The optional editor check uses a disposable project to exercise painting, shape edits, saving/reopening, and playtest launch. To capture the actual editor on a machine with a display, add `--screenshot artifacts/editor.png`.

## Export

Install the export templates matching your Godot version, then run:

```sh
mkdir -p build/linux build/web
godot --headless --path . --export-release "Linux Desktop" build/linux/grid-game.x86_64
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server --directory build/web 8000
```

Open `http://localhost:8000` for the web build; opening the HTML directly from disk will not work. The web preset uses single-threaded Compatibility rendering. To ship a different level, change the project's main scene before exporting. Windows/macOS presets can be added in Godot's Export dialog.

## Movement timing

Movement buffers up to four fresh direction presses during an animation and plays them in order. Rapid taps shorten stage animations from `step_duration` (default 0.12 s) to `buffered_step_duration` (default 0.06 s); held key repeats keep the normal pace without filling the buffer. Undo, redo, and restart clear pending movement and run after the current action finishes. Both durations can be tuned on `GGGame`.

## Scope

The addon focuses on designer authoring and independent levels. Campaigns, progression, player editors, community sharing, and Unity level import belong to future work or consuming games. Implementation scope is tracked in [GitHub issue #1](https://github.com/AkaCMD/grid-game-groundwork-godot/issues/1).
