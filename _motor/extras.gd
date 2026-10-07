extends Node2D

const BOLA := preload("res://scenes/bola.tscn")
const ITEM := preload("res://scenes/item_area.tscn")
const LAVA_FOGO := preload("res://scenes/fogo_lava.tscn")

var _bolas: Array = []
var _pulos: Array = []
var _vulcoes: Array = []
var _lava_fogos: Array = []
var _tex_roda: Texture2D
var _tex_pulo: Texture2D
var _tex_lava: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Log.fase("extras.ready")
	Log.passo("extras", "_ready")
	_tex_roda = _carregar("res://assets/Images/Car/Wheel.png")
	_tex_pulo = _carregar("res://assets/Images/Pickups/Fuel.png")
	if ResourceLoader.exists("res://assets/Images/Other/Alarm.png"):
		_tex_pulo = _carregar("res://assets/Images/Other/Alarm.png")
		Log.passo("extras", "pulo usa Alarm")
	_tex_lava = _carregar("res://assets/Images/Pickups/Coin50.png")
	var terreno = get_parent().get_node_or_null("Terreno")
	if terreno == null:
		Log.erro("extras", "sem Terreno")
		return
	_montar_bolas(terreno)
	_montar_pulos(terreno)
	_montar_vulcoes(terreno)
	Log.passo("extras", "bolas=%d pulos=%d vulcoes=%d" % [_bolas.size(), _pulos.size(), _vulcoes.size()])

func checar(v) -> void:
	Log.fase("extras.pulos")
	_checar_pulos(v)
	Log.fase("extras.vulcoes")
	_checar_vulcoes(v)

func cull(x: float) -> void:
	Log.fase("extras.cull")
	_bolas = _limpar(_bolas, x, "bola")
	_pulos = _limpar(_pulos, x, "pulo")
	_vulcoes = _limpar(_vulcoes, x, "vulcao")
	_lava_fogos = _limpar(_lava_fogos, x, "fogo_lava")

func _carregar(caminho: String) -> Texture2D:
	if not ResourceLoader.exists(caminho):
		Log.erro("extras", "textura ausente " + caminho)
		return null
	var tex := load(caminho) as Texture2D
	Log.passo("extras", "tex %s %s" % [caminho, tex != null])
	return tex

func _montar_bolas(terreno) -> void:
	Log.fase("extras.bolas")
	if _tex_roda == null:
		Log.erro("extras", "sem tex roda, bolas puladas")
		return
	var i := 0
	while i < 40:
		var x := randf_range(Corrida.Z2 + 180.0, Corrida.Z3 - 180.0)
		var raio := randf_range(22.0, 48.0)
		var y: float = float(terreno.altura(x)) - raio - randf_range(40.0, 260.0)
		var corpo := BOLA.instantiate() as RigidBody2D
		corpo.position = Vector2(x, y)
		add_child(corpo)
		corpo.configurar(raio, _tex_roda, Color(randf_range(0.45, 0.9), randf_range(0.35, 0.7), randf_range(0.25, 0.55)))
		_bolas.append(corpo)
		i += 1
	Log.passo("extras", "bolas criadas %d" % _bolas.size())

func _montar_pulos(terreno) -> void:
	Log.fase("extras.pulos_montar")
	var x := Corrida.Z3 + 1400.0
	while x < Corrida.Z4 - 200.0:
		var y: float = float(terreno.altura(x)) - 52.0
		var area := _criar_item("Pulo", x, y, 72.0, _tex_pulo, Color(1.0, 0.55, 0.12), 0.48)
		_pulos.append(area)
		Log.passo("extras", "pulo x=%.0f y=%.0f" % [x, y])
		x += randf_range(1400.0, 2200.0)

func _montar_vulcoes(terreno) -> void:
	Log.fase("extras.vulcoes_montar")
	for fx in terreno._fossos:
		var sup: float = float(terreno.altura(fx))
		var area := _criar_item("Vulcao", fx, sup - 12.0, 78.0, _tex_lava, Color(1.0, 0.28, 0.08), 0.55)
		_vulcoes.append(area)
		var fogo := LAVA_FOGO.instantiate() as Node2D
		fogo.position = Vector2(fx, sup + 165.0)
		add_child(fogo)
		_lava_fogos.append(fogo)
		Log.passo("extras", "vulcao x=%.0f lava y=%.0f" % [fx, sup + 165.0])

func _criar_item(nome: String, x: float, y: float, raio: float, tex: Texture2D, cor: Color, escala: float) -> Area2D:
	var area := ITEM.instantiate() as Area2D
	area.name = nome
	area.position = Vector2(x, y)
	add_child(area)
	area.configurar(raio, tex, cor, escala)
	return area

func _checar_pulos(v) -> void:
	if v.pulo_espera > 0.0:
		return
	for area in _pulos:
		if not is_instance_valid(area):
			continue
		if _perto(v, area):
			var fx := randf_range(-400.0, 900.0)
			var fy := randf_range(-15000.0, -8200.0)
			Log.passo("extras", "pulo impulso fx=%.0f fy=%.0f" % [fx, fy])
			v.apply_central_impulse(Vector2(fx, fy))
			if v.frente_ativa and is_instance_valid(v.roda_frente):
				v.roda_frente.apply_central_impulse(Vector2(fx * 0.2, fy * 0.18))
			if v.tras_ativa and is_instance_valid(v.roda_tras):
				v.roda_tras.apply_central_impulse(Vector2(fx * 0.2, fy * 0.18))
			v.pulo_espera = 0.7
			return

func _checar_vulcoes(v) -> void:
	for area in _vulcoes:
		if not is_instance_valid(area):
			continue
		if _pega_carro(v, area):
			Log.passo("extras", "vulcao em %s" % area.global_position)
			v.morrer("Chamuscou!")
			return

func _pega_carro(v, area: Area2D) -> bool:
	var corpos := area.get_overlapping_bodies()
	for item in corpos:
		if item.get_instance_id() in v.ids_carro:
			return true
	return false

func _perto(v, area: Area2D) -> bool:
	if _pega_carro(v, area):
		return true
	var centro := area.global_position
	if v.global_position.distance_to(centro) < 95.0:
		return true
	if v.frente_ativa and is_instance_valid(v.roda_frente) and v.roda_frente.global_position.distance_to(centro) < 80.0:
		return true
	if v.tras_ativa and is_instance_valid(v.roda_tras) and v.roda_tras.global_position.distance_to(centro) < 80.0:
		return true
	return false

func _limpar(lista: Array, x: float, rotulo: String) -> Array:
	var vivos: Array = []
	for no in lista:
		if not is_instance_valid(no):
			continue
		if no.position.x < x - Corrida.MARGEM_NIVEL:
			Log.passo("extras", "libera %s x=%.0f" % [rotulo, no.position.x])
			no.queue_free()
		else:
			vivos.append(no)
	return vivos
