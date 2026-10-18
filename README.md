# Grid Game Groundwork for Godot

**English** | [简体中文](README.zh-CN.md)

A Godot addon for making 3D grid puzzles. Paint levels, playtest, and build mechanics with GDScript. Includes Sokoban and pipe-connection examples.

**Godot 4.6+ Standard · Compatibility renderer · Tested with 4.7.2**

![Movement, crate and L-shaped pushing, falling, undo, and redo](docs/media/gameplay.gif)

## Quick start

1. Import `project.godot` in Godot.
2. Open **Grid Levels** in the top toolbar. If missing, enable **Grid Game Groundwork** under **Project → Project Settings → Plugins**.
3. Click **Open…** and choose `examples/levels/sokoban.tres` or `pipes.tres` in the same folder.
4. Use **1 / 2 / 3** for Paint / Erase / Select. In Select, drag an XYZ arrow or plane handle to move by whole cells; press **End** to snap down.
5. Click **Save**, then **Playtest ▶**.

Press **F5** to play Sokoban directly, or open `examples/pipes.tscn` and press **F6** for pipes. In Sokoban, press **S twice** from the start to push a crate onto the lower landing.

![Paint and erase, select an entity, drag its XYZ handles with grid snapping, press End to snap down, and undo/redo the whole move](docs/media/authoring.gif)

Switch tools with **1** (Paint), **2** (Erase), and **3** (Select). Drag to paint or erase; click to select and inspect an entity.

In **Select**, drag **X/Y/Z arrows** or **XY/XZ/YZ plane handles** to move the whole entity with **one-cell snapping**. Coordinates follow the preview; invalid destinations turn red and restore the original position on release. **Esc** cancels, and each completed drag is one undo/redo action. Godot's **Y axis remains height**.

Press **End** while selected or dragging to snap down to the nearest solid support (ground, walls, or crates). Continue dragging after the snap; release commits the whole operation as one undo action, and **Esc** restores the position before dragging. Missing support or an invalid starting position leaves the entity in place with a single-line status message.

## Features

- Visual level editor with painting, stacking, shape editing, and `.tres` saving.
- Grid movement, multi-cell entities, chain pushing, and gravity.
- Undo/redo for complete actions, including falls and restarts.
- Reusable entity definitions, per-entity overrides, and custom game rules.

## Controls

| Context | Input | Action |
| --- | --- | --- |
| Level editor | **1 / 2 / 3** (number row or keypad) | Paint / Erase / Select |
| Level editor | Left click / drag | Paint or erase with the active tool; in Select, click an entity to inspect it |
| Select | Left-drag an **X/Y/Z arrow** or **XY/XZ/YZ square** | Move along an axis or within a plane, snapped to whole cells |
| Select, idle or dragging | **End** | Snap down to the nearest solid support; continue dragging afterward |
| Active move | **Esc** | Cancel the whole drag, including any End snap |
| Level editor | Right click | Pick an entity's definition, rotation, and mirroring for the brush |
| Shape editor | **1 / 2**, left click / drag | Add / remove occupied cells; **3** is ignored |
| Shape editor | Right click | Remove an occupied cell |
| Level editor | **Ctrl/Cmd+S** | Save the level |
| Level editor | **Ctrl/Cmd+Z** | Undo the last authoring action |
| Level editor | **Ctrl/Cmd+Shift+Z** or **Ctrl/Cmd+Y** | Redo the last authoring action |
| Editor viewport or play | Middle drag | Orbit the camera |
| Editor viewport or play | **Shift+middle drag** | Pan the camera |
| Editor viewport or play | Mouse wheel | Zoom in / out |
| Editor viewport or play | **F** | Frame the level |
| Play | **WASD / arrow keys** | Move on the grid |
| Play | **Z / Y / R** | Undo / redo / restart |
| Godot editor | **F5** (macOS: **Cmd+B**) | Run the project |
| Godot editor | **F6** (macOS: **Cmd+R**) | Run the current scene |
| Godot editor | **F8** (macOS: **Cmd+.**) | Stop the running project/scene |

**1/2/3** and **End** require focus in Grid Levels and no modifier keys; they are ignored in text, coordinate, and Inspector property fields or modal dialogs. Tool switching waits until the current mouse stroke/drag ends. **End** works only in Select. Click the board before using viewport shortcuts. In play, click the game window for keyboard focus. Godot's run/stop keys use its [default editor keymap](https://docs.godotengine.org/en/4.6/tutorials/editor/default_key_mapping.html) and can be customized.

## Use in your project

Copy `addons/grid_game_groundwork/` into your project's `addons/` folder and enable the plugin. To run a level, attach `addons/grid_game_groundwork/runtime/game.gd` to a `Node3D` and assign its **Level** resource.

## Documentation

- [Designer guide](docs/designer-guide.md) — author levels and configure entities.
- [Extension guide](docs/extending.md) — add mechanics and pushing rules.
- [Development](docs/development.md) — run checks and export builds.
- [Domain language](CONTEXT.md) · [Design decisions](docs/adr)

Inspired by Corey Martin's [Grid Game Groundwork for Unity](https://github.com/corey-martin/grid-game-groundwork). See [third-party notices](THIRD_PARTY_NOTICES.md).
