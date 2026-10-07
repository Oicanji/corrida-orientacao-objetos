extends Node

var _pista: Node2D
var _ceu: CanvasLayer
var _neve: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pista = get_parent() as Node2D
	_ceu = _pista.get_node_or_null("CeuDiaNoite") as CanvasLayer
	_neve = _pista.get_node_or_null("Neve") as CanvasLayer
	if Engine.is_editor_hint():
		return
	if _ceu and _ceu.has_method("ativar"):
		_ceu.call_deferred("ativar")
		call_deferred("_esconder_parallax")
	Log.passo("efeitos", "ceu=%s neve=%s" % [_ceu != null, _neve != null])

func _esconder_parallax() -> void:
	if _ceu == null or not _ceu.visible:
		return
	var fundo := _pista.get_node_or_null("Fundo")
	var nuvens := _pista.get_node_or_null("Nuvens")
	if fundo:
		fundo.hide()
	if nuvens:
		nuvens.hide()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or get_tree().paused:
		return
	_atualizar_neve()

func _atualizar_neve() -> void:
	if _neve == null or _pista == null or not _neve.has_method("definir_visivel"):
		return
	var v = _pista.get_node_or_null("Veiculo")
	if v == null:
		_neve.definir_visivel(false)
		return
	var x: float = v.position.x
	if x < Corrida.Z3 or x >= Corrida.Z4:
		_neve.definir_visivel(false)
		return
	var borda := 350.0
	var a := 1.0
	if x < Corrida.Z3 + borda:
		a = smoothstep(Corrida.Z3, Corrida.Z3 + borda, x)
	elif x > Corrida.Z4 - borda:
		a = smoothstep(Corrida.Z4, Corrida.Z4 - borda, x)
	_neve.definir_visivel(true, a)
	if _neve.has_method("atualizar_dimensoes"):
		_neve.atualizar_dimensoes(get_viewport().get_visible_rect().size)

func reproduzir_explosao_capotamento(pos_mundo: Vector2) -> void:
	var explosao = _pista.get_node_or_null("ExplosaoCapotamento")
	if explosao == null or not explosao.has_method("disparar"):
		return
	explosao.disparar(pos_mundo)
