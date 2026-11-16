shader_type spatial;
// Wind for the grass tufts (visual only). The wind comes as GUST BANDS that travel across
// the world: a tuft starts to lean a moment after the tuft upwind of it, so you can see a
// gust run through the grass from one side to the other. Every tuft's delay comes only from
// where it stands (a phase that changes smoothly with position), so neighbours lean almost
// the same way at almost the same time - the change from one to the next is gradual.
// The wind direction itself drifts slowly, and the fronts are slightly curved.
render_mode cull_disabled;   // two-sided, like the model's own material

uniform vec4 albedo : source_color = vec4(0.278, 0.538, 0.163, 1.0);
// How far the tips lean at the strongest gust (metres per metre of height).
uniform float wind_strength = 0.24;
// How fast the gusts travel (the gust bands move at wind_speed / gust_scale metres per
// second: 1.1 / 0.12 = about 9 m/s).
uniform float wind_speed = 1.1;
// How quickly the delay grows with distance: the distance between two gust bands is
// 2 * PI / gust_scale (about 52 m). Bigger = bands closer together and more delay
// between neighbours.
uniform float gust_scale = 0.12;
// How pointed the gusts are (higher = short strong gusts with calm air between).
uniform float gust_sharpness = 2.5;
// How fast the wind direction drifts.
uniform float turn_speed = 0.03;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;                       // where the tuft stands
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = max(world.y - base.y, 0.0);
	// The wind direction: the same everywhere, turning slowly.
	float angle = 0.8 * sin(TIME * turn_speed) + 0.45 * sin(TIME * turn_speed * 2.3 + 1.7);
	vec2 dir = vec2(cos(angle), sin(angle));
	vec2 across = vec2(-dir.y, dir.x);
	// The time a gust needs to reach this tuft: its distance along the wind (plus a slow
	// sideways bend, so the fronts are not ruler-straight). Smooth in space, so adjacent
	// tufts are only a tiny moment apart.
	float delay = dot(base.xz, dir) + 6.0 * sin(dot(base.xz, across) * 0.02 + TIME * 0.05);
	float phase = delay * gust_scale - TIME * wind_speed;
	// Gust bands: calm air with a strong lean while a band passes.
	float gust = pow(0.5 + 0.5 * sin(phase), gust_sharpness);
	float sway = 0.1 + 1.05 * gust;
	// Lean the blade tips (more at the top), and let them dip a little as they bend.
	float lean = sway * wind_strength * pow(height, 1.3);
	vec3 offset = vec3(dir.x * lean, -lean * lean * 0.5 / max(height, 0.05), dir.y * lean);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * offset;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
