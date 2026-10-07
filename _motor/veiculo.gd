extends RigidBody2D

const CABECA := preload("res://scenes/cabeca.tscn")
const RELACAO_M: Array[float] = [4.0, 3.15, 2.55, 1.85, 1.4]
const TETO_MARCHA_KMH: Array[float] = [15.0, 30.0, 50.0, 80.0, 150.0]
const DURACAO_TROCA := 0.16
const TRACAO := 2.4

signal morreu(titulo: String)
signal venceu

var classe: Node
var terreno
var extras
var pista
var camera: Camera2D
var teto: Area2D
var motor: AudioStreamPlayer
var roda_frente: RigidBody2D
var roda_tras: RigidBody2D
var junta_frente: PinJoint2D
var junta_tras: PinJoint2D
var poeira_frente: CPUParticles2D
var poeira_tras: CPUParticles2D
var cabeca: Node2D

var morto := false
var ganhou := false
var pronto := false
var km := 0.0
var tempo_vivo := 0.0
var x_inicio := 0.0
var pulo_espera := 0.0
var vel_hud := 0.0
var rpm := 800.0
var no_chao_agora := true
var sentido := 0.0
var marcha_atual := 1
var modo_marcha := "manual"
var cambio_espera := 0.0
var sobe_antes := false
var desce_antes := false
var na_re := false
var troca_t := 0.0
var troca_de := 1
var marcha_pedida := 0
var vel_pico := 0.0
var alavanca := Vector2(-36, -18)
var frente_ativa := true
var tras_ativa := true
var ids_carro: Array = []
var nframe := 0
var _rodas_aplicadas := false
var _mat_uso := PhysicsMaterial.new()
var _audio_toquei := false
var _recua_log := false
var _solo_antes := ""
var _cfg_frente := {}
var _cfg_tras := {}

func _ready() -> void:
	Log.fase("veiculo.ready")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Log.passo("veiculo", "_ready pos=%s" % position)
	pista = get_parent()
	classe = get_node_or_null("Classe")
	camera = get_node_or_null("Camera2D")
	teto = get_node_or_null("Teto")
	terreno = _irmao("Terreno")
	extras = _irmao("Extras")
	motor = pista.get_node_or_null("Sons/Motor") if pista else null
	roda_frente = _irmao("RodaFrente")
	roda_tras = _irmao("RodaTras")
	junta_frente = _irmao("JuntaFrente")
	junta_tras = _irmao("JuntaTras")
	if classe == null:
		Log.erro("veiculo", "sem no Classe")
	else:
		Log.passo("veiculo", "classe script=%s" % classe.get_script())
		_garantir_attrs()
		_log_attrs()
	if teto:
		teto.monitoring = false
		teto.monitorable = false
		teto.collision_mask = 1
		Log.passo("veiculo", "teto monitoring=%s mask=%s" % [teto.monitoring, teto.collision_mask])
	else:
		Log.erro("veiculo", "sem Teto")
	contact_monitor = true
	max_contacts_reported = 12
	angular_damp = 1.8
	_mat_uso.bounce = 0.0
	if physics_material_override != null:
		var corpo_mat: PhysicsMaterial = physics_material_override.duplicate()
		corpo_mat.friction = 0.05
		physics_material_override = corpo_mat
	if roda_frente:
		roda_frente.process_mode = Node.PROCESS_MODE_PAUSABLE
		roda_frente.contact_monitor = true
		roda_frente.max_contacts_reported = 8
		poeira_frente = roda_frente.get_node_or_null("Poeira")
	else:
		Log.erro("veiculo", "sem RodaFrente")
	if roda_tras:
		roda_tras.process_mode = Node.PROCESS_MODE_PAUSABLE
		roda_tras.contact_monitor = true
		roda_tras.max_contacts_reported = 8
		poeira_tras = roda_tras.get_node_or_null("Poeira")
	else:
		Log.erro("veiculo", "sem RodaTras")
	if junta_frente:
		junta_frente.softness = 0.28
	if junta_tras:
		junta_tras.softness = 0.28
	_iniciar_cambio()
	_aplicar_rodas()
	_aplicar_cor()
	_montar_cabeca()
	_atualizar_ids()
	_configurar_audio()
	x_inicio = position.x
	_colocar_spawn()
	call_deferred("_aplicar_rodas")
	pronto = roda_frente != null and roda_tras != null and terreno != null and classe != null
	Log.passo("veiculo", "pronto=%s x_inicio=%.1f" % [pronto, x_inicio])

func _process(delta: float) -> void:
	if not pronto or camera == null:
		return
	if pista and pista.get("editando") == true:
		return
	if morto or ganhou:
		return
	var vel := linear_velocity
	if is_nan(vel.x) or is_nan(vel.y):
		Log.erro("veiculo", "camera vel nan")
		return
	var alvo := Vector2(
		180.0 + clampf(vel.x * 0.05, -50.0, 320.0),
		-70.0 + clampf(vel.y * 0.04, -50.0, 50.0)
	)
	var peso := minf(1.0, delta * 5.0)
	camera.position = camera.position.lerp(alvo, peso)
	var zoom_v := 0.74 - minf(absf(vel.x) / Corrida.ZOOM_VEL, 0.16)
	camera.zoom = Vector2(zoom_v, zoom_v)

func _physics_process(delta: float) -> void:
	Log.fase("veiculo.inicio")
	nframe += 1
	if not pronto:
		Log.fase("veiculo.nao_pronto")
		if nframe % 60 == 0:
			Log.erro("veiculo", "fisica sem pronto frame=%d" % nframe)
		return
	if pista and pista.get("editando") == true:
		Log.fase("veiculo.editando")
		return
	if morto or ganhou:
		Log.fase("veiculo.parado")
		return
	if delta <= 0.0:
		Log.erro("veiculo", "delta<=0 %s" % delta)
		return
	if delta > 0.1:
		Log.passo("veiculo", "delta alto %.3f frame=%d" % [delta, nframe])
	Log.passo("veiculo", "frame %d inicio x=%.1f y=%.1f" % [nframe, position.x, position.y], nframe < 3)
	if not _rodas_aplicadas:
		Log.passo("veiculo", "rodas na primeira fisica")
		_aplicar_rodas()
		_rodas_aplicadas = true
	tempo_vivo += delta
	if pulo_espera > 0.0:
		pulo_espera -= delta
	var pos := position
	if is_nan(pos.x) or is_nan(pos.y):
		Log.erro("veiculo", "pos nan frame=%d" % nframe)
		morrer("Erro no motor")
		return
	km = maxf(0.0, (pos.x - x_inicio) / Corrida.PX_POR_KM)
	if pos.x >= Corrida.Z6:
		Log.passo("veiculo", "chegou Z6 x=%.1f" % pos.x)
		_vencer()
		return
	var vel := linear_velocity
	if is_nan(vel.x) or is_nan(vel.y) or vel.length() > Corrida.VEL_MORTE:
		Log.erro("veiculo", "vel ruim vx=%s vy=%s len=%s" % [vel.x, vel.y, vel.length()])
		morrer("Capotou!")
		return
	Log.fase("veiculo.cambio")
	var recuando := _tecla(KEY_CTRL)
	if recuando != _recua_log:
		Log.passo("veiculo", "RECUA %s marcha=%s" % [recuando, marcha_atual])
		_recua_log = recuando
	_atualizar_cambio(delta, recuando)
	var acelerando := _tecla(KEY_SPACE)
	sentido = 0.0
	if recuando:
		sentido = -1.0
	elif acelerando:
		sentido = 1.0
	var ang := rotation
	var n := 1 if recuando else marcha_atual
	var solo_agora: String = terreno.nome_solo(pos.x)
	var relacao: float = RELACAO_M[n - 1]
	var kmh: float = absf(vel.x) * Corrida.KMH_FATOR
	if kmh >= Corrida.KMH_MORTE:
		Log.passo("veiculo", "explodiu kmh=%.1f" % kmh)
		morrer("Explodiu!")
		return
	var ef: float = float(terreno.eficiencia(solo_agora, kmh))
	var rodas: float = _fator_rodas()
	var peso: float = _peso_rodas()
	if solo_agora != _solo_antes:
		Log.passo("veiculo", "SOLO %s marcha=%s n=%s x=%d kmh=%.1f ef=%.2f" % [solo_agora, marcha_atual, n, int(pos.x), kmh, ef])
		_solo_antes = solo_agora
	Log.fase("veiculo.chao")
	var no_chao := _no_chao()
	no_chao_agora = no_chao
	if sentido != 0.0 and not no_chao:
		sentido = 0.0
	var entrega: float = _entrega_marcha(kmh, n)
	var carga: float = _carga_marcha(kmh, n)
	Log.fase("veiculo.forca")
	var empuxo := 0.0
	if sentido != 0.0 and no_chao and rodas > 0.0 and entrega > 0.0:
		var potencia := _potencia()
		if morto:
			return
		var chao := _chao_tangente()
		empuxo = sentido * maxf(potencia, 80.0) * relacao * TRACAO * carga * ef * rodas * entrega
		if is_nan(empuxo) or is_inf(empuxo):
			Log.erro("veiculo", "empuxo invalido %s potencia=%s" % [empuxo, potencia])
			morrer("Erro na classe")
			return
		apply_central_force(chao.tangente * empuxo)
		if chao.inclinacao > 0.12:
			apply_central_force(-chao.normal * mass * 520.0 * chao.inclinacao)
	if no_chao and sentido == 0.0:
		_freio_motor(kmh, n, delta)
	if no_chao and ef < 1.0:
		_sangrar_debuff(ef, delta)
	if no_chao and rodas <= 0.0:
		linear_velocity.x = 0.0
	_cortar_excesso(kmh, delta)
	vel_hud = absf(linear_velocity.x)
	var damp_base: float = 2.2
	if solo_agora == "gelo":
		damp_base = 3.4
	elif solo_agora == "barro":
		damp_base = 2.8
	angular_damp = damp_base + (peso - 1.0) * 0.35
	if no_chao:
		_estabilizar(peso)
	Log.fase("veiculo.giro")
	var rot := 0.0
	if tras_ativa and (_acao("girar_esq", [KEY_A, KEY_LEFT]) or Input.is_action_pressed("ui_left")):
		rot -= 1.0
	if frente_ativa and (_acao("girar_dir", [KEY_D, KEY_RIGHT]) or Input.is_action_pressed("ui_right")):
		rot += 1.0
	if rot != 0.0:
		_aplicar_giro(rot, ang)
	_atualizar_rpm(delta)
	var solo: String = terreno.nome_solo(pos.x)
	var no_barro := solo == "barro"
	var no_gelo := solo == "gelo"
	if solo == "preto":
		linear_damp = 0.04
	else:
		linear_damp = 0.05
	var base_f := 0.72
	if no_barro:
		base_f = 0.9
	elif no_gelo:
		base_f = 0.22
	elif solo == "verde" or solo == "montanha":
		base_f = 0.95
	elif solo == "areia":
		base_f = 0.48
	elif solo == "vulcao":
		base_f = 0.62
	var grip := 1.04 - (n - 1) * 0.02
	_mat_uso.friction = base_f * grip
	_mat_uso.bounce = 0.0
	_mat_uso.rough = no_barro
	if frente_ativa:
		roda_frente.physics_material_override = _mat_uso
		roda_frente.linear_damp = 0.02
	if tras_ativa:
		roda_tras.physics_material_override = _mat_uso
		roda_tras.linear_damp = 0.02
	var linha := "F marcha=%s n=%s recua=%s esp=%s vx=%.1f vy=%.1f kmh=%.1f teto=%.0f emp=%.0f ef=%.2f rodas=%.2f solo=%s x=%d y=%d damp=%.2f troca=%.2f chao=%s frame=%d" % [
		marcha_atual, n, recuando, acelerando, vel.x, vel.y, kmh, _teto_marcha(n),
		empuxo, ef, rodas, solo_agora, int(pos.x), int(pos.y), linear_damp, troca_t, no_chao, nframe,
	]
	Log.passo("veiculo", linha, nframe < 3 or nframe % 30 == 0)
	Log.fase("veiculo.giro_limite")
	_limitar_giro()
	if nframe % 12 == 0:
		Log.fase("veiculo.cull")
		terreno.cull(pos.x)
		if extras and extras.has_method("cull"):
			extras.cull(pos.x)
	if extras and extras.has_method("checar"):
		extras.checar(self)
		if morto or ganhou:
			return
	Log.fase("veiculo.teto")
	_checar_teto()
	if morto:
		return
	var velocidade := vel.length()
	Log.fase("veiculo.junta")
	if junta_frente and junta_tras:
		if velocidade > Corrida.VEL_JUNTA_RIGIDA:
			junta_frente.softness = 0.0
			junta_tras.softness = 0.0
		else:
			junta_frente.softness = 0.28
			junta_tras.softness = 0.28
	Log.fase("veiculo.cabeca")
	_checar_cabeca(delta, velocidade)
	if morto:
		return
	var poeira := sentido != 0.0 and no_chao and velocidade > 40.0
	if frente_ativa and poeira_frente:
		poeira_frente.emitting = poeira
	if tras_ativa and poeira_tras:
		poeira_tras.emitting = poeira
	_atualizar_audio()
	_atualizar_anim_marcha(delta)
	Log.fase("veiculo.fim")

func ao_teto(corpo: Node) -> void:
	Log.passo("veiculo", "sinal teto %s vivo=%.2f morto=%s" % [corpo.name if corpo else "?", tempo_vivo, morto])
	if morto or ganhou or tempo_vivo < 0.7:
		return
	if pista and pista.get("editando") == true:
		return
	morrer("Capotou!")

func morrer(titulo: String = "Capotou!") -> void:
	Log.passo("veiculo", "morrer %s morto=%s ganhou=%s frame=%d pos=%s vel=%s pilha=%s" % [
		titulo, morto, ganhou, nframe, position, linear_velocity, _pilha(),
	])
	if morto or ganhou:
		return
	morto = true
	Log.fase("veiculo.morrer")
	_congelar()
	morreu.emit(titulo)

func texto_km() -> String:
	return ("%.2f" % km).replace(".", ",")

func texto_tempo() -> String:
	var t := tempo_vivo
	var m := int(t / 60.0)
	var s := t - float(m) * 60.0
	return "%d:%s" % [m, ("%05.2f" % s).replace(".", ",")]

func modo_auto() -> bool:
	return modo_marcha == "auto"

func _vencer() -> void:
	if ganhou or morto:
		return
	ganhou = true
	Log.passo("veiculo", "vitoria tempo=%s km=%s" % [texto_tempo(), texto_km()])
	Log.fase("veiculo.vencer")
	_congelar()
	venceu.emit()

func _congelar() -> void:
	Log.passo("veiculo", "congelar")
	if frente_ativa and poeira_frente:
		poeira_frente.emitting = false
	if tras_ativa and poeira_tras:
		poeira_tras.emitting = false
	if frente_ativa and roda_frente:
		roda_frente.freeze = true
	if tras_ativa and roda_tras:
		roda_tras.freeze = true
	if motor:
		motor.stop()
	var corpo := get_node_or_null("Corpo")
	if corpo:
		corpo.hide()
	if roda_frente:
		var frente_sprite := roda_frente.get_node_or_null("Sprite2D")
		if frente_sprite:
			frente_sprite.hide()
	if roda_tras:
		var tras_sprite := roda_tras.get_node_or_null("Sprite2D")
		if tras_sprite:
			tras_sprite.hide()
	freeze = true

func _colocar_spawn() -> void:
	var sx := 0.0
	if pista:
		var bruto = pista.get("spawn_x")
		if bruto != null:
			sx = float(bruto)
	if sx <= 0.0:
		Log.passo("veiculo", "sem spawn especial")
		return
	var y_chao: float = terreno.altura(sx)
	var y := y_chao - 75.0
	Log.passo("veiculo", "SPAWN x=%.0f y=%.0f chao=%.0f" % [sx, y, y_chao])
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	position = Vector2(sx, y)
	x_inicio = sx
	_aplicar_rodas()
	freeze = false
	terreno.cull(sx)

func _configurar_roda(roda: RigidBody2D, junta: PinJoint2D, x: float, y: float, tamanho: float, ativa: bool) -> void:
	if junta:
		junta.node_a = NodePath()
		junta.node_b = NodePath()
	if roda == null:
		Log.erro("veiculo", "configurar roda nula")
		return
	if not ativa:
		roda.hide()
		roda.collision_layer = 0
		roda.collision_mask = 0
		roda.freeze = true
		roda.position = Vector2(-4000, -4000)
		Log.passo("veiculo", "roda off %s" % roda.name)
		return
	var pos := Vector2(x, y)
	roda.freeze = true
	roda.position = pos
	roda.linear_velocity = Vector2.ZERO
	roda.angular_velocity = 0.0
	roda.show()
	roda.collision_layer = 2
	roda.collision_mask = 5
	if junta:
		junta.position = pos
	var sprite := roda.get_node_or_null("Sprite2D")
	if sprite:
		sprite.scale = Vector2(0.425 * tamanho, 0.425 * tamanho)
	var colisao := roda.get_node_or_null("CollisionShape2D")
	if colisao:
		var forma := CircleShape2D.new()
		forma.radius = 27.2 * tamanho
		colisao.shape = forma
	if junta:
		junta.node_a = get_path()
		junta.node_b = roda.get_path()
	roda.freeze = false
	Log.passo("veiculo", "roda %s pos=%s tam=%.2f" % [roda.name, pos, tamanho])

func _aplicar_rodas() -> void:
	Log.fase("veiculo.rodas")
	_cfg_tras = _cfg_roda("roda_atras")
	_cfg_frente = _cfg_roda("roda_frente")
	var dist_atras := maxf(0.2, float(_cfg_tras["distancia"]))
	var dist_frente := maxf(0.2, float(_cfg_frente["distancia"]))
	frente_ativa = bool(_cfg_frente["presente"])
	tras_ativa = bool(_cfg_tras["presente"])
	var corpo := position
	var meio := -9.5
	var eixo_y_atras := corpo.y + 68.2 - 27.2 * float(_cfg_tras["tamanho"])
	var eixo_y_frente := corpo.y + 68.2 - 27.2 * float(_cfg_frente["tamanho"])
	Log.passo("veiculo", "rodas frente=%s tras=%s" % [_cfg_frente, _cfg_tras])
	_configurar_roda(roda_tras, junta_tras, corpo.x + meio - 58.5 * dist_atras, eixo_y_atras, float(_cfg_tras["tamanho"]), tras_ativa)
	_configurar_roda(roda_frente, junta_frente, corpo.x + meio + 58.5 * dist_frente, eixo_y_frente, float(_cfg_frente["tamanho"]), frente_ativa)
	_atualizar_ids()
	_aplicar_peso()

func _tamanho_medio() -> float:
	var soma: float = 0.0
	var qtd: int = 0
	if tras_ativa:
		soma += float(_cfg_tras["tamanho"])
		qtd += 1
	if frente_ativa:
		soma += float(_cfg_frente["tamanho"])
		qtd += 1
	if qtd == 0:
		return 10.0
	return soma / float(qtd)

func _peso_rodas() -> float:
	var t: float = _tamanho_medio()
	if t <= 1.0:
		return 1.0
	return 1.0 + pow((t - 1.0) / 4.0, 3.0) * 20.0

func _fator_rodas() -> float:
	var t: float = _tamanho_medio()
	if t >= 10.0:
		return 0.0
	if t <= 1.0:
		return 1.0
	var bonus: float = 1.0 + 0.35 * minf(t - 1.0, 2.0)
	return maxf(0.0, bonus / _peso_rodas())

func _aplicar_peso() -> void:
	var peso: float = _peso_rodas()
	var extra: float = 1.0 + (peso - 1.0) * 0.25
	mass = Corrida.MASSA_CHASSI * extra
	if tras_ativa and roda_tras:
		roda_tras.mass = Corrida.MASSA_RODA * maxf(float(_cfg_tras["tamanho"]), 0.2) * extra
	if frente_ativa and roda_frente:
		roda_frente.mass = Corrida.MASSA_RODA * maxf(float(_cfg_frente["tamanho"]), 0.2) * extra
	Log.passo("veiculo", "peso=%.2f extra=%.2f massa=%.2f fator=%.3f" % [peso, extra, mass, _fator_rodas()])

func _chao_tangente() -> Dictionary:
	var passo := 36.0
	var dy: float = terreno.altura(position.x + passo) - terreno.altura(position.x - passo)
	var tangente := Vector2(passo * 2.0, dy)
	if tangente.length_squared() < 1.0:
		tangente = Vector2.RIGHT
	else:
		tangente = tangente.normalized()
	if tangente.x < 0.0:
		tangente = -tangente
	var normal := Vector2(tangente.y, -tangente.x)
	return {
		"tangente": tangente,
		"normal": normal,
		"inclinacao": clampf(absf(tangente.y), 0.0, 1.0),
	}

func _teto_marcha(marcha: int) -> float:
	return TETO_MARCHA_KMH[clampi(marcha, 1, 5) - 1]

func _entrega_marcha(kmh: float, marcha: int) -> float:
	var teto: float = _teto_marcha(marcha)
	if kmh >= teto:
		return 0.0
	var resto: float = (teto - kmh) / teto
	if resto >= 0.08:
		return 1.0
	return clampf(resto / 0.08, 0.0, 1.0)

func _carga_marcha(kmh: float, marcha: int) -> float:
	if marcha <= 1:
		return 1.0
	var chegada: float = _teto_marcha(marcha - 1) * 0.45
	if kmh >= chegada:
		return 1.0
	return lerpf(0.85, 1.0, kmh / maxf(chegada, 1.0))

func _freio_motor(kmh: float, marcha: int, delta: float) -> void:
	var teto: float = _teto_marcha(marcha)
	if kmh <= teto:
		return
	var vx: float = linear_velocity.x
	if vx == 0.0:
		return
	var excesso: float = kmh - teto
	var puxa: float = 1.2 + float(6 - marcha) * 0.35
	var perda_kmh: float = minf(excesso * puxa, 18.0) * delta
	var perda_vx: float = perda_kmh / Corrida.KMH_FATOR
	if vx > 0.0:
		linear_velocity.x = maxf(0.0, vx - perda_vx)
	else:
		linear_velocity.x = minf(0.0, vx + perda_vx)

func _sangrar_debuff(ef: float, delta: float) -> void:
	var vx: float = linear_velocity.x
	var queda: float = (1.0 - ef) * vx * 0.45 * delta
	var novo: float = vx - queda
	if vx > 0.0:
		novo = maxf(novo, 0.0)
	elif vx < 0.0:
		novo = minf(novo, 0.0)
	linear_velocity.x = novo

func _cortar_excesso(kmh: float, delta: float) -> void:
	if kmh <= Corrida.KMH_TETO:
		return
	var faixa: float = Corrida.KMH_MORTE - Corrida.KMH_TETO
	var u: float = clampf((kmh - Corrida.KMH_TETO) / faixa, 0.0, 1.0)
	var perda_kmh: float = (exp(u * 4.0) - 1.0) * delta
	var perda_vx: float = perda_kmh / Corrida.KMH_FATOR
	var vx: float = linear_velocity.x
	if vx > 0.0:
		linear_velocity.x = maxf(0.0, vx - perda_vx)
	elif vx < 0.0:
		linear_velocity.x = minf(0.0, vx + perda_vx)

func _estabilizar(peso: float) -> void:
	var ang_up: float = fposmod(rotation + PI, TAU) - PI
	apply_torque(-ang_up * 900.0 * peso)

func _atualizar_ids() -> void:
	ids_carro = [get_instance_id()]
	if frente_ativa and roda_frente:
		ids_carro.append(roda_frente.get_instance_id())
	if tras_ativa and roda_tras:
		ids_carro.append(roda_tras.get_instance_id())
	Log.passo("veiculo", "ids=%s" % str(ids_carro))

func _aplicar_cor() -> void:
	Log.fase("veiculo.cor")
	var sprite := get_node_or_null("Corpo")
	if sprite == null:
		Log.erro("veiculo", "sem Corpo")
		return
	var cor := _txt("cor_carro", "vermelho")
	var caminho := "res://assets/Images/Car/RedCar.png" if cor == "vermelho" else "res://assets/Images/Car/Car.png"
	Log.passo("veiculo", "cor=%s tex=%s" % [cor, caminho])
	if not ResourceLoader.exists(caminho):
		Log.erro("veiculo", "textura ausente " + caminho)
		return
	sprite.texture = load(caminho)

func _montar_cabeca() -> void:
	Log.fase("veiculo.cabeca_montar")
	if cabeca != null and is_instance_valid(cabeca):
		cabeca.queue_free()
		cabeca = null
	var nome := _txt("motorista", "ryan.png")
	var cam := Imagens.caminho_motorista(nome)
	if cam.is_empty():
		Log.erro("veiculo", "cabeca sem arquivo")
		return
	var img: Dictionary = Imagens.carregar(cam)
	if img.tex == null:
		Log.erro("veiculo", "cabeca sem textura")
		return
	cabeca = CABECA.instantiate()
	add_child(cabeca)
	cabeca.aplicar_textura(img.tex, int(img.px))
	Log.passo("veiculo", "cabeca no arvore")

func _configurar_audio() -> void:
	if motor == null:
		Log.erro("veiculo", "sem player Motor")
		return
	if motor.stream == null:
		Log.erro("veiculo", "Motor sem stream")
		return
	if motor.stream is AudioStreamOggVorbis:
		motor.stream.loop = true
	else:
		motor.stream.set("loop", true)
	motor.volume_db = -8.0
	Log.passo("veiculo", "audio pronto %s" % motor.stream)

func _iniciar_cambio() -> void:
	marcha_atual = _clamp_marcha(int(_num("marcha_inicial", 1.0)))
	modo_marcha = _txt("marcha", "manual").strip_edges().to_lower()
	if modo_marcha != "auto":
		modo_marcha = "manual"
	if classe:
		classe.set("marcha", modo_marcha)
		classe.set("marcha_inicial", marcha_atual)
	cambio_espera = 0.0
	sobe_antes = false
	desce_antes = false
	na_re = false
	troca_t = 0.0
	troca_de = 1
	vel_pico = 0.0
	alavanca = _pos_alavanca(marcha_atual)
	Log.passo("veiculo", "cambio marcha=%s modo=%s vel=%s" % [marcha_atual, modo_marcha, _num("velocidade", 0.0)])

func _clamp_marcha(n: int) -> int:
	return clampi(n, 1, 5)

func _pos_alavanca(marcha) -> Vector2:
	if str(marcha) == "R" or (typeof(marcha) != TYPE_STRING and int(marcha) == 0):
		return Vector2(36, 18)
	var n: int = _clamp_marcha(int(marcha))
	var col := int((n - 1) / 2.0)
	if n == 5:
		col = 2
	var linha := -18.0 if n % 2 == 1 else 18.0
	return Vector2(-36.0 + col * 36.0, linha)

func _pedir_troca(nova: int) -> void:
	nova = _clamp_marcha(nova)
	if nova == marcha_atual:
		marcha_pedida = 0
		return
	if troca_t > 0.0:
		marcha_pedida = nova
		return
	_aplicar_troca(nova)

func _aplicar_troca(nova: int) -> void:
	nova = _clamp_marcha(nova)
	if nova == marcha_atual:
		return
	troca_de = marcha_atual
	marcha_atual = nova
	troca_t = DURACAO_TROCA
	cambio_espera = 0.45
	if motor:
		motor.play(0.0)
	Log.passo("veiculo", "CAMBIO %s -> %s auto=%s" % [troca_de, nova, modo_auto()])

func _atualizar_cambio(delta: float, recuando: bool) -> void:
	if recuando:
		if not na_re:
			troca_de = marcha_atual
			troca_t = DURACAO_TROCA
			if motor:
				motor.play(0.0)
			Log.passo("veiculo", "entrou re")
		marcha_atual = 1
		marcha_pedida = 0
		na_re = true
		sobe_antes = true
		desce_antes = true
		return
	na_re = false
	if cambio_espera > 0.0:
		cambio_espera -= delta
	if troca_t <= 0.0 and marcha_pedida != 0:
		var pedido: int = marcha_pedida
		marcha_pedida = 0
		_aplicar_troca(pedido)
	if modo_auto():
		_cambio_auto()
		return
	var sobe := _tecla(KEY_W) or _tecla(KEY_UP)
	var desce := _tecla(KEY_S) or _tecla(KEY_DOWN)
	if sobe and not sobe_antes:
		_pedir_troca(marcha_atual + 1)
	if desce and not desce_antes:
		_pedir_troca(marcha_atual - 1)
	sobe_antes = sobe
	desce_antes = desce

func _cambio_auto() -> void:
	if cambio_espera > 0.0 or troca_t > 0.0:
		return
	var kmh: float = absf(linear_velocity.x) * Corrida.KMH_FATOR
	var teto: float = _teto_marcha(marcha_atual)
	if marcha_atual < 5 and kmh >= teto * 0.9:
		_aplicar_troca(marcha_atual + 1)
	elif marcha_atual > 1 and kmh <= _teto_marcha(marcha_atual - 1) * 0.55:
		_aplicar_troca(marcha_atual - 1)

func _tecla(codigo: Key) -> bool:
	return Input.is_physical_key_pressed(codigo) or Input.is_key_pressed(codigo)

func _acao(nome: String, codigos: Array) -> bool:
	if InputMap.has_action(nome) and Input.is_action_pressed(nome):
		return true
	for codigo in codigos:
		if _tecla(codigo):
			return true
	return false

func _aplicar_giro(rot: float, ang: float) -> void:
	Log.fase("veiculo.torque")
	var cima_x := sin(ang)
	var cima_y := -cos(ang)
	var forca := 260.0 * rot
	apply_torque(rot * 260000.0)
	if frente_ativa:
		roda_frente.apply_central_force(Vector2(-cima_x * forca, -cima_y * forca))
		roda_frente.apply_torque(rot * 48000.0)
	if tras_ativa:
		roda_tras.apply_central_force(Vector2(cima_x * forca, cima_y * forca))
		roda_tras.apply_torque(rot * 48000.0)

func _potencia() -> float:
	Log.fase("veiculo.acelerar")
	if classe == null or not classe.has_method("acelerar"):
		Log.erro("veiculo", "sem metodo acelerar")
		return 80.0
	var r = classe.call("acelerar", 1.0)
	if r == null or not (r is float or r is int):
		Log.erro("veiculo", "acelerar retornou %s" % str(r))
		return 80.0
	var valor := float(r)
	if is_nan(valor) or is_inf(valor):
		Log.erro("veiculo", "acelerar nan/inf")
		morrer("Erro na classe")
		return 0.0
	return absf(valor)

func _no_chao() -> bool:
	var pos := position
	var y_chao: float = terreno.altura(pos.x)
	if pos.y > y_chao - 118.0:
		return true
	if tras_ativa and _roda_no_chao(roda_tras):
		return true
	if frente_ativa and _roda_no_chao(roda_frente):
		return true
	return false

func _roda_no_chao(roda: RigidBody2D) -> bool:
	if roda == null:
		return false
	var corpos = roda.get_colliding_bodies()
	for item in corpos:
		if _e_terreno(item):
			return true
	return false

func _e_terreno(item) -> bool:
	if item == null or not is_instance_valid(item):
		return false
	var camada = item.get("collision_layer")
	if camada == null:
		return false
	return int(camada) == 1

func _limitar_giro() -> void:
	var teto_w := 5.5
	if terreno.nome_solo(position.x) == "gelo":
		teto_w = 2.8
	var w: float = angular_velocity
	if w > teto_w:
		angular_velocity = teto_w
	elif w < -teto_w:
		angular_velocity = -teto_w

func _checar_teto() -> void:
	if tempo_vivo < 0.55 or teto == null:
		return
	if _chao_no_teto():
		Log.passo("veiculo", "teto chao")
		morrer("Capotou!")
		return
	if _capotado() and _corpo_no_terreno():
		Log.passo("veiculo", "teto coll ang=%.2f" % rotation)
		morrer("Capotou!")

func _chao_no_teto() -> bool:
	var corpos = teto.get_overlapping_bodies()
	for item in corpos:
		if _e_terreno(item):
			return true
	return false

func _corpo_no_terreno() -> bool:
	for item in get_colliding_bodies():
		if _e_terreno(item):
			return true
	return false

func _capotado() -> bool:
	var ang := fposmod(rotation + PI, TAU) - PI
	return absf(ang) > 1.65

func _checar_cabeca(delta: float, velocidade: float) -> void:
	if cabeca == null or not is_instance_valid(cabeca):
		if nframe == 1:
			Log.passo("veiculo", "sem cabeca na fisica")
		return
	cabeca.atualizar(delta, velocidade)
	if tempo_vivo < 0.7:
		return
	if cabeca.tocou_chao(terreno):
		morrer("Capotou!")
		return
	if _capotado() and position.y > terreno.altura(position.x) - 130.0:
		Log.passo("veiculo", "cabeca capotada y=%.1f" % position.y)
		morrer("Capotou!")

func _atualizar_rpm(delta: float) -> void:
	var idle := 850.0
	var alvo := idle
	if sentido != 0.0 and no_chao_agora:
		var n_rpm: int = 1 if na_re else marcha_atual
		var frac: float = minf(1.0, (vel_hud * Corrida.KMH_FATOR) / _teto_marcha(n_rpm))
		alvo = 2200.0 + frac * 5600.0
	else:
		var giro := 0.0
		if tras_ativa and roda_tras:
			giro = maxf(giro, absf(roda_tras.angular_velocity))
		if frente_ativa and roda_frente:
			giro = maxf(giro, absf(roda_frente.angular_velocity))
		alvo = idle + minf(giro * 42.0, 6900.0)
	alvo = minf(alvo, 8000.0)
	var sobe_giro := 5.2
	var desce_giro := 2.1
	if troca_t > 0.0 and alvo < rpm:
		desce_giro = 16.0
	if alvo > rpm:
		rpm += (alvo - rpm) * minf(1.0, delta * sobe_giro)
	else:
		rpm += (alvo - rpm) * minf(1.0, delta * desce_giro)

func _atualizar_audio() -> void:
	if motor == null or motor.stream == null:
		return
	if not _audio_toquei and not morto and not ganhou:
		motor.play()
		_audio_toquei = true
		Log.passo("veiculo", "motor play frame=%d" % nframe)
	var pitch := 0.42 + minf(rpm / 7800.0, 1.05)
	if sentido != 0.0:
		pitch += 0.06
	if rpm > 6200.0:
		pitch += (rpm - 6200.0) / 1800.0 * 0.18
	motor.pitch_scale = pitch
	var frac := clampf((rpm - 800.0) / 6200.0, 0.0, 1.0)
	var vol := -16.0 + frac * frac * 17.0
	if rpm > 6000.0:
		vol += (rpm - 6000.0) / 1000.0 * 5.5
	motor.volume_db = vol

func _atualizar_anim_marcha(delta: float) -> void:
	if troca_t > 0.0:
		troca_t -= delta
		if troca_t < 0.0:
			troca_t = 0.0
	var alvo := _pos_alavanca("R") if na_re else _pos_alavanca(marcha_atual)
	if troca_t > 0.0:
		var tot := DURACAO_TROCA
		var p := 1.0 - troca_t / tot
		p = clampf(p, 0.0, 1.0)
		var de := _pos_alavanca(troca_de)
		var meio := Vector2.ZERO
		if p < 0.45:
			alavanca = de.lerp(meio, p / 0.45)
		else:
			alavanca = meio.lerp(alvo, (p - 0.45) / 0.55)
	else:
		alavanca = alavanca.lerp(alvo, minf(1.0, delta * 14.0))

func _garantir_attrs() -> void:
	_num("velocidade", 2000.0)
	_txt("cor_carro", "vermelho")
	_txt("motorista", "ryan.png")
	_txt("marcha", "manual")
	_num("marcha_inicial", 1.0)
	classe.set("roda_atras", _cfg_roda("roda_atras"))
	classe.set("roda_frente", _cfg_roda("roda_frente"))

func _log_attrs() -> void:
	Log.passo("veiculo", "attrs vel=%s cor=%s marcha=%s ini=%s motorista=%s atras=%s frente=%s" % [
		classe.get("velocidade"),
		classe.get("cor_carro"),
		classe.get("marcha"),
		classe.get("marcha_inicial"),
		classe.get("motorista"),
		classe.get("roda_atras"),
		classe.get("roda_frente"),
	])

func _num(nome: String, padrao: float) -> float:
	if classe == null:
		return padrao
	var v = classe.get(nome)
	if v == null:
		Log.passo("veiculo", "attr ausente %s=%s" % [nome, padrao])
		classe.set(nome, padrao)
		return padrao
	if v is String and v.is_valid_float():
		return v.to_float()
	if v is float or v is int:
		return float(v)
	Log.erro("veiculo", "attr %s tipo %s valor=%s" % [nome, type_string(typeof(v)), v])
	return padrao

func _txt(nome: String, padrao: String) -> String:
	if classe == null:
		return padrao
	var v = classe.get(nome)
	if v == null:
		classe.set(nome, padrao)
		Log.passo("veiculo", "attr ausente %s=%s" % [nome, padrao])
		return padrao
	return str(v)

func _cfg_roda(nome: String) -> Dictionary:
	var cfg := {"presente": true, "tamanho": 1.0, "distancia": 1.0}
	if classe == null:
		return cfg
	var valor = classe.get(nome)
	if valor is Dictionary:
		if valor.has("presente"):
			cfg["presente"] = bool(valor["presente"])
		for chave in ["tamanho", "distancia"]:
			if not valor.has(chave):
				continue
			var bruto = valor[chave]
			if bruto is float or bruto is int:
				cfg[chave] = float(bruto)
			else:
				Log.erro("veiculo", "%s.%s invalido %s" % [nome, chave, bruto])
		return cfg
	if valor is bool:
		cfg["presente"] = valor
	elif valor != null:
		Log.erro("veiculo", "%s tipo %s" % [nome, type_string(typeof(valor))])
	return cfg

func _irmao(caminho: String):
	if pista == null:
		Log.erro("veiculo", "sem pista para " + caminho)
		return null
	var no = pista.get_node_or_null(caminho)
	if no == null:
		Log.erro("veiculo", "sem irmao " + caminho)
	else:
		Log.passo("veiculo", "no %s" % caminho)
	return no

func _pilha() -> String:
	var s := ""
	for f in get_stack():
		s += " | %s:%s %s" % [f.get("source", ""), f.get("line", ""), f.get("function", "")]
	return s
