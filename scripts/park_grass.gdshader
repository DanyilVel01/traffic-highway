shader_type spatial;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grid = floor(world_position.xz * 3.1);
	float seed = fract(sin(dot(grid, vec2(12.9898, 78.233))) * 43758.5453);
	float patches = 0.5 + 0.5 * sin(world_position.x * 0.41 + sin(world_position.z * 0.52));
	ALBEDO = mix(vec3(0.27, 0.37, 0.23), vec3(0.43, 0.55, 0.32), patches * 0.62 + seed * 0.27);
	ROUGHNESS = 0.94;
}
