shader_type canvas_item;
render_mode unshaded, blend_mix;

varying vec4 v_modulate;

uniform float boom_anim = -1.0;
uniform vec2 panel_size = vec2(520.0, 520.0);
uniform vec3 boom_pal1 = vec3(0.2, 0.15, 0.3);
uniform vec3 boom_pal2 = vec3(0.9, 0.15, 0.05);
uniform vec3 boom_pal3 = vec3(0.9, 0.5, 0.1);
uniform vec3 boom_pal4 = vec3(0.95, 0.95, 0.35);
uniform vec3 smoke_pal1 = vec3(0.2, 0.15, 0.3);
uniform vec3 smoke_pal2 = vec3(0.35, 0.3, 0.45);
uniform vec3 smoke_pal3 = vec3(0.5, 0.45, 0.6);
uniform float size : hint_range(0.1, 50.0, 0.1) = 5.0;
uniform float disperse : hint_range(0.1, 10.0, 0.1) = 1.0;
uniform float boom_repeat : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float boom_shape : hint_range(0.1, 20.0, 0.1) = 12.0;
uniform float boom_distortion : hint_range(0.0, 10.0, 0.1) = 0.5;
uniform float boom_bubbles : hint_range(0.0, 10.0, 0.1) = 0.5;
uniform float boom_bw : hint_range(0.0, 10.0, 0.1) = 0.5;
uniform float smoke_repeat : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float smoke_shape : hint_range(0.0, 30.0, 0.1) = 16.0;
uniform float smoke_distortion : hint_range(0.0, 10.0, 0.1) = 1.5;
uniform float smoke_bubbles : hint_range(0.0, 10.0, 0.1) = 0.5;
uniform float smoke_bw : hint_range(0.0, 10.0, 0.1) = 0.75;

void vertex() {
	v_modulate = COLOR;
}

vec3 n_rand3(vec3 p) {
	vec3 r = fract(sin(vec3(
		dot(p, vec3(127.1, 311.7, 371.8)),
		dot(p, vec3(269.5, 183.3, 456.1)),
		dot(p, vec3(352.5, 207.3, 198.67))
	)) * 43758.5453) * 2.0 - 1.0;
	return normalize(r + vec3(0.001));
}

float noise(vec3 p) {
	vec3 fv = fract(p);
	vec3 nv = vec3(floor(p));
	vec3 u = fv * fv * fv * (fv * (fv * 6.0 - 15.0) + 10.0);
	return mix(
		mix(
			mix(dot(n_rand3(nv + vec3(0.0, 0.0, 0.0)), fv - vec3(0.0, 0.0, 0.0)),
				dot(n_rand3(nv + vec3(1.0, 0.0, 0.0)), fv - vec3(1.0, 0.0, 0.0)), u.x),
			mix(dot(n_rand3(nv + vec3(0.0, 1.0, 0.0)), fv - vec3(0.0, 1.0, 0.0)),
				dot(n_rand3(nv + vec3(1.0, 1.0, 0.0)), fv - vec3(1.0, 1.0, 0.0)), u.x), u.y),
		mix(
			mix(dot(n_rand3(nv + vec3(0.0, 0.0, 1.0)), fv - vec3(0.0, 0.0, 1.0)),
				dot(n_rand3(nv + vec3(1.0, 0.0, 1.0)), fv - vec3(1.0, 0.0, 1.0)), u.x),
			mix(dot(n_rand3(nv + vec3(0.0, 1.0, 1.0)), fv - vec3(0.0, 1.0, 1.0)),
				dot(n_rand3(nv + vec3(1.0, 1.0, 1.0)), fv - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

float worley(vec3 s, float i_time) {
	vec3 si = floor(s);
	vec3 sf = fract(s);
	float m_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			for (int z = -1; z <= 1; z++) {
				vec3 neighbor = vec3(float(x), float(y), float(z));
				vec3 point = fract(n_rand3(si + neighbor));
				point = 0.5 + 0.5 * sin(disperse * i_time + 6.2831 * point);
				vec3 diff = neighbor + point - sf;
				m_dist = min(m_dist, length(diff));
			}
		}
	}
	return m_dist;
}

float boom(vec2 p, float i_time) {
	float repeat = clamp(i_time * boom_repeat, 0.08, 1.85);
	float shape = 1.0 - pow(distance(vec3(p, 0.0), vec3(0.0)), 2.0) / (repeat * boom_shape) - repeat * 2.0;
	float distortion = noise(vec3(p * boom_distortion, i_time * 0.5));
	float bubbles = boom_bubbles - pow(worley(vec3(p * 1.2, i_time * 2.0), i_time), 3.0);
	float effects = (boom_bw * bubbles + (1.0 - boom_bw) * distortion);
	return shape + effects;
}

float smoke(vec2 p, float i_time) {
	float repeat = clamp(i_time * smoke_repeat, 0.08, 1.85);
	float shape = 1.0 - pow(distance(vec3(p - vec2(0.0, 2.0) * pow(repeat / 1.45, 2.0) * 1.5, 0.0), vec3(0.0)), 2.0) / (repeat * smoke_shape) - pow(repeat * 1.5, 0.5);
	float distortion = noise(vec3(p * smoke_distortion - vec2(0.0, 2.0) * pow(repeat / 1.45, 2.0) * 1.5, i_time * 0.1));
	float pr = max(pow(repeat, 0.35), 0.08);
	float bubbles = smoke_bubbles - pow(worley(vec3((p / pr) - vec2(0.0, 2.0) * pow(repeat / 1.65, 2.0) * 1.5, i_time * 0.1), i_time), 2.0);
	float effects = (smoke_bw * bubbles + (1.0 - smoke_bw) * distortion);
	return shape + effects;
}

float posterize(float v, int n) {
	float fn = float(n);
	return floor(v * fn) / max(fn - 1.0, 1.0);
}

void fragment() {
	float ligado = step(0.0, boom_anim);
	float i_time = max(boom_anim, 0.08);
	vec2 uv = UV;
	uv.y = 1.0 - uv.y;
	vec2 pos = uv - vec2(0.5, 0.4);
	pos.x *= panel_size.y / max(panel_size.x, 1.0);
	pos *= size;

	float boom_val = boom(pos, i_time);
	float boom_a = step(0.0, boom_val);
	int bi = clamp(int(posterize(boom_val, 4) * 4.0), 0, 3);
	vec3 boom_col = bi == 0 ? boom_pal1 : bi == 1 ? boom_pal2 : bi == 2 ? boom_pal3 : boom_pal4;
	boom_col -= vec3(1.0 - boom_a);

	float smoke_val = smoke(pos, i_time);
	float smoke_a = step(0.0, smoke_val);
	int si = clamp(int(posterize(smoke_val, 3) * 3.0), 0, 2);
	vec3 smoke_col = si == 0 ? smoke_pal1 : si == 1 ? smoke_pal2 : smoke_pal3;
	smoke_col -= vec3(1.0 - smoke_a);

	float bw = step(smoke_val * 1.25, boom_val);
	vec3 color = bw * boom_col + (1.0 - bw) * smoke_col;
	float alpha = bw * boom_a + (1.0 - bw) * smoke_a;
	alpha *= 1.0 - smoothstep(1.55, 2.05, i_time);
	COLOR = vec4(max(color, vec3(0.0)), alpha * ligado) * v_modulate;
}
