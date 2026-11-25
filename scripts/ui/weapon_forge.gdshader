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
		float pulse = 0.78 + 0.22 * sin(TIME * 3.0);
		col += glow * m.b * glow_power * pulse;
	} else {
		col *= mix(vec3(1.0), tint, 0.45);
	}
	COLOR = vec4(col, base.a) * COLOR;
}
