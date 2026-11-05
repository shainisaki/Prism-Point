shader_type canvas_item;
render_mode unshaded;
uniform vec2 world_size = vec2(6000.0, 4500.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float line_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0));
}
void fragment() {
	vec2 world = UV * world_size;
	vec2 cell = floor(world / 96.0);
	vec2 p = mod(world, 96.0);
	float choice = hash(cell);
	if (choice > 0.5) { p.x = 96.0 - p.x; }
	if (hash(cell + 7.0) > 0.5) { p = p.yx; }
	float wire = min(line_distance(p, vec2(12.0, 20.0), vec2(35.0, 20.0)), line_distance(p, vec2(35.0, 20.0), vec2(53.0, 38.0)));
	wire = min(wire, line_distance(p, vec2(53.0, 38.0), vec2(53.0, 76.0)));
	float branch = min(line_distance(p, vec2(72.0, 16.0), vec2(72.0, 39.0)), line_distance(p, vec2(72.0, 39.0), vec2(84.0, 51.0)));
	float traces = 1.0 - smoothstep(0.35, 1.1, min(wire, branch));
	float ring = min(abs(length(p - vec2(12.0, 20.0)) - 2.5), abs(length(p - vec2(53.0, 76.0)) - 2.5));
	ring = min(ring, abs(length(p - vec2(72.0, 16.0)) - 2.0));
	float contacts = 1.0 - smoothstep(0.35, 0.9, ring);
	float enabled = step(0.18, choice);
	// All non-circuit pixels stay exactly #141414, without grain or stone tiles.
	vec3 base = vec3(20.0 / 255.0);
	vec3 color = mix(base, vec3(0.13, 0.17, 0.19), traces * enabled * 0.62);
	color = mix(color, vec3(0.22, 0.30, 0.33), contacts * enabled * 0.72);
	COLOR = vec4(color, 1.0);
}
