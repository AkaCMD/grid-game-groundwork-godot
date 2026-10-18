# Share entity definitions with per-entity overrides

Placed entities will reference reusable entity definitions and may override individual properties. Changes to a definition update inherited values while leaving explicit overrides intact, allowing bulk changes without losing intentional exceptions. Authored level data must preserve the distinction between inherited properties and overrides rather than copying every default into each placed entity; gameplay changes remain confined to the play session.

Entity shapes will be authored by adding or removing occupied cells in a visual 3D cell editor. Visual models will be assigned separately; neither model geometry nor collision shapes will implicitly determine occupied cells. This keeps gameplay shapes explicit and prevents artwork changes from silently altering puzzle rules.

Goals, switches, and triggers will be non-solid entities with their own definitions and properties, rather than special cell metadata. They can share cells with players, crates, and other entities, keeping authoring and custom mechanics within the same entity model. Occupancy must therefore support multiple entities in a cell while enforcing non-overlap between solid entities.
