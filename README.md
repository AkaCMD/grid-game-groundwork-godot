# Grid Game Groundwork for Godot

**English** | [简体中文](README.zh-CN.md)

A Godot addon for making 3D grid puzzles. Paint levels, playtest, and build mechanics with GDScript. Includes Sokoban and pipe-connection examples.

**Godot 4.6+ Standard · Compatibility renderer · Tested with 4.7.2**

![Movement, crate and L-shaped pushing, falling, undo, and redo](docs/media/gameplay.gif)

## Quick start

1. Import `project.godot` in Godot.
2. Open **Grid Levels** in the top toolbar. If missing, enable **Grid Game Groundwork** under **Project → Project Settings → Plugins**.
3. Click **Open…** and choose `examples/levels/sokoban.tres` or `pipes.tres` in the same folder.
4. Choose **Paint**, **Erase**, or **Select**, then click or drag on the board. Click **Save**, then **Playtest ▶**.

Press **F5** to play Sokoban directly, or open `examples/pipes.tscn` and press **F6** for pipes. In Sokoban, press **S twice** from the start to push a crate onto the lower landing.

![Paint crates with a drag, erase crates, and select entities to inspect their properties](docs/media/authoring.gif)

Switch tools with **1** (Paint), **2** (Erase), and **3** (Select). Drag to paint or erase; click to select and inspect an entity.

## Features

- Visual level editor with painting, stacking, shape editing, and `.tres` saving.
- Grid movement, multi-cell entities, chain pushing, and gravity.
- Undo/redo for complete actions, including falls and restarts.
- Reusable entity definitions, per-entity overrides, and custom game rules.

## Controls

| Input | Action |
| --- | --- |
| Left click / drag | Use the active editor tool |
| Right click | Pick an entity in the editor |
| Ctrl/Cmd+S | Save the level |
| WASD / arrows | Move during play |
| Z / Y / R | Undo / redo / restart during play |
| Middle drag / Shift + middle drag | Orbit / pan |
| Wheel / F | Zoom / frame the level |

## Use in your project

Copy `addons/grid_game_groundwork/` into your project's `addons/` folder and enable the plugin. To run a level, attach `addons/grid_game_groundwork/runtime/game.gd` to a `Node3D` and assign its **Level** resource.

## Documentation

- [Designer guide](docs/designer-guide.md) — author levels and configure entities.
- [Extension guide](docs/extending.md) — add mechanics and pushing rules.
- [Development](docs/development.md) — run checks and export builds.
- [Domain language](CONTEXT.md) · [Design decisions](docs/adr)

Inspired by Corey Martin's [Grid Game Groundwork for Unity](https://github.com/corey-martin/grid-game-groundwork). See [third-party notices](THIRD_PARTY_NOTICES.md).
