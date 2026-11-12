shader_type spatial;
render_mode unshaded;

varying vec3 globe;
uniform vec3 sun = vec3(-0.6, 0.45, 0.65);

void vertex() {
	globe = normalize(VERTEX);
}

void fragment() {
	vec3 p = normalize(globe);
	float relief = sin(p.x * 10.0 + sin(p.z * 12.0) * 1.6) * sin(p.y * 15.0 + p.z * 9.0);
	float detail = sin(p.x * 59.0 + p.y * 35.0) * sin(p.z * 46.0 - p.y * 14.0);
	float ridges = smoothstep(-0.3, 0.75, relief + detail * 0.15);
	vec3 water = vec3(0.065, 0.20, 0.25);
	vec3 highlands = mix(vec3(0.20, 0.23, 0.31), vec3(0.64, 0.36, 0.25), ridges);
	vec3 ground = mix(water, highlands, smoothstep(-0.62, -0.22, relief));
	float clouds = smoothstep(0.55, 0.92, sin(p.y * 34.0 + p.z * 9.0 + sin(p.x * 9.0)) + detail * 0.22);
	ground = mix(ground, vec3(0.65, 0.76, 0.82), clouds * 0.36);
	float daylight = smoothstep(-0.22, 0.62, dot(p, normalize(sun)));
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	ALBEDO = ground * (0.10 + 0.90 * daylight) + vec3(0.12, 0.48, 0.55) * rim * (daylight * 0.8 + 0.12);
}
