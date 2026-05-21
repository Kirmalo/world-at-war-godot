shader_type spatial;
render_mode cull_disabled;

// Smooth value noise — used for alpha-clip leaf silhouette
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

void vertex() {
	// Wind sway — amplitude increases with height, per-instance phase from VERTEX.x
	float phase = VERTEX.x * 2.7 + VERTEX.z * 1.9;
	float sway  = sin(TIME * 1.4 + phase) * 0.038 + cos(TIME * 0.9 + phase * 0.7) * 0.022;
	VERTEX.x += sway * max(0.0, VERTEX.y);
	VERTEX.z += cos(TIME * 1.1 + phase * 1.3) * 0.024 * max(0.0, VERTEX.y);
}

void fragment() {
	// Two-frequency noise clip creates irregular leafy silhouette (~34% removed)
	float c1 = vnoise(UV * 5.0);
	float c2 = vnoise(UV * 11.0 + vec2(3.7, 1.2));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA = step(0.34, c1 * 0.55 + c2 * 0.45);

	ALBEDO    = COLOR.rgb;
	ROUGHNESS = 0.88;
	METALLIC  = 0.0;
	// Faint SSS-style emission: sunlit faces get a warm green-gold subsurface glow
	EMISSION  = COLOR.rgb * 0.06 * max(0.0, dot(NORMAL, vec3(0.3, 1.0, 0.2)));
}
