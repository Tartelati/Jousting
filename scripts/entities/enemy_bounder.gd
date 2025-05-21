extends "res://scripts/entities/enemy_base.gd"

var sprite_path = "res://assets/sprites/enemy_bounder-placeholder.png"

func _ready():
	super._ready()
	points_value = 100
	move_speed = 80
	
	# Set sprite color to distinguish enemy type
	enemy_sprite.texture = load(sprite_path)  # Use the loaded texture on the existing sprite
	
# Override the flying process for this specific enemy type
func process_flying(delta):
	screen_wrapping()
	
	# Bounder just bounces around randomly
	# Apply gravity
	velocity.y += gravity * delta
	
	# Random flapping
	if randf() < 0.03:  # 3% chance per frame to flap
		velocity.y = flap_force
	
	# Horizontal movement
	velocity.x = direction * move_speed
	
	move_and_slide()
