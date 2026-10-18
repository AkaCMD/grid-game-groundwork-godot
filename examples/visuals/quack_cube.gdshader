shader_type spatial;

uniform sampler2D sprite : source_color, filter_nearest;
uniform vec4 background_color : source_color = vec4(1.0);

void fragment() {
	vec4 pixel = texture(sprite, UV);
	ALBEDO = mix(background_color.rgb, pixel.rgb, pixel.a);
	ROUGHNESS = 1.0;
}
