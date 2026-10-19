# Designer guide

**English** | [简体中文](designer-guide.zh-CN.md) · [README](../README.md)

## Create, save and playtest

Open **Grid Levels** in Godot. Use **File → New level** for a default palette, or **File → Open…** for an existing `.tres`. Choose a definition in the palette, paint, **Save** / **File → Save as…**, then **Playtest**. **Stop** returns to editing.

Playtest uses a temporary copy, including unsaved edits. Movement, falls and gameplay history never change the authored level. Save to keep your edits after closing Godot. A `*` marks unsaved changes; opening or creating another level asks before discarding them. The workspace remembers the last saved level across editor sessions.

The left sidebar holds entity definitions. The visible **Paint / Erase / Select** buttons show the current tool; brush rotation and mirroring appear in Paint. The right sidebar separates **Selected entity** from **Level** settings. Both sidebars scroll and can be resized. Below the viewport, a short tool hint and **Help** replace the full shortcut list. Operation results stay in the bottom status line while pointer coordinates update separately; **Details** opens the complete result. Stop is disabled when no scene is running.

## Paint and build

Godot's **Y axis is height**; horizontal gameplay uses **XZ**. All occupied cells have integer coordinates. A common layout puts ground at `Y=-1` and players/goals at `Y=0`.

| Tool | Use |
| --- | --- |
| **Paint (1)** | Click or drag to place the selected definition. The ghost previews its complete rotated/mirrored shape. |
| **Erase (2)** | Click or drag over a model to remove its entire entity, including all occupied cells. |
| **Select (3)** | Click an entity to inspect or move it. Plain empty click clears selection. |
| Right click | Copy an entity's definition, quarter turns and mirroring into the brush. |
| **Quarter turns / Mirror brush** | Rotate around Y in 90° increments / reflect the shape on local X. |

Paint snaps to solid occupied-cell faces, including elevated tops and sides. Empty space uses the **Height** plane. Solid placements rise to the first free height if they overlap another solid; non-solid entities such as goals can share cells. Each stroke uses its starting surfaces and paints each target once, preventing accidental towers. Release and start another stroke to add a layer. One stroke is one undo action.

In **Level → Fill ground**, choose a single-cell definition with `ground=true`, set **Height**, **Width** and **Depth**, then **Fill ground**. Height stays synchronized with the toolbar placement plane. The rectangle begins at `X=0, Z=0` and skips occupied solid cells. One fill is one undo action.

Under **Level → Transform entire level**, **Rotate level 90°** and **Mirror level on X** transform positions and orientations together; the result can be saved and undone.

## Select and move

**Shift+click** toggles entities in a selection; Shift-clicking empty space keeps it. Plain click selects only the clicked entity. The movement gizmo sits on the last selected entity.

- Drag an **X/Y/Z arrow** along one world axis, or an **XY/XZ/YZ square** within a plane. X is red, Y green, Z blue. Edge-on handles hide; orbit to reach them.
- Movement snaps to whole cells. A group preserves relative spacing, shapes, orientations and overrides. Only the destination is checked, so dragging can cross obstacles.
- A valid release commits immediately as one undo action. Invalid destinations turn steady red and restore the whole group on release. **Esc**, hiding the workspace or losing window focus cancels an unfinished move. No movement adds no history.
- **Duplicate** copies the group one cell right, lifting the copies together to the first free height if needed, and selects them. A failed duplicate creates nothing. **Delete** or **Delete** in Select mode removes the group. Each operation is one undo action.

Selection itself is not undoable; undoing deletion restores entities without selecting them. Opening another level or entering shape editing clears selection. Multi-selection disables individual coordinates, orientation, overrides and End snap.

### Snap down with End

With **one entity selected** in Select, press **End** to lower it onto the nearest solid support without changing X/Z. Ground, walls and crates can support it; non-solid markers cannot. The whole rotated/mirrored shape moves, stopping when any occupied cell is supported. Gameplay gravity may be off.

During a drag, keep the left button held and press End. You can keep dragging with the same handle; the snap changes Y even with an X/Z constraint. Release to commit the drag and snap together, or Esc to cancel both. Outside a drag, End commits immediately; **Apply entity changes** is unnecessary.

No support, an invalid starting position or an already supported entity leaves the position/history unchanged. The status line explains failures; hover it for full details.

### Model feedback and picking

Selected model surfaces breathe blue while retaining textures. Erase preserves the selection, hides its blue feedback, and shows red breathing on the hovered entity. Invalid moves use steady red. Highlights respect occlusion.

Select/Erase pick the nearest visible model surface, including geometry outside occupied cells, and pass through holes and transparent pixels in supported materials. QUACK's white backgrounds are opaque and pickable; editor selection uses blue feedback, while runtime selection turns a duck's background black. Paint uses logical cell faces. Artwork never changes gameplay occupancy. Custom shader support and limits are in [editor surface coverage](editor-surface-coverage.md).

## Definitions, overrides and shapes

The palette holds reusable **entity definitions**, shared by placements. Use **+ Entity** to create one, **Import…** to add an existing definition, **Edit in Inspector** to change defaults, and **Definition options → Save definition as…** to save a reusable `.tres`. Definitions can also remain embedded in a level. Saving a level saves its externally referenced definitions and game-rule configuration too.

A definition supplies its occupied cells, solid/movable/gravity flags, color, optional **Visual Scene**, and game-specific properties. Changes affect every placement inheriting that value.

To change just one entity:

1. Select it and edit X/Y/Z, **Quarter turns**, or **Mirrored** in the **Selected entity** tab.
2. Expand **Property overrides** and add only keys to replace, with typed values, such as `weight` as a float `4.0`.
3. Click **Apply entity changes**. Invalid destinations are rejected.

Removing an override key restores inheritance. **Reset all overrides** clears the draft; click Apply to commit. Duplication preserves overrides and orientation.

| Property | Meaning |
| --- | --- |
| `solid`, `movable`, `gravity` | Core occupancy, movement and gravity behavior; override the definition's flags. |
| `player` | Allows runtime actor selection. |
| `can_push`, `pushable` | Default push policy: actor may push / target may be pushed. |
| `transmits_push` | Whether a pushed entity can push another ahead; default crates, including L-shaped crates, allow chains. |
| `strength`, `weight` | With `GGStrengthPushRule`, actor strength must cover the combined weight of pushed entities. |

Game-specific keys are interpreted by rules. Chain pushing is configured per entity rather than by a level-wide toggle. See [custom pushing](extending.md#custom-pushing).

### Edit occupied cells

Choose a definition and enable **Edit occupied cells**. **1** adds cells; **2** removes them by click/drag at **Height**; **3** is ignored. Change height to build a 3D shape. The last cell cannot be removed. Use **Return to level** (or disable the toggle) to restore the previous level tool. A banner identifies the shared definition; Select and the Level tab are disabled in shape editing.

Shape changes affect all placements sharing the definition and can be undone. Check for new overlaps with **Validate**. Artwork is separate: assign a `Node3D` **Visual Scene** whose origin matches the entity origin. Meshes and colliders do not define occupied cells.

## Camera and shortcuts

Focus the viewport before navigating. **WASD** flies relative to the view without holding a mouse button; **Q/E** moves along world Y. In Select mode with entities selected, each **Q/E** press lowers/raises the entire selection by one cell instead. Holding the key does not repeat the move. Relative positions are preserved; an invalid destination rejects the whole move, and each successful move is one undo action. Finish dragging before using this shortcut. Hold the right mouse button with **Q/E** to fly the camera while entities are selected. Right-drag looks around without moving. Right+wheel adjusts speed (default 8, range 0.25–128 cells/s). Cameras pass through entities and below the board.

Flight and Shift+middle pan carry the placement plane vertically, snapping Height to whole cells. Orbit and zoom preserve Height. **Page Up/Down** changes Height independently by one cell; manual Height changes become the new starting plane.

Finish painting or moving entities before navigating. Navigation hides brush previews. Releasing keys stops flight; Esc, dialogs, focus loss and leaving the workspace stop navigation and release the cursor.

### Shortcut reference

| Context | Input | Action |
| --- | --- | --- |
| Editor | **1 / 2 / 3**, number row or keypad | Paint / Erase / Select |
| Editor | Left click / drag | Use current tool |
| Select | **Shift+click** | Toggle selection |
| Select, one or more entities | **Delete** | Delete selection |
| Select viewport, one or more entities, idle | **Q / E** | Lower/raise selection one cell per press |
| Select | Drag an axis / plane handle | Move selection by whole cells |
| Select, one entity | **End**, idle or dragging | Snap down to support |
| Active move | **Esc** | Cancel the complete move |
| Editor | Right click | Pick brush settings |
| Editor viewport | **WASD**, **Q/E** (right+Q/E with selection) | Fly relative to view; down/up along Y |
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

Tool keys, Delete and End require focus in Grid Levels and no modifiers; text/property inputs and dialogs retain their normal behavior. Tool switching waits for the mouse stroke/drag to end. Viewport shortcuts require viewport focus. Use Godot's **Run Project**, **Run Current Scene** and **Stop** controls for standalone examples; their key bindings depend on your editor settings.

Editor undo covers strokes, entity edits, group moves/copies/deletes, shapes, floor fills, level settings and whole-level transforms. Shared defaults edited in Godot's Inspector use Godot's native resource editing/undo workflow.

## Rules, validation and play

In the **Level** tab, set title, **Enable gravity** and **Fall-out height**, then click **Apply level settings**. Choose an optional **Game rule** resource; inspect it to configure its push rule. Rule changes apply immediately; the other level settings require Apply.

Ground must be placed explicitly. With gravity enabled, support beneath any one occupied cell holds the entire rigid entity; overhangs do not tip. Unsupported stacks fall together. Players falling out fail; other entities are removed from that attempt. Undo can restore them.

| Rule | Goal |
| --- | --- |
| Sokoban | Every goal cell must have a crate, with at least one goal. Extra crates may remain; multi-cell crates can cover multiple goals. |
| Pipes | Every destination must connect to a source through reciprocal ports. Connected pipes light up. |
| QUACK | Feed all three ducks; slides, falls and feeding form one action. [Full rules and walkthrough](quack-example.md). |
| No rule | Test movement and gravity without a built-in victory condition. |

**Validate** checks schema, missing/invalid definitions and IDs, empty/duplicate shapes, solid overlap and placements at/below fall-out height. Save and Playtest also validate.

During play, click a player entity to switch actors while idle; foreground occupied cells can block picking. Selection survives undo/redo/restart while the actor exists. Camera rotation never changes movement directions. Rapid presses buffer up to four moves and accelerate animation; held repeats do not build a backlog. Undo/redo/restart clear buffered input and wait for the current action to finish.

**Z** restores a whole action: pushes, falls, removed entities and mechanic state. **Y** reapplies it. **R** restarts, and that restart is undoable. History remains available after success/failure. Campaigns and persistent progression belong to the consuming game; use the runtime's [completion/failure signals](extending.md#visuals-and-lifecycle) for your own flow.
