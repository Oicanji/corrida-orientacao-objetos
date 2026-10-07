extends Logger

func _log_message(message: String, error: bool) -> void:
	if message.is_empty() or "[corrida]" in message:
		return
	var prefixo := "MOTOR-ERR " if error else "MOTOR "
	_enviar(prefixo + message)

func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	script_backtraces: Array[ScriptBacktrace],
) -> void:
	var extra := ""
	for bt in script_backtraces:
		var n := bt.get_frame_count()
		var f := 0
		while f < n and f < 12:
			extra += " | %s:%d %s" % [bt.get_frame_file(f), bt.get_frame_line(f), bt.get_frame_function(f)]
			f += 1
	var texto := "%s:%d type=%d %s %s %s%s" % [file, line, error_type, function, code, rationale, extra]
	_enviar("MOTOR-FALHA " + texto)

func _enviar(linha: String) -> void:
	var arvore = Engine.get_main_loop()
	if arvore == null or arvore.root == null:
		return
	var no = arvore.root.get_node_or_null("Log")
	if no == null:
		return
	no.do_motor(linha.left(4000))
