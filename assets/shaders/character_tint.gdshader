shader_type spatial;
// People: the painted body texture, with the clothes recoloured. The mask texture is
// black everywhere except the clothes, where it holds the brightness of the base texture
// (so fabric folds and patterns survive). Where the mask is on, the base colour is replaced
// by the shirt or trousers colour, shaded by the mask; the rest (skin, face, hair) is
// the base texture untouched.
//
// Shirt and trousers are told apart by where they lie in the texture: the shirt islands
// are above `split_v` (rows 103-152 of 256), the trousers below (rows 154-193).
render_mode cull_disabled;

uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D clothes_mask : filter_linear_mipmap, repeat_disable;
uniform vec3 shirt_color : source_color = vec3(0.2, 0.4, 0.75);
uniform vec3 pants_color : source_color = vec3(0.18, 0.2, 0.28);
// Height in the texture (0 = top, 1 = bottom) between the shirt islands and the trousers.
uniform float split_v = 0.6;
// Average mask brightness of the shirt and the trousers, so each keeps the colour you pick
// instead of getting darker or lighter with the mask.
uniform float shirt_average = 0.83;
uniform float pants_average = 0.23;
// 0 = flat colours, 1 = the full folds and patterns of the texture.
uniform float detail : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 base = texture(base_texture, UV).rgb;
	float mask = texture(clothes_mask, UV).r;
	float cloth = smoothstep(0.03, 0.1, mask);
	bool is_shirt = UV.y < split_v;
	vec3 tint = is_shirt ? shirt_color : pants_color;
	float average = is_shirt ? shirt_average : pants_average;
	float shade = mix(1.0, clamp(mask / average, 0.0, 1.6), detail);
	ALBEDO = mix(base, tint * shade, cloth);
	ROUGHNESS = 0.8;
	METALLIC = 0.0;
}
