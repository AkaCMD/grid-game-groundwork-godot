# Preserve three-dimensional grid gameplay

The framework will retain the original's three-dimensional grid, stacking, and gravity instead of reducing its scope to flat two-dimensional puzzles. The user chose this to retain these capabilities in the Godot recreation. Ground will be explicitly authored and gravity configurable per level; see [ADR 0005](0005-use-explicit-ground.md). One supported cell holds an entire rigid entity. Falling beyond the level causes player failure or removal of other entities from the current attempt, with undo available.
