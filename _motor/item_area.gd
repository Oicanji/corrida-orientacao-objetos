extends Area2D

func configurar(raio: float, tex: Texture2D, cor: Color, escala: float) -> void:
	Log.passo("item", "%s raio=%.1f pos=%s" % [name, raio, position])
	var forma := CircleShape2D.new()
	forma.radius = raio
	$CollisionShape2D.shape = forma
	var sprite := $Sprite2D as Sprite2D
	sprite.texture = tex
	sprite.scale = Vector2(escala, escala)
	sprite.modulate = cor
