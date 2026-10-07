extends Node2D

@export var spawn_x: float = 0.0

var editando := false
var modo_editor := true
var veiculo
var editor
var ajuda: Label
var morte: CanvasLayer
var morte_titulo: Label
var morte_fundo: ColorRect
var morte_km: Label
var vitoria: CanvasLayer
var vitoria_tempo: Label
var som_morte: AudioStreamPlayer
var efeitos
var _enter_antes := false
var _esc_antes := false
var _ajuda_viva := true
var _jogar_direto := false

func _enter_tree() -> void:
	Log.fase("pista.enter")
	Log.passo("pista", "_enter_tree")
	if FileAccess.file_exists("user://carro_aluno.py"):
		Log.passo("pista", "ignorado user://carro_aluno.py sem interpretador")
	_jogar_direto = _consumir_flag()
	_aplicar_script_salvo()

func _ready() -> void:
	Log.fase("pista.ready")
	Log.passo("pista", "_ready spawn_x=%s" % spawn_x)
	for filho in get_children():
		Log.passo("arvore", "%s %s script=%s" % [filho.name, filho.get_class(), filho.get_script()])
	modo_editor = _ler_editor()
	_garantir_acao("girar_esq", [KEY_A, KEY_LEFT])
	_garantir_acao("girar_dir", [KEY_D, KEY_RIGHT])
	veiculo = get_node_or_null("Veiculo")
	editor = get_node_or_null("Editor")
	ajuda = get_node_or_null("HUD/Ajuda")
	morte = get_node_or_null("Morte")
	morte_titulo = get_node_or_null("Morte/Titulo")
	morte_fundo = get_node_or_null("Morte/Fundo")
	morte_km = get_node_or_null("Morte/KmFinal")
	vitoria = get_node_or_null("Vitoria")
	vitoria_tempo = get_node_or_null("Vitoria/TempoFinal")
	efeitos = get_node_or_null("Efeitos")
	var km_label := get_node_or_null("HUD/Km")
	if km_label:
		km_label.hide()
	var info := get_node_or_null("HUD/Info")
	if info:
		info.hide()
	if morte:
		morte.layer = 80
		morte.process_mode = Node.PROCESS_MODE_ALWAYS
		morte.hide()
	if vitoria:
		vitoria.layer = 81
		vitoria.hide()
	_pronto_som()
	if veiculo and veiculo.has_signal("morreu"):
		veiculo.morreu.connect(_on_morreu)
		veiculo.venceu.connect(_on_venceu)
		Log.passo("pista", "sinais do veiculo ligados")
	else:
		Log.erro("pista", "veiculo sem sinais")
	if editor == null:
		Log.erro("pista", "sem Editor")
		modo_editor = false
	editando = modo_editor and not _jogar_direto and spawn_x <= 0.0
	Log.passo("pista", "modo_editor=%s editando=%s direto=%s" % [modo_editor, editando, _jogar_direto])
	if modo_editor:
		process_mode = Node.PROCESS_MODE_ALWAYS
	if editando and editor:
		editor.abrir()
		get_tree().paused = true
		var motor := get_node_or_null("Sons/Motor")
		if motor:
			motor.stop()
		Log.passo("pista", "pausado no editor")
	elif editor:
		editor.hide()
	Log.fase("editor.aberto" if editando else "pista.jogando")
	Log.passo("pista", "_ready fim pausado=%s" % get_tree().paused)

func _process(_delta: float) -> void:
	if editando:
		var esc := Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_ESCAPE)
		if esc and not _esc_antes and editor:
			Log.passo("pista", "esc joga a classe")
			editor.jogar()
		_esc_antes = esc
		return
	if veiculo and (veiculo.morto or veiculo.ganhou):
		var enter := Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)
		if enter and not _enter_antes:
			Log.passo("pista", "enter reinicia")
			get_tree().paused = false
			var err := get_tree().reload_current_scene()
			Log.passo("pista", "reload %s" % error_string(err))
		_enter_antes = enter
		return
	_enter_antes = false
	if modo_editor and editor and veiculo and not veiculo.morto and not veiculo.ganhou:
		var esc2 := Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_ESCAPE)
		if esc2 and not _esc_antes:
			_abrir_editor()
			_esc_antes = true
			return
		_esc_antes = esc2
	_atualizar_ajuda()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Log.passo("pista", "WM_CLOSE_REQUEST")
	elif what == NOTIFICATION_PREDELETE:
		Log.passo("pista", "PREDELETE editando=%s" % editando)

func _on_teto_body_entered(corpo: Node) -> void:
	Log.passo("pista", "teto body_entered %s" % (corpo.name if corpo else "?"))
	if veiculo and veiculo.has_method("ao_teto"):
		veiculo.ao_teto(corpo)

func _on_morreu(titulo: String) -> void:
	Log.passo("pista", "ui morte %s" % titulo)
	if titulo == "Capotou!" and efeitos and veiculo and efeitos.has_method("reproduzir_explosao_capotamento"):
		efeitos.reproduzir_explosao_capotamento(veiculo.global_position)
	if editando:
		editando = false
		if editor:
			editor.hide()
		get_tree().paused = false
	if morte_titulo:
		morte_titulo.text = titulo
	if morte_km and veiculo:
		morte_km.text = "Voce andou " + veiculo.texto_km() + " km"
	if morte_fundo:
		if titulo == "Chamuscou!":
			morte_fundo.color = Color(0.28, 0.06, 0.02, 0.88)
		else:
			morte_fundo.color = Color(0.05, 0.04, 0.07, 0.72)
	if morte:
		morte.layer = 80
		morte.show()
	if som_morte and som_morte.stream:
		som_morte.play()
		Log.passo("pista", "som morte")
	else:
		Log.erro("pista", "som morte indisponivel")

func _on_venceu() -> void:
	Log.passo("pista", "ui vitoria")
	if vitoria_tempo and veiculo:
		vitoria_tempo.text = "Tempo: " + veiculo.texto_tempo()
	if vitoria:
		vitoria.layer = 81
		vitoria.show()

func _abrir_editor() -> void:
	Log.passo("pista", "abrir editor durante a corrida")
	editando = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_esc_antes = true
	if editor:
		editor.abrir()
	get_tree().paused = true
	var motor := get_node_or_null("Sons/Motor")
	if motor:
		motor.stop()
	Log.passo("pista", "pausado=%s" % get_tree().paused)

func _atualizar_ajuda() -> void:
	if not _ajuda_viva or ajuda == null or veiculo == null:
		return
	if veiculo.tempo_vivo < 18.0:
		return
	if veiculo.tempo_vivo >= 20.0:
		ajuda.hide()
		_ajuda_viva = false
		Log.passo("pista", "ajuda escondida")
		return
	var a: float = 1.0 - (float(veiculo.tempo_vivo) - 18.0) / 2.0
	ajuda.modulate = Color(1, 1, 1, a)

func _aplicar_script_salvo() -> void:
	Log.fase("pista.script")
	var classe := get_node_or_null("Veiculo/Classe")
	if classe == null:
		Log.erro("pista", "sem Veiculo/Classe")
		return
	Log.passo("pista", "script cena %s" % classe.get_script())
	if not FileAccess.file_exists(Corrida.ARQ_CARRO_ALUNO):
		Log.passo("pista", "sem carro_aluno.py, fica o script da cena")
		return
	var texto := FileAccess.get_file_as_string(Corrida.ARQ_CARRO_ALUNO)
	Log.passo("pista", "lendo carro_aluno bytes=%d" % texto.length())
	var r: Dictionary = ClasseCarro.validar(texto)
	if not r["ok"]:
		Log.erro("pista", "carro_aluno rejeitado: %s" % str(r["erro"]))
		return
	classe.set_script(r["script"])
	Log.passo("pista", "script aplicado no no Classe acelerar=%s" % classe.has_method("acelerar"))

func _consumir_flag() -> bool:
	if not FileAccess.file_exists(Corrida.ARQ_JOGAR):
		Log.passo("pista", "sem flag de jogar")
		return false
	var pasta := DirAccess.open("user://")
	if pasta == null:
		Log.erro("pista", "user:// %s" % error_string(DirAccess.get_open_error()))
		return true
	var err := pasta.remove("corrida_jogar.flag")
	Log.passo("pista", "flag removida %s" % error_string(err))
	return true

func _ler_editor() -> bool:
	var cfg := get_node_or_null("Configuracao")
	if cfg == null:
		Log.passo("pista", "sem Configuracao, editor ligado")
		return true
	var val = cfg.get("editor_da_classe")
	Log.passo("pista", "editor_da_classe=%s tipo=%s" % [val, type_string(typeof(val)) if val != null else "null"])
	if val == null:
		return true
	if val is bool:
		return val
	if val is int or val is float:
		return val != 0
	if val is String:
		return val.strip_edges().to_lower() in ["true", "1", "yes"]
	return true

func _garantir_acao(nome: String, codigos: Array) -> void:
	if InputMap.has_action(nome):
		Log.passo("pista", "acao existe " + nome)
		return
	InputMap.add_action(nome)
	for codigo in codigos:
		var ev := InputEventKey.new()
		ev.physical_keycode = codigo
		InputMap.action_add_event(nome, ev)
	Log.passo("pista", "acao criada " + nome)

func _pronto_som() -> void:
	som_morte = get_node_or_null("Sons/MorteSom")
	if som_morte == null:
		var sons := get_node_or_null("Sons")
		if sons == null:
			Log.erro("pista", "sem Sons")
			return
		som_morte = AudioStreamPlayer.new()
		som_morte.name = "MorteSom"
		sons.add_child(som_morte)
		Log.passo("pista", "MorteSom criado")
	var caminho := "res://assets/Audio/death-sound-effect.mp3"
	if ResourceLoader.exists(caminho):
		som_morte.stream = load(caminho)
		Log.passo("pista", "som morte carregado")
	else:
		Log.erro("pista", "arquivo de morte ausente")
	som_morte.volume_db = -2.0
	var doh := get_node_or_null("Sons/Doh")
	var caminho_doh := "res://assets/Audio/d-oh_1.mp3"
	if doh and ResourceLoader.exists(caminho_doh):
		doh.stream = load(caminho_doh)
		doh.volume_db = 2.0
		Log.passo("pista", "som doh carregado")
	else:
		Log.passo("pista", "som doh nao usado")
