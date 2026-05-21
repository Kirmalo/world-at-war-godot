shader_type spatial;
render_mode blend_mix, depth_draw_disabled, cull_disabled, unshaded;

uniform vec4 zone_color : source_color = vec4(0.3, 1.0, 0.43, 0.22);
uniform float pulse_speed : hint_range(0.5, 4.0) = 1.6;
uniform float ring_count  : hint_range(1.0, 6.0) = 3.0;

void fragment() {
	// CylinderMesh UV: (0.5, 0.5) at center, unit circle at edge
	vec2  centered = UV - vec2(0.5);
	float r        = clamp(length(centered) * 2.0, 0.0, 1.0);

	// Slow base pulse
	float pulse = 0.55 + 0.45 * sin(TIME * pulse_speed);

	// Outward-travelling concentric rings
	float ring = sin(r * 6.2832 * ring_count - TIME * pulse_speed * 2.5) * 0.5 + 0.5;
	ring = pow(ring, 2.5) * (1.0 - r * 0.9);   // fade rings at edge

	// Edge glow — bright rim fades inward
	float rim = pow(r, 3.0);

	float alpha = zone_color.a * (0.5 + 0.5 * pulse)
	            + ring * 0.22
	            + rim  * 0.30;

	ALBEDO = zone_color.rgb;
	ALPHA  = clamp(alpha, 0.0, 0.85);
}
