shader_type canvas_item;
render_mode unshaded, blend_mix;

varying vec4 v_modulate;

uniform vec2 dimensions = vec2(1280.0, 720.0);
uniform float rows = 22.0;
uniform float columns = 7.0;
uniform float vertical_scroll : hint_range(-1.0, 1.0, 0.01) = 0.5;
uniform float horizontal_scroll : hint_range(-1.0, 1.0, 0.01) = 0.12;
uniform float size_min : hint_range(0.1, 1.0, 0.1) = 0.28;
uniform float size_max : hint_range(0.1, 1.0, 0.1) = 0.62;
uniform float wave_min : hint_range(0.0, 1.0, 0.1) = 0.12;
uniform float wave_max : hint_range(0.0, 1.0, 0.1) = 0.9;
uniform float wave_speed : hint_range(0.0, 2.0, 0.1) = 0.48;
uniform float wave_rotation : hint_range(-1.0, 1.0, 0.1) = 0.85;
uniform vec4 far_color : source_color = vec4(0.82, 0.88, 0.95, 0.55);
uniform vec4 near_color : source_color = vec4(1.0, 1.0, 1.0, 0.95);

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	float time = 10000.0 + TIME;
	float row_rn = fract(sin(floor((UV.y - vertical_scroll * time) * rows)));
	float column_rn = fract(sin(floor((UV.x + row_rn - horizontal_scroll * time) * columns)));
	float wave = sin(wave_speed * time + column_rn * 90.0);
	vec2 uv = (vec2(
		fract((UV.x + row_rn - horizontal_scroll * time + (wave * (wave_min + (wave_max - wave_min) * column_rn) / columns / 2.0)) * columns),
		fract((UV.y - vertical_scroll * time) * rows)) * 2.0 - 1.0) * vec2(dimensions.x / dimensions.y * rows / columns, 1.0);
	float size = size_min + (size_max - size_min) * column_rn;
	vec4 color = mix(far_color, near_color, column_rn);
	float a = ((column_rn + wave) * wave_rotation) * PI;
	uv *= mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
	float flake = max((size - length(uv)) / size, 0.0) * color.a;
	vec4 out_col = mix(vec4(0.0), vec4(color.rgb, flake), flake);
	COLOR = out_col * v_modulate;
}
