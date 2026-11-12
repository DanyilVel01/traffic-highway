shader_type canvas_item;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float moisture : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 center_offset = SCREEN_UV - vec2(0.5);
	vec2 spread = center_offset * amount * 0.085;
	vec3 sharp = texture(scene_color, SCREEN_UV).rgb;
	vec3 blurred = (texture(scene_color, SCREEN_UV - spread).rgb
		+ texture(scene_color, SCREEN_UV - spread * 0.60).rgb
		+ texture(scene_color, SCREEN_UV - spread * 0.25).rgb + sharp) * 0.25;
	float radius = length(center_offset);
	float angle = atan(center_offset.y, center_offset.x);
	float lines = pow(max(0.0, sin(angle * 67.0 + sin(floor(angle * 9.0) * 71.0))), 19.0);
	lines *= smoothstep(0.25, 0.68, radius) * smoothstep(0.35, 0.95, amount);
	lines *= 0.36 + 0.64 * sin(radius * 31.0 - TIME * 19.0) * sin(radius * 31.0 - TIME * 19.0);
	vec2 droplets = fract(SCREEN_UV * vec2(39.0, 21.0) + vec2(0.0, -TIME * 0.28)) - vec2(0.5);
	float dew = 1.0 - smoothstep(0.05, 0.18, length(droplets * vec2(1.6, 0.65)));
	vec3 image = mix(sharp, blurred, smoothstep(0.12, 0.67, radius));
	image = mix(image, vec3(0.90, 0.96, 1.0), lines * 0.45 + moisture * (0.12 + dew * 0.26));
	COLOR = vec4(image, 1.0);
}
