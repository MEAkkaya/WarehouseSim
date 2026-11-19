shader_type sky;
// The sky: a gradient from a (warm at sunrise and sunset) horizon to the zenith, drifting
// clouds that are lit from the side of the sun, a sun and a moon disc with a soft glow and a
// few stars at night. DayNightCycle sets the uniforms from the clock every frame; nothing
// here needs textures.

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);      // direction TOWARDS the sun
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);    // direction TOWARDS the moon
uniform float day : hint_range(0.0, 1.0) = 1.0;       // 0 = night, 1 = day (smooth)
uniform float warmth : hint_range(0.0, 1.0) = 0.0;    // 1 = the sun is on the horizon

uniform vec3 top_day : source_color = vec3(0.2, 0.42, 0.85);
uniform vec3 horizon_day : source_color = vec3(0.72, 0.83, 0.93);
uniform vec3 top_warm : source_color = vec3(0.3, 0.36, 0.62);
uniform vec3 horizon_warm : source_color = vec3(1.0, 0.55, 0.26);
uniform vec3 top_night : source_color = vec3(0.004, 0.01, 0.04);
uniform vec3 horizon_night : source_color = vec3(0.035, 0.06, 0.14);

uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_softness : hint_range(0.01, 0.6) = 0.22;
uniform float cloud_scale = 1.1;
uniform float cloud_speed = 0.006;
// The graphics setting "Clouds": 1 = on, 0 = a clear sky (project.godot > shader_globals).
global uniform float sky_clouds;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;

	// ---- the gradient
	vec3 top = mix(top_night, mix(top_day, top_warm, warmth), day);
	vec3 horizon = mix(horizon_night, mix(horizon_day, horizon_warm, warmth), day);
	float up = pow(clamp(h, 0.0, 1.0), 0.45);
	vec3 col = mix(horizon, top, up);
	if (h < 0.0) {
		col = mix(horizon, horizon * 0.55, clamp(-h * 4.0, 0.0, 1.0));
	}
	// the warm glow on the side of the horizon where the sun is
	vec2 flat_dir = normalize(dir.xz + vec2(0.0001));
	vec2 flat_sun = normalize(sun_dir.xz + vec2(0.0001));
	float side = pow(max(dot(flat_dir, flat_sun), 0.0), 3.0);
	float low = exp(-max(h, 0.0) * 5.0);
	col += horizon_warm * side * low * warmth * day * 0.55;

	// ---- stars (only when it is dark and the direction is above the horizon)
	float night = 1.0 - day;
	if (night > 0.5 && h > 0.0) {
		vec2 sp = dir.xz / (h + 0.35) * 70.0;
		vec2 cell = floor(sp);
		vec2 jitter = vec2(hash(cell + 7.1), hash(cell + 13.7)) - 0.5;
		float dot_size = smoothstep(0.16, 0.0, length(fract(sp) - 0.5 - jitter * 0.5));
		float star = dot_size * step(0.9965, hash(cell));
		float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + hash(cell) * 40.0);
		col += vec3(star * twinkle) * smoothstep(0.5, 0.9, night) * smoothstep(0.02, 0.3, h) * 1.2;
	}

	// ---- the sun and the moon
	float sd = dot(dir, sun_dir);
	float sun_visible = smoothstep(-0.08, 0.04, sun_dir.y);
	vec3 sun_col = mix(vec3(1.0, 0.93, 0.78), vec3(1.0, 0.55, 0.25), warmth);
	col += sun_col * (smoothstep(0.99955, 0.99985, sd) * 6.0 + pow(max(sd, 0.0), 80.0) * 0.45 + pow(max(sd, 0.0), 6.0) * 0.06) * sun_visible;
	float md = dot(dir, moon_dir);
	float moon_visible = smoothstep(-0.08, 0.05, moon_dir.y) * night;
	vec3 moon_col = vec3(0.5, 0.72, 1.0);
	col += moon_col * (smoothstep(0.99935, 0.9996, md) * 2.2 + pow(max(md, 0.0), 120.0) * 0.5 + pow(max(md, 0.0), 8.0) * 0.04) * moon_visible;

	// ---- clouds on a flat layer above, drifting with the wind
	if (h > 0.0 && sky_clouds > 0.5) {
		vec2 uv = dir.xz / (h + 0.18) * cloud_scale + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);
		float density = fbm(uv * 0.8);
		float lit_side = fbm(uv * 0.8 + sun_dir.xz * 0.12);
		float cover = smoothstep(1.0 - cloud_cover - 0.05, 1.0 - cloud_cover + cloud_softness, density);
		cover *= smoothstep(0.0, 0.22, h);
		float shade = clamp((density - lit_side) * 3.5 + 0.55, 0.0, 1.0);
		vec3 bright = mix(vec3(0.1, 0.13, 0.24), mix(vec3(0.97, 0.97, 1.0), vec3(1.0, 0.62, 0.42), warmth), day);
		vec3 dark = bright * mix(vec3(0.55, 0.6, 0.72), vec3(0.45, 0.4, 0.5), warmth);
		vec3 cloud_col = mix(dark, bright, shade);
		// the edge of a cloud facing the sun shines
		cloud_col += sun_col * pow(max(sd, 0.0), 10.0) * 0.5 * sun_visible * (1.0 - cover * 0.6);
		col = mix(col, cloud_col, cover * 0.92);
	}

	COLOR = col;
}
