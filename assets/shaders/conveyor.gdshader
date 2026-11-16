shader_type spatial;
// The moving surface of the conveyor belt: dark rubber with lighter stripes that slide along
// the belt's length (the mesh's local Z axis), so you can see it is running. Visual only.
render_mode cull_disabled;

uniform vec4 rubber : source_color = vec4(0.12, 0.12, 0.14, 1.0);
uniform vec4 stripe : source_color = vec4(0.28, 0.28, 0.3, 1.0);
// Metres per second the stripes move (the same as the speed of the boxes), and the distance
// between two stripes.
uniform float speed = 2.0;
uniform float spacing = 0.5;
// +1 or -1: which way the belt moves along its local Z axis.
uniform float direction = -1.0;

varying float along;

void vertex() {
	along = VERTEX.z;
}

void fragment() {
	float t = fract((along - direction * TIME * speed) / spacing);
	float band = step(0.82, t);
	ALBEDO = mix(rubber.rgb, stripe.rgb, band);
	ROUGHNESS = 0.9;
}
