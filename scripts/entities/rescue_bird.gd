extends CharacterBody2D

@export_group("Movement")
@export var move_speed: float = 100.0

@export var direction: int = 1
var target_x: float = 0.0
var target_enemy: Node = null

#  Internal State
var is_invincible := false

# Internal Variable
var rescue_fly_time : float = 0.0

# Reference
@onready var animation: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	is_invincible = true
	animation.play("default")
	animation.flip_h = (direction < 0) # Face the right way at spawn


func _physics_process(delta):
	# Move horizontally towards the target_x
	position.x += direction * move_speed * delta

	rescue_fly_time += delta
	var sine_offset = 15.0 * sin(rescue_fly_time * 4.0)
	position.y = target_enemy.global_position.y + sine_offset # Sine wave around enemy's y

	# Check for collision with the target enemy
	if target_enemy and is_instance_valid(target_enemy):
		if abs(global_position.x - target_enemy.global_position.x) < 10:
			# Rescue event: reset enemy to flying
			target_enemy.rescue_from_hatching()
			queue_free()
