shader_type spatial;
render_mode blend_mix, cull_back;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

void fragment() {
	// Two layers of wave UVs scrolling in different directions
	vec2 uv1 = UV * 4.0 + vec2(TIME * 0.050,  TIME * 0.028);
	vec2 uv2 = UV * 2.5 + vec2(-TIME * 0.036, TIME * 0.062);
	vec2 uv3 = UV * 8.0 + vec2(TIME * 0.022, -TIME * 0.041);

	float w1 = sin(uv1.x * 6.2832 + uv1.y * 4.1888) * 0.5 + 0.5;
	float w2 = sin(uv2.x * 3.1416 - uv2.y * 6.2832) * 0.5 + 0.5;
	float w3 = sin(uv3.x * 9.4248 + uv3.y * 3.1416) * 0.5 + 0.5;
	float wave = w1 * 0.50 + w2 * 0.32 + w3 * 0.18;

	// Depth-based shore fade: sample scene depth, compute water column thickness
	float raw_depth  = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec3  ndc        = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	vec4  view_pos   = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz    /= view_pos.w;
	float scene_depth = -view_pos.z;
	float frag_depth  = -VERTEX.z;   // VERTEX is in view space
	float water_depth = scene_depth - frag_depth;
	float shore       = clamp(water_depth / 1.8, 0.0, 1.0);  // fade over 1.8 world units

	vec3 deep    = vec3(0.04, 0.13, 0.30);
	vec3 shallow = vec3(0.18, 0.44, 0.62);   // lighter, more cyan near shore
	vec3 albedo = mix(shallow, mix(deep, shallow, wave * 0.5), shore);

	// Shore foam: white band at very shallow water, modulated by wave crests
	float foam_band  = smoothstep(0.0, 0.55, water_depth) * (1.0 - smoothstep(0.35, 0.85, water_depth));
	float foam_noise = w1 * 0.55 + w2 * 0.30 + w3 * 0.15;
	float foam       = foam_band * clamp(foam_noise - 0.28, 0.0, 1.0) * 2.0;
	albedo = mix(albedo, vec3(0.92, 0.94, 0.96), clamp(foam, 0.0, 0.82));

	ALBEDO    = albedo;
	ROUGHNESS = 0.04 + wave * 0.05;
	METALLIC  = 0.0;
	SPECULAR  = 0.95;
	ALPHA     = mix(0.30, 0.86, shore);   // near-transparent at shoreline

	// Normal map from wave gradients (three octaves)
	float nx = sin(uv1.y * 6.2832) * 0.14 + sin(uv3.y * 9.4248) * 0.06;
	float nz = cos(uv2.x * 3.1416) * 0.14 + cos(uv3.x * 6.2832) * 0.06;
	NORMAL_MAP       = normalize(vec3(nx, nz, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.70;
}
