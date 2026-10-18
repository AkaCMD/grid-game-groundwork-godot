# Use explicit ground and per-level gravity

Ground must be placed explicitly rather than supplied by the original framework's invisible floor, so supporting surfaces and gaps can be understood from the authored level. A fill-floor tool will make ordinary flat levels convenient to create, and gravity can be enabled or disabled per level.

Support beneath any occupied cell holds the entire rigid entity, matching the original framework and allowing overhangs and bridge-like arrangements. Moves do not require support beneath every occupied cell, and entities do not tip.

When a player falls beyond the level, the attempt enters a failure state with undo and restart available. Other entities falling beyond the level are removed from the current attempt without automatically causing failure; undo can restore them. This allows deliberately dropping a crate to be part of a solution. Fall-out detection must terminate even when there is no ground below an entity; its exact boundary representation remains an implementation decision.
