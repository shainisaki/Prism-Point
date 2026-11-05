shader_type canvas_item;
render_mode unshaded;

uniform vec2 world_size = vec2(4800.0, 3600.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 world = UV * world_size;
	float row = floor(world.y / 192.0);
	vec2 masonry = vec2(world.x + mod(row, 2.0) * 128.0, world.y) / vec2(256.0, 192.0);
	vec2 tile = floor(masonry);
	vec2 local = fract(masonry) * vec2(256.0, 192.0);
	vec2 edge = min(local, vec2(256.0, 192.0) - local);
	float joint = 1.0 - smoothstep(0.7, 2.5, min(edge.x, edge.y));
	float variation = hash(tile) - 0.5;
	float mineral = noise(world * 0.024) * 0.65 + noise(world * 0.085) * 0.35;
	float grain = hash(floor(world * 0.9)) - 0.5;
	vec3 stone = vec3(0.046, 0.067, 0.080);
	stone += variation * vec3(0.012, 0.016, 0.018);
	stone += (mineral - 0.5) * vec3(0.021, 0.026, 0.030);
	stone += grain * 0.010;
	// Fine recessed joints and a restrained upper bevel suggest material depth.
	stone = mix(stone, vec3(0.022, 0.033, 0.041), joint * 0.82);
	float upper_bevel = smoothstep(1.5, 2.5, local.y) * (1.0 - smoothstep(2.5, 4.5, local.y));
	stone += upper_bevel * vec3(0.016, 0.021, 0.024);
	float wear = smoothstep(0.66, 0.9, noise(world * 0.013 + vec2(13.0, 2.0)));
	stone += wear * vec3(0.009, 0.011, 0.012);
	COLOR = vec4(stone, 1.0);
}
