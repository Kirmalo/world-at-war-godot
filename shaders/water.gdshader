shader_type spatial;
render_mode blend_mix, depth_draw_disabled, cull_back;

void fragment() {
	// Two layers of wave UVs scrolling in different directions
	vec2 uv1 = UV * 4.0 + vec2(TIME * 0.050,  TIME * 0.028);
	vec2 uv2 = UV * 2.5 + vec2(-TIME * 0.036, TIME * 0.062);
	vec2 uv3 = UV * 8.0 + vec2(TIME * 0.022, -TIME * 0.041);

	float w1 = sin(uv1.x * 6.2832 + uv1.y * 4.1888) * 0.5 + 0.5;
	float w2 = sin(uv2.x * 3.1416 - uv2.y * 6.2832) * 0.5 + 0.5;
	float w3 = sin(uv3.x * 9.4248 + uv3.y * 3.1416) * 0.5 + 0.5;
	float wave = w1 * 0.50 + w2 * 0.32 + w3 * 0.18;

	vec3 deep    = vec3(0.04, 0.13, 0.30);
	vec3 shallow = vec3(0.09, 0.24, 0.48);
	ALBEDO    = mix(deep, shallow, wave);
	ROUGHNESS = 0.04 + wave * 0.05;
	METALLIC  = 0.0;
	SPECULAR  = 0.95;
	ALPHA     = 0.86;

	// Normal map from wave gradients (three octaves)
	float nx = sin(uv1.y * 6.2832) * 0.14 + sin(uv3.y * 9.4248) * 0.06;
	float nz = cos(uv2.x * 3.1416) * 0.14 + cos(uv3.x * 6.2832) * 0.06;
	NORMAL_MAP       = normalize(vec3(nx, nz, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.70;
}
