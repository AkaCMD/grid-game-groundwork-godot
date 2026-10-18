// A fragment in an include exercises coverage beyond the top-level shader source.
uniform float opacity = 0.0;
void fragment() {
	ALBEDO = vec3(1.0);
	ALPHA = opacity;
}
