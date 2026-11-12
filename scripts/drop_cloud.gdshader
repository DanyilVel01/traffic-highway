shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, fog_disabled;

varying vec3 local_eye;
varying vec3 local_surface;

void vertex() {
	local_eye = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	local_surface = VERTEX;
}

void fragment() {
	vec3 ray = normalize(local_surface - local_eye);
	float b = dot(local_eye, ray);
	float discriminant = b * b - dot(local_eye, local_eye) + 0.25;
	if (discriminant <= 0.0) { discard; }
	float span = sqrt(discriminant);
	float near_t = max(0.0, -b - span);
	float step_size = (-b + span - near_t) / 12.0;
	float opacity = 0.0;
	for (int i = 0; i < 12; i++) {
		vec3 p = local_eye + ray * (near_t + (float(i) + 0.5) * step_size);
		float lumps = sin(p.x * 22.0 + p.y * 11.0) * sin(p.z * 19.0 - p.y * 9.0);
		float density = smoothstep(0.0, 0.19, 0.46 - length(p) + 0.074 * lumps);
		opacity += (1.0 - opacity) * density * step_size * 4.6;
	}
	ALBEDO = vec3(0.92, 0.96, 1.0);
	ALPHA = opacity * 0.86;
}
