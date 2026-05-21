shader_type spatial;
render_mode cull_disabled;

void fragment() {
	float is_roof = step(0.9, NORMAL.y);
	float a = COLOR.a;

	// Material type from vertex alpha: 1.0=brick, 0.75=wood, 0.5=concrete, 0.25=glass
	float is_brick = step(0.875, a);
	float is_wood  = step(0.625, a) * (1.0 - is_brick);
	float is_glass = step(a, 0.375);
	float is_conc  = 1.0 - is_brick - is_wood - is_glass;

	// Brick — running bond pattern
	vec2 b_uv   = UV / vec2(0.48, 0.26);
	float b_row = floor(b_uv.y);
	float b_off = mod(b_row, 2.0) * 0.5;
	vec2 b_cell = vec2(fract(b_uv.x + b_off), fract(b_uv.y));
	float mortar = max(step(0.91, b_cell.x), step(0.88, b_cell.y));
	float brnd   = fract(sin(dot(floor(vec2(b_uv.x + b_off, b_uv.y)),
		vec2(127.1, 311.7))) * 43758.5453);
	vec3 brick_col = mix(COLOR.rgb * (0.92 + brnd * 0.16), COLOR.rgb * 0.50, mortar);

	// Wood — horizontal grain lines
	vec2 w_uv    = UV / vec2(0.10, 0.04);
	float wgrain = fract(w_uv.y);
	float wn     = fract(sin(dot(floor(w_uv), vec2(127.1, 311.7))) * 43758.5453);
	float wline  = smoothstep(0.80, 1.0, wgrain) * 0.30;
	vec3 wood_col = COLOR.rgb * (0.85 + wn * 0.20 - wline);

	// Glass curtain wall
	vec2 g_uv   = UV / vec2(0.42, 0.36);
	vec2 g_cell = fract(g_uv);
	float frame = max(max(step(g_cell.x, 0.07), step(0.93, g_cell.x)),
		max(step(g_cell.y, 0.09), step(0.91, g_cell.y)));
	float grnd  = fract(sin(dot(floor(g_uv), vec2(127.1, 311.7))) * 43758.5453);
	vec3 glass_col = mix(COLOR.rgb * (0.75 + grnd * 0.50), COLOR.rgb, frame);
	float g_rough = mix(0.03, 0.80, frame);
	float g_metal = mix(0.55, 0.0, frame);

	// Concrete panels
	vec2 c_uv    = UV / vec2(0.55, 0.40);
	float cnoise = fract(sin(dot(floor(c_uv), vec2(127.1, 311.7))) * 43758.5453);
	float c_seam = max(step(0.96, fract(c_uv.y)), step(0.97, fract(c_uv.x)));
	vec3 conc_col = COLOR.rgb * (0.88 + cnoise * 0.20) - vec3(c_seam * 0.12);

	// Roof — granular tar/gravel, matches satellite color
	float rnoise  = fract(sin(dot(floor(UV * 12.0), vec2(127.1, 311.7))) * 43758.5453);
	vec3 roof_albedo = COLOR.rgb * (0.80 + rnoise * 0.24);

	vec3 wall_albedo = brick_col*is_brick + wood_col*is_wood + glass_col*is_glass + conc_col*is_conc;
	float wall_rough = 0.88*is_brick + 0.85*is_wood + g_rough*is_glass + 0.92*is_conc;

	ALBEDO    = mix(wall_albedo, roof_albedo, is_roof);
	ROUGHNESS = mix(wall_rough, 0.90, is_roof);
	METALLIC  = g_metal * is_glass * (1.0 - is_roof);
	SPECULAR  = 0.5;
	EMISSION  = vec3(0.18, 0.28, 0.44) * (1.0 - frame) * is_glass * (1.0 - is_roof) * 0.25;
}
