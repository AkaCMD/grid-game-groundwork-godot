# Editor surface coverage

Selection and Erase share mesh-triangle picking. Highlights use additional mesh
surfaces; neither operation changes authored materials or runtime selection hooks.

For StandardMaterial3D, the overlay specializes the alpha sampler to the source
wrap and filter mode, and retains UV scale/offset, base alpha, culling and scissor.
CPU picking samples nearest or bilinear base-level alpha with the same UV/wrap.

For ShaderMaterial, source sprite alpha is not a coverage contract: QUACK, for
example, composites it onto an opaque white background. The highlight derives an
editor-only shader from the original fragment, preserving its uniforms, sampler
hints, vertex stage, includes and discard/alpha logic, then applies the feedback
color and strength. Scissor runs before the feedback strength is applied. Feedback
uniform names avoid collisions with original uniforms. Original resources stay intact.
While an overlay remains visible, each render frame synchronizes source material
uniforms (including textures and UV parameters) and instance uniforms. Standard
material alpha, UV, wrap/filter and culling settings are synchronized too. Feedback
color/breathing use one shared setter and remain independent of source uniforms.

Shaders without alpha/discard are opaque under Godot's spatial shader contract.
Cull modes are matched as complete tokens only inside actual `render_mode`
declarations, after stripping comments and quoted strings. If preprocessing remains
(macros or conditional branches), geometry accepts either face and the renderer
resolves active culling; this path also requires a graphical renderer for opaque
shaders. Highlight derivation retains each cull declaration in its original
preprocessor scope.

For alpha/discard or preprocessor-dependent culling, picking renders the candidate
surface into a tiny transparent viewport along the ray, clipped just beyond each geometric intersection, and reads final
coverage. Transparent front faces can reveal later faces or other entities. The
probe copies transforms and instance uniforms, synchronizes before reading, and
is released at the end of each pick. It requires a graphical renderer and adds a
synchronous GPU read; it does not cache alpha results that can change with uniforms.

The shader coverage path supports material-local alpha/discard (including UV,
textures, uniforms and includes). Scene-dependent screen/depth textures, viewport
coordinates, vertex-displaced picking geometry, conditional alternative fragment
entry points, and custom blend equations need a dedicated rendering/picking
integration; the isolated probe cannot reproduce the original scene's buffers.
Standard-material CPU picking does not evaluate mip-level derivatives. These
limits are separate from logical cell occupancy and gameplay rules.

Run `tests/test_editor_surfaces.gd` with a graphical renderer for coverage and
pixel regressions; `tests/editor_harness/plugin.gd` covers shared Select/Erase and
move behavior inside the actual editor.
