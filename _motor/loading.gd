extends Control

const CENA := "res://scenes/pista.tscn"

@onready var roda: TextureRect = $Roda
@onready var texto: Label = $Texto

var _trocando := false
var _tempo := 0.0
var _status := -1

func _ready() -> void:
	Log.passo("loading", "_ready")
	call_deferred("_centrar_roda")
	var err := ResourceLoader.load_threaded_request(CENA)
	Log.passo("loading", "pedido %s -> %s" % [CENA, error_string(err)])

func _centrar_roda() -> void:
	roda.pivot_offset = roda.size * 0.5

func _process(delta: float) -> void:
	_tempo += delta
	roda.rotation += delta * 4.4
	var pontos := int(_tempo * 2.4) % 4
	var progresso: Array = []
	var status := ResourceLoader.load_threaded_get_status(CENA, progresso)
	var pct := 0
	if progresso.size() > 0:
		pct = int(float(progresso[0]) * 100.0)
	if status != _status:
		_status = status
		Log.passo("loading", "status=%s pct=%s t=%.2f" % [status, pct, _tempo])
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		texto.text = "Carregando" + ".".repeat(pontos)
		if pct > 0:
			texto.text = "Carregando %d%%" % pct
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		texto.text = "Carregando"
		if _tempo >= 0.55 and not _trocando:
			_trocando = true
			var packed := ResourceLoader.load_threaded_get(CENA)
			Log.passo("loading", "cena pronta %s" % packed)
			var troca := get_tree().change_scene_to_packed(packed)
			Log.passo("loading", "troca %s" % error_string(troca))
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		Log.erro("loading", "falha ao carregar pista")
		texto.text = "Falha ao carregar"
		if _tempo >= 1.2 and not _trocando:
			_trocando = true
			get_tree().change_scene_to_file(CENA)
	else:
		texto.text = "Carregando" + ".".repeat(pontos)
