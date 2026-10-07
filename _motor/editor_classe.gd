extends CanvasLayer

const CLASSE_PADRAO := """class Carro:
	velocidade = 1200
	cor_carro = \"vermelho\"
	roda_atras = {
		\"presente\": True,
		\"tamanho\": 1.0,
		\"distancia\": 1.0,
	}
	roda_frente = {
		\"presente\": True,
		\"tamanho\": 1.0,
		\"distancia\": 1.0,
	}
	motorista = \"ryan.png\"
	marcha_inicial = 1
	marcha = \"manual\"

	def acelerar(self, tempo):
		return self.velocidade * tempo
"""

var codigo: CodeEdit
var erro: Label
var preview: TextureRect
var dialogo: FileDialog
var _re := RegEx.new()
var _hl: CodeHighlighter
var _ultimo_nome := ""
var _ultimo_upload := ""
var _jogando := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Log.fase("editor.ready")
	Log.passo("editor", "_ready")
	for filho in get_children():
		Log.passo("editor", "filho %s %s" % [filho.name, filho.get_class()])
	codigo = get_node_or_null("Codigo")
	erro = get_node_or_null("Erro")
	preview = get_node_or_null("Preview")
	dialogo = get_node_or_null("Dialogo")
	if codigo == null or erro == null:
		Log.erro("editor", "cena incompleta")
		return
	var err_re := _re.compile("(?m)^[ \\t]*motorista[ \\t]*=[ \\t]*[\"']([^\"']+)[\"']")
	Log.passo("editor", "regex %s" % error_string(err_re))
	_hl = _montar_highlighter()
	codigo.syntax_highlighter = _hl
	codigo.text = _texto_inicial()
	codigo.text_changed.connect(_on_texto)
	var jogar := get_node_or_null("Jogar")
	var resetar := get_node_or_null("Resetar")
	var upload := get_node_or_null("Upload")
	if jogar:
		jogar.pressed.connect(_on_jogar)
	else:
		Log.erro("editor", "sem botao Jogar")
	if resetar:
		resetar.pressed.connect(_on_resetar)
	if upload:
		upload.pressed.connect(_on_upload)
	if dialogo:
		dialogo.process_mode = Node.PROCESS_MODE_ALWAYS
		dialogo.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dialogo.access = FileDialog.ACCESS_FILESYSTEM
		dialogo.use_native_dialog = false
		dialogo.clear_filters()
		dialogo.add_filter("*.png, *.jpg, *.jpeg, *.webp", "Imagens")
		dialogo.file_selected.connect(_on_arquivo)
		dialogo.canceled.connect(func() -> void:
			Log.passo("editor", "upload cancelado")
		)
	else:
		Log.erro("editor", "sem Dialogo")
	_atualizar_preview()
	visible = true
	codigo.call_deferred("grab_focus")
	Log.fase("editor.visivel")
	Log.passo("editor", "texto bytes=%d visivel=%s" % [codigo.text.length(), visible])

func abrir() -> void:
	Log.fase("editor.aberto")
	Log.passo("editor", "abrir")
	visible = true
	_jogando = false
	_msg("", false)
	_atualizar_preview()
	if codigo:
		codigo.call_deferred("grab_focus")

func jogar() -> void:
	if _jogando:
		Log.passo("editor", "jogar ignorado, ja em curso")
		return
	_jogando = true
	Log.fase("editor.jogar")
	if codigo == null:
		_jogando = false
		_msg("Editor sem area de codigo.")
		return
	var texto := codigo.text
	Log.passo("editor", "jogar bytes=%d" % texto.length())
	var r: Dictionary = ClasseCarro.validar(texto)
	if not r["ok"]:
		_jogando = false
		_msg(str(r["erro"]))
		return
	if not _salvar(Corrida.ARQ_CARRO_ALUNO, texto):
		_jogando = false
		_msg("Nao foi possivel salvar a classe.")
		return
	if OS.has_feature("editor"):
		_salvar(Corrida.ARQ_CARRO_RES, texto)
	else:
		Log.passo("editor", "fora do editor, res://carro.py nao foi regravado")
	_msg("", false)
	_marcar_flag()
	get_tree().paused = false
	Log.passo("editor", "reload cena")
	var err := get_tree().reload_current_scene()
	Log.passo("editor", "reload %s" % error_string(err))
	if err != OK:
		_jogando = false
		_msg("Nao recarregou a cena: %s" % error_string(err))

func _on_jogar() -> void:
	Log.passo("editor", "botao jogar")
	jogar()

func _on_resetar() -> void:
	Log.passo("editor", "resetar")
	if codigo == null:
		return
	codigo.text = CLASSE_PADRAO
	_msg("", false)
	_atualizar_preview()
	codigo.grab_focus()

func _on_upload() -> void:
	Log.passo("editor", "botao upload")
	if dialogo == null:
		_msg("Seletor de imagem indisponivel.")
		return
	dialogo.current_file = ""
	dialogo.popup_centered(Vector2i(900, 600))
	Log.passo("editor", "dialogo visivel=%s dir=%s" % [dialogo.visible, dialogo.current_dir])

func _on_arquivo(caminho: String) -> void:
	Log.passo("editor", "arquivo %s" % caminho)
	if caminho == _ultimo_upload:
		Log.passo("editor", "upload repetido")
		return
	var r: Dictionary = Imagens.importar_motorista(caminho)
	if not r["ok"]:
		_msg(str(r["erro"]))
		return
	_aplicar_motorista(str(r["nome"]))
	_atualizar_preview(str(r["nome"]))
	_ultimo_upload = caminho
	_msg("Imagem pronta: motorista = \"%s\"" % str(r["nome"]), false)

func _on_texto() -> void:
	if codigo == null:
		return
	var nome := _motorista_do_texto(codigo.text)
	if nome == _ultimo_nome:
		return
	_ultimo_nome = nome
	Log.passo("editor", "motorista texto %s" % nome)
	_atualizar_preview(nome)

func _texto_inicial() -> String:
	if FileAccess.file_exists(Corrida.ARQ_CARRO_ALUNO):
		Log.passo("editor", "texto de " + Corrida.ARQ_CARRO_ALUNO)
		return FileAccess.get_file_as_string(Corrida.ARQ_CARRO_ALUNO)
	if FileAccess.file_exists(Corrida.ARQ_CARRO_RES):
		Log.passo("editor", "texto de " + Corrida.ARQ_CARRO_RES)
		return FileAccess.get_file_as_string(Corrida.ARQ_CARRO_RES)
	Log.passo("editor", "texto padrao")
	return CLASSE_PADRAO

func _salvar(caminho: String, texto: String) -> bool:
	var arq := FileAccess.open(caminho, FileAccess.WRITE)
	if arq == null:
		Log.erro("editor", "nao abriu %s %s" % [caminho, error_string(FileAccess.get_open_error())])
		return false
	arq.store_string(texto)
	arq.close()
	Log.passo("editor", "salvou %s bytes=%d" % [ProjectSettings.globalize_path(caminho), texto.length()])
	return true

func _marcar_flag() -> void:
	var arq := FileAccess.open(Corrida.ARQ_JOGAR, FileAccess.WRITE)
	if arq == null:
		Log.erro("editor", "flag %s" % error_string(FileAccess.get_open_error()))
		return
	arq.store_string("1")
	arq.close()
	Log.passo("editor", "flag gravada")

func _motorista_do_texto(texto: String) -> String:
	var achado := _re.search(texto)
	if achado == null:
		return ""
	return achado.get_string(1).strip_edges()

func _aplicar_motorista(nome: String) -> void:
	if codigo == null:
		return
	var texto := codigo.text
	var linha := "\tmotorista = \"%s\"" % nome
	if _re.search(texto):
		codigo.text = _re.sub(texto, linha, false)
		Log.passo("editor", "motorista substituido")
		return
	codigo.text = texto.rstrip("\n") + "\n" + linha + "\n"
	Log.passo("editor", "motorista acrescentado")

func _atualizar_preview(nome: String = "") -> void:
	if preview == null or codigo == null:
		return
	if nome.is_empty():
		nome = _motorista_do_texto(codigo.text)
	_ultimo_nome = nome
	if nome.is_empty():
		preview.hide()
		return
	var caminho := Imagens.caminho_motorista(nome)
	if caminho.is_empty():
		preview.hide()
		return
	var tex = Imagens.carregar(caminho).tex
	if tex == null:
		preview.hide()
		return
	preview.texture = tex
	preview.show()

func _msg(texto: String, falha: bool = true) -> void:
	if erro == null:
		return
	erro.add_theme_color_override("font_color", Color(0.94, 0.28, 0.28) if falha else Color(0.45, 0.78, 0.45))
	erro.text = texto
	if not texto.is_empty():
		Log.passo("editor", "msg %s" % texto)

func _montar_highlighter() -> CodeHighlighter:
	var hl := CodeHighlighter.new()
	var kw := Color(0.33, 0.61, 0.84)
	for palavra in [
		"class", "def", "return", "True", "False", "None", "and", "or", "not",
		"if", "else", "elif", "for", "while", "pass", "self", "in", "is",
	]:
		hl.add_keyword_color(palavra, kw)
	hl.number_color = Color(0.71, 0.81, 0.66)
	hl.symbol_color = Color(0.83, 0.83, 0.83)
	hl.function_color = Color(0.86, 0.86, 0.67)
	hl.member_variable_color = Color(0.61, 0.86, 0.99)
	hl.add_color_region("\"", "\"", Color(0.81, 0.61, 0.4), false)
	hl.add_color_region("'", "'", Color(0.81, 0.61, 0.4), false)
	hl.add_color_region("#", "", Color(0.42, 0.6, 0.33), true)
	return hl
