shader_type canvas_item;
render_mode unshaded;

uniform float mist_time = 0.0;
uniform vec2 view_size = vec2(1280.0, 800.0);
uniform vec2 world_offset = vec2(0.0);

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
	// Broad drifting clouds across the whole view, with no spotlight or hard rim.
	vec2 p = UV * vec2(view_size.x / max(view_size.y, 1.0), 1.0);
	p = p * 3.2 + world_offset * 0.0006;
	vec2 drift = vec2(mist_time * 0.018, -mist_time * 0.012);
	float cloud = noise(p + drift) * 0.62;
	cloud += noise(p * 2.1 - drift * 0.7) * 0.27;
	cloud += noise(p * 4.0 + drift * 0.4) * 0.11;
	float density = smoothstep(0.05, 0.95, cloud);
	vec3 tint = mix(vec3(0.22, 0.29, 0.33), vec3(0.64, 0.71, 0.73), cloud);
	COLOR = vec4(tint, mix(0.30, 0.68, density));
}
