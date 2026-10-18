# Extending the framework

## Boundaries

`data/` holds the authored resource model: `GGLevel`, `GGEntityDefinition`, and `GGEntityPlacement`. A placement references a shared definition, a cell/orientation, and explicit property overrides.

`core/` resolves the grid. `GGSession.start(level)`, `move(entity_id, direction)`, `undo()`, `redo()`, `restart()`, and `snapshot()` form the public gameplay boundary. `entities`, `mechanic_state`, and `status` describe the current session. No scene transforms or physics simulation determine movement. Horizontal commands supply a cardinal XZ direction; the default resolver moves one cell.

`rules/` defines the game extension points. `runtime/` renders snapshots, animates intermediate turn stages, reads input, and reports outcomes. `editor/` owns authoring and playtest preparation; `GGLevelAuthoring` is its save/load and editing boundary.

The addon does not reference the example games. Examples depend on the addon and supply their own win/connection rules.

## Create a game rule

Extend `GGGameRule`, give the class a name, and mark it `@tool` so its resource is available in the editor. Assign an instance through the level's **Game rule** picker.

```gdscript
@tool
class_name MyPuzzleRule
extends GGGameRule

func after_action(session: GGSession) -> void:
    if session.status == &"failed":
        return
    # Evaluate your conditions from the resolved session state.
    var activated: int = session.mechanic_state.get("activated", 0)
    if activated >= 3:
        session.status = &"won"
```

`after_action` runs after initialization and after each successful move has resolved its pushes and falls. Undo and redo restore snapshots directly without running the hook again. A blocked command does not run the hook or add a history entry. To implement switches, inspect shared-cell occupancy with `GGGrid.index(session.entities)` and store activation state in the session.

Mutable mechanic data must live in `session.mechanic_state` or each entity's `state` dictionary. These are included in history along with positions, orientation, entity properties, removals, and status. Use values, arrays, and dictionaries for mutable state. Do not store mutable state on the rule resource, in visual nodes, or in other external resources: those are shared configuration and are not part of session snapshots.

Each entity record contains `cell`, `turns`, `mirror`, `shape`, `properties`, and `state`. Entity shapes contain local `Vector3i` offsets; `GGGrid.cells(entity)` returns occupied world cells. `GGGrid.transform_cell(offset, turns, mirror)` applies the same orientation as the visual representation.

The initial framework hook is for state changes and evaluation after movement. If a mechanic changes occupancy in this hook, it must leave a valid, settled board; the hook is not automatically called recursively to resolve additional movement. Add a deliberate resolution phase when introducing mechanics such as conveyors or teleport chains, and test it at the session boundary.

## Custom pushing

Extend `GGPushRule` and override `allows(session, actor_id, moving_ids, direction)`. The session first constructs the complete collision-free movement plan, with visited entities to terminate cyclic dependencies. Your policy then approves or rejects that plan before any mutation. Keep this decision free of side effects.

```gdscript
@tool
class_name ColorPushRule
extends GGPushRule

func allows(session: GGSession, actor_id: StringName,
        moving_ids: Array, direction: Vector3i) -> bool:
    if not super.allows(session, actor_id, moving_ids, direction):
        return false
    var actor_color = session.entities[actor_id].properties.get("team", "blue")
    for id in moving_ids:
        if id != actor_id and session.entities[id].properties.get("team") != actor_color:
            return false
    return true
```

Assign this resource to the game rule's **Push Rule** field. Alternatively, override `GGGameRule.allows_push` for a policy that needs game-level configuration.

`GGPushRule` provides the permission preset: the actor needs `can_push`, pushed entities need `pushable`, and an entity with `transmits_push=false` cannot push another entity ahead of it. `GGStrengthPushRule` adds a comparison between the actor's `strength` and the total `weight` of all pushed entities. Per-entity overrides can change these values. A custom game rule is free to define different properties and policies.

## Visuals and lifecycle

Assign a custom `PackedScene` to an entity definition's `visual_scene`. The default renderer otherwise builds colored cell meshes and non-solid markers. Custom visual scenes may implement `configure_entity(definition, properties)` to build their appearance and `apply_entity_state(state)` to react to restored or updated state. The pipe example owns its geometry and flow colors through this interface. The renderer positions visual roots from snapshots; never query those animated roots for gameplay coordinates.

`GGGame` creates an orthographic camera, lighting, input, and a small HUD for an individual level. A consuming game can use `GGSession` and `GGBoardView` separately to supply its own presentation and controls. Connect `GGGame.level_completed` and `level_failed` for game-specific transitions. The framework does not maintain persistent progression.

## Native authoring and exports

Level resources carry `schema_version=1`. Definitions can be external shared `.tres` resources or embedded resources; overrides remain explicit rather than flattening inherited defaults. `GGLevel.validate()` returns author-facing errors. `GGLevelAuthoring.save(path)` validates before writing a temporary resource and replacing the destination level file. Definitions and game-rule configuration stored in separate `.tres`/`.res` files are saved separately before the level; saving the entire collection is not a multi-file transaction.

Use Standard GDScript and the Compatibility renderer for desktop and browser builds. Editor code is excluded by the provided export presets. Web uses single-threaded export and must be served over HTTP. Rebuild the example resources with `godot --headless --path . --script tools/create_examples.gd` only when intentionally replacing their authored content.

The accepted design is recorded in `docs/adr/`. Before adding mechanics, add behavior checks through `GGSession`; before changing storage or editing semantics, use `GGLevelAuthoring` and a real save/reload round trip. `python3 tools/check.py` runs both boundaries and runtime checks.

## Actor selection and composed movement

`session.select_actor(entity_id)` accepts an existing entity with the `player` property. `session.player_id()` returns the selected actor, falling back to the first remaining player. Selection lives outside snapshots: undo, redo and restart preserve it while that entity exists; starting a new level clears it. Runtime left click picks the nearest occupied cell under the cursor, so foreground terrain occludes actors. Click selection is disabled during action animation. There is no Tab cycling.

Override `GGGameRule.resolve_move(session, actor_id, direction)` to compose movement. The default calls `session.step(...)` once, preserving the existing Sokoban/pipe behavior. `step` resolves one cardinal XZ step, its push plan and gravity, and appends presentation stages; it creates no history and does not call `after_action`. Only call it within a resolver. Return true if a complete action occurred; false restores the state and preceding stages without adding history or clearing redo. The outer `move` records one before-state, calls `after_action` once, then appends the final stage. Never call `move` recursively from a resolver or `after_action`.

Resolvers must terminate, even with malformed edited layouts, and keep mutable state in session dictionaries. The QUACK example composes steps into a straight slide, stopping at a collision, food or failure. It rejects an unbounded slide atomically if an edited gravity-disabled level has no stopping obstacle within the authored board's span.

Custom visuals may implement `apply_entity_selection(selected: bool)` as a presentation hook. `GGBoardView.set_selected(id)` applies it to existing visuals and reapplies it after state restoration; the editor uses the same hook. `select_actor(id)` also supplies the runtime's generic selection ring.

Override `blocks_entity(session, actor_id, obstacle_id, direction)` for actor-dependent obstacles. It is queried for horizontal motion and downward support; the default blocks solid entities only. `after_step(session)` runs after each horizontal displacement and each one-cell fall, and once before initial settling. Use it for interactions that must happen before gravity continues, such as consuming bread crossed during a fall. It must leave valid occupancy, store mutable data in the session, and may append a snapshot stage when its visual changes need a distinct animation phase. It must not create history or recursively issue movement. A resolver can detect state changes from this hook to stop further horizontal steps while allowing current gravity consequences to finish.
