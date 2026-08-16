shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 grass_dark : source_color = vec3(0.07, 0.22, 0.025);
uniform vec3 grass_mid : source_color = vec3(0.15, 0.40, 0.045);
uniform vec3 grass_sun : source_color = vec3(0.29, 0.57, 0.08);
uniform vec3 path_dark : source_color = vec3(0.27, 0.22, 0.13);
uniform vec3 path_light : source_color = vec3(0.62, 0.55, 0.36);
uniform vec3 garden_soil : source_color = vec3(0.22, 0.115, 0.035);
uniform vec3 workshop_soil : source_color = vec3(0.29, 0.19, 0.08);

varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float soft_box(vec2 p, vec2 center, vec2 half_size, float feather) {
	vec2 q = abs(p - center) - half_size;
	float distance_to_box = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	return 1.0 - smoothstep(-feather, feather, distance_to_box);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float broad = value_noise(p * 0.075);
	float detail = value_noise(p * 0.31);
	float tiny = value_noise(p * 1.15);
	vec3 grass = mix(grass_dark, grass_mid, smoothstep(0.12, 0.88, broad));
	grass = mix(grass, grass_sun, smoothstep(0.58, 0.95, detail) * 0.48);
	grass *= mix(0.90, 1.08, tiny);

	// A broad, gently wandering route from the woodland gate into the
	// village. Noise breaks the edge so it reads as worn earth, not a stripe.
	float path_center = sin((p.y + 17.0) * 0.22) * 0.8;
	float path_width = 2.45 + value_noise(vec2(p.y * 0.18, 9.0)) * 0.75;
	float path_length = 1.0 - smoothstep(7.0, 10.0, p.y);
	path_length *= smoothstep(-30.0, -26.0, p.y);
	float edge_noise = (detail - 0.5) * 0.85;
	float path_mask = (1.0 - smoothstep(path_width - 0.55, path_width + 0.7, abs(p.x - path_center) + edge_noise)) * path_length;

	// Soft destination wear replaces the former raised rectangular plates.
	float village_wear = soft_box(p, vec2(0.0), vec2(6.2, 5.1), 2.3) * 0.34;
	float garden = soft_box(p, vec2(-7.0, 15.0), vec2(6.7, 4.7), 1.35);
	float workshop = soft_box(p, vec2(15.5, -4.0), vec2(4.8, 5.6), 1.25);
	float home_wear = soft_box(p, vec2(-15.5, -5.5), vec2(5.2, 7.0), 1.8) * 0.16;

	vec3 dirt = mix(path_dark, path_light, broad * 0.62 + detail * 0.38);
	dirt *= mix(0.9, 1.08, tiny);
	vec3 color = mix(grass, dirt, clamp(max(path_mask, village_wear), 0.0, 1.0));
	color = mix(color, mix(garden_soil, dirt, detail * 0.22), garden * 0.88);
	color = mix(color, mix(workshop_soil, path_light, broad * 0.28), workshop * 0.82);
	color = mix(color, dirt, home_wear);

	ALBEDO = color;
	ROUGHNESS = 0.94;
	SPECULAR = 0.08;
}
