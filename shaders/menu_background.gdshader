shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.035, 0.055, 0.07, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.006, 0.009, 0.015, 1.0);
uniform vec4 glow_color : source_color = vec4(0.22, 0.34, 0.31, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 base = mix(bottom_color.rgb, top_color.rgb, 1.0 - uv.y);
	float hall_light = exp(-55.0 * pow(uv.x - 0.28, 2.0)) * smoothstep(0.82, 0.28, uv.y);
	float vignette = 1.0 - smoothstep(0.28, 0.78, distance(uv, vec2(0.5)));
	float grain = (hash(floor(uv * vec2(640.0, 360.0)) + floor(TIME * 7.0)) - 0.5) * 0.018;
	float scanline = sin(uv.y * 720.0) * 0.006;
	base += glow_color.rgb * hall_light * 0.12 + grain + scanline;
	COLOR = vec4(base * mix(0.62, 1.0, vignette), 1.0);
}
