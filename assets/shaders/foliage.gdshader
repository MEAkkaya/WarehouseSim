shader_type spatial;
// Leaves (tree crowns, bushes). Two tricks, both cheap:
//  - the NORMAL comes from the canopy centre: every point of the crown is shaded as if the
//    crown were one soft ball (the direction from the centre of the canopy to the point), not
//    as the faceted low-poly mesh it is. The silhouette stays low-poly, the lighting becomes
//    smooth, and the underside of the crown is a bit darker, like leaves in the shade.
//  - a tiny sway: the outer parts of the crown move a few centimetres in the wind, each tree
//    out of step with the others (the phase comes from where the tree stands).
// `canopy_center` is in the space of the mesh (Foliage works it out from the tree model).

uniform vec4 albedo_color : source_color = vec4(0.24, 0.53, 0.2, 1.0);
uniform vec3 canopy_center = vec3(0.0);
uniform float canopy_radius = 2.0;
// 0 = the mesh's own normals, 1 = the normal points straight away from the canopy centre.
uniform float normal_blend : hint_range(0.0, 1.0) = 0.85;
// How much darker the underside of the crown is (0 = not at all).
uniform float underside_shade : hint_range(0.0, 1.0) = 0.3;
// Sway: how far the outer leaves move (in the mesh's units) and how fast.
uniform float sway_amount = 0.04;
uniform float sway_speed = 1.3;

// The graphics setting "Wind": 1 = on, 0 = off (project.godot > shader_globals).
global uniform float wind_amount;

varying float shade;

void vertex() {
	vec3 from_center = VERTEX - canopy_center;
	vec3 radial = normalize(from_center + vec3(0.0001));
	NORMAL = normalize(mix(NORMAL, radial, normal_blend));
	shade = 1.0 - underside_shade * (1.0 - smoothstep(-0.7, 0.8, radial.y));
	// the sway
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = dot(origin.xz, vec2(0.37, 0.53));
	float t = TIME * sway_speed + phase;
	float reach = clamp(length(from_center) / max(canopy_radius, 0.001), 0.0, 1.5);
	VERTEX += vec3(sin(t) + 0.5 * sin(t * 2.3 + 1.7), 0.15 * sin(t * 1.7), cos(t * 0.9 + 0.6) + 0.5 * sin(t * 1.9)) * sway_amount * reach * wind_amount;
}

void fragment() {
	ALBEDO = albedo_color.rgb * shade;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
