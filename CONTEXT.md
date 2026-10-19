# Grid Game Groundwork

A framework for creating grid-based puzzle games and authoring their levels. Games use a three-dimensional grid and can include stacking and gravity.

## Language

**Level**:
A designed puzzle arrangement containing entities and the configuration needed to play it.

**Authored level**:
The saved starting arrangement and configuration of a level, as created by its author.

**Playtest**:
A temporary play session used to test an authored level. Changes caused by playing do not change the authored level.

**Cell**:
A discrete location in the three-dimensional grid.

**Entity**:
A distinct element of a level occupying one or more cells, such as a player, wall, crate, or pipe.
_Avoid_: Object, game object, piece

**Entity definition**:
A reusable description of an entity type and its default properties, shared by entities of that type.

**Entity shape**:
The arrangement of cells occupied by an entity, defined independently of its visual appearance.

**Solid entity**:
An entity that prevents other solid entities from occupying the same cells.

**Non-solid entity**:
An entity that allows other entities to occupy its cells, such as a goal, switch, or trigger. It has its own entity definition and properties.

**Entity override**:
An explicitly authored property value for one entity that replaces the corresponding default from its entity definition. Properties without overrides continue to inherit the shared defaults.

**Editor selection**:
An ordered group of entities chosen for authoring edits. The last selected entity anchors group movement. Selection is temporary editor state and is not restored by undoing an edit.

**Move preview**:
A temporary proposed displacement of the editor selection. It may show an invalid destination, but changes the authored level only when accepted at a valid destination. Cancelling restores the original positions.

**Authoring stroke**:
A continuous pointer gesture that paints or erases entities, or edits an entity shape, as one undoable edit. Surface painting uses the occupied cells present when the stroke begins, so it does not stack repeatedly on entities created during that same stroke.

**Stacking**:
The arrangement of entities above other entities at different heights in the grid.

**Gravity**:
The game rule that makes unsupported movable entities fall. It can be enabled or disabled for each level.

**Ground**:
Explicitly placed terrain that provides a supporting surface for entities.

**Support**:
A supporting surface directly beneath at least one cell occupied by an entity. One supported cell holds the entire rigid entity, allowing the remaining cells to overhang without tipping.

**Fall out**:
An entity falling beyond the level with no supporting surface to catch it. A player falling out causes failure; other entities are removed from the current attempt, and undo can restore them.

**Mechanic**:
A rule governing how entities behave or interact during play.

**Push rule**:
A game-defined rule governing whether and how one entity can push other entities, based on their properties.

**Action**:
A gameplay operation together with all its consequences, including pushes, falls, entity removals, and changes caused by mechanics. An action is restored or reapplied as a whole by undo or redo.

**Restart**:
An action that restores the level's authored starting state for a new attempt. Undoing a restart restores the preceding gameplay state.
