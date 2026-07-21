shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
varying vec3 model_position;

void vertex() {
	model_position = VERTEX;
}

void fragment() {
	vec4 base_color = texture(albedo_tex, UV);
	bool nose_region = abs(model_position.x) < 0.10
		&& model_position.y > 0.47
		&& model_position.y < 0.63
		&& model_position.z > 0.67;
	ALBEDO = nose_region ? vec3(0.002, 0.002, 0.003) : base_color.rgb;
	ROUGHNESS = 0.88;
}
