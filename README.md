# Grid Game Groundwork for Godot

A reusable Godot addon for building 3D grid puzzles, with a visual level designer and standalone Sokoban and pipe-connection examples. Create entity definitions, paint levels, save, and playtest without writing code. Add new mechanics with small GDScript rules.

Requires **Godot 4.6+ Standard**, using the Compatibility renderer. Verified with Godot **4.7.2**. No .NET, physics engine integration, or third-party Godot addons are required.

## Start here

1. Import `project.godot` into Godot and let its first import finish.
2. Open the **Grid Levels** workspace in the top toolbar. If it is missing, enable **Grid Game Groundwork** under Project → Project Settings → Plugins.
3. Click **Open…** and choose `examples/levels/sokoban.tres` or `examples/levels/pipes.tres`.
4. Select an entity from the palette, then click or drag to paint. Painting into solid entities automatically stacks the new entity above them.
5. Click **Save**, then **Playtest ▶**. **Stop ■** returns to your authored arrangement.

Press **F5** to play Sokoban directly. Open `examples/pipes.tscn` and press **F6** to play the pipe example. These are independent levels, with no campaign or menu system.

Levels default to a high-angle perspective view in both the editor and gameplay, matching the original project's demo: visible block sides, no diagonal board rotation, and north (negative Z) toward the top of the screen. Middle-drag in the editor to inspect stacking from another angle.

For a blank level, click **New level**. Select **Ground**, set **Height** to **-1**, choose a floor width/depth, and click **Fill ground at current height**. Then set height to **0** and paint a player, crates, and goals. Choose a game rule in the right panel to give the level its win conditions; the example rules are available as `GGSokobanRule` and `GGPipeRule` resources.

See the [designer guide](docs/designer-guide.md) for the complete workflow and the [extension guide](docs/extending.md) for creating a game.

## Included

- Visual 3D board, entity palette, continuous painting, erasing, selection, eyedropper, rotation, mirroring, height control, and automatic stacking.
- Floor fill, duplication, whole-level rotation/mirroring, validation, editor undo/redo, native `.tres` saving/loading, and one-click playtests.
- Reusable entity definitions with per-entity overrides, a visual occupied-cell shape editor, and optional custom visual scenes.
- Exact grid movement, multi-cell entities, explicit ground, per-level gravity, overhang support, and falling into gaps.
- Custom game-defined push rules, with permission and strength/weight presets.
- Complete action undo/redo, including mechanic state, removed entities, failure, and restart. Restart itself can be undone.
- Solid and non-solid entities, including goals that share cells with crates.
- Independent Sokoban and pipe-network examples, primitive visuals, and desktop/web export presets.

Player editors, community sharing/import formats, Unity level import, progression, and saved campaign completion are deferred. This release concentrates on designer authoring and individual levels.

## Controls

| Context | Input | Action |
| --- | --- | --- |
| Level editor | Left click / drag | Paint, erase, or select using the active tool |
| Level editor | Right click | Pick an existing entity definition and orientation |
| Level editor | Middle drag | Orbit |
| Level editor | Shift + middle drag | Pan |
| Level editor | Wheel / F | Zoom / frame the level |
| Level editor | Ctrl/Cmd+S | Save |
| Level editor | Undo / Redo buttons | Undo or redo an entire brush stroke or edit |
| Shape editor | Left click / drag | Add occupied cells at the current height |
| Shape editor | Right click / Erase tool | Remove occupied cells |
| Game | WASD / arrows | Move on the XZ grid |
| Game | Z / Y / R | Undo / redo / restart |

## Use in another project

Copy `addons/grid_game_groundwork/` into the other project's `addons/` directory, enable the plugin, and open **Grid Levels**. The addon has no dependency on `examples/`. Copy an example rule separately if you want to use it.

To play a level in your own scene, add a `Node3D`, attach `addons/grid_game_groundwork/runtime/game.gd`, and assign its **Level** resource. `GGGame` provides `level_completed` and `level_failed` signals so your game can handle navigation and progression.

## Verify

```sh
python3 tools/check.py --godot /path/to/godot
python3 tools/check.py --godot /path/to/godot --editor-smoke
```

The first command imports/typechecks scripts, runs simulation and authoring/save-load checks, and smoke-tests both runtime scenes. The optional editor check uses a disposable project to exercise painting, shape edits, saving/reopening, and playtest launch. To capture the actual editor on a machine with a display, add `--screenshot artifacts/editor.png`.

Export with the matching Godot export templates installed:

```sh
mkdir -p build/linux build/web
godot --headless --path . --export-release "Linux Desktop" build/linux/grid-game.x86_64
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server --directory build/web 8000
```

Open `http://localhost:8000` for the web build; opening the HTML directly from disk will not work. The web preset uses single-threaded Compatibility rendering. To ship a different level, change the project's main scene before exporting. Windows/macOS presets can be added in Godot's Export dialog.

## Design and credit

Domain language lives in [CONTEXT.md](CONTEXT.md). Accepted design decisions live in [docs/adr](docs/adr). The implementation scope is tracked in [GitHub issue #1](https://github.com/AkaCMD/grid-game-groundwork-godot/issues/1).

Inspired by Corey Martin's [Grid Game Groundwork for Unity](https://github.com/corey-martin/grid-game-groundwork). This recreation uses Godot-native resources, independent grid state, and new editor/runtime code. The original project's MIT notice is retained in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
