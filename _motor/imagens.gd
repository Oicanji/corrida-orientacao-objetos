class_name Imagens
extends RefCounted

const EXT_IMG := [".png", ".jpg", ".jpeg", ".webp"]

static func candidatos(nome: String) -> PackedStringArray:
	nome = nome.strip_edges().replace("\\", "/")
	if nome.is_empty():
		return PackedStringArray()
	if nome.begins_with("res://") or nome.begins_with("user://"):
		return PackedStringArray([nome])
	if nome.length() > 2 and nome.substr(1, 1) == ":":
		return PackedStringArray([nome])
	return PackedStringArray([
		Corrida.PASTA_MOTORISTA + nome,
		"user://" + nome,
		"res://" + nome,
		"res://assets/Images/Characters/" + nome,
		"res://assets/" + nome,
	])

static func existe(caminho: String) -> bool:
	caminho = caminho.replace("\\", "/")
	if caminho.begins_with("res://"):
		return ResourceLoader.exists(caminho)
	if FileAccess.file_exists(caminho):
		return true
	var glob := ProjectSettings.globalize_path(caminho).replace("\\", "/")
	return glob != caminho and FileAccess.file_exists(glob)

static func extensao(caminho: String) -> String:
	var nome := caminho.replace("\\", "/").get_file().to_lower()
	var ponto := nome.rfind(".")
	if ponto < 0:
		return ""
	return nome.substr(ponto)

static func caminho_motorista(nome: String) -> String:
	var lista := candidatos(nome)
	for c in lista:
		if existe(c):
			Log.passo("imagem", "motorista %s" % c)
			return c
	Log.erro("imagem", "sem imagem '%s' candidatos=%s" % [nome, str(lista)])
	return ""

static func carregar(caminho: String) -> Dictionary:
	Log.fase("imagem.carregar")
	caminho = caminho.replace("\\", "/")
	Log.passo("imagem", "carregar " + caminho)
	if caminho.begins_with("res://") and ResourceLoader.exists(caminho):
		var pronta = ResourceLoader.load(caminho)
		var lado := 0
		if pronta is Texture2D:
			lado = maxi(pronta.get_width(), pronta.get_height())
		Log.passo("imagem", "res tex=%s px=%d" % [pronta != null, lado])
		return {"tex": pronta, "px": lado}
	var img := _imagem_de_arquivo(caminho)
	if img == null:
		Log.erro("imagem", "arquivo vazio " + caminho)
		return {"tex": null, "px": 0}
	_limitar(img)
	var lar := img.get_width()
	var alt := img.get_height()
	var px := lar if alt <= lar else alt
	Log.passo("imagem", "user %dx%d" % [lar, alt])
	return {"tex": ImageTexture.create_from_image(img), "px": px}

static func importar_motorista(caminho: String) -> Dictionary:
	Log.fase("imagem.importar")
	caminho = caminho.replace("\\", "/")
	Log.passo("imagem", "importar " + caminho)
	if not (extensao(caminho) in EXT_IMG):
		return {"ok": false, "erro": "Formato de imagem nao suportado.", "nome": ""}
	var img := _imagem_de_arquivo(caminho)
	if img == null:
		return {"ok": false, "erro": "Nao foi possivel abrir a imagem.", "nome": ""}
	_limitar(img)
	var nome := _nome_seguro(caminho)
	var pasta := ProjectSettings.globalize_path("user://motoristas")
	var err_dir := DirAccess.make_dir_recursive_absolute(pasta)
	Log.passo("imagem", "mkdir %s -> %s" % [pasta, err_dir])
	var destino := ProjectSettings.globalize_path(Corrida.PASTA_MOTORISTA + nome)
	var err := img.save_png(destino)
	Log.passo("imagem", "save %s err=%s" % [destino, err])
	if err != OK:
		return {"ok": false, "erro": "Nao foi possivel salvar a imagem.", "nome": ""}
	return {"ok": true, "erro": "", "nome": nome}

static func _nome_seguro(caminho: String) -> String:
	var base := caminho.replace("\\", "/").get_file()
	var nome := base.get_basename()
	var limpo := ""
	for i in nome.length():
		var ch := nome.substr(i, 1)
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "-" or ch == "_":
			limpo += ch
		else:
			limpo += "_"
	limpo = limpo.strip_edges().trim_prefix("_").trim_suffix("_")
	if limpo.is_empty():
		limpo = "motorista"
	return limpo + ".png"

static func _limitar(img: Image) -> void:
	var lar := img.get_width()
	var alt := img.get_height()
	if lar < 1 or alt < 1:
		return
	var maior := lar if alt <= lar else alt
	if maior <= 512:
		return
	var escala := 512.0 / float(maior)
	img.resize(maxi(1, int(lar * escala)), maxi(1, int(alt * escala)), Image.INTERPOLATE_BILINEAR)
	Log.passo("imagem", "redimensionada para %dx%d" % [img.get_width(), img.get_height()])

static func _imagem_de_arquivo(caminho: String) -> Image:
	var img := Image.new()
	if img.load(caminho) == OK and not img.is_empty():
		return img
	var glob := ProjectSettings.globalize_path(caminho).replace("\\", "/")
	if glob != caminho:
		img = Image.new()
		if img.load(glob) == OK and not img.is_empty():
			return img
		caminho = glob
	if not FileAccess.file_exists(caminho):
		Log.erro("imagem", "nao existe " + caminho)
		return null
	var dados := FileAccess.get_file_as_bytes(caminho)
	if dados.is_empty():
		Log.erro("imagem", "bytes vazios " + caminho)
		return null
	var ext := extensao(caminho)
	img = Image.new()
	var err := ERR_FILE_CORRUPT
	if ext == ".png":
		err = img.load_png_from_buffer(dados)
	elif ext == ".jpg" or ext == ".jpeg":
		err = img.load_jpg_from_buffer(dados)
	elif ext == ".webp":
		err = img.load_webp_from_buffer(dados)
	else:
		err = img.load_png_from_buffer(dados)
		if err != OK:
			err = img.load_jpg_from_buffer(dados)
	if err == OK and not img.is_empty():
		return img
	Log.erro("imagem", "decode %s ext=%s err=%s" % [caminho, ext, error_string(err)])
	return null
