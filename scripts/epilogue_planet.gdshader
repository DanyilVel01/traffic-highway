shader_type spatial;
render_mode unshaded;

uniform vec4 dark_band : source_color = vec4(0.3, 0.2, 0.16, 1.0);
uniform vec4 light_band : source_color = vec4(0.9, 0.7, 0.4, 1.0);
varying vec3 globe;

void vertex() {
	globe = normalize(VERTEX);
}

void fragment() {
	vec3 p = normalize(globe);
	float wave = sin(p.y * 40.0 + sin(p.x * 6.0 + p.z * 4.0) * 0.8);
	float fine = sin(p.y * 124.0 + sin(p.z * 19.0) * 1.7);
	float blend = clamp(0.51 + wave * 0.27 + fine * 0.09 + sin(p.y * 12.0) * 0.13, 0.0, 1.0);
	float daylight = smoothstep(-0.28, 0.57, dot(p, normalize(vec3(-0.5, 0.65, 0.68))));
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.5);
	ALBEDO = mix(dark_band.rgb, light_band.rgb, blend) * (0.10 + 0.90 * daylight) + light_band.rgb * rim * daylight * 0.18;
}
