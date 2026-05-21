shader_type spatial;

void vertex() {
	// Conifers sway stiffly from base — low amplitude, slow frequency
	float phase = VERTEX.x * 1.6 + VERTEX.z * 1.3;
	// Local Y: apex is +h/2, base is -h/2; scale sway so base barely moves
	float height_factor = clamp(VERTEX.y * 2.0 + 1.0, 0.0, 1.0);
	VERTEX.x += sin(TIME * 0.80 + phase) * 0.014 * height_factor;
	VERTEX.z += cos(TIME * 0.62 + phase * 0.85) * 0.009 * height_factor;
}

void fragment() {
	ALBEDO    = COLOR.rgb;
	ROUGHNESS = 0.92;
	METALLIC  = 0.0;
	SPECULAR  = 0.10;
}
