# Editor surface coverage

**English** | [简体中文](editor-surface-coverage.zh-CN.md) · [README](../README.md) · [Designer guide](designer-guide.md#model-feedback-and-picking)

Select and Erase use [mesh-triangle picking](../addons/grid_game_groundwork/editor/entity_surfaces.gd) to find visible model surfaces. Transparent pixels can reveal geometry behind them. Highlights add surfaces without changing authored materials or runtime selection hooks.

`StandardMaterial3D` picking samples base-level alpha on the CPU with nearest or bilinear filtering. Picking and highlights respect UV scale/offset, wrapping, base alpha, culling and alpha scissor.

`ShaderMaterial` highlights derive from the source shader, preserving its uniforms, sampler hints, vertex stage, includes and alpha/discard logic. Alpha scissor runs before feedback strength. Source and instance uniforms synchronize each render frame; feedback parameters avoid name collisions.

Shader picking uses the final rendered coverage, so QUACK's white background stays opaque even where its sprite is transparent. Alpha/discard and preprocessor-dependent culling require a graphical renderer and a synchronous GPU read. Shaders without alpha/discard or preprocessing use opaque geometry picking. Coverage results are not cached across picks.

Custom integration is required for scene-dependent screen/depth textures, viewport coordinates, vertex-displaced picking geometry, conditional fragment entry points and custom blend equations. The isolated probe cannot reproduce scene buffers. Standard-material CPU picking does not evaluate mip-level derivatives. These limits do not change logical occupancy or gameplay.

Run [surface tests](../tests/test_editor_surfaces.gd) with a graphical renderer for coverage and pixel checks. The [editor harness](../tests/editor_harness/plugin.gd) checks Select/Erase and movement. Commands are in [Development](development.md#checks).
