extends "res://scripts/entities/enemy_base.gd"

func _ready():
	super._ready()
	points_value = 100
	move_speed = 80
	
	# Set sprite color to distinguish enemy type
	enemy_sprite.modulate = Color(1, 0.5, 0.5)  # Red tint

# Override the flying process for this specific enemy type
func process_flying(delta):
	# Bounder just bounces around randomly
	# Apply gravity
	velocity.y += gravity * delta
	
	# Random flapping
	if randf() < 0.03:  # 3% chance per frame to flap
		velocity.y = flap_force
	
	# Horizontal movement
	velocity.x = direction * move_speed
	
	# Screen wrapping
	var viewport_size = get_viewport_rect().size
	if position.x < 0:
		position.x = viewport_size.x
	elif position.x > viewport_size.x:
		position.x = 0
	
	# Change direction occasionally
	if randf() < 0.01:  # 1% chance per frame
		direction *= -1
		enemy_sprite.flip_h = (direction < 0)
	
	move_and_slide()
