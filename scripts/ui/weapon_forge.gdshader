shader_type canvas_item;
// Colours a forged weapon: the mask's red channel takes the material tint, its blue channel
// glows with the enchantment. Without a mask (older sheets), the whole sprite is tinted lightly.

uniform sampler2D mask_tex : filter_nearest;
uniform bool has_mask = false;
uniform vec3 tint = vec3(1.0);
uniform vec3 glow = vec3(1.0, 0.6, 0.2);
uniform float glow_power = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 col = base.rgb;
	if (has_mask) {
		vec4 m = texture(mask_tex, UV);
		col *= mix(vec3(1.0), tint, m.r);
		// glowing zones take the enchantment's hue (an additive glow would wash out to white)
		float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
		vec3 lit = glow * (0.45 + 1.1 * col) * pulse;
		col = mix(col, lit, m.b * clamp(glow_power, 0.0, 1.0));
	} else {
		col *= mix(vec3(1.0), tint, 0.45);
	}
	COLOR = vec4(col, base.a) * COLOR;
}
