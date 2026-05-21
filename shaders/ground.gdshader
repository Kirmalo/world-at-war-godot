shader_type spatial;
render_mode depth_draw_opaque;

uniform sampler2D road_mask : hint_default_black, filter_linear;

// Smooth value noise — no hard cell edges
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i,              vec2(127.1, 311.7))) * 43758.5);
	float b = fract(sin(dot(i + vec2(1,0),  vec2(127.1, 311.7))) * 43758.5);
	float c = fract(sin(dot(i + vec2(0,1),  vec2(127.1, 311.7))) * 43758.5);
	float d = fract(sin(dot(i + vec2(1,1),  vec2(127.1, 311.7))) * 43758.5);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	// Two octaves of smooth noise — coarse patch variation + fine detail
	float n1 = vnoise(UV * 6.0);
	float n2 = vnoise(UV * 28.0);
	float noise = n1 * 0.65 + n2 * 0.35;

	vec3 grass_lo = vec3(0.048, 0.098, 0.032);
	vec3 grass_hi = vec3(0.165, 0.260, 0.088);
	vec3 albedo = mix(grass_lo, grass_hi, noise);

	// Dirt patches follow the coarse octave
	float dirt = smoothstep(0.62, 0.76, n1);
	vec3 dirt_col = vec3(0.170, 0.122, 0.068) * (0.78 + n2 * 0.22);
	albedo = mix(albedo, dirt_col, dirt * 0.58);

	// Two-octave normal: coarse landscape bumps + fine-scale micro-surface detail
	float eps = 0.008;
	float nx = vnoise(UV * 6.0 + vec2(eps, 0.0)) - vnoise(UV * 6.0 - vec2(eps, 0.0));
	float nz = vnoise(UV * 6.0 + vec2(0.0, eps)) - vnoise(UV * 6.0 - vec2(0.0, eps));
	float eps2 = 0.004;
	float nx2 = vnoise(UV * 28.0 + vec2(eps2, 0.0)) - vnoise(UV * 28.0 - vec2(eps2, 0.0));
	float nz2 = vnoise(UV * 28.0 + vec2(0.0, eps2)) - vnoise(UV * 28.0 - vec2(0.0, eps2));
	NORMAL_MAP       = normalize(vec3(nx * 4.0 + nx2 * 2.5, nz * 4.0 + nz2 * 2.5, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.65;

	// Road-edge blend: ground near roads darkens to asphalt-bleed colour
	// road_mask is a TG×TG texture (white where roads exist); linear filter
	// creates a soft gradient over the neighbouring tiles.
	float road_prox = texture(road_mask, UV).r;
	vec3  road_edge = vec3(0.09, 0.08, 0.06);
	albedo = mix(albedo, road_edge, smoothstep(0.15, 0.65, road_prox) * 0.55);

	ALBEDO    = albedo;
	ROUGHNESS = mix(0.90 - noise * 0.07, 0.96, smoothstep(0.3, 0.7, road_prox));
	METALLIC  = 0.0;
	SPECULAR  = 0.15;
}
