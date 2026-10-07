extends Node

var fase_atual := "boot"
var ultima_motor := ""
var caminho_log := ""
var _log: FileAccess
var _fase: FileAccess
var _cap = null
var _batida := 0

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preservar_fase_anterior()
	_abrir()
	_ligar_captura()
	passo("log", "enter_tree pid=%d" % OS.get_process_id())

func _ready() -> void:
	var info := Engine.get_version_info()
	passo("log", "Godot %s OS=%s render=%s" % [
		str(info.get("string", info)),
		OS.get_name(),
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
	])
	passo("log", "log=%s" % ProjectSettings.globalize_path(caminho_log))
	passo("log", "fase=%s" % ProjectSettings.globalize_path("user://corrida_fase.txt"))
	var janela := get_tree().root
	if janela.has_signal("close_requested"):
		janela.close_requested.connect(func() -> void:
			passo("log", "close_requested")
		)
	janela.tree_exiting.connect(func() -> void:
		passo("log", "root tree_exiting")
	)
	_escrever_fase()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		passo("log", "PREDELETE fase=%s" % fase_atual)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		passo("log", "WM_CLOSE_REQUEST fase=%s" % fase_atual)

func _process(_delta: float) -> void:
	_batida += 1
	if _batida % 15 == 0:
		_escrever_fase()
	if _batida % 60 == 0:
		passo("log", "vivo proc=%d phys=%d mem=%d fase=%s" % [
			Engine.get_process_frames(),
			Engine.get_physics_frames(),
			OS.get_static_memory_usage(),
			fase_atual,
		], false)

func fase(nome: String) -> void:
	fase_atual = nome
	_escrever_fase()

func passo(origem: String, msg: String, console: bool = true) -> void:
	var linha := "%s [%s] %s | %s" % [
		Time.get_datetime_string_from_system(),
		fase_atual,
		origem,
		msg,
	]
	_gravar(linha)
	if console:
		print("[corrida] " + linha)

func erro(origem: String, msg: String) -> void:
	passo(origem, "ERRO " + msg, true)
	push_error("[corrida] %s %s" % [origem, msg])

func do_motor(linha: String) -> void:
	if "[corrida]" in linha:
		return
	ultima_motor = linha
	_gravar("MOTOR " + linha.replace("\n", " | "))

func _preservar_fase_anterior() -> void:
	if not FileAccess.file_exists("user://corrida_fase.txt"):
		return
	var antigo := FileAccess.get_file_as_string("user://corrida_fase.txt")
	var dest := FileAccess.open("user://corrida_fase_anterior.txt", FileAccess.WRITE)
	if dest == null:
		return
	dest.store_string(antigo)
	dest.close()

func _abrir() -> void:
	var carimbo := Time.get_datetime_string_from_system().replace(":", "-")
	caminho_log = "user://corrida_debug_%s.log" % carimbo
	_log = FileAccess.open(caminho_log, FileAccess.WRITE)
	if _log == null:
		print("[corrida] nao abriu log %s" % error_string(FileAccess.get_open_error()))
	var ponteiro := FileAccess.open("user://corrida_ultimo_log.txt", FileAccess.WRITE)
	if ponteiro != null:
		ponteiro.store_string(ProjectSettings.globalize_path(caminho_log))
		ponteiro.close()
	_fase = FileAccess.open("user://corrida_fase.txt", FileAccess.WRITE_READ)
	if FileAccess.file_exists("user://corrida_fase_anterior.txt"):
		var anterior := FileAccess.get_file_as_string("user://corrida_fase_anterior.txt").replace("\n", " | ")
		_gravar("FASE_ANTERIOR " + anterior)

func _ligar_captura() -> void:
	var cap_script = load("res://_motor/log_captura.gd")
	if cap_script == null:
		_gravar("captura nao carregou")
		return
	_cap = cap_script.new()
	OS.add_logger(_cap)
	_gravar("captura ativa")

func _escrever_fase() -> void:
	if _fase == null:
		return
	var texto := "t=%d\nfase=%s\nproc=%d\nphys=%d\nmem=%d\nlog=%s\n" % [
		Time.get_ticks_msec(),
		fase_atual,
		Engine.get_process_frames(),
		Engine.get_physics_frames(),
		OS.get_static_memory_usage(),
		caminho_log,
	]
	_fase.resize(0)
	_fase.seek(0)
	_fase.store_string(texto)
	_fase.flush()

func _gravar(linha: String) -> void:
	if _log == null:
		return
	_log.store_line(linha)
	_log.flush()
