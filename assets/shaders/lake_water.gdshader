shader_type spatial;
// Lake water (visual only). The colour and see-through-ness depend on how much water there
// is between the surface and the lake bed (read from the depth buffer): clear and light
// near the shore, dark and opaque in the middle, with a thin foam line where the water
// meets the bank. Small waves tilt the surface normal, so the sky reflection ripples.
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.22, 0.58, 0.62);
uniform vec3 deep_color : source_color = vec3(0.015, 0.09, 0.18);
// How quickly the colour changes from shallow to deep (1 / metres of water).
uniform float colour_fade = 0.55;
// Metres of water after which the surface is almost opaque.
uniform float opaque_depth = 1.6;
uniform float min_alpha = 0.2;
// Width (metres of water) of the foam line at the shore.
uniform float foam_depth = 0.22;
uniform float wave_strength = 0.1;
uniform float wave_speed = 0.7;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

// Slope (d height / d x, d height / d z) of a few crossing sine waves.
vec2 wave_slope(vec2 p, float t) {
	vec2 g = vec2(0.0);
	vec2 d1 = normalize(vec2(1.0, 0.35));
	vec2 d2 = normalize(vec2(-0.4, 1.0));
	vec2 d3 = normalize(vec2(0.8, -0.9));
	vec2 d4 = normalize(vec2(-1.0, -0.2));
	g += d1 * cos(dot(d1, p) * 1.7 + t * 1.3) * 0.55;
	g += d2 * cos(dot(d2, p) * 2.6 + t * 1.9) * 0.35;
	g += d3 * cos(dot(d3, p) * 4.1 - t * 2.4) * 0.22;
	g += d4 * cos(dot(d4, p) * 6.3 + t * 3.1) * 0.06;
	return g;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// (far away the ripples fade out, otherwise the sun glint on them shimmers)
	float fade = 1.0 / (1.0 + length(VERTEX) * 0.03);
	vec2 slope = wave_slope(world.xz, TIME * wave_speed) * wave_strength * fade;
	vec3 world_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	// Water between the surface and what is behind it (the lake bed).
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	behind.xyz /= behind.w;
	float thickness = max(0.0, (-behind.z) - (-VERTEX.z));

	float deepness = 1.0 - exp(-thickness * colour_fade);
	vec3 colour = mix(shallow_color, deep_color, deepness);
	float alpha = mix(min_alpha, 0.97, 1.0 - exp(-thickness / opaque_depth));
	// The surface reflects more when seen at a low angle.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	alpha = mix(alpha, 1.0, fresnel * 0.5);
	// Foam where the water is very thin.
	float foam = 1.0 - smoothstep(0.0, foam_depth, thickness);
	colour = mix(colour, vec3(0.92, 0.96, 0.97), foam * 0.55);
	alpha = max(alpha, foam * 0.7);

	ALBEDO = colour;
	ALPHA = alpha;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	METALLIC = 0.0;
}
