# Designer guide

## The everyday loop

Open **Grid Levels**, open or create a level, choose an entity, paint, save, and playtest. Stop the playtest to continue editing. Gameplay never writes movements, falls, or undo history back to the authored resource. Unsaved edits can be playtested using a temporary copy, but still need **Save** if you want to keep them after closing Godot.

The title shows `*` when the workspace has unsaved changes. Opening another level or creating a new one asks before discarding edits. The workspace remembers the last saved level across editor sessions.

## Grid, ground, and height

Godot's **Y axis is height**; movement takes place on **XZ**. Entity cells use integer coordinates. A typical level has ground at `Y=-1`, entities and goals at `Y=0`, and its fall-out height below the lowest platform.

Ground is explicit: empty space beneath an entity is a gap, not an invisible floor. With gravity enabled, one supported occupied cell holds an entire entity rigidly. Overhangs do not tip. Unsupported stacks fall together. A player falling beyond the fall-out height fails the attempt; other entities disappear from that attempt, and undo can restore them.

**Height** sets the brush's starting Y coordinate. Camera flight and Shift+middle pan carry this plane vertically with the camera, snapped to whole cells; rotation and zoom keep it unchanged. **Page Up / Page Down** raises/lowers the plane by one cell without moving the camera. Manual Height changes become the starting height for subsequent movement. When a solid entity overlaps existing solids, its preview and placement rise to the first collision-free height. Its entire multi-cell shape is considered. Non-solid entities, such as goals, share cells without stacking upward.

**Fill ground** uses the selected single-cell ground definition, the current height, and a rectangle beginning at `X=0, Z=0`. Existing solid cells are skipped. One fill is one undo action.

## Entities and reusable defaults

The palette contains **entity definitions**. Select a definition, then paint instances of it into the level. A shared definition contains its occupied cells, solid/movable/gravity flags, color or visual scene, and game-specific default properties.

Use **Edit definition in Inspector** for defaults. Changing them affects every entity inheriting that value. Use **Save definition as…** to make the definition a reusable `.tres` asset, or **Import…** to add an existing definition to another level's palette. Unsaved definitions can be embedded in the level; saving a level also saves its externally referenced definitions and game-rule configuration.

To customize one entity:

1. Choose **Select**, then click the entity.
2. Adjust X/Y/Z, quarter turns, or mirroring on the right.
3. Expand **Overrides** and add just the property keys you want to replace. Godot's dictionary editor provides typed values; for example, add `weight` with a float value of `4.0`.
4. Click **Apply entity changes**. A solid-overlap or invalid placement is rejected without changing the entity.

Removing a key restores inheritance for that property. **Reset all overrides** clears the draft; click **Apply entity changes** to apply it. **Duplicate selected** copies overrides and orientation, starting one cell to the right and stacking if needed. Deleting or erasing removes the whole entity, including all occupied cells.

In **Select**, hold **Shift** and click to add or remove entities. Shift-clicking empty space keeps the selection; an ordinary click selects just that entity, or clears the selection on empty space. All selected entities are highlighted, with the movement gizmo on the last selected entity. Dragging moves the whole group with preserved spacing; an invalid destination marks the group red and rejects the entire move. **Duplicate selected** copies the group one cell right and lifts all copies together to the first free position, then selects the copies. **Delete selected** removes the group. Each group operation is one undo action. Selection itself is not undoable; undoing deletion restores entities without selecting them. Multiple selection disables individual position, rotation, mirror, overrides and **End** snap. Opening another level or entering shape editing clears selection.

Selected entities breathe blue on their actual model surfaces, retaining their textures. Erase hides blue selection feedback while preserving the selection, and the entity under the pointer breathes red; leaving it clears the red feedback. Invalid move destinations use steady red. Highlights respect occlusion. Select and Erase hit the nearest visible model surface, including parts outside occupied cells, and pass through model holes and fully transparent standard-material pixels. QUACK white backgrounds remain opaque and pickable; the editor no longer turns selected ducks black. Paint placement and gameplay occupied cells are unchanged.

In **Select**, drag an **X/Y/Z arrow** to move along one world axis, or an **XY/XZ/YZ square handle** to move within that plane. X is red, Y is green (height), and Z is blue. The handles sit at the last selected entity's authored origin, even for a multi-cell shape, and remain usable as you zoom. Handles viewed almost edge-on are hidden; orbit the camera to access them.

Movement snaps to **one whole grid cell while dragging**, and the right-side coordinates follow the preview. The entire entity moves together, preserving its shape, rotation, mirroring, and overrides. Only the destination is validated, so you can drag across obstacles to an empty space. Solid overlaps and other invalid destinations appear **red**; releasing there restores the original position. Non-solid entities can share occupied cells. Press **Esc** to cancel. A valid release commits immediately without **Apply entity changes**, and the whole drag is one undo/redo action. Cancelling or releasing without movement creates no undo action. Hiding the workspace or losing window focus cancels an unfinished move. Movement handles are available for one or more selected entities and are hidden in Paint, Erase, and occupied-cell editing.

With one entity selected, press **End** in Select to snap it **down along Y** onto the nearest solid support, keeping X/Z unchanged. Ground, wall tops, and crates can all support it; non-solid markers cannot. The complete rotated/mirrored shape is considered, and support under any occupied cell holds the entire entity. This editing shortcut works even with gameplay gravity disabled. If there is no support below, or the current position is invalid, the entity stays in place with a single-line status message; hover over the status for full details.

During a drag, **End** snaps the current preview and lets you continue with the same axis/plane handle without jumping back. The snap changes Y even when the handle is constrained to X/Z; subsequent mouse movement keeps the handle's original constraint. Release to commit the whole drag and snap as one undo action, or press **Esc** to restore the position before dragging. Outside a drag, End commits one undo action immediately. An already supported entity or a failed snap adds no history. End is ignored while typing in text, coordinates, or properties, with modifier keys, or while a modal dialog is open.

Core property keys are `solid`, `movable`, and `gravity`. Other properties are defined by game rules. The example presets use `player`, `can_push`, `pushable`, `transmits_push`, `strength`, and `weight`. These belong to entities, not a level-wide chain-pushing toggle. Default crates, including L-shaped crates, transmit pushes, matching the original Unity project: a player can push a chain when all destination cells are clear. Set `transmits_push=false` on an entity to prevent it from pushing another entity ahead of it.

Editor undo covers placements, brush strokes, selection edits, shape edits, floor fills, level settings, and whole-level transforms. Shared-default edits made in Godot's native Inspector use its native resource editing/undo workflow.

## Visual occupied-cell editor

Select a definition, then enable **Edit occupied cells**. The board changes to show that definition's shape around its origin. Left-click or drag to add cells at the current **Height**. Choose **Erase** (**2**) and left-click or drag to remove them. Change height to build a three-dimensional shape. The last occupied cell cannot be removed.

Turn off **Edit occupied cells** to return to the level. These edits affect the shared definition, so inspect the resulting level for overlaps and click **Validate** before saving. Shape edits can be undone.

The shape is gameplay data. Artwork is separate: assign **Visual Scene** on the definition to use a custom `Node3D` scene. Its origin should match the entity origin and its model should fit the occupied cells. Artwork and colliders never silently change the gameplay shape.

## Painting and navigation

**Paint** places the selected definition. A drag stroke is one editor undo step. **Erase** removes the entity under the pointer; **Select** opens it for editing. Right-click picks the definition, rotation, and mirroring from an existing entity. The ghost shows where the brush will place the entity after automatic stacking.

Press **1** for Paint, **2** for Erase, or **3** for Select anywhere in the Grid Levels panel. Both the number row and numeric keypad work, without modifier keys. Shortcuts are ignored while typing in text, coordinate, or property fields, while a dialog is open, and during a left-button stroke; release the mouse before switching. In **Edit occupied cells**, **1** adds cells and **2** removes them; **3** is ignored.

With the viewport focused, hold **WASD** to fly relative to the camera: looking down and pressing W descends, and looking up and pressing W ascends. **Q/E** moves down/up along world Y. No mouse button is required. Right-click retains the brush eyedropper; right-drag turns the camera in place. Hold right and scroll to adjust flight speed (default **8 cells/s**, range **0.25–128 cells/s**). Ordinary wheel still zooms. The camera passes freely through entities and below the board, can look up/down, and never rolls upside down.

Release a movement key to stop immediately. **Esc**, changing focus, opening a dialog, window focus loss, or leaving the workspace clears navigation and releases any captured cursor. Finish a paint stroke or entity drag before navigating. Navigation suppresses painting and hides the brush preview. Text, coordinate and Inspector fields retain their normal keyboard behavior; Ctrl/Cmd shortcuts do not move the camera.

Middle-drag orbits, Shift+middle-drag pans, the wheel zooms, and **F** or **Frame** fits the level. Quarter turns rotate around Y. **Mirror brush** reflects the entity's shape on local X. Whole-level rotation and mirroring transform entity positions and shapes together and survive saving/reloading.

## Shortcut reference

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

**1/2/3** and **End** require focus in Grid Levels and no modifier keys; they are ignored in text, coordinate, and Inspector property fields or modal dialogs. Tool switching waits until the current mouse stroke/drag ends. **End** works only in Select with one entity selected. Click the board before using viewport shortcuts. In play, click the game window for keyboard focus. Godot's run/stop keys use its [default editor keymap](https://docs.godotengine.org/en/4.6/tutorials/editor/default_key_mapping.html) and can be customized.

## Rules, validation, and playtesting

Select a **Game rule** resource in the right panel. `GGSokobanRule` completes when every original crate has at least one occupied cell on a goal. `GGPipeRule` completes when every destination has a reciprocal pipe connection to a source; connected pipes light up. A generic level with no rule can test movement and gravity but does not have a built-in win condition.

**Apply level settings** commits the title, gravity toggle, and fall-out height. **Validate** checks schema compatibility, missing definitions, empty/duplicate shapes, duplicate IDs, solid overlaps, and entities starting beyond the fall-out boundary. Saving and playtesting also validate.

During play, Z undoes an entire action including pushes, falls, removed entities, and mechanic state; Y redoes it. R restarts the level, and that restart can itself be undone. Undo also works after success or failure.

No level menu, unlocking, or persistent completion system is included. Each game can react to the runtime's completion/failure signals to provide its own flow.
