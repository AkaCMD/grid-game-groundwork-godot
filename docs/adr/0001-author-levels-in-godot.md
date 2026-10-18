# Author levels inside Godot

Level authoring will take place inside the Godot editor, using visual tools to assemble levels and configure existing entities; new mechanics can be added with scripts. This uses Godot's existing authoring environment rather than requiring a separate in-game editor, matching the user's focus on creating games and levels. Games produced with the framework must support both desktop and web browsers; choosing the Godot editor for authoring does not limit game releases to desktop.

The framework will be distributed as a reusable addon with a ready-to-run example project; see [ADR 0003](0003-distribute-a-reusable-addon.md).

Painting a solid entity into occupied space will automatically raise the new entity until its entire shape fits without overlapping existing solid entities, preserving the original editor's automatic stacking workflow. Existing entities remain in place. This is an authoring placement behavior, separate from gravity during gameplay.
