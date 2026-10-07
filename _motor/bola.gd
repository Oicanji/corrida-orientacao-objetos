extends RigidBody2D

func configurar(raio: float, tex: Texture2D, cor: Color) -> void:
	Log.passo("bola", "raio=%.1f pos=%s" % [raio, position], false)
	mass = 0.45 + raio / 70.0
	var forma := CircleShape2D.new()
	forma.radius = raio
	$CollisionShape2D.shape = forma
	var sprite := $Sprite2D as Sprite2D
	sprite.texture = tex
	var escala := raio * 2.0 / 128.0
	sprite.scale = Vector2(escala, escala)
	sprite.modulate = cor
	var mat := PhysicsMaterial.new()
	mat.friction = 0.45
	mat.bounce = 0.38
	physics_material_override = mat
