# Extending the framework

**English** | [简体中文](extending.zh-CN.md) · [README](../README.md) · [Designer guide](designer-guide.md)

Extend the resources and rules in [addons/grid_game_groundwork/](../addons/grid_game_groundwork/) to add mechanics or replace presentation. Keep mutable gameplay state in `GGSession` so undo and redo can restore it.

## Boundaries

[data/](../addons/grid_game_groundwork/data/) defines `GGLevel`, `GGEntityDefinition` and `GGEntityPlacement`. Placements reference shared definitions and store position, orientation and explicit overrides. [GGSession](../addons/grid_game_groundwork/core/session.gd) resolves integer-grid movement independently of scene transforms and physics. Use `start`, `move`, `undo`, `redo`, `restart` and `snapshot` for gameplay.

[rules/](../addons/grid_game_groundwork/rules/) supplies mechanics; [runtime/](../addons/grid_game_groundwork/runtime/) renders snapshots and handles input. [GGLevelAuthoring](../addons/grid_game_groundwork/editor/level_authoring.gd) supplies editing and save/load operations. The addon is independent of the example games.

## Create a game rule

Extend `GGGameRule`, name the class and add `@tool`. Assign an instance through the level's **Game rule** picker.

The hooks in [GGGameRule](../addons/grid_game_groundwork/rules/game_rule.gd) have these defaults:

| Hook | Default | Usage |
| --- | --- | --- |
| `resolve_move(session, actor_id, direction)` | Calls `session.step(...)` once. | Compose several grid steps into one action. |
| `allows_push(session, actor_id, moving_ids, direction)` | Uses the assigned push rule, or `GGPushRule`. | Approve a planned push without changing state. |
| `carried_entities(session, actor_id, direction)` | Returns an empty array. | Return companion IDs for this step. |
| `blocks_entity(session, actor_id, obstacle_id, direction)` | Blocks solid entities. | Define actor-dependent obstacles and support. |
| `after_step(session)` | Does nothing. | Handle each horizontal step, each one-cell fall and initial state before settling. |
| `after_action(session)` | Does nothing. | Evaluate the settled board after initialization or a successful move. |

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

Your mechanic must update `session.mechanic_state["activated"]`; this example only evaluates it. For switches, use `GGGrid.index(session.entities)` to inspect shared-cell occupancy. Undo/redo restore snapshots without rerunning hooks; blocked commands add no history.

Store mutable state in `session.mechanic_state` or each entity's `state`, using values, arrays and dictionaries. Snapshots include these along with positions, orientation, properties, removals and status. Rule resources and visual nodes are outside history.

Entity records contain `cell`, `turns`, `mirror`, `shape`, `properties` and `state`. Shapes use local `Vector3i` offsets; `GGGrid.cells(entity)` returns world cells. If `after_action` changes occupancy, leave a valid, settled board: the session does not recursively settle changes made by this hook.

## Custom pushing

Extend `GGPushRule` and override `allows(session, actor_id, moving_ids, direction)`. The session builds the complete movement plan first; your policy approves or rejects it without side effects.

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

Assign the resource to the game rule's **Push Rule**, or override `GGGameRule.allows_push` for game-level configuration.

[GGPushRule](../addons/grid_game_groundwork/rules/push_rule.gd) requires `can_push` on the actor and `pushable` on pushed entities. `transmits_push=false` prevents a pushed entity from pushing another ahead. [GGStrengthPushRule](../addons/grid_game_groundwork/rules/strength_push_rule.gd) also requires actor `strength` to cover the total pushed `weight`. Per-entity overrides can change these properties.

## Visuals and lifecycle

Assign a `PackedScene` to the definition's `visual_scene`; otherwise the renderer builds colored cell meshes and non-solid markers. Implement `configure_entity(definition, properties)` and `apply_entity_state(state)` for custom appearance. The renderer positions roots from snapshots; read gameplay coordinates from the session.

Attach [GGGame](../addons/grid_game_groundwork/runtime/game.gd) to a `Node3D` and assign `level` for camera, lighting, controls and a HUD. Connect `level_completed` and `level_failed` for transitions. Use `GGSession` and [GGBoardView](../addons/grid_game_groundwork/runtime/board_view.gd) separately for custom presentation. Persistent progression belongs to the consuming game.

Custom visuals may implement `apply_entity_selection(selected: bool)`. `GGBoardView.set_selected(id)` applies it and restores it after state changes; `select_actor(id)` also shows the generic selection ring. The editor supplies separate [surface feedback](editor-surface-coverage.md).

## Native authoring and exports

[GGLevel](../addons/grid_game_groundwork/data/level.gd) uses `schema_version=1` and validates resources with `validate()`. Definitions may be embedded or external; overrides remain explicit. `GGLevelAuthoring.save(path)` validates, saves external configuration, then replaces the level through a temporary file. Saving multiple resources is not a single transaction.

See [development checks](development.md#checks), [export](development.md#export) and [example regeneration](development.md#regenerate-examples) for commands. Test mechanics through `GGSession` and storage changes through real `GGLevelAuthoring` save/reload checks. Design decisions are in [docs/adr/](adr/).

## Editor selection and authoring strokes

Use [GGEditorSelection](../addons/grid_game_groundwork/editor/selection.gd) and [GGEditorStroke](../addons/grid_game_groundwork/editor/stroke.gd) with the same `GGLevelAuthoring`. Selection stages group movement with `begin_move`, `preview_move` and `finish_move`. Strokes take camera rays through `begin`, `preview`, `sample` and `finish`, keeping starting surfaces and visited placements stable.

Keep placement rules in these modules; input code supplies rays and renders previews. Test their behavior directly, and use the [editor harness](../tests/editor_harness/plugin.gd) for camera projection, focus and input delivery.

## Actor selection and composed movement

`session.select_actor(id)` accepts an existing entity with `player=true`. `player_id()` returns the selected actor or the first remaining player. Selection survives undo/redo/restart while the entity exists; a new level clears it. Runtime picking uses occupied cells and is disabled during animation.

Override `resolve_move` to compose movement. Call `session.step(...)` only inside the resolver: it performs one cardinal XZ step, pushes and gravity, and appends animation stages. It creates no history and does not call `after_action`. Return true to record one complete action; false restores the preceding state and stages while preserving redo. Never call `move` recursively from a resolver or hook.

`carried_entities` returns movable companion IDs for each step. A missing companion or a blocker outside the movement plan rejects the step; companions cannot push their obstacles. Use `after_step` for interactions that must happen before gravity continues, such as eating bread during a fall. Leave valid occupancy and store changes in session state; append a snapshot stage when a visual change needs separate animation.

Resolvers must terminate for malformed layouts. The [QUACK rule](../examples/rules/quack_rule.gd) demonstrates a bounded multi-step slide and rejects unbounded movement atomically.
