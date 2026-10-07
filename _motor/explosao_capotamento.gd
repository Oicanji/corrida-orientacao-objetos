extends Node2D

const DURACAO := 2.1
const INICIO_ANIM := 0.08

@export var tamanho_painel: Vector2 = Vector2(520, 520)

@onready var _painel: ColorRect = $Painel
@onready var _animador: AnimationPlayer = $AnimationPlayer

var _ativa := false
var _material: ShaderMaterial
var _tween: Tween

func _ready() -> void:
	_preparar_painel()
	if _painel != null and _painel.material is ShaderMaterial:
		_material = (_painel.material as ShaderMaterial).duplicate()
		_painel.material = _material
		_aplicar_boom(-1.0)
	if _animador:
		_animador.animation_finished.connect(_ao_terminar_animacao)
	if not Engine.is_editor_hint():
		visible = false

func _preparar_painel() -> void:
	if _painel == null:
		return
	_painel.custom_minimum_size = tamanho_painel
	_painel.size = tamanho_painel
	_painel.color = Color.WHITE

func _aplicar_boom(valor: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("boom_anim", valor)
	_material.set_shader_parameter("panel_size", tamanho_painel)

func disparar(posicao_mundo: Vector2) -> void:
	if _ativa or _painel == null:
		return
	_ativa = true
	_preparar_painel()
	global_position = posicao_mundo
	_painel.position = -_painel.size * 0.5
	_painel.show()
	visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_aplicar_boom(INICIO_ANIM)
	if Engine.is_editor_hint() and _animador != null:
		_animador.stop(true)
		_animador.play(&"explodir")
		return
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_aplicar_boom, INICIO_ANIM, DURACAO, DURACAO)
	_tween.tween_callback(_finalizar)

func _finalizar() -> void:
	visible = false
	if _painel:
		_painel.hide()
	_aplicar_boom(-1.0)

func _ao_terminar_animacao(nome: StringName) -> void:
	if not Engine.is_editor_hint() or nome != &"explodir":
		return
	_finalizar()
