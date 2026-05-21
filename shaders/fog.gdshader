shader_type spatial;
render_mode blend_mix, depth_draw_disabled, cull_back, unshaded;

uniform sampler2D fog_texture : hint_default_white, filter_linear;

// Smooth value noise — same convention as ground.gdshader
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
	vec4 fog_sample  = texture(fog_texture, UV);
	float base_alpha = fog_sample.a;

	// Noise dithering applied only at transition bands:
	//   visible (0.0) → seen (0.55): edge1 peaks mid-band
	//   seen   (0.55) → fog  (0.93): edge2 peaks mid-band
	// Solid fog and fully-clear areas are left clean.
	float n = vnoise(UV * 72.0) * 2.0 - 1.0;   // -1..1 high-freq noise
	float edge1 = smoothstep(0.0,  0.25, base_alpha) * (1.0 - smoothstep(0.30, 0.46, base_alpha));
	float edge2 = smoothstep(0.44, 0.62, base_alpha) * (1.0 - smoothstep(0.72, 0.90, base_alpha));
	float edge  = max(edge1, edge2);

	ALBEDO = fog_sample.rgb;
	ALPHA  = clamp(base_alpha + n * 0.12 * edge, 0.0, 1.0);
}
