# Extending the framework

**English** | [简体中文](extending.zh-CN.md) · [README](../README.md) · [Designer guide](designer-guide.md)

Extend the resources and rules in [addons/grid_game_groundwork/](../addons/grid_game_groundwork/) to add mechanics or replace presentation. Keep mutable gameplay state in `GGSession` so undo and redo can restore it.

## Boundaries

[data/](../addons/grid_game_groundwork/data/) defines `GGLevel`, `GGEntityDefinition` and `GGEntityPlacement`. Placements reference shared definitions and store position, orientation and explicit overrides. [GGSession](../addons/grid_game_groundwork/core/session.gd) resolves integer-grid movement independently of scene transforms and physics. Use `start`, `act`, `move`, `undo`, `redo`, `restart` and `snapshot` for gameplay.

[rules/](../addons/grid_game_groundwork/rules/) supplies mechanics; [runtime/](../addons/grid_game_groundwork/runtime/) renders snapshots and handles input. [GGLevelAuthoring](../addons/grid_game_groundwork/editor/level_authoring.gd) supplies editing and save/load operations. The addon is independent of the example games.

## Create a game rule

Extend `GGGameRule`, name the class and add `@tool`. Assign an instance through the level's **Game rule** picker.

The hooks in [GGGameRule](../addons/grid_game_groundwork/rules/game_rule.gd) have these defaults:

| Hook | Default | Usage |
| --- | --- | --- |
| `resolve_action(session, command, arguments)` | Dispatches `move` commands. | Handle game-defined commands in a shared action transaction. |
| `initial_state(level)` | Supplies down/off gravity and fall-out height. | Initialize snapshot-owned mechanic state. |
| `allows_direction(direction)` | Accepts four cardinal XZ directions. | Enable other movement directions. |
| `gravity_direction(session)` | Reads `mechanic_state.gravity_direction`. | Choose the current global gravity direction. |
| `resolve_gravity(session)` | Calls `session.fall(direction)`. | Replace gravity resolution. |
| `supports_entity(session, actor_id, support_id, direction)` | Uses `blocks_entity`. | Define runtime support independently of collision. |
| `is_outside(session, entity_id, direction)` | Entire shape passes the fall-out limit projected onto gravity. | Define activity bounds. |
| `on_fall_out(session, entity_id)` | Fails players and removes the entity. | Define fall-out consequences. |
| `validate_state(session)` | Rejects solid entities blocked at their final cells. | Validate a resolved action before committing history. |
| `validate_level(level)` | Checks authored bounds and collisions. | Validate authored gameplay arrangements. |
| `authored_cell_allowed(level, cell)` | Requires Y above `void_height`. | Supply game-specific authoring bounds. |
| `blocks_placement(level, actor, other)` | Rejects overlapping solid placements. | Supply authored collision policy. |
| `authoring_gravity(level)` | Returns down. | Supply the editor's support direction. |
| `supports_placement(level, actor, other, direction)` | Accepts solid supports. | Filter supports for the editor's snap tool. |
| `resolve_move(session, actor_id, direction)` | Calls `session.step(...)` once. | Compose several grid steps into one action. |
| `allows_push(session, actor_id, moving_ids, direction)` | Uses the assigned push rule, or `GGPushRule`. | Approve a planned push without changing state. |
| `carried_entities(session, actor_id, direction)` | Returns an empty array. | Return companion IDs for this step. |
| `blocks_entity(session, actor_id, obstacle_id, direction)` | Blocks solid entities. | Define actor-dependent obstacles and support. |
| `after_step(session)` | Does nothing. | Handle each grid step, each one-cell fall and initial state before settling. |
| `after_action(session)` | Does nothing. | Evaluate the settled board after initialization or an accepted action. |

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

[GGLevel](../addons/grid_game_groundwork/data/level.gd) accepts schemas 1 and 2; opening in `GGLevelAuthoring` migrates to schema 2. Definitions may be embedded or external; overrides remain explicit. `GGLevelAuthoring.save(path)` checks structural validity, saves external configuration, then replaces the level through a temporary file. Saving multiple resources is not a single transaction.

Authoring previews, Paint, movement, duplication and entity edits validate proposed levels with copied placements and overrides. Shared definitions, rule configuration and the playtest scene retain their identities. Keep validation hooks read-only: accepted edits commit once, while rejected proposals preserve live placements and history. [Authoring tests](../tests/test_authoring.gd) check isolation during rule evaluation and preservation of the redo branch.

See [development checks](development.md#checks), [export](development.md#export) and [example regeneration](development.md#regenerate-examples) for commands. Test mechanics through `GGSession` and storage changes through real `GGLevelAuthoring` save/reload checks. Design decisions are in [docs/adr/](adr/).

## Editor selection and authoring strokes

Use [GGEditorInteraction](../addons/grid_game_groundwork/editor/interaction.gd) with a `GGLevelAuthoring` to own tool transitions, shape-editing context and preview invalidation. Its `selection` and `stroke` share that authoring module. Input adapters call `set_mode`, `set_shape_mode`, `configure_brush`, `set_plane` and `open`; `height_target` chooses the Q/E action. Render `refreshed_level()` so selection reconciliation precedes visual rebuilding, including after Inspector edits. Window focus loss and hiding the editor call `cancel()`.

[GGEditorSelection](../addons/grid_game_groundwork/editor/selection.gd) stages group movement with `begin_move`, `preview_move` and `finish_move`. [GGEditorStroke](../addons/grid_game_groundwork/editor/stroke.gd) takes camera rays through `begin`, `preview`, `sample` and `finish`, keeping starting surfaces and visited placements stable. They can also be used directly with the same `GGLevelAuthoring`.

Keep transition rules in the interaction module; input code supplies rays and renders previews. [Interaction tests](../tests/test_interaction.gd) cover transitions and invalidation. Use the [editor harness](../tests/editor_harness/plugin.gd) for camera projection, focus and input delivery.

## Actor selection and composed movement

`session.select_actor(id)` accepts an existing entity with `player=true`. `player_id()` returns the selected actor or the first remaining player. Selection survives undo/redo/restart while the entity exists; a new level clears it. Runtime picking uses occupied cells and is disabled during animation.

Override `resolve_move` to compose movement. Call `session.step(...)` only inside the resolver: it performs one cardinal XYZ step, pushes and gravity, and appends animation stages. It creates no history and does not call `after_action`. Return true to record one complete action; false restores the preceding state and stages while preserving redo. Recursive `act`, `move` and history operations are refused during resolution. Call `step` only during resolution.

`carried_entities` returns movable companion IDs for each step. A missing companion or a blocker outside the movement plan rejects the step; companions cannot push their obstacles. Use `after_step` for interactions that must happen before gravity continues, such as eating bread during a fall. Leave valid occupancy and store changes in session state; append a snapshot stage when a visual change needs separate animation.

Resolvers must terminate for malformed layouts. The [QUACK rule](../examples/rules/quack_rule.gd) demonstrates a bounded multi-step slide and rejects unbounded movement atomically.

## Commands, fields and playtest scenes

`session.act(command, arguments)` starts one transaction. A false resolver result, failed settlement or invalid resolved state restores the preceding snapshot and animation stages, preserving redo. Successful actions run `after_action` and enter history once. Keep rule configuration immutable during play; store gravity direction, door states and portal latches in session or entity state. The rolling block rule supplies a custom move resolver. [Rolling block rule](../examples/rules/rolling_rule.gd)

The default `move` command remains horizontal. `step` accepts unit directions along any axis during resolution; `settle()` applies the current gravity policy. The default fall solver shares a `resolution_limit` budget across the action and rejects nonterminating settlement. Custom resolvers must bound their own loops. Calling `settle` recursively during gravity resolution rejects the action.

[GGGrid](../addons/grid_game_groundwork/core/grid.gd) provides `orientation_basis(index, mirror)`, `rotated(index, axis, turns)` and `transform_cell(cell, index, mirror)`. Orientations 0-3 retain the legacy Y rotations; 4-23 cover the remaining orthogonal poses. Placement `orientation` is canonical, `quarter_turns` retains legacy access, and runtime records retain the `turns` key. World coordinates and the editor placement plane are independent of gameplay gravity.

Declare [GGPropertyField](../addons/grid_game_groundwork/data/property_field.gd) resources in a definition's `fields` list. Fields have `key`, `label`, `kind`, `default_value`, `choices` and `required`. Kinds are BOOLEAN, INTEGER, FLOAT, TEXT, CHOICE, ENTITY, ENTITIES and CELL. Missing defaults use false, zero, empty text/reference/list, the first choice, or the zero cell. `required` enforces a nonempty reference or reference list. Defaults remain inherited until an explicit override is enabled. Mutable defaults are copied into each resolved entity.

ENTITY and ENTITIES values are entity IDs with editor selectors and reference validation. Group copying remaps internal references, including inherited defaults, while retaining external references. Deleted targets remain missing; generated identities are independent of the current entity count. `validate_structure()` checks types and resource integrity, `validate_placement()` adds rule checks, and `validate()` adds reference checks. Draft saves require structure; playtests require full validation. Keep authored collision and support policies consistent with their runtime counterparts.

Assign `GGLevel.playtest_scene` for custom controls or presentation. Its root must expose `level` or implement `configure_level(level)`; the launcher supplies the isolated level before adding the root to the scene tree. `GGLevelAuthoring.prepare_playtest(directory)` writes the temporary snapshot and launch scene. Rule resource fields and entity references are included; scripts and visual scenes remain external assets.
