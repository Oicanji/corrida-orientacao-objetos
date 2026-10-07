shader_type canvas_item;
render_mode unshaded, blend_mix;

varying vec4 v_modulate;

uniform float hour : hint_range(0.0, 24.0) = 10.0;
uniform float horizon_y : hint_range(0.3, 1.0) = 0.68;

group_uniforms Colors;
uniform vec4 night_top : source_color = vec4(0.03, 0.05, 0.13, 1.0);
uniform vec4 night_horizon : source_color = vec4(0.17, 0.20, 0.36, 1.0);
uniform vec4 dawn_top : source_color = vec4(0.25, 0.30, 0.55, 1.0);
uniform vec4 dawn_horizon : source_color = vec4(1.0, 0.72, 0.55, 1.0);
uniform vec4 day_top : source_color = vec4(0.30, 0.53, 0.86, 1.0);
uniform vec4 day_horizon : source_color = vec4(0.84, 0.91, 0.94, 1.0);
uniform vec4 dusk_top : source_color = vec4(0.22, 0.20, 0.44, 1.0);
uniform vec4 dusk_horizon : source_color = vec4(0.98, 0.58, 0.40, 1.0);

group_uniforms Sun_and_Moon;
uniform vec4 sun_color : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform float sun_size : hint_range(0.0, 0.2) = 0.05;
uniform vec4 moon_color : source_color = vec4(0.92, 0.94, 1.0, 1.0);
uniform float moon_size : hint_range(0.0, 0.2) = 0.035;
uniform float moon_phase : hint_range(-1.0, 1.0) = 0.55;
uniform float glow : hint_range(0.0, 2.0) = 1.0;
uniform float arc_height : hint_range(0.1, 1.0) = 0.8;

group_uniforms Stars;
uniform float star_density : hint_range(0.0, 1.0) = 0.5;
uniform float twinkle : hint_range(0.0, 1.0) = 0.5;

group_uniforms Clouds;
uniform float clouds : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_speed : hint_range(-0.1, 0.1) = 0.015;
uniform float cloud_scale : hint_range(0.3, 3.0) = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float disc(float r, float radius, float px) {
	return smoothstep(radius + px, radius - px, r);
}

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec2 uv = UV;
	float asp = fwidth(UV.y) / max(fwidth(UV.x), 1e-6);
	float px = fwidth(UV.y);

	float ang = (hour - 6.0) / 12.0 * PI;
	float sun_e = sin(ang);
	float moon_e = -sun_e;
	float arc = horizon_y * arc_height;
	vec2 sun_p = vec2(0.5 - 0.42 * cos(ang), horizon_y - sun_e * arc);
	vec2 moon_p = vec2(0.5 + 0.42 * cos(ang), horizon_y - moon_e * arc);

	vec3 tw_top = hour < 12.0 ? dawn_top.rgb : dusk_top.rgb;
	vec3 tw_hor = hour < 12.0 ? dawn_horizon.rgb : dusk_horizon.rgb;
	float to_day = smoothstep(0.02, 0.4, sun_e);
	float to_night = smoothstep(-0.02, -0.3, sun_e);
	vec3 top = mix(mix(tw_top, day_top.rgb, to_day), night_top.rgb, to_night);
	vec3 hor = mix(mix(tw_hor, day_horizon.rgb, to_day), night_horizon.rgb, to_night);

	float y = clamp(uv.y / horizon_y, 0.0, 1.0);
	vec3 c = mix(top, hor, smoothstep(0.0, 1.0, pow(y, 1.25)));
	float twilight = (1.0 - to_day) * (1.0 - to_night);
	vec2 ds = (uv - sun_p) * vec2(asp, 1.0);
	float rs = length(ds);
	c = mix(c, tw_hor * 1.05, twilight * exp(-rs * 2.5) * smoothstep(0.4, 1.0, y) * 0.6);

	vec3 sun_c = mix(sun_color.rgb * vec3(1.0, 0.66, 0.42), sun_color.rgb, smoothstep(0.0, 0.35, sun_e));
	float sun_up = smoothstep(-0.12, 0.02, sun_e);
	c += sun_c * glow * sun_up * (exp(-rs * 9.0) * 0.3 + exp(-rs * 2.6) * 0.1);

	float night = smoothstep(0.1, -0.2, sun_e);
	if (star_density > 0.0 && night > 0.0) {
		vec2 p = FRAGCOORD.xy / 9.0;
		vec2 cell = floor(p);
		float h1 = hash(cell);
		if (h1 < star_density * 0.35) {
			vec2 at = vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.7 + 0.15;
			float rr = length(fract(p) - at) * 9.0;
			float big = hash(cell + 1.9);
			float size = mix(0.5, 1.3, big * big);
			float star = smoothstep(size + 0.7, size - 0.3, rr) * mix(0.35, 1.0, big);
			star *= 1.0 - twinkle * 0.6 * (0.5 + 0.5 * sin(TIME * mix(1.5, 3.5, h1 * 3.0) + big * 40.0));
			c += vec3(0.9, 0.93, 1.0) * star * night * (1.0 - smoothstep(0.35, 0.95, y));
		}
	}

	vec2 dm = (uv - moon_p) * vec2(asp, 1.0);
	float rm = length(dm);
	float moon_up = smoothstep(-0.12, 0.02, moon_e);
	c += moon_color.rgb * glow * moon_up * night * (exp(-rm * 12.0) * 0.22 + exp(-rm * 3.5) * 0.06);

	float hide = smoothstep(horizon_y + px, horizon_y - px, uv.y);
	float sd = disc(rs, sun_size, px);
	vec3 lw = vec3(0.3, 0.59, 0.11);
	float boost = max(1.05, dot(c, lw) / max(dot(sun_c, lw), 1e-3) + 0.08);
	c = mix(c, sun_c * boost, sd * hide);
	float md = disc(rm, moon_size, px);
	float shift = sign(moon_phase) * (1.0 - abs(moon_phase)) * 2.0 * moon_size;
	float shadow = disc(length(dm - vec2(shift, 0.0)), moon_size, px);
	float moon_lit = md * (1.0 - shadow * abs(sign(moon_phase)));
	vec3 moon_c = moon_color.rgb * (0.92 + 0.08 * (1.0 - length(dm) / max(moon_size, 1e-4)));
	c = mix(c, max(c, moon_c), moon_lit * hide * mix(0.35, 1.0, night));

	if (clouds > 0.0) {
		float cw = 0.34 * cloud_scale;
		float x = uv.x * asp + TIME * cloud_speed * 2.0;
		float id = floor(x / cw);
		float dist = 10.0;
		float base = 0.0;
		float size = 1.0;
		for (int j = -1; j <= 1; j++) {
			float cid = id + float(j);
			if (hash(vec2(cid, 1.7)) > clouds * 1.5) continue;
			float far = hash(vec2(cid, 5.3));
			float sz = cw * mix(0.2, 0.11, far);
			vec2 cc = vec2((cid + 0.5 + (hash(vec2(cid, 2.9)) - 0.5) * 0.4) * cw,
				horizon_y * mix(0.18, 0.62, far));
			float len = mix(0.8, 1.5, hash(vec2(cid, 8.1)));
			float bottom = cc.y + sz * 0.45;
			vec2 bq = abs(vec2(x, uv.y) - vec2(cc.x, bottom - sz * 0.32)) - vec2(sz * 1.05 * len, 0.0);
			float d = length(max(bq, 0.0)) - sz * 0.32;
			for (int k = 0; k < 4; k++) {
				float fk = float(k);
				float ox = (fk - 1.5) * sz * 0.62 * len;
				float r = sz * mix(0.62, 1.05, hash(vec2(cid, fk + 11.0))) * (1.0 - 0.3 * abs(fk - 1.5) / 1.5);
				r *= 1.0 + 0.07 * sin(TIME * 0.35 + fk * 2.1 + cid * 5.0);
				vec2 q = vec2(x, uv.y) - vec2(cc.x + ox, bottom - r * 0.72);
				d = min(d, length(q) - r);
			}
			d = max(d, uv.y - bottom);
			if (d < dist) {
				dist = d;
				base = bottom;
				size = sz;
			}
		}
		float cov = smoothstep(px, -px, dist);
		if (cov > 0.0) {
			float lit = 1.0 - smoothstep(base - size * 0.9, base - size * 0.05, uv.y) * 0.55;
			vec3 light = mix(hor, vec3(1.0), 0.6 * (1.0 - to_night)) * mix(1.0, 0.8, to_night);
			light += sun_c * sun_up * exp(-rs * 3.0) * 0.35;
			vec3 shade = mix(mix(top, hor, 0.5), light, 0.35) * mix(0.95, 0.8, to_night);
			c = mix(c, mix(shade, light, lit), cov * smoothstep(0.0, 0.03, horizon_y - uv.y));
		}
	}

	c += (hash(FRAGCOORD.xy + fract(TIME * 7.0) * 61.0) - 0.5) / 255.0 * 1.5;
	COLOR = vec4(c, 1.0) * v_modulate;
}
