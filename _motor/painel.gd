extends Control

var veiculo
var ponteiro_vel: Line2D
var ponteiro_rpm: Line2D

@onready var vel_num: Label = $VelNum
@onready var rpm_num: Label = $RpmNum
@onready var crono: Label = $Crono
@onready var odo: Label = $Odo
@onready var knob: Node2D = $Gate/Knob
@onready var marcha_num: Label = $MarchaNum
@onready var marcha_modo: Label = $MarchaModo
@onready var marcha_alerta: Label = $MarchaAlerta

func _ready() -> void:
	Log.fase("painel.ready")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Log.passo("painel", "_ready")
	ponteiro_vel = _montar_relogio($RelogioVel, Color(0.85, 0.88, 0.9), Color(1, 0.22, 0.16))
	ponteiro_rpm = _montar_relogio($RelogioRpm, Color(0.45, 0.92, 0.62), Color(1, 0.35, 0.12))
	_lcd(vel_num, 0.98, 0.78, 0.22)
	_lcd(rpm_num, 0.45, 0.92, 0.62)
	_lcd($VelUnidade, 0.85, 0.88, 0.9)
	_lcd($RpmUnidade, 0.45, 0.92, 0.62)
	_lcd(crono, 0.35, 0.95, 0.55)
	_lcd(odo, 0.98, 0.78, 0.22)
	_lcd(marcha_num, 0.98, 0.78, 0.22)
	_lcd(marcha_modo, 0.85, 0.88, 0.9)
	_lcd(marcha_alerta, 1.0, 0.28, 0.18)
	_disco(knob, 8.5, Color(0.98, 0.78, 0.22))
	_disco(knob, 3.2, Color(0.22, 0.18, 0.1))
	veiculo = get_node_or_null("../../Veiculo")
	Log.passo("painel", "veiculo=%s" % veiculo)

func _process(_delta: float) -> void:
	if veiculo == null or not is_instance_valid(veiculo):
		return
	if not veiculo.has_method("texto_km"):
		return
	var kmh := minf(float(veiculo.vel_hud) * Corrida.KMH_FATOR, Corrida.KMH_MORTE)
	vel_num.text = str(int(kmh))
	_apontar(ponteiro_vel, kmh / Corrida.KMH_MORTE)
	var mil := int(round(float(veiculo.rpm) / 1000.0))
	mil = clampi(mil, 0, 8)
	rpm_num.text = str(mil)
	_apontar(ponteiro_rpm, float(veiculo.rpm) / 8000.0)
	crono.text = veiculo.texto_tempo()
	odo.text = veiculo.texto_km() + " km"
	if veiculo.na_re:
		marcha_num.text = "R"
	elif veiculo.troca_t > 0.14:
		marcha_num.text = "N"
	else:
		marcha_num.text = str(veiculo.marcha_atual)
	marcha_modo.text = "AUTO" if veiculo.modo_auto() else "MANUAL"
	var alerta: bool = (
		not bool(veiculo.modo_auto())
		and not bool(veiculo.na_re)
		and float(veiculo.rpm) >= 7000.0
		and int(veiculo.marcha_atual) < 5
	)
	if alerta:
		var pisca := 0.35 + 0.65 * absf(sin(float(veiculo.tempo_vivo) * 12.0))
		marcha_alerta.text = "TROQUE W"
		marcha_alerta.modulate = Color(1, 0.25, 0.12, pisca)
	else:
		marcha_alerta.text = ""
		marcha_alerta.modulate = Color(1, 1, 1, 1)
	if veiculo.troca_t > 0.0:
		var punch: float = 1.0 + float(veiculo.troca_t) * 1.8
		marcha_num.add_theme_font_size_override("font_size", int(52 + punch * 12.0))
	else:
		marcha_num.add_theme_font_size_override("font_size", 64)
	knob.position = veiculo.alavanca

func _lcd(label: Label, r: float, g: float, b: float) -> void:
	label.add_theme_color_override("font_color", Color(r, g, b))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04))
	label.add_theme_constant_override("outline_size", 8)

func _disco(pai: Node2D, raio: float, cor: Color) -> void:
	var fundo := Polygon2D.new()
	var poly := PackedVector2Array()
	var i := 0
	while i <= 36:
		var a := float(i) / 36.0 * TAU
		poly.append(Vector2(cos(a) * raio, sin(a) * raio))
		i += 1
	fundo.polygon = poly
	fundo.color = cor
	pai.add_child(fundo)

func _linha(pai: Node2D, x0: float, y0: float, x1: float, y1: float, largura: float, cor: Color) -> Line2D:
	var linha := Line2D.new()
	var pts := PackedVector2Array()
	pts.append(Vector2(x0, y0))
	pts.append(Vector2(x1, y1))
	linha.points = pts
	linha.width = largura
	linha.default_color = cor
	linha.begin_cap_mode = Line2D.LINE_CAP_ROUND
	linha.end_cap_mode = Line2D.LINE_CAP_ROUND
	pai.add_child(linha)
	return linha

func _montar_relogio(raiz: Node2D, cor_arco: Color, cor_redline: Color) -> Line2D:
	_disco(raiz, 92.0, Color(0.08, 0.09, 0.11, 0.94))
	_disco(raiz, 78.0, Color(0.12, 0.13, 0.16))
	var anel := PackedVector2Array()
	var i := 0
	while i <= 40:
		var a := deg_to_rad(150.0) + float(i) / 40.0 * deg_to_rad(240.0)
		anel.append(Vector2(cos(a) * 72.0, sin(a) * 72.0))
		i += 1
	var arco := Line2D.new()
	arco.points = anel
	arco.width = 6.0
	arco.default_color = cor_arco
	raiz.add_child(arco)
	i = 0
	while i <= 8:
		var frac := float(i) / 8.0
		var a2 := deg_to_rad(150.0) + frac * deg_to_rad(240.0)
		var cor := cor_redline if i >= 7 else Color(0.95, 0.95, 0.9)
		_linha(raiz, cos(a2) * 62.0, sin(a2) * 62.0, cos(a2) * 76.0, sin(a2) * 76.0, 3.4, cor)
		i += 1
	var ponteiro := _linha(
		raiz,
		0.0,
		0.0,
		cos(deg_to_rad(150.0)) * 58.0,
		sin(deg_to_rad(150.0)) * 58.0,
		4.5,
		cor_redline,
	)
	_disco(raiz, 6.5, Color(0.92, 0.9, 0.82))
	return ponteiro

func _apontar(ponteiro: Line2D, frac: float) -> void:
	if ponteiro == null:
		return
	frac = clampf(frac, 0.0, 1.0)
	var a := deg_to_rad(150.0) + frac * deg_to_rad(240.0)
	var pts := PackedVector2Array()
	pts.append(Vector2(cos(a) * -9.0, sin(a) * -9.0))
	pts.append(Vector2(cos(a) * 60.0, sin(a) * 60.0))
	ponteiro.points = pts
