# Prioritize convenient native level authoring

The immediate priority is the level designer's editing and saving workflow inside Godot. Levels and entity definitions will use Godot-native text resources (`.tres`) to fit that workflow, including Inspector editing and references to reusable definitions and visual assets. This representation follows the user's priority of authoring convenience; it does not establish a portable community exchange format.

Player-created levels, an in-game player editor, and player-facing level sharing or import/export are deferred. Interest in sharing was raised, but the user explicitly chose to focus on the simplest designer workflow first. Desktop and browser game targets remain in scope.

Godot's [resource documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html) describes built-in resource serialization, Inspector support, and text resource files.
