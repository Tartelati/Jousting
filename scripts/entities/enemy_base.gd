extends CharacterBody2D

enum State {FLYING, WALKING, EGG, HATCHING, DEAD}

@export_group("Movement")
@export var gravity: float = 600.0
@export var flap_force: float = -250.0
@export var move_speed: float = 100.0
@export var walk_speed: float = 70.0
@export var max_walk_time: float = 3.0  # Max time walking before trying to fly
@export var egg_fall_speed: float = 200.0

@export_group("AI Behavior")
@export var random_flap_chance: float = 0.02 # Chance per physics frame (flying)
@export var random_dir_change_chance_flying: float = 0.005 # Chance per physics frame
@export var random_dir_change_chance_walking: float = 0.01 # Chance per physics frame
@export var random_fly_chance_walking: float = 0.01 # Chance per physics frame

@export_group("Collision & Interaction")
@export var points_value: int = 100
@export var collision_y_threshold: float = 10.0 # Threshold for player joust check
@export var enemy_bounce_velocity_x: float = 100.0
@export var enemy_bounce_velocity_y: float = -50.0

@export_group("Ground Check (Walking)")
@export var ground_check_distance_ahead: float = 20.0
@export var ground_check_distance_down: float = 30.0

# Internal State
var current_state = State.FLYING
var direction = 1
var walk_time = 0.0

# References
#@onready var enemy_sprite = $EnemySprite
@onready var hatch_timer = $HatchTimer
@onready var combat_area = $CombatArea # Main body collision
@onready var egg_area = $EggArea # For player collecting egg
@onready var egg_sprite = $EggSprite
@onready var vulnerable_area = $VulnerableArea # For player stomping enemy
@onready var enemy_animation: AnimatedSprite2D = $AnimatedSprite2D
var ground_raycast: RayCast2D # Declare variable for the raycast
var is_spawning := true

func _ready():
	add_to_group("enemies")
	
	# Create and configure the ground check raycast once
	ground_raycast = RayCast2D.new()
	add_child(ground_raycast) # Add it as a child node
	ground_raycast.target_position = Vector2(0, ground_check_distance_down)
	ground_raycast.enabled = true # Ensure it's enabled
	
	enemy_animation.play("Enemy_spawn")
	enemy_animation.connect("animation_finished", Callable(self, "_on_enemy_animation_finished"))
	
	if hatch_timer:
		hatch_timer.connect("timeout", _on_hatch_timer_timeout)

	# Initialize with random direction
	direction = 1 if randf() > 0.5 else -1
	
	# Add areas to groups and connect signals
	if combat_area:
		combat_area.add_to_group("enemy_combat_areas") # Add area to group
		# Connect in editor OR uncomment below, not both. Commenting out to fix error.
		# combat_area.connect("area_entered", _on_combat_area_area_entered) 
		
	if vulnerable_area:
		vulnerable_area.add_to_group("enemy_vulnerable_areas") # Add area to group
		# IMPORTANT: Ensure this signal is connected in the Godot Editor.
		# Connecting via code is commented out to avoid double connection error.
		# vulnerable_area.connect("area_entered", _on_vulnerable_area_area_entered)
	
	# Connect egg area signal and add it to group
	if egg_area:
		egg_area.add_to_group("egg_collection_zones") # Add area to group
		egg_area.connect("area_entered", _on_egg_area_area_entered)
		egg_area.set_deferred("monitoring", false)  # Start disabled

func _on_enemy_animation_finished(anim_name):
	if anim_name == "Enemy_spawn":
		is_spawning = false

func _physics_process(delta):
	# Handle screen wrapping
	screen_wrapping()
	
	if is_spawning:
		velocity = Vector2.ZERO
		return
	
	match current_state:
		State.FLYING:
			process_flying(delta)
			# Ensure egg area is disabled in flying state
			if egg_area: egg_area.monitoring = false
			# Ensure combat area is enabled in flying state
			if combat_area: combat_area.monitoring = true
		State.WALKING:
			process_walking(delta)
			# Ensure egg area is disabled in walking state
			if egg_area: egg_area.monitoring = false
			# Ensure combat area is enabled in walking state
			if combat_area: combat_area.monitoring = true
		State.EGG:
			process_egg(delta)
			# Ensure combat area is disabled in egg state
			if combat_area: combat_area.monitoring = false
			# Egg area monitoring is handled in process_egg()
		State.HATCHING:
			# Handled by animation and timer
			# Ensure both areas are disabled during hatching
			if combat_area: combat_area.monitoring = false
			if egg_area: egg_area.monitoring = true # Should be monitorable to be collected
		State.DEAD:
			queue_free()

	# --- Add Fall Guardrail ---
	# Check if enemy fell off the screen
	var viewport_height = get_viewport_rect().size.y
	var death_y_threshold = viewport_height + 50 # Kill if 50 pixels below screen bottom
	
	if global_position.y > death_y_threshold and current_state != State.DEAD:
		print("Enemy %s fell off screen. Removing." % name) # Optional debug
		queue_free() # Remove the enemy


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
	if randf() < random_flap_chance:
		velocity.y = flap_force

	# Horizontal movement
	velocity.x = direction * move_speed

	# Change direction occasionally
	if randf() < random_dir_change_chance_flying:
		direction *= -1
		if enemy_animation: enemy_animation.flip_h = (direction < 0)
		
	var just_hit_floor = false
	var vertical_velocity_before_move = velocity.y # Store velocity before move_and_slide

	move_and_slide()
	
	# Check for collision with floor (platform) after moving
	if is_on_floor() and vertical_velocity_before_move > 0: # Check if moving downwards when hitting floor
		# Apply a small upward bounce immediately
		velocity.y = enemy_bounce_velocity_y 
		just_hit_floor = true # Flag that we bounced

	# Transition to walking state only if we actually landed and didn't just bounce
	if is_on_floor() and not just_hit_floor and current_state == State.FLYING: # Added check for FLYING state
		current_state = State.WALKING
		walk_time = 0
		if enemy_animation: 
			enemy_animation.play("Enemy_base_walk")


func process_walking(delta):
	# Walking behavior
	walk_time += delta

	# Apply gravity to keep on ground
	velocity.y = 5  # Small downward force to stay on platform

	# Horizontal movement
	if direction < 0:
		if enemy_animation: enemy_animation.flip_h = true
		
	velocity.x = direction * walk_speed
	
	
	# Handle screen wrapping
	screen_wrapping()

	# After walking for some time, try to fly again
	if walk_time > max_walk_time || randf() < random_fly_chance_walking:
		current_state = State.FLYING
		velocity.y = flap_force  # Initial flap to get airborne
		# Update animation to flying (would use proper animation in full implementation)
		if enemy_animation: 
			enemy_animation.play("Enemy_base_fly")

	move_and_slide()

	# If we're not on floor anymore (walked off edge), switch to flying
	if not is_on_floor():
		current_state = State.FLYING
		# Update animation to flying
		if enemy_animation: 
			enemy_animation.play("Enemy_base_fly")

func check_ground_ahead():
	# Use the pre-configured raycast
	if not is_instance_valid(ground_raycast): return false # Safety check
	ground_raycast.position.x = direction * ground_check_distance_ahead # Update position based on direction
	ground_raycast.force_raycast_update() # Force update for immediate result
	return ground_raycast.is_colliding()

func _on_combat_area_area_entered(area):
	# This function now primarily handles enemy-vs-enemy collisions.
	# Player interactions (stomp, side collision, player death) are mostly handled
	# by the player script (_on_combat_area_area_entered, _on_stomp_area_area_entered)
	# and this enemy's _on_vulnerable_area_area_entered.
	
	if current_state != State.FLYING and current_state != State.WALKING:
		return # Only handle collisions when active
		
	# Check if colliding with another enemy's combat area
	if area.is_in_group("enemy_combat_areas"):
		var other_enemy = area.get_parent()
		if not other_enemy or other_enemy == self or not other_enemy.is_in_group("enemies"):
			return # Ignore self-collision or non-enemy parents
			
		# If both enemies are walking, just change directions
		if current_state == State.WALKING and "current_state" in other_enemy and other_enemy.current_state == State.WALKING:
			direction *= -1
			if enemy_animation: enemy_animation.flip_h = (direction < 0)
		else:
			# For flying enemies, use the bounce behavior
			var bounce_direction = sign(global_position.x - other_enemy.global_position.x)
			if bounce_direction == 0: bounce_direction = 1 # Avoid zero direction
			velocity.x = bounce_direction * enemy_bounce_velocity_x
			velocity.y = enemy_bounce_velocity_y

func process_egg(delta):
	velocity.y = egg_fall_speed
	velocity.x = 0
	move_and_slide()

	# Check if landed on platform and is stationary
	if is_on_floor() and abs(velocity.y) < 1.0:
		if hatch_timer and not hatch_timer.is_stopped(): # Check if timer exists and not already started
			hatch_timer.start()
		current_state = State.HATCHING
		if egg_sprite: egg_sprite.modulate = Color(1, 1, 0.8)  # Slight yellow tint when hatching
		
	# Enable Egg Collection when in Egg state
	if egg_area: 
		egg_area.monitoring = true
		egg_area.monitorable = true
		vulnerable_area.monitoring = false

	# Manual overlap check might be redundant if signal connection works, but keep for now
	# for area in egg_area.get_overlapping_areas():
	#	 if area.name == "Collection Area" and area.get_parent().is_in_group("players"):
	#		 print("Manual overlap detection: Egg collected")
	#		 collect_egg()
	#		 break

# New function for area-based egg collection
func _on_egg_area_area_entered(player_index: int, area):
	# Add debug print to see if this function is being called
	# print("Area entered egg area: ", area.name) # Can be noisy
	
	# Check if the entering area is the player's Collection Area (which should be in the "player_collectors" group)
	if (current_state == State.EGG or current_state == State.HATCHING) and area.is_in_group("player_collectors"):
		print("Egg collected by player's collection area!")
		collect_egg(player_index)

func defeat(player_index: int, award_score := true):
	if current_state == State.EGG or current_state == State.HATCHING or current_state == State.DEAD:
		return # Already defeated or dead

	current_state = State.EGG
	
	if enemy_animation: enemy_animation.visible = false
	if egg_sprite: egg_sprite.visible = true
	# Change sprite to egg (would use animation in full implementation)

	# Disable combat area
	if combat_area:
		combat_area.monitoring = false
		combat_area.monitorable = false
	
	# Enable egg area for collection
	if egg_area:
		egg_area.monitoring = true
		egg_area.monitorable = true
	
	# Change collision layers for the main body
	set_collision_layer_value(3, false) # Turn off enemy layer
	set_collision_layer_value(4, true) # Turn on egg layer
	set_collision_mask_value(1, false) # Don't collide with player
	set_collision_mask_value(2, true) # Do collide with environment.
	
	
	# Signal to score manager to add points
	if award_score:
		ScoreManager.add_score(player_index, points_value)
	
	# print debug message
	print("Enemy %s defeated" % name)

func collect_egg(player_index):
	if current_state == State.DEAD: return # Already collected/dead
	current_state = State.DEAD
	
	# Disable both areas
	if combat_area: combat_area.monitoring = false
	if egg_area: egg_area.monitoring = false
	
	# Add more points for collecting egg
	ScoreManager.add_score(player_index, points_value / 2) # Use ScoreManager directly
	
	# Play collection sound if available
	if has_node("CollectionSound"):
		$CollectionSound.play()
		# Wait for sound to finish before removing
		await $CollectionSound.finished
	   
	queue_free()

func _on_vulnerable_area_area_entered(player_index: int, area):
	# Handles being stomped by the player.
	# Check if the entering area is the player's stomp area
	if area.is_in_group("player_stomp_areas"):
		# Check if the parent is actually the player
		print("STOMP!!")
		var player = area.get_parent()
		if player and player.is_in_group("players"):
			# Player successfully stomped this enemy
			defeat(player_index) # Call the existing defeat logic
			player.velocity.y = player.joust_bounce_velocity

func _on_hatch_timer_timeout():
	if current_state != State.HATCHING: return # Only hatch if in hatching state

	current_state = State.FLYING
	if enemy_animation: 
		enemy_animation.play("Enemy_spawn")
		enemy_animation.visible = true
	if egg_sprite: 
		egg_sprite.visible = false
	
	# Reset collision layers
	set_collision_layer_value(3, true) # Turn on enemy layer
	set_collision_layer_value(4, false) # Turn off egg layer
	set_collision_mask_value(1, true) # Collide with player again
	set_collision_mask_value(2, true) # Ensure it collides with environment

	# Re-enable combat area, disable egg area
	if combat_area: combat_area.monitoring = true
	if egg_area: egg_area.monitoring = false
	
	print("Enemy %s hatched" % name)

# Called by Player script during side collisions
func handle_bounce(bounce_direction, bounce_vel_x, bounce_vel_y):
	"""Handles being bounced by the player or another object."""
	if current_state == State.EGG or current_state == State.HATCHING or current_state == State.DEAD:
		return # Don't bounce if in these states

	print("Enemy %s received bounce command. Direction: %s" % [name, bounce_direction]) # Debug

	# Apply vertical bounce velocity immediately
	velocity.y = bounce_vel_y

	# Apply horizontal bounce velocity (using enemy's own bounce value for consistency?)
	# Or use the player's passed value? Let's use the enemy's value for now.
	velocity.x = bounce_direction * enemy_bounce_velocity_x

	# Reverse internal direction variable
	direction = bounce_direction # Set direction based on bounce
	if enemy_animation:
		enemy_animation.flip_h = (direction < 0)

	# IMPORTANT: Do NOT change move_speed or walk_speed here.
	# The velocity change handles the immediate bounce effect.
	# The base speed for subsequent movement remains the same.
