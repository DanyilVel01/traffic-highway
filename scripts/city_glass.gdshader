shader_type spatial;

uniform vec4 tint : source_color = vec4(0.27, 0.43, 0.50, 1.0);

void fragment() {
	float glancing = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	float sky_band = smoothstep(-0.1, 0.9, UV.y + glancing * 0.3);
	vec3 reflection = mix(vec3(0.22, 0.33, 0.37), vec3(0.61, 0.76, 0.81), sky_band);
	ALBEDO = mix(tint.rgb, reflection, 0.22 + 0.45 * glancing);
	ROUGHNESS = 0.25;
	METALLIC = 0.28;
	EMISSION = reflection * glancing * 0.055;
}
