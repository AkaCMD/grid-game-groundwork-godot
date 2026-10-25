# Share authoring across discrete game rules

**English** | [简体中文](0010-share-authoring-across-game-rules.zh-CN.md)

Games share an integer cubic grid, 24 orthogonal orientations, typed authored fields and entity references. They supply collision, support, activity bounds and command resolution through rules, while a common session owns complete action history. The editor's placement planes remain independent of game gravity. A game may supply its own playtest scene without changing the editor or level schema.

This generalizes the default support and fall-out policies recorded in [ADR 0002](0002-preserve-three-dimensional-grid-gameplay.md), [ADR 0005](0005-use-explicit-ground.md) and [ADR 0008](0008-share-entity-definitions-with-overrides.md). Their behavior remains the default policy. Native resources and isolated playtests remain in place, with automatic migration to schema 2. Draft saves require structural validity; playtests additionally require resolved references and valid gameplay arrangements.

The trade-off is a broader data model and explicit authoring/runtime policy hooks. Rolling blocks, six-axis gravity and linked mechanisms provide acceptance cases alongside the existing examples. The agreed requirements are recorded in [issue 14](https://github.com/AkaCMD/grid-game-groundwork-godot/issues/14).
