
extends RefCounted
class_name BoxingAI

var boxer: BoxerBase

# Personalidad del personaje: valores entre 0 y 100.
var aggression: float = 60.0
var defense: float = 35.0
var special_chance: float = 25.0
var attack_variety: float = 65.0

# Distancia preferida y alcance para decidir cuándo atacar.
var preferred_distance: float = 85.0
var attack_range: float = 105.0

# Temporizadores para evitar decisiones y ataques constantes.
var decision_interval: float = 0.25
var reaction_timer: float = 0.0
var attack_cooldown: float = 0.0


func _init(owner: BoxerBase) -> void:
	boxer = owner


func update_ai(delta: float) -> void:
	if not is_instance_valid(boxer):
		return

	if boxer.is_out:
		boxer.velocity.x = 0.0
		boxer.guarding = false
		boxer.crouching = false
		return

	if boxer.is_attacking or boxer.is_receiving_hit:
		boxer.guarding = false
		boxer.crouching = false
		return

	if not is_instance_valid(boxer.opponent):
		boxer.velocity.x = 0.0
		return

	if boxer.opponent.is_out:
		boxer.velocity.x = 0.0
		boxer.guarding = false
		return

	reaction_timer = maxf(0.0, reaction_timer - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)

	var distance_x: float = absf(
		boxer.opponent.global_position.x - boxer.global_position.x
	)

	var opponent_attacking: bool = boxer.opponent.is_attacking
	var opponent_guarding: bool = boxer.opponent.guarding

	boxer.guarding = false
	boxer.crouching = false

	# Defenderse si el rival está atacando.
	if opponent_attacking and randf() * 100.0 < defense:
		boxer.velocity.x = 0.0
		boxer.guarding = true
		return

	# Acercarse si el rival está lejos.
	if distance_x > attack_range:
		boxer.velocity.x = _facing_direction() * boxer.move_speed
		return

	# Acercarse con más cuidado si está fuera de la distancia preferida.
	if distance_x > preferred_distance + 25.0:
		boxer.velocity.x = (
			_facing_direction() * boxer.move_speed * 0.65
		)
		return

	# Intentar crear espacio si el rival está demasiado cerca.
	if distance_x < preferred_distance * 0.45:
		if randf() * 100.0 < defense:
			boxer.velocity.x = (
				-_facing_direction() * boxer.move_speed * 0.5
			)
			return

	# Detenerse para decidir si ataca.
	boxer.velocity.x = 0.0

	if reaction_timer > 0.0 or attack_cooldown > 0.0:
		return

	reaction_timer = decision_interval

	# Si el rival bloquea, variar la estrategia.
	if opponent_guarding and randf() * 100.0 < 65.0:
		if randf() * 100.0 < defense:
			boxer.guarding = true
			return

	# Intentar usar la habilidad especial.
	if randf() * 100.0 < special_chance:
		if _try_attack(&"special"):
			return

	# A corta distancia, intentar un jab agachado.
	if distance_x < preferred_distance * 0.65:
		if randf() * 100.0 < attack_variety:
			if _try_attack(&"crouch_jab"):
				return

		if _try_attack(&"jab"):
			return

	# Variar los ataques cuando el rival está a distancia.
	if randf() * 100.0 < attack_variety:
		if _try_attack(&"kick"):
			return

	# Los personajes más agresivos intentan golpes fuertes.
	if randf() * 100.0 < aggression:
		if _try_attack(&"heavy"):
			return

	# Ataque básico como última opción.
	_try_attack(&"jab")


func _facing_direction() -> float:
	if not is_instance_valid(boxer.opponent):
		return 0.0

	if boxer.opponent.global_position.x > boxer.global_position.x:
		return 1.0

	return -1.0


func _try_attack(attack_type: StringName) -> bool:
	if not is_instance_valid(boxer):
		return false

	var animation_name: StringName

	match attack_type:
		&"jab":
			animation_name = boxer.ANIM_JAB

		&"crouch_jab":
			animation_name = boxer.ANIM_CROUCH_JAB

		&"heavy":
			animation_name = boxer.ANIM_HEAVY_ATTACK

		&"kick":
			animation_name = boxer.ANIM_KICK

		&"special":
			animation_name = boxer.ANIM_SPECIAL

		_:
			return false

	# Comprobar que exista la animación.
	if not boxer.animated_sprite.sprite_frames:
		return false

	if not boxer.animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		return false

	# Solicitar al BoxerBase que ejecute el ataque.
	if not boxer.try_start_attack(animation_name):
		return false

	# Pausa breve entre ataques.
	attack_cooldown = randf_range(0.45, 0.9)
	return true
