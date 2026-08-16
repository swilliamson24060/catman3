shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D grass_atlas : source_color, filter_linear_mipmap_anisotropic;

void fragment() {
	vec4 source = texture(grass_atlas, UV);
	float value = dot(source.rgb, vec3(0.24, 0.66, 0.10));
	float variation = smoothstep(0.12, 0.86, value);
	vec3 shade_green = vec3(0.075, 0.25, 0.025);
	vec3 sun_green = vec3(0.34, 0.62, 0.075);
	ALBEDO = mix(shade_green, sun_green, variation);
	ROUGHNESS = 0.92;
	SPECULAR = 0.06;
	ALPHA = source.a;
	ALPHA_SCISSOR_THRESHOLD = 0.42;
}
