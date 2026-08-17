shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D source_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform bool has_albedo_texture = false;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 source = has_albedo_texture ? texture(source_albedo, UV) : vec4(1.0);
	float luminance = dot(source.rgb, vec3(0.24, 0.68, 0.08));
	// Keep shingles, seams, and modeled material variation as value detail,
	// while making the requested pastel—not the source hue—authoritative.
	float shade = mix(0.52, 1.08, smoothstep(0.04, 0.92, luminance));
	ALBEDO = tint.rgb * shade;
	ROUGHNESS = 0.82;
	SPECULAR = 0.12;
	ALPHA = source.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
}
