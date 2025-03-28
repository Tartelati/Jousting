extends CharacterBody2D

enum State {FLYING, WALKING, EGG, HATCHING, DEAD}

# Properties
var current_state = State.FLYING
var gravity = 600
var flap_force = -250
var move_speed = 100
var walk_speed = 70  # Walking is typically slower than flying
var direction = 1
var egg_fall_speed = 200
var points_value = 100
var walk_time = 0
var max_walk_time = 3.0  # Maximum time to walk before trying to fly again

# References
@onready var enemy_sprite = $EnemySprite
@onready var hatch_timer = $HatchTimer
@onready var combat_area = $CombatArea
@onready var egg_area = $EggArea
@onready var egg_sprite = $EggSprite


func _ready():
	add_to_group("enemies")
	if hatch_timer:
		hatch_timer.connect("timeout", _on_hatch_timer_timeout)

	# Initialize with random direction
	direction = 1 if randf() > 0.5 else -1
	
	# Connect the combat area signal
	if combat_area:
		combat_area.connect("area_entered", _on_combat_area_area_entered)
	
	# Connect egg area signal - changed from body_entered to area_entered
	if egg_area:
		egg_area.connect("area_entered", _on_egg_area_area_entered)
		egg_area.monitoring = false  # Start disabled

func _physics_process(delta):
	# Handle screen wrapping
	screen_wrapping()
	
	match current_state:
		State.FLYING:
			process_flying(delta)
			# Ensure egg area is disabled in flying state
			egg_area.monitoring = false
			# Ensure combat area is enabled in flying state
			combat_area.monitoring = true
		State.WALKING:
			process_walking(delta)
			# Ensure egg area is disabled in walking state
			egg_area.monitoring = false
			# Ensure combat area is enabled in walking state
			combat_area.monitoring = true
		State.EGG:
			process_egg(delta)
			# Ensure combat area is disabled in egg state
			combat_area.monitoring = false
			# Egg area monitoring is handled in process_egg()
		State.HATCHING:
			# Handled by animation and timer
			# Ensure both areas are disabled during hatching
			combat_area.monitoring = false
			egg_area.monitoring = true
		State.DEAD:
			queue_free()

	# Check if landed on a platform while flying
	if current_state == State.FLYING and is_on_floor():
		current_state = State.WALKING
		walk_time = 0
		# Update animation to walking (would use proper animation in full implementation)
		enemy_sprite.modulate = Color(0.8, 1, 0.8)  # Slight green tint when walking
	


func screen_wrapping():
	var viewport_rect = get_viewport_rect().size
	
	# Create a larger buffer for wrapping
	var buffer = 10  # Increased buffer size
	
	# Check if player is about to go off the left edge
	if global_position.x < buffer:
		# Immediately teleport to right side with same velocity
		global_position.x = viewport_rect.x - buffer
		# No need to change velocity, keep momentum
	
	# Check if player is about to go off the right edge
	elif global_position.x > viewport_rect.x - buffer:
	# Immediately teleport to left side with same velocity
		global_position.x = buffer
	# No need to change velocity, keep momentum

func process_flying(delta):
	# Basic AI movement - override in specific enemy types
	# Apply gravity
	velocity.y += gravity * delta

	# Random flapping
	if randf() < 0.02:  # 2% chance per frame to flap
		velocity.y = flap_force

	# Horizontal movement
	velocity.x = direction * move_speed

	# Change direction occasionally
	if randf() < 0.05:  # 0.5% chance per frame
		direction *= -1
		enemy_sprite.flip_h = (direction < 0)

	move_and_slide()

func process_walking(delta):
	# Walking behavior
	walk_time += delta

	# Apply gravity to keep on ground
	velocity.y = 5  # Small downward force to stay on platform

	# Horizontal movement
	velocity.x = direction * walk_speed

	# Screen wrapping
	var viewport_size = get_viewport_rect().size

	# Change direction if at edge of platform or randomly
	if !check_ground_ahead() || randf() < 0.01:  # 1% chance per frame to change direction
		direction *= -1
		enemy_sprite.flip_h = (direction < 0)

	# After walking for some time, try to fly again
	if walk_time > max_walk_time || randf() < 0.01:  # Random chance to start flying
		current_state = State.FLYING
		velocity.y = flap_force  # Initial flap to get airborne
		# Update animation to flying (would use proper animation in full implementation)
		enemy_sprite.modulate = Color(1, 1, 1)  # Reset color

	move_and_slide()

	# If we're not on floor anymore (walked off edge), switch to flying
	if !is_on_floor():
		current_state = State.FLYING
		# Update animation to flying
		enemy_sprite.modulate = Color(1, 1, 1)  # Reset color

func check_ground_ahead():
	# Cast a ray downward from slightly ahead of the enemy to check if there's ground
	var ray_cast = RayCast2D.new()
	add_child(ray_cast)
	ray_cast.position = Vector2(direction * 20, 0)  # Check 20 pixels ahead
	ray_cast.target_position = Vector2(0, 30)  # Check 30 pixels down
	ray_cast.force_raycast_update()
	var has_ground = ray_cast.is_colliding()
	ray_cast.queue_free()
	return has_ground

func _on_combat_area_area_entered(area):
	if current_state != State.FLYING and current_state != State.WALKING:
		return
	
	if area.get_parent().is_in_group("players"):
		var player = area.get_parent()
		
		# Get the collision shapes for more precise position comparison
		var enemy_top = 0
		var collision_shape = get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape:
			if collision_shape.shape is CircleShape2D:
				enemy_top = global_position.y - collision_shape.shape.radius
			elif collision_shape.shape is CapsuleShape2D or collision_shape.shape is RectangleShape2D:
				enemy_top = global_position.y - collision_shape.shape.height/2
			else:
				#fallback for other shape types
				enemy_top = global_position.y - 10 #use of default value here
				
		var player_bottom = player.global_position.y + player.get_node("CollisionShape2D").shape.height/2

		# Compare Y positions to determine winner
		if player_bottom < enemy_top +10: # Add small threshold
			#player wins
			defeat()
		else:
			#enemy wins or bounce handled by player script
			pass
	elif area.get_parent().is_in_group("enemies"):
		# Enemy-enemy collision
		var other_enemy = area.get_parent()
		# simple bounce behaviour for enemy-enemy collisions
		var direction = sign(global_position.x - other_enemy.global_position.x)
		velocity.x = direction * 100
		velocity.y = -50

func process_egg(delta):
	velocity.y = egg_fall_speed
	velocity.x = 0
	move_and_slide()

	# Check if landed on platform
	if is_on_floor():
		hatch_timer.start()
		current_state = State.HATCHING
		egg_sprite.modulate = Color(1, 1, 0.8)  # Slight yellow tint when hatching
		
	# Enable Egg Collection when in Egg state
	egg_area.monitoring = true
	egg_area.monitorable = true

	for area in egg_area.get_overlapping_areas():
		if area.name == "Collection Area" and area.get_parent().is_in_group("players"):
			print("Manual overlap detection: Egg collected")
			collect_egg()
			break

# New function for area-based egg collection
func _on_egg_area_area_entered(area):
	# Add debug print to see if this function is being called
	print("Area entered egg area: ", area.name)
	
	# Check if the area is the player's Collection Area
	if (current_state == State.EGG or current_state == State.HATCHING) and area.get_parent().is_in_group("players"):
		print("Egg collected by player's collection area!")
		collect_egg()

func defeat():
	current_state = State.EGG
	
	enemy_sprite.visible = false
	egg_sprite.visible = true
	# Change sprite to egg (would use animation in full implementation)

	# Disable combat area
	combat_area.monitoring = false
	combat_area.monitorable = false
	
	# Enable egg area for collection
	egg_area.monitoring = true
	egg_area.monitorable = true
	
	# Change collision layers for the main body
	set_collision_layer_value(3, false) # Turn off enemy layer
	set_collision_layer_value(4, true) # Turn on egg layer
	set_collision_mask_value(1, false) # Don't collide with player
	set_collision_mask_value(2, true) # Do collide with environment.
	
	
	# Signal to score manager to add points
	get_node("/root/ScoreManager").add_score(points_value)
	
	# print debug message
	print("Enemy defeated")

func collect_egg():
	current_state = State.DEAD
	
	# Disable both areas
	combat_area.monitoring = false
	egg_area.monitoring = false
	
	# Add more points for collecting egg
	get_node("/root/ScoreManager").add_score(points_value / 2)
	
	# Play collection sound if available
	if has_node("CollectionSound"):
		$CollectionSound.play()
		# Wait for sound to finish before removing
		await $CollectionSound.finished
	   
	queue_free()


func _on_hatch_timer_timeout():
	current_state = State.FLYING
	enemy_sprite.modulate = Color(1, 1, 1)  # Reset color
	# Change sprite back to enemy
	enemy_sprite.visible = true
	egg_sprite.visible = false
	
	# Reset collision layers
	set_collision_layer_value(3, true) # Turn on enemy layer
	set_collision_layer_value(4, false) # Turn off egg layer
	set_collision_mask_value(1, true) # Collide with player again
