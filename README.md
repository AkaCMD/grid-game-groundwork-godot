# Grid Game Groundwork for Godot

**English** | [简体中文](README.zh-CN.md)

A Godot addon for making 3D grid puzzles. Paint levels, playtest, and build mechanics with GDScript. Includes Sokoban, pipe-connection and QUACK!!! on ICE examples.

**Godot 4.6+ Standard · Compatibility renderer · Tested with 4.7.2**

![Movement, crate and L-shaped pushing, falling, undo, and redo](docs/media/gameplay.gif)

## Quick start

1. Import `project.godot` in Godot.
2. Open **Grid Levels** in the top toolbar. If missing, enable **Grid Game Groundwork** under **Project → Project Settings → Plugins**.
3. Click **Open…** and choose `examples/levels/sokoban.tres` or `pipes.tres` / `quack.tres` in the same folder.
4. Use **1 / 2 / 3** for Paint / Erase / Select. In Select, drag an XYZ arrow or plane handle to move by whole cells; press **End** to snap down.
5. Click **Save**, then **Playtest ▶**.

Press **F5** to play Sokoban directly, or open `examples/pipes.tscn` and press **F6** for pipes. In Sokoban, press **S twice** from the start to push a crate onto the lower landing.

![Paint and erase, select an entity, drag its XYZ handles with grid snapping, press End to snap down, and undo/redo the whole move](docs/media/authoring.gif)

Switch tools with **1** (Paint), **2** (Erase), and **3** (Select). Drag to paint or erase; click to select and inspect an entity.

In **Select**, drag **X/Y/Z arrows** or **XY/XZ/YZ plane handles** to move the whole entity with **one-cell snapping**. Coordinates follow the preview; invalid destinations turn red and restore the original position on release. **Esc** cancels, and each completed drag is one undo/redo action. Godot's **Y axis remains height**.

### Snap to ground (End)

1. Press **3** for **Select**, then click the entity to move.
2. Drag an XYZ arrow or plane handle to place the entity above its destination.
3. **Keep the left mouse button held and press End**. The entity snaps down to the nearest ground, crate, or wall top, keeping X/Z unchanged and aligning Y to whole grid cells.
4. Continue dragging if needed, then **release the left mouse button** to commit the whole operation. **Esc** restores the position before dragging; **Ctrl/Cmd+Z** undoes the completed operation as a whole.

**End also works without dragging**: select an entity and press End to commit one undoable snap immediately, without clicking Apply. Multi-cell entities move as a whole and stop when any occupied cell has solid support. This also works when level gravity is disabled.

If there is no solid support below, or the current position overlaps another solid or is otherwise invalid, End leaves the position unchanged and shows a single-line status message. An already supported entity adds no undo action. While editing text or coordinates, End keeps the input field's normal behavior.

## QUACK!!! on ICE — 3D example

A standalone two-platform puzzle inspired by [QUACK!!! on ICE — play the original](https://akacmd.itch.io/quack-on-ice) ([original source code](https://github.com/AkaCMD/Bevy_Jam_4)). Control three ducks, slide to eat bread, drop between platforms, and use fed ducks as stoppers to help the others.

![QUACK!!! on ICE 3D example: three ducks on two platforms, with white cube backgrounds and the selected duck highlighted in black](docs/media/quack.png)

Open [examples/quack.tscn](examples/quack.tscn) and press **F6** to play, or open [examples/levels/quack.tres](examples/levels/quack.tres) in **Grid Levels** to edit, save and playtest. Click a duck to select it; **WASD / arrows** slide in fixed board directions, and **Z / Y / R** undo, redo and restart. See the [verified seven-move walkthrough](docs/quack-example.md).

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
| Select | **Shift+click** | Toggle an entity in the selection; plain click replaces it, plain empty click clears it |
| Select | Left-drag an **X/Y/Z arrow** or **XY/XZ/YZ square** | Move along an axis or within a plane, snapped to whole cells |
| Select, one entity, idle or dragging | **End** | Snap down to the nearest solid support; continue dragging afterward |
| Active move | **Esc** | Cancel the whole drag, including any End snap |
| Level editor | Right click | Pick an entity's definition, rotation, and mirroring for the brush |
| Editor workspace | **Page Up / Page Down** | Raise/lower the placement plane by one cell without moving the camera |
| Editor viewport | **WASD** / **Q / E** | Fly relative to the view / descend or ascend along world Y; no mouse button required |
| Editor viewport | Right drag | Look around in place; release restores the cursor |
| Editor viewport | **Right button + wheel** | Increase / decrease flight speed |
| Editor navigation | **Esc** | Stop movement and release the cursor |
| Shape editor | **1 / 2**, left click / drag | Add / remove occupied cells; **3** is ignored |
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

In **Select**, hold **Shift** and click to add or remove entities. Shift-clicking empty space keeps the selection; an ordinary click selects just that entity, or clears the selection on empty space. All selected entities are highlighted, with the movement gizmo on the last selected entity. Dragging moves the whole group with preserved spacing; an invalid destination marks the group red and rejects the entire move. **Duplicate selected** copies the group one cell right and lifts all copies together to the first free position, then selects the copies. **Delete selected** removes the group. Each group operation is one undo action. Selection itself is not undoable; undoing deletion restores entities without selecting them. Multiple selection disables individual position, rotation, mirror, overrides and **End** snap. Opening another level or entering shape editing clears selection.

Selected entities breathe blue on their actual model surfaces, retaining their textures. Erase hides blue selection feedback while preserving the selection, and the entity under the pointer breathes red; leaving it clears the red feedback. Invalid move destinations use steady red. Highlights respect occlusion. Select and Erase hit the nearest visible model surface, including parts outside occupied cells, and pass through model holes and fully transparent standard-material pixels. QUACK white backgrounds remain opaque and pickable; the editor no longer turns selected ducks black. Paint placement and gameplay occupied cells are unchanged.

With the editor viewport focused, **WASD** flies along the current view and **Q/E** descends/ascends along world Y, without holding a mouse button. Right-click still picks brush settings; drag the right button to look around, or hold it and scroll to change flight speed (default 8 cells/s). Cameras can pass through entities and below the board. Flight and pan carry the placement plane vertically with the camera, snapping Height to whole cells; rotation and zoom preserve it. **Page Up / Page Down** adjusts placement height independently by one cell. Release a movement key to stop; **Esc**, focus loss, dialogs, and leaving the workspace stop navigation. Finish painting or dragging an entity before navigating; brush previews stay hidden during navigation.

**1/2/3** and **End** require focus in Grid Levels and no modifier keys; they are ignored in text, coordinate, and Inspector property fields or modal dialogs. Tool switching waits until the current mouse stroke/drag ends. **End** works only in Select with one entity selected. Click the board before using viewport shortcuts. In play, click the game window for keyboard focus. Godot's run/stop keys use its [default editor keymap](https://docs.godotengine.org/en/4.6/tutorials/editor/default_key_mapping.html) and can be customized.

## Use in your project

Copy `addons/grid_game_groundwork/` into your project's `addons/` folder and enable the plugin. To run a level, attach `addons/grid_game_groundwork/runtime/game.gd` to a `Node3D` and assign its **Level** resource.

## Documentation

- [Designer guide](docs/designer-guide.md) — author levels and configure entities.
- [Extension guide](docs/extending.md) — add mechanics and pushing rules.
- [Development](docs/development.md) — run checks and export builds.
- [Domain language](CONTEXT.md) · [Design decisions](docs/adr)

Inspired by Corey Martin's [Grid Game Groundwork for Unity](https://github.com/corey-martin/grid-game-groundwork). See [third-party notices](THIRD_PARTY_NOTICES.md).
