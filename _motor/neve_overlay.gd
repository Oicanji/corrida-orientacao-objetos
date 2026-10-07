extends CanvasLayer

@onready var _painel: ColorRect = $Painel

var _material: ShaderMaterial

func _ready() -> void:
	if _painel != null and _painel.material is ShaderMaterial:
		_material = (_painel.material as ShaderMaterial).duplicate()
		_painel.material = _material
		_painel.color = Color.WHITE
	visible = false

func definir_visivel(ativo: bool, alpha: float = 1.0) -> void:
	visible = ativo
	if _painel:
		_painel.modulate = Color(1, 1, 1, alpha)

func atualizar_dimensoes(tamanho: Vector2) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("dimensions", tamanho)
