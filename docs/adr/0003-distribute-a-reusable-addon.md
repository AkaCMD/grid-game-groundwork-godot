# Distribute a reusable addon with an example project

The framework will be packaged as a reusable Godot addon accompanied by a ready-to-run example project, rather than only as a starter repository to copy for each game. The user wants to create different games with the framework, so reusable functionality should be installable independently of the examples. Game-specific mechanics and example content must not become requirements for using the addon.

The addon will focus on authoring and playing individual levels. Level-selection menus, unlocking rules, and persistent campaign completion progress are outside its scope and belong to each consuming game. This boundary does not exclude level saving/loading for authoring or an individual level's win and failure conditions.

Pushing behavior will be controlled through properties on entities, with those properties and the rules interpreting them defined by the consuming game. The addon will provide reusable presets for simple push permissions and strength/weight rules, while allowing games to supply their own properties and pushing logic. A level-wide single-entity-versus-chain-pushing switch is not the chosen model.
