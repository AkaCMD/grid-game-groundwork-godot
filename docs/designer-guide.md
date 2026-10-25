# Designer guide

**English** | [简体中文](designer-guide.zh-CN.md) · [README](../README.md)

Edit the starting layout in [Grid Levels](../addons/grid_game_groundwork/editor/panel.gd), then test it in a separate play session. Custom mechanics are covered in the [extension guide](extending.md).

## Create, save and playtest

Open **Grid Levels** in Godot's top toolbar. If missing, enable **Grid Game Groundwork** in **Project → Project Settings → Plugins**.

1. Choose **File → New level**, or **File → Open…** for an existing `.tres`.
2. Choose a definition in the left palette and paint in the viewport.
3. Click **Save**, or **File → Save as…** for a new file or layout copy.
4. Click **Playtest** to test; **Stop** returns to editing.

New levels have a default palette but no ground or game rule. Playtest includes unsaved edits and never changes the authored level. Save to keep edits after closing Godot. A `*` marks unsaved changes; New/Open asks before discarding them. The editor remembers the last saved level.

Use the right sidebar for **Selected entity** and **Level** settings. **Help** lists shortcuts; **Details** shows the full last operation result.

## Paint and build

**Y is height; XZ is horizontal.** Occupied cells use integer coordinates. Ground commonly sits at `Y=-1`, with players and goals at `Y=0`.

| Tool | Use |
| --- | --- |
| **Paint (1)** | Click/drag to place the selected definition; the ghost previews its full shape. |
| **Erase (2)** | Click/drag over a model to remove its entire entity. |
| **Select (3)** | Click an entity to inspect or move it; empty click clears selection. |
| Right click | Pick the entity's definition, rotation and mirroring into the brush. |
| **Quarter turns / Mirror brush** | Rotate around Y in 90° increments / mirror on local X. |

Paint snaps to occupied-cell tops and sides, including non-solid entities. Empty space uses **Height**. Overlapping solids automatically rise until the full shape fits; non-solids can share cells. Each stroke keeps its starting surfaces, visits each target once and forms one undo action. Start another stroke to add a layer.

**Q/E** adjusts the preview one world-Y cell per press, starting from its displayed position, including automatic lifting. Release the mouse first; held keys do not repeat. The offset follows the surface under the pointer, or Height in empty space. Solid overlap or cells at/below **Fall-out height** turn the preview red and prevent placement. After adjustment, height stays exact even at zero offset. Leaving Paint, changing definitions or opening a level resets automatic stacking; rotation and mirroring keep the offset.

For **Level → Fill ground**, select a single-cell definition with `ground=true`, then set Height, Width and Depth. The rectangle starts at `X=0, Z=0`, skips solid cells and is one undo action. Height is shared with the toolbar.

**Level → Transform entire level** rotates or mirrors all positions and orientations as one undoable edit.

## Select and move

**Shift+click** toggles entities; Shift-clicking empty space keeps selection. Plain click selects one entity or clears selection on empty space. The last selected entity anchors the gizmo.

- Drag X/Y/Z arrows or XY/XZ/YZ squares to move in whole cells. Groups keep relative positions. Only the destination is checked, so moves can cross obstacles.
- Release commits one edit. Invalid destinations turn red and restore the group. **Esc**, hiding Grid Levels or losing window focus cancels a drag.
- **Duplicate** copies the group along +X, lifting together if needed, and selects the copies. A failed duplicate creates nothing. Click **Delete**, or press it in Select, to remove the group.

Selection is outside undo history. Undoing deletion restores entities without selecting them. Opening a level or entering shape editing clears selection. Multi-selection disables individual transforms, overrides and End snap.

### Snap down with End

In Select, choose one entity and press **End** to lower its complete shape onto the nearest solid support, keeping X/Z. Any supported cell holds the shape; gravity may be off. Missing support, invalid starts or already supported entities leave position/history unchanged.

During a drag, End can change Y even with an X/Z handle. Release commits the drag and snap together; Esc cancels both. Outside a drag, End applies immediately.

### Model feedback and picking

Selection pulses blue; Erase hides selection feedback and pulses red on hover. Invalid moves stay red. Select/Erase pick visible model surfaces, including geometry outside occupied cells, and pass through supported transparency. Paint uses logical occupied-cell faces. See [custom-material limits](editor-surface-coverage.md).

QUACK's white backgrounds are opaque. Editor selection uses blue feedback; runtime selection turns the duck background black.

## Definitions, overrides and shapes

Placements share **entity definitions**. **Entity** (plus icon) creates one; **Import…** adds one; **Edit in Inspector** changes defaults. **Definition options → Save definition as…** saves a reusable `.tres`; definitions may also stay embedded.

[Saving](../addons/grid_game_groundwork/editor/level_authoring.gd) also writes external definitions and rule configuration. **Save as…** keeps these references, so shared changes can affect other levels. Default changes affect every placement inheriting that value.

To change one entity:

1. Select it and edit X/Y/Z, **Quarter turns** or **Mirrored**.
2. Add typed keys under **Property overrides**, such as float `weight=4.0`.
3. Click **Apply entity changes**; invalid destinations are rejected.

Removing a key restores inheritance. **Reset all overrides** clears the draft; Apply commits it. Copies keep overrides and orientation.

| Property | Meaning |
| --- | --- |
| `solid`, `movable`, `gravity` | Core occupancy, movement and gravity behavior; override the definition's flags. |
| `player` | Allows runtime actor selection. |
| `can_push`, `pushable` | Default push policy: actor may push / target may be pushed. |
| `transmits_push` | Whether a pushed entity can push another ahead; default crates, including L-shaped crates, allow chains. |
| `strength`, `weight` | With `GGStrengthPushRule`, actor strength must cover the combined weight of pushed entities. |

Other keys belong to game rules. See [custom pushing](extending.md#custom-pushing).

### Edit occupied cells

Choose a definition and enable **Edit occupied cells**. Use **1/2** to add/remove cells at **Height**; change Height to build in 3D. The final cell cannot be removed. **Return to level** restores the previous tool; Select and Level settings are disabled during shape editing.

Shape edits affect all placements sharing the definition and support undo. Use **Validate** to check overlaps. **Visual Scene** is a separate `Node3D` scene: meshes and colliders never define occupied cells.

## Camera and shortcuts

Focus the viewport. **WASD** flies relative to the view; right-drag looks; right+wheel adjusts speed (default 8, range 0.25-128 cells/s). **Q/E** changes Paint height or selected entities; right+Q/E always flies vertically. Without Paint or a selection, Q/E flies directly.

Flight and Shift+middle pan move the Height plane vertically; orbit and zoom preserve it. **Page Up/Down** changes Height independently. Finish strokes and drags before navigating. Esc, dialogs, focus loss or leaving Grid Levels stop navigation.

### Shortcut reference

| Context | Input | Action |
| --- | --- | --- |
| Editor | **1 / 2 / 3**, number row or keypad | Paint / Erase / Select |
| Editor | Left click / drag | Use current tool |
| Select | **Shift+click** | Toggle selection |
| Select, one or more entities | **Delete** | Delete selection |
| Paint viewport, idle | **Q / E** | Lower/raise brush height offset one cell per press |
| Select viewport, one or more entities, idle | **Q / E** | Lower/raise selection one cell per press |
| Select | Drag an axis / plane handle | Move selection by whole cells |
| Select, one entity | **End**, idle or dragging | Snap down to support |
| Active move | **Esc** | Cancel the complete move |
| Editor | Right click | Pick brush settings |
| Editor viewport | **WASD**, **Q/E** (right+Q/E in Paint or with selection) | Fly relative to view; down/up along Y |
| Editor viewport | Right drag / right+wheel | Look / adjust flight speed |
| Editor workspace | **Page Up / Page Down** | Raise/lower placement height |
| Editor navigation | **Esc** | Stop and release cursor |
| Shape editor | **1 / 2**, left click / drag | Add / remove cells |
| Editor | **Ctrl/Cmd+S** | Save |
| Editor | **Ctrl/Cmd+Z** | Undo |
| Editor | **Ctrl/Cmd+Shift+Z** or **Ctrl/Cmd+Y** | Redo |
| Editor or play | Middle drag / **Shift+middle drag** | Orbit / pan |
| Editor or play | Wheel / **F** | Zoom / frame level |
| Play | Click a player entity | Select actor, while idle |
| Play | **WASD / arrows** | Move in fixed board directions: W −Z, S +Z, A −X, D +X |
| Play | **Z / Y / R**, or HUD buttons | Undo / redo / restart |

Tool keys, Delete and End require Grid Levels focus and no modifiers. Text/property fields and dialogs keep normal behavior. Tool-switch presses during strokes/drags are ignored. Viewport shortcuts need viewport focus.

Editor undo covers strokes, entity/group edits, shapes, fills, settings and transforms. Inspector defaults use Godot's resource editing/undo.

## Rules, validation and play

In **Level**, set Title, **Enable gravity** and **Fall-out height**, then **Apply level settings**. **Game rule** changes apply immediately; inspect its resource to configure pushing.

Place ground explicitly. With gravity, support below any occupied cell holds the entire rigid entity; overhangs do not tip. Unsupported stacks fall together. Players falling out fail; other entities are removed from the attempt. Undo restores them.

| Rule | Goal |
| --- | --- |
| Sokoban | Cover every goal cell with a crate; at least one goal is required. Extra crates may remain. |
| Pipes | Connect every destination to a source through reciprocal ports; connected pipes light up. |
| QUACK | Consume all bread. [Rules and walkthrough](quack-example.md). |
| No rule | Test movement and gravity without a victory condition. |

[Validate](../addons/grid_game_groundwork/data/level.gd) checks resource structure, IDs, shapes, solid overlap and the fall-out boundary. Save and Playtest run the same checks. Validation does not establish solvability.

During play, click a player while idle to switch actors; foreground cells can block picking. Selection survives undo/redo/restart while the actor exists. Camera rotation never changes movement directions. Rapid taps buffer up to four moves; held repeats do not build a backlog.

**Z** undoes a complete action, including pushes, falls and mechanic state. **Y** redoes it; **R** restarts, and restart is undoable. History remains available after success/failure. History commands clear buffered moves and wait for the current action to finish. Connect [completion/failure signals](extending.md#visuals-and-lifecycle) for custom progression.
