shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.12, 0.42, 1.0, 1.0);
uniform bool breathing = true;
uniform int face_cull = 0;
uniform bool use_alpha = false;
// entity_surfaces.gd specializes these hints to the source material wrap/filter.
uniform sampler2D alpha_texture : filter_nearest, repeat_enable;
uniform float base_alpha = 1.0;
uniform float alpha_cutoff = 0.001;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);

void fragment() {
	if ((face_cull == 0 && !FRONT_FACING) || (face_cull == 1 && FRONT_FACING)) {
		discard;
	}
	float coverage = base_alpha;
	if (use_alpha) {
		coverage *= texture(alpha_texture, UV * uv_scale.xy + uv_offset.xy).a;
	}
	if (coverage < alpha_cutoff) {
		discard;
	}
	ALBEDO = tint.rgb;
	float strength = breathing ? mix(0.16, 0.48, 0.5 - 0.5 * cos(TIME * 6.283185307)) : 0.55;
	ALPHA = strength * coverage;
}
