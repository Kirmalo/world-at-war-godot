shader_type spatial;

void vertex() {
	// Wind sway — amplitude increases with height, per-instance phase from VERTEX.x
	float phase = VERTEX.x * 2.7 + VERTEX.z * 1.9;
	float sway  = sin(TIME * 1.4 + phase) * 0.038 + cos(TIME * 0.9 + phase * 0.7) * 0.022;
	VERTEX.x += sway * max(0.0, VERTEX.y);
	VERTEX.z += cos(TIME * 1.1 + phase * 1.3) * 0.024 * max(0.0, VERTEX.y);
}

void fragment() {
	ALBEDO    = COLOR.rgb;
	ROUGHNESS = 0.88;
	METALLIC  = 0.0;
	// Faint SSS-style emission: sunlit faces get a warm green-gold subsurface glow
	EMISSION  = COLOR.rgb * 0.06 * max(0.0, dot(NORMAL, vec3(0.3, 1.0, 0.2)));
}
