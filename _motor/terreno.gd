extends StaticBody2D

const ZONA := preload("res://scenes/zona_terreno.tscn")

var destino: CollisionObject2D
var _fossos: Array[float] = []
var _niveis: Array = []
var _polys := 0
var _zona_i := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Log.fase("terreno.ready")
	Log.passo("terreno", "_ready")
	_fossos = _calcular_fossos()
	Log.passo("terreno", "fossos=%d" % _fossos.size())
	_desligar_placeholder()
	_montar()
	Log.passo("terreno", "pronto zonas=%d polys=%d filhos=%d" % [_niveis.size(), _polys, get_child_count()])

func usar_corpo(corpo: CollisionObject2D) -> void:
	destino = corpo
	Log.passo("terreno", "usar_corpo %s" % corpo.name, false)

func montar_faixa(pts: PackedVector2Array) -> int:
	Log.fase("terreno.faixa_z%d" % _zona_i)
	if pts.size() < 2:
		Log.erro("terreno", "faixa curta %d" % pts.size())
		return 0
	var pai: CollisionObject2D = self
	if destino != null:
		pai = destino
	else:
		Log.erro("terreno", "destino nulo, faixa no terreno raiz")
	var criados := 0
	var i := 0
	while i < pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if absf(b.x - a.x) < 1.0:
			i += 1
			continue
		var poly := PackedVector2Array()
		poly.append(Vector2(a.x, a.y))
		poly.append(Vector2(b.x, b.y))
		poly.append(Vector2(b.x, 1800.0))
		poly.append(Vector2(a.x, 1800.0))
		var col := CollisionPolygon2D.new()
		pai.add_child(col)
		col.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		col.polygon = poly
		criados += 1
		i += 1
	_polys += criados
	Log.passo("terreno", "faixa z=%d pts=%d polys=%d total=%d" % [_zona_i, pts.size(), criados, _polys], false)
	return criados

func altura(x: float) -> float:
	if x <= Corrida.Z0:
		if x > Corrida.Z0 - 220.0:
			var p := (x - (Corrida.Z0 - 220.0)) / 220.0
			return _altura_preto(x) * (1.0 - p) + _altura_barro(x) * p
		return _altura_preto(x)
	if x <= Corrida.Z1:
		if x > Corrida.Z1 - 220.0:
			var p1 := (x - (Corrida.Z1 - 220.0)) / 220.0
			return _altura_barro(x) * (1.0 - p1) + _altura_colinas(x) * p1
		return _altura_barro(x)
	if x <= Corrida.Z2:
		if x > Corrida.Z2 - 220.0:
			var p2 := (x - (Corrida.Z2 - 220.0)) / 220.0
			return _altura_colinas(x) * (1.0 - p2) + _altura_bolas(x) * p2
		return _altura_colinas(x)
	if x <= Corrida.Z3:
		if x > Corrida.Z3 - 140.0:
			var p3 := (x - (Corrida.Z3 - 140.0)) / 140.0
			return _altura_bolas(x) * (1.0 - p3) + _altura_degraus(x) * p3
		return _altura_bolas(x)
	if x <= Corrida.Z4:
		if x > Corrida.Z4 - 140.0:
			var p4 := (x - (Corrida.Z4 - 140.0)) / 140.0
			return _altura_degraus(x) * (1.0 - p4) + _altura_vulcoes(x) * p4
		return _altura_degraus(x)
	if x <= Corrida.Z5:
		if x > Corrida.Z5 - 180.0:
			var p5 := (x - (Corrida.Z5 - 180.0)) / 180.0
			return _altura_vulcoes(x) * (1.0 - p5) + _altura_montanhas(x) * p5
		return _altura_vulcoes(x)
	return _altura_montanhas(x)

func nome_solo(x: float) -> String:
	if x < Corrida.Z0:
		return "preto"
	if x < Corrida.Z1:
		return "barro"
	if x < Corrida.Z2:
		return "verde"
	if x < Corrida.Z3:
		return "areia"
	if x < Corrida.Z4:
		return "gelo"
	if x < Corrida.Z5:
		return "vulcao"
	return "montanha"

func eficiencia(solo: String, kmh: float) -> float:
	var v: float = clampf(kmh, 0.0, Corrida.KMH_TETO)
	return 1.0 + _bonus_solo(solo, v)

func _bonus_solo(solo: String, kmh: float) -> float:
	if solo == "preto" or solo == "vulcao":
		return _bonus_asfalto(kmh)
	if solo == "barro":
		if kmh < 50.0:
			return 0.10
		return -0.80
	if solo == "verde" or solo == "montanha":
		return _bonus_grama(kmh)
	if solo == "areia":
		if kmh > 30.0 and kmh <= 60.0:
			return 0.20
		return 0.0
	if solo == "gelo":
		if kmh <= 30.0:
			return 0.40
		if kmh <= 40.0:
			return 0.10
		return -0.60
	return 0.0

func _bonus_asfalto(kmh: float) -> float:
	if kmh <= 60.0:
		return 0.20
	if kmh >= 80.0:
		return 0.40
	return lerpf(0.20, 0.40, (kmh - 60.0) / 20.0)

func _bonus_grama(kmh: float) -> float:
	if kmh <= 20.0:
		return 0.0
	if kmh <= 60.0:
		return 0.40
	if kmh >= 80.0:
		return -0.40
	return lerpf(0.40, -0.40, (kmh - 60.0) / 20.0)

func cull(x: float) -> void:
	Log.fase("terreno.cull")
	var vivos := 0
	for nivel in _niveis:
		if nivel["morto"]:
			continue
		if nivel["x1"] >= x - Corrida.MARGEM_NIVEL:
			vivos += 1
			continue
		if is_instance_valid(nivel["no"]):
			nivel["no"].queue_free()
		_polys -= int(nivel["polys"])
		nivel["morto"] = true
		Log.passo("terreno", "zona morta x1=%.0f em x=%.0f polys=%d" % [nivel["x1"], x, _polys])
	if Engine.get_physics_frames() % 120 == 0:
		Log.passo("terreno", "vivos=%d polys=%d x=%.0f" % [vivos, _polys, x], false)

func _desligar_placeholder() -> void:
	var col := get_node_or_null("Colisao")
	if col is CollisionPolygon2D:
		col.disabled = true
		col.polygon = PackedVector2Array()
		Log.passo("terreno", "placeholder colisao off")
	else:
		Log.erro("terreno", "sem Colisao")
	var visual := get_node_or_null("Visual")
	if visual:
		visual.hide()
	var linha := get_node_or_null("GramaLinha")
	if linha:
		linha.hide()

func _montar() -> void:
	Log.fase("terreno.montar")
	var tex = null
	if ResourceLoader.exists("res://assets/Images/Terrain/DirtBG.png"):
		tex = load("res://assets/Images/Terrain/DirtBG.png")
		Log.passo("terreno", "tex chao %s" % tex)
	else:
		Log.erro("terreno", "DirtBG ausente")
	var zonas: Array = [
		[-200.0, Corrida.Z0, Color(0.08, 0.08, 0.09), Color(0.20, 0.20, 0.22)],
		[Corrida.Z0, Corrida.Z1, Color(0.22, 0.10, 0.04), Color(0.48, 0.28, 0.10)],
		[Corrida.Z1, Corrida.Z2, Color(0.40, 0.52, 0.24), Color(0.38, 0.74, 0.28)],
		[Corrida.Z2, Corrida.Z3, Color(0.84, 0.62, 0.30), Color(0.95, 0.78, 0.38)],
		[Corrida.Z3, Corrida.Z4, Color(0.58, 0.78, 0.90), Color(0.88, 0.96, 1.0)],
		[Corrida.Z4, Corrida.Z5, Color(0.28, 0.11, 0.09), Color(0.95, 0.32, 0.10)],
		[Corrida.Z5, Corrida.Z6 + 400.0, Color(0.38, 0.42, 0.36), Color(0.62, 0.66, 0.52)],
	]
	_niveis = []
	var i := 0
	for zona_cfg in zonas:
		_zona_i = i
		Log.fase("terreno.zona_%d" % i)
		var x0: float = zona_cfg[0]
		var x1: float = zona_cfg[1]
		Log.passo("terreno", "zona %d x0=%.0f x1=%.0f" % [i, x0, x1])
		var pts: Array = _pontos_faixa(x0, x1, 12.0 if i == 6 else 24.0)
		Log.passo("terreno", "zona %d pts=%d" % [i, pts.size()])
		var zona := ZONA.instantiate()
		zona.name = "Zona%d" % i
		zona.physics_material_override = physics_material_override
		add_child(zona)
		var visual: Polygon2D = zona.get_node("Visual")
		var linha: Line2D = zona.get_node("Linha")
		visual.polygon = _poly_fundo(pts)
		visual.color = zona_cfg[2]
		if tex != null:
			visual.texture = tex
			visual.texture_scale = Vector2(0.2, 0.2)
		var superficie := PackedVector2Array()
		for p in pts:
			superficie.append(p)
		linha.points = superficie
		linha.width = 34.0 if i == 1 else 22.0
		linha.default_color = zona_cfg[3]
		Log.fase("terreno.zona_%d_colisao" % i)
		var npol := _colidir_faixa(zona, pts, 1 if i >= 1 else 2)
		_niveis.append({"x1": x1, "no": zona, "morto": false, "polys": npol})
		Log.passo("terreno", "zona %d ok polys=%d" % [i, npol])
		i += 1
	Log.fase("terreno.fim")

func _colidir_faixa(zona: StaticBody2D, pts: Array, passo_col: int) -> int:
	var col_pts: Array = []
	var k := 0
	if passo_col < 1:
		passo_col = 1
	while k < pts.size():
		col_pts.append(pts[k])
		k += passo_col
	if col_pts.is_empty():
		Log.erro("terreno", "sem pontos de colisao")
		return 0
	if col_pts[-1].x < pts[-1].x - 0.5:
		col_pts.append(pts[-1])
	usar_corpo(zona)
	var inicio := 0
	var total := 0
	while inicio < col_pts.size() - 1:
		var fim := inicio + 80
		if fim > col_pts.size():
			fim = col_pts.size()
		Log.fase("terreno.z%d_chunk_%d" % [_zona_i, inicio])
		var pack := PackedVector2Array()
		var j := inicio
		while j < fim:
			var p: Vector2 = col_pts[j]
			pack.append(Vector2(p.x, p.y))
			j += 1
		if pack.size() >= 2:
			total += montar_faixa(pack)
		inicio = fim - 1
	return total

func _pontos_faixa(x0: float, x1: float, passo: float) -> Array:
	var pts: Array = []
	var x := x0
	while x <= x1:
		pts.append(Vector2(x, altura(x)))
		x += passo
	if pts.is_empty() or pts[-1].x < x1 - 0.5:
		pts.append(Vector2(x1, altura(x1)))
	return pts

func _poly_fundo(pts: Array) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(p)
	poly.append(Vector2(pts[-1].x, 1800.0))
	poly.append(Vector2(pts[0].x, 1800.0))
	return poly

func _calcular_fossos() -> Array[float]:
	var lista: Array[float] = []
	var x := Corrida.Z4 + 1380.0
	while x < Corrida.Z5 - 700.0:
		lista.append(x)
		x += 2100.0
	return lista

func _altura_preto(x: float) -> float:
	var y := 520.0
	if x <= 900.0:
		return y
	var t := x - 900.0
	y += 12.0 * sin(t / 680.0)
	y += 5.0 * sin(t / 260.0)
	var colinas: Array = [
		[3200.0, 1600.0, 26.0],
		[7800.0, 1800.0, 22.0],
		[12800.0, 1700.0, 20.0],
		[17500.0, 1900.0, 24.0],
	]
	for item in colinas:
		var ini: float = item[0]
		var largura: float = item[1]
		var pico: float = item[2]
		if ini < x and x < ini + largura:
			var p := (x - ini) / largura
			y -= pico * sin(p * PI)
	return y

func _altura_colinas(x: float) -> float:
	var local := x - Corrida.Z1
	var y := 520.0
	if local <= 700.0:
		return y
	var t := local - 700.0
	var fade := minf(1.0, t / 450.0)
	y += fade * 88.0 * sin(t / 310.0)
	y += fade * 28.0 * sin(t / 180.0)
	var rampas: Array = [
		[1500.0, 980.0, 210.0],
		[2680.0, 820.0, -150.0],
		[3720.0, 1080.0, 250.0],
		[5120.0, 760.0, -130.0],
		[6120.0, 1020.0, 230.0],
		[7480.0, 880.0, 170.0],
		[8620.0, 740.0, -120.0],
		[9580.0, 1100.0, 260.0],
		[10940.0, 780.0, 160.0],
	]
	for item in rampas:
		var ini: float = item[0]
		var largura: float = item[1]
		var pico: float = item[2]
		if ini < local and local < ini + largura:
			var p := (local - ini) / largura
			var onda := sin(p * PI)
			y -= pico * onda * onda
	return y

func _altura_barro(x: float) -> float:
	var t := x - Corrida.Z0
	return 528.0 + 16.0 * sin(t / 320.0) + 8.0 * sin(t / 160.0)

func _altura_bolas(x: float) -> float:
	var t := x - Corrida.Z2
	return 510.0 + 42.0 * sin(t / 280.0) + 12.0 * sin(t / 160.0)

func _altura_degraus(x: float) -> float:
	var t := x - Corrida.Z3
	var y := 528.0 + 4.0 * sin(t / 520.0)
	var picos: Array = [
		[180.0, 780.0, 26.0],
		[1080.0, 860.0, 50.0],
		[2140.0, 920.0, 88.0],
		[3280.0, 980.0, 140.0],
		[4520.0, 1040.0, 200.0],
		[5840.0, 1100.0, 280.0],
		[7240.0, 1160.0, 360.0],
		[8720.0, 1220.0, 450.0],
		[10200.0, 1280.0, 520.0],
	]
	for item in picos:
		var ini: float = item[0]
		var largura: float = item[1]
		var pico: float = item[2]
		if ini < t and t < ini + largura:
			var p := (t - ini) / largura
			var onda := sin(p * PI)
			y -= pico * onda * onda
	return y

func _altura_vulcoes(x: float) -> float:
	var t := x - Corrida.Z4
	var y := 536.0 + 8.0 * sin(t / 300.0)
	for fx in _fossos:
		var d_rampa := x - (fx - 480.0)
		var raio_r := 580.0
		if absf(d_rampa) < raio_r:
			var p := 1.0 - absf(d_rampa) / raio_r
			var onda := sin(p * PI * 0.5)
			y -= 280.0 * onda * onda
		var d := x - fx
		var raio_f := 280.0 if d < 0.0 else 390.0
		if absf(d) < raio_f:
			var p2 := 1.0 - absf(d) / raio_f
			var onda2 := sin(p2 * PI * 0.5)
			y += 240.0 * onda2 * onda2
	return y

func _altura_montanhas(x: float) -> float:
	var t := x - Corrida.Z5
	var y := 518.0
	y += 11.0 * sin(t / 390.0)
	y += 7.0 * sin(t / 167.0 + 0.9)
	y += 5.0 * sin(t / 83.0 + 1.4)
	y += 3.5 * sin(t / 41.0 + 2.1)
	y += 2.5 * sin(t / 19.0 + 0.4)
	var espaco := 58.0
	var k0 := int(t / espaco)
	for k in range(k0 - 2, k0 + 3):
		if k < 0:
			continue
		var centro := k * espaco + 16.0 * sin(k * 2.17)
		var largura := 18.0 + 16.0 * (0.5 + 0.5 * sin(k * 1.31))
		var pico := 6.0 + 18.0 * (0.5 + 0.5 * sin(k * 0.73 + 0.2))
		var d := absf(t - centro)
		if d < largura:
			var p := 1.0 - d / largura
			var onda := sin(p * PI * 0.5)
			y -= pico * onda * onda
	return y
