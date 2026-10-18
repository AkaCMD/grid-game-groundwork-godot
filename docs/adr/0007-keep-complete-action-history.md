# Keep complete action history, including restarts

Undo and redo operate on complete actions, restoring or reapplying pushes, resulting falls, removed entities, failure state, and mechanic changes together. Restart restores the authored starting state while remaining undoable, so players can experiment without losing their previous position. This requires history to cover gameplay state beyond entity positions and requires custom mechanics to participate in state restoration; the original framework's position-and-rotation-only history is insufficient.
