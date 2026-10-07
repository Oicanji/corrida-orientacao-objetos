class_name ClasseCarro
extends RefCounted

static func validar(texto: String) -> Dictionary:
	Log.fase("classe.validar")
	Log.passo("classe", "validar bytes=%d" % texto.length())
	var gerado: Dictionary = _para_gdscript(texto)
	if not gerado["ok"]:
		return gerado
	var fonte: String = gerado["fonte"]
	Log.passo("classe", "gdscript bytes=%d" % fonte.length())
	var script := GDScript.new()
	script.source_code = fonte
	Log.fase("classe.reload")
	var err := script.reload()
	Log.fase("classe.reload_fim")
	if err != OK:
		return _falha("Erro ao compilar a classe: %s %s" % [error_string(err), Log.ultima_motor])
	if not script.can_instantiate():
		return _falha("A classe nao pode ser instanciada.")
	Log.fase("classe.teste_new")
	var teste: Object = script.new() as Object
	if teste == null:
		return _falha("Nao foi possivel criar a classe. %s" % Log.ultima_motor)
	var tem: bool = teste.has_method("acelerar")
	Log.passo("classe", "teste acelerar=%s" % tem)
	if teste is Node:
		teste.free()
	if not tem:
		return _falha("A classe Carro precisa do metodo acelerar.")
	Log.passo("classe", "valida")
	return {"ok": true, "erro": "", "script": script}

static func _para_gdscript(texto: String) -> Dictionary:
	var proibido := _proibido(texto)
	if not proibido.is_empty():
		return _falha(proibido)
	var extraido: Dictionary = _extrair_corpo(texto)
	if not extraido["ok"]:
		return extraido
	var corpo: PackedStringArray = _dedentar(extraido["linhas"])
	var tem_acelerar := false
	var saida := "extends Node\n"
	var em_funcao := false
	for linha in corpo:
		var limpa := linha.strip_edges()
		var indent := linha.length() - linha.lstrip(" \t").length()
		if indent == 0 and limpa.begins_with("def "):
			em_funcao = true
			var assinatura := _assinar(limpa)
			if assinatura.begins_with("func acelerar("):
				tem_acelerar = true
			saida += _py_para_gd_linha(assinatura) + "\n"
			continue
		if indent == 0 and not limpa.is_empty() and not limpa.begins_with("#"):
			em_funcao = false
			saida += _py_para_gd_linha(_var_se_atribuicao(limpa)) + "\n"
			continue
		if em_funcao or limpa.is_empty() or limpa.begins_with("#") or indent > 0:
			saida += _py_para_gd_linha(linha) + "\n"
	if not tem_acelerar:
		return _falha("A classe Carro precisa do metodo acelerar.")
	return {"ok": true, "erro": "", "fonte": saida}

static func _extrair_corpo(texto: String) -> Dictionary:
	var linhas: PackedStringArray = texto.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var achou := false
	var corpo: PackedStringArray = []
	for linha in linhas:
		var s := linha.strip_edges()
		if not achou:
			if s.is_empty() or s.begins_with("#"):
				continue
			if not _eh_classe_carro(s):
				return _falha("A classe Carro nao foi encontrada.")
			achou = true
			continue
		if s.is_empty() or s.begins_with("#") or _indentado(linha):
			corpo.append(linha)
			continue
		break
	if not achou:
		return _falha("A classe Carro nao foi encontrada.")
	return {"ok": true, "erro": "", "linhas": corpo}

static func _eh_classe_carro(s: String) -> bool:
	if not s.begins_with("class "):
		return false
	var resto := s.substr(6).strip_edges()
	if resto == "Carro:":
		return true
	return resto.begins_with("Carro(") and resto.ends_with(":")

static func _dedentar(linhas: PackedStringArray) -> PackedStringArray:
	var unidade := ""
	for linha in linhas:
		if linha.strip_edges().is_empty():
			continue
		var i := 0
		while i < linha.length() and (linha.substr(i, 1) == " " or linha.substr(i, 1) == "\t"):
			i += 1
		if i > 0:
			unidade = linha.substr(0, i)
		break
	if unidade.is_empty():
		return linhas
	var saida: PackedStringArray = []
	for linha in linhas:
		if linha.begins_with(unidade):
			saida.append(linha.substr(unidade.length()))
		else:
			saida.append(linha)
	return saida

static func _assinar(s: String) -> String:
	var resto := s.substr(4).strip_edges()
	var abre := resto.find("(")
	var fecha := resto.rfind(")")
	if abre < 0 or fecha < abre:
		return "func " + resto
	var nome := resto.substr(0, abre).strip_edges()
	var args := resto.substr(abre + 1, fecha - abre - 1)
	var fim := resto.substr(fecha + 1)
	var partes: PackedStringArray = args.split(",")
	var limpos: PackedStringArray = []
	for parte in partes:
		var a := parte.strip_edges()
		if a.is_empty() or a == "self":
			continue
		limpos.append(a)
	return "func %s(%s)%s" % [nome, ", ".join(limpos), fim]

static func _var_se_atribuicao(s: String) -> String:
	if s.begins_with("if ") or s.begins_with("elif ") or s.begins_with("else") or s.begins_with("for ") or s.begins_with("while ") or s.begins_with("return") or s.begins_with("pass") or s.begins_with("func "):
		return s
	var eq := _pos_igual(s)
	if eq <= 0:
		return s
	var nome := s.substr(0, eq).strip_edges()
	if not nome.is_valid_identifier():
		return s
	return "var %s =%s" % [nome, s.substr(eq + 1)]

static func _pos_igual(s: String) -> int:
	var aspas := ""
	var i := 0
	while i < s.length():
		var ch := s.substr(i, 1)
		if aspas != "":
			if ch == "\\":
				i += 2
				continue
			if ch == aspas:
				aspas = ""
			i += 1
			continue
		if ch == "#":
			return -1
		if ch == "\"" or ch == "'":
			aspas = ch
			i += 1
			continue
		if ch == "=":
			var ant := ""
			var prox := ""
			if i > 0:
				ant = s.substr(i - 1, 1)
			if i + 1 < s.length():
				prox = s.substr(i + 1, 1)
			if ant != "=" and ant != "!" and ant != "<" and ant != ">" and prox != "=":
				return i
		i += 1
	return -1

static func _py_para_gd_linha(linha: String) -> String:
	var saida := ""
	var i := 0
	var aspas := ""
	while i < linha.length():
		var ch := linha.substr(i, 1)
		if aspas != "":
			saida += ch
			if ch == "\\":
				if i + 1 < linha.length():
					saida += linha.substr(i + 1, 1)
					i += 2
					continue
			elif ch == aspas:
				aspas = ""
			i += 1
			continue
		if ch == "#":
			saida += linha.substr(i)
			break
		if ch == "\"" or ch == "'":
			aspas = ch
			saida += ch
			i += 1
			continue
		if linha.substr(i, 5) == "self." and (i == 0 or not _eh_id(linha.substr(i - 1, 1))):
			i += 5
			continue
		var palavra := _ler_palavra(linha, i)
		if palavra == "True":
			saida += "true"
			i += 4
			continue
		if palavra == "False":
			saida += "false"
			i += 5
			continue
		if palavra == "None":
			saida += "null"
			i += 4
			continue
		saida += ch
		i += 1
	return saida

static func _ler_palavra(linha: String, i: int) -> String:
	if i > 0 and _eh_id(linha.substr(i - 1, 1)):
		return ""
	var j := i
	while j < linha.length() and _eh_id(linha.substr(j, 1)):
		j += 1
	if j == i:
		return ""
	return linha.substr(i, j - i)

static func _eh_id(ch: String) -> bool:
	if ch >= "a" and ch <= "z":
		return true
	if ch >= "A" and ch <= "Z":
		return true
	if ch >= "0" and ch <= "9":
		return true
	return ch == "_"

static func _indentado(linha: String) -> bool:
	if linha.is_empty():
		return false
	var ch := linha.substr(0, 1)
	return ch == " " or ch == "\t"

static func _proibido(texto: String) -> String:
	var linhas: PackedStringArray = texto.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	for linha in linhas:
		var s := _sem_comentario(linha).strip_edges()
		if s.begins_with("import ") or s.begins_with("from "):
			return "Nao use import neste arquivo."
		if "exec(" in s or "eval(" in s or "__" in s or s.begins_with("lambda ") or " lambda " in s:
			return "Esse codigo nao pode ser usado na classe Carro."
	return ""

static func _sem_comentario(linha: String) -> String:
	var aspas := ""
	var i := 0
	while i < linha.length():
		var ch := linha.substr(i, 1)
		if aspas != "":
			if ch == "\\":
				i += 2
				continue
			if ch == aspas:
				aspas = ""
			i += 1
			continue
		if ch == "#":
			return linha.substr(0, i)
		if ch == "\"" or ch == "'":
			aspas = ch
		i += 1
	return linha

static func _falha(msg: String) -> Dictionary:
	Log.erro("classe", msg)
	return {"ok": false, "erro": msg, "script": null}
