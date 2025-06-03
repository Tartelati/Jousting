extends "res://scripts/entities/enemy_base.gd"

var target = null


func _ready():
	super._ready()
	points_value = 200
	move_speed = 100
	

# Override the flying process for this specific enemy type
func process_flying(delta):
	enemy_animation.play("fly")
	screen_wrapping()
	
	# Hunter actively seeks the player
	# Find target if none
	if target == null:
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 0:
			target = players[0]  # Target first player
	
	# Apply gravity
	velocity.y += gravity * delta
	 
	# Flap to maintain height and chase player
	if target != null and is_instance_valid(target):
		# Flap more when below the player
		if position.y > target.position.y + 50:
			if randf() < 0.1:  # 10% chance per frame to flap
				velocity.y = flap_force
		
		# Move toward player
		if target.position.x < position.x - 20:
			direction = -1
		elif target.position.x > position.x + 20:
			direction = 1
			enemy_animation.flip_h = (direction < 0)
	else:
		# Random flapping if no target
		if randf() < 0.03:
			velocity.y = flap_force
		# Random direction changes
		if randf() < 0.01:
			direction *= -1
			enemy_animation.flip_h = (direction < 0)
	
	# Horizontal movement
	velocity.x = direction * move_speed
	
	# Check if landed on a platform while flying
	if current_state == State.FLYING and is_on_floor():
		current_state = State.WALKING
		walk_time = 0

	
	move_and_slide()
