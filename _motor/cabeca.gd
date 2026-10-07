extends Node2D

var base := 0.1
var cang := 0.0
var cvang := 0.0
var cx := 0.0
var cy := 0.0
var cvx := 0.0
var cvy := 0.0
var prev_vx := 0.0
var prev_vy := 0.0
var pescoco := Vector2(-38.0, -48.0)

func _ready() -> void:
	Log.passo("cabeca", "_ready pai=%s" % (get_parent().name if get_parent() else "nenhum"))
	position = pescoco
	rotation = 0.0

func aplicar_textura(tex: Texture2D, px: int) -> void:
	Log.passo("cabeca", "tex=%s px=%d" % [tex.resource_path if tex else "null", px])
	if tex == null:
		Log.erro("cabeca", "textura nula")
		return
	$Sprite2D.texture = tex
	base = 0.1 if px < 8 else Corrida.CABECA_PX / float(px)
	$Sprite2D.scale = Vector2(base, base)
	Log.passo("cabeca", "escala=%.3f" % base)

func atualizar(delta: float, velocidade: float) -> void:
	Log.fase("cabeca.atualizar")
	var corpo := get_parent() as RigidBody2D
	if corpo == null:
		Log.erro("cabeca", "pai nao e RigidBody2D")
		return
	if delta < 0.0001:
		delta = 0.0167
	if velocidade > Corrida.VEL_JUNTA_RIGIDA:
		cang = 0.0
		cvang = 0.0
		cx = 0.0
		cy = 0.0
		cvx = 0.0
		cvy = 0.0
		var vel := corpo.linear_velocity
		prev_vx = vel.x
		prev_vy = vel.y
		position = pescoco
		rotation = 0.0
		$Sprite2D.scale = Vector2(base, base)
		return
	var vel2 := corpo.linear_velocity
	var ax := (vel2.x - prev_vx) / delta
	var ay := (vel2.y - prev_vy) / delta
	prev_vx = vel2.x
	prev_vy = vel2.y
	var ang_v := corpo.angular_velocity
	var tempo := 0.0
	var tempo_bruto = corpo.get("tempo_vivo")
	if tempo_bruto != null:
		tempo = float(tempo_bruto)
	cvang += -ang_v * 16.0 * delta
	cvang += -ax * 0.028 * delta
	cvang += sin(tempo * 11.0) * 2.2 * delta
	cvang += -cang * 10.0 * delta
	cvang *= pow(0.93, delta * 60.0)
	cang += cvang * delta
	if cang > 1.25:
		cang = 1.25
		cvang *= -0.45
	if cang < -1.25:
		cang = -1.25
		cvang *= -0.45
	cvx += (-ax * 0.022 - cx * 11.0) * delta
	cvy += (-ay * 0.02 - cy * 11.0) * delta
	cvx *= pow(0.97, delta * 60.0)
	cvy *= pow(0.97, delta * 60.0)
	cx += cvx * delta
	cy += cvy * delta
	cx = clampf(cx, -22.0, 22.0)
	cy = clampf(cy, -18.0, 18.0)
	position = Vector2(pescoco.x + cx, pescoco.y + cy)
	rotation = cang
	var squash := clampf(-ay * 0.00018, -0.22, 0.22)
	$Sprite2D.scale = Vector2(base * (1.0 - squash * 0.6), base * (1.0 + squash))

func tocou_chao(terreno) -> bool:
	Log.fase("cabeca.chao")
	var origin := global_position
	var ang := global_rotation
	var c := cos(ang)
	var s := sin(ang)
	var pontos: Array[Vector2] = [
		Vector2(0.0, -28.0),
		Vector2(0.0, -52.0),
		Vector2(18.0, -40.0),
		Vector2(-18.0, -40.0),
		Vector2(0.0, -70.0),
	]
	for ponto in pontos:
		var wx: float = origin.x + ponto.x * c - ponto.y * s
		var wy: float = origin.y + ponto.x * s + ponto.y * c
		var chao: float = terreno.altura(wx)
		if wy >= chao - 14.0:
			Log.passo("cabeca", "toca chao wx=%.1f wy=%.1f chao=%.1f" % [wx, wy, chao])
			return true
	return false
