shader_type spatial;
render_mode depth_draw_opaque;

float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i,             vec2(127.1,311.7)))*43758.5);
	float b = fract(sin(dot(i+vec2(1,0),   vec2(127.1,311.7)))*43758.5);
	float c = fract(sin(dot(i+vec2(0,1),   vec2(127.1,311.7)))*43758.5);
	float d = fract(sin(dot(i+vec2(1,1),   vec2(127.1,311.7)))*43758.5);
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}

void fragment() {
	// Asphalt grain — two scale noise
	float grain = vnoise(UV * 60.0) * 0.55 + vnoise(UV * 180.0) * 0.45;
	vec3 asphalt = vec3(0.140, 0.138, 0.132) * (0.82 + grain * 0.36);

	// Dashed centre line — runs along V axis
	float dash_u = abs(UV.x - 0.5);
	float dash_v = fract(UV.y * 5.0);
	float centre_line = step(dash_u, 0.022) * step(dash_v, 0.55);

	// Solid edge lines
	float edge_line = step(abs(UV.x - 0.08), 0.018) + step(abs(UV.x - 0.92), 0.018);
	edge_line = clamp(edge_line, 0.0, 1.0);

	// Faded white markings
	float markings = clamp(centre_line * 0.55 + edge_line * 0.35, 0.0, 1.0);
	vec3 mark_col = vec3(0.82, 0.80, 0.72);
	vec3 albedo = mix(asphalt, mark_col, markings);

	// Derive cheap surface normal for micro-roughness
	float eps = 0.006;
	float nx = vnoise(UV*60.0+vec2(eps,0)) - vnoise(UV*60.0-vec2(eps,0));
	float nz = vnoise(UV*60.0+vec2(0,eps)) - vnoise(UV*60.0-vec2(0,eps));
	NORMAL_MAP       = normalize(vec3(nx*3.0, nz*3.0, 1.0))*0.5+0.5;
	NORMAL_MAP_DEPTH = 0.25;

	ALBEDO    = albedo;
	ROUGHNESS = 0.88 - grain * 0.06;
	METALLIC  = 0.0;
	SPECULAR  = 0.22;
}
