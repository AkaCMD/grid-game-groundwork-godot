# Designer guide

## The everyday loop

Open **Grid Levels**, open or create a level, choose an entity, paint, save, and playtest. Stop the playtest to continue editing. Gameplay never writes movements, falls, or undo history back to the authored resource. Unsaved edits can be playtested using a temporary copy, but still need **Save** if you want to keep them after closing Godot.

The title shows `*` when the workspace has unsaved changes. Opening another level or creating a new one asks before discarding edits. The workspace remembers the last saved level across editor sessions.

## Grid, ground, and height

Godot's **Y axis is height**; movement takes place on **XZ**. Entity cells use integer coordinates. A typical level has ground at `Y=-1`, entities and goals at `Y=0`, and its fall-out height below the lowest platform.

Ground is explicit: empty space beneath an entity is a gap, not an invisible floor. With gravity enabled, one supported occupied cell holds an entire entity rigidly. Overhangs do not tip. Unsupported stacks fall together. A player falling beyond the fall-out height fails the attempt; other entities disappear from that attempt, and undo can restore them.

**Height** sets the brush's starting Y coordinate. When a solid entity overlaps existing solids, its preview and placement rise to the first collision-free height. Its entire multi-cell shape is considered. Non-solid entities, such as goals, share cells without stacking upward.

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

Core property keys are `solid`, `movable`, and `gravity`. Other properties are defined by game rules. The example presets use `player`, `can_push`, `pushable`, `transmits_push`, `strength`, and `weight`. These belong to entities, not a level-wide chain-pushing toggle.

Editor undo covers placements, brush strokes, selection edits, shape edits, floor fills, level settings, and whole-level transforms. Shared-default edits made in Godot's native Inspector use its native resource editing/undo workflow.

## Visual occupied-cell editor

Select a definition, then enable **Edit occupied cells**. The board changes to show that definition's shape around its origin. Left-click or drag to add cells at the current **Height**. Right-click or choose **Erase** to remove them. Change height to build a three-dimensional shape. The last occupied cell cannot be removed.

Turn off **Edit occupied cells** to return to the level. These edits affect the shared definition, so inspect the resulting level for overlaps and click **Validate** before saving. Shape edits can be undone.

The shape is gameplay data. Artwork is separate: assign **Visual Scene** on the definition to use a custom `Node3D` scene. Its origin should match the entity origin and its model should fit the occupied cells. Artwork and colliders never silently change the gameplay shape.

## Painting and navigation

**Paint** places the selected definition. A drag stroke is one editor undo step. **Erase** removes the entity under the pointer; **Select** opens it for editing. Right-click picks the definition, rotation, and mirroring from an existing entity. The ghost shows where the brush will place the entity after automatic stacking.

Middle-drag orbits, Shift+middle-drag pans, the wheel zooms, and **F** or **Frame** fits the level. Quarter turns rotate around Y. **Mirror brush** reflects the entity's shape on local X. Whole-level rotation and mirroring transform entity positions and shapes together and survive saving/reloading.

## Rules, validation, and playtesting

Select a **Game rule** resource in the right panel. `GGSokobanRule` completes when every original crate has at least one occupied cell on a goal. `GGPipeRule` completes when every destination has a reciprocal pipe connection to a source; connected pipes light up. A generic level with no rule can test movement and gravity but does not have a built-in win condition.

**Apply level settings** commits the title, gravity toggle, and fall-out height. **Validate** checks schema compatibility, missing definitions, empty/duplicate shapes, duplicate IDs, solid overlaps, and entities starting beyond the fall-out boundary. Saving and playtesting also validate.

During play, Z undoes an entire action including pushes, falls, removed entities, and mechanic state; Y redoes it. R restarts the level, and that restart can itself be undone. Undo also works after success or failure.

No level menu, unlocking, or persistent completion system is included. Each game can react to the runtime's completion/failure signals to provide its own flow.
