extends CanvasLayer

@export_range(0.0, 24.0, 0.05) var hour: float = 10.0

@onready var _painel: ColorRect = $Painel

var _material: ShaderMaterial

func _ready() -> void:
	_garantir_material()

func ativar() -> void:
	_garantir_material()
	visible = true
	if _painel:
		_painel.show()
		_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_painel.offset_left = 0.0
		_painel.offset_top = 0.0
		_painel.offset_right = 0.0
		_painel.offset_bottom = 0.0
	_aplicar_hora()

func _garantir_material() -> void:
	if _material != null or _painel == null:
		return
	if _painel.material is ShaderMaterial:
		_material = (_painel.material as ShaderMaterial).duplicate()
		_painel.material = _material
		_painel.color = Color.WHITE

func _process(delta: float) -> void:
	if not visible or Engine.is_editor_hint():
		return
	hour = fmod(hour + delta * (24.0 / Corrida.CICLO_CEU_SEG), 24.0)
	_aplicar_hora()

func _aplicar_hora() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("hour", hour)
