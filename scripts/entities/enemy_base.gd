extends CharacterBody2D

enum State {FLYING, WALKING, EGG, HATCHING, DEAD}

@export_group("Movement")
@export var gravity: float = 600.0
@export var flap_force: float = -250.0
@export var move_speed: float = 100.0
@export var walk_speed: float = 100.0
@export var max_walk_time: float = 3.0  # Max time walking before trying to fly
@export var egg_fall_speed: float = 200.0

@export_group("Egg Physics")
@export var egg_bounce_damping: float = 0.7  # How much velocity is retained after bounce (0.0 = no bounce, 1.0 = perfect bounce)
@export var egg_horizontal_damping: float = 0.8  # Horizontal velocity damping on ground bounce
@export var egg_min_bounce_velocity: float = 50.0  # Minimum velocity needed to bounce
@export var egg_settling_threshold: float = 10.0  # Velocity below which egg stops bouncing
@export var air_catch_bonus_multiplier: float = 2.0  # Bonus multiplier for air catches

@export_group("AI Behavior")
@export var random_flap_chance: float = 0.02 # Chance per physics frame (flying)
@export var random_dir_change_chance_flying: float = 0.005 # Chance per physics frame
@export var random_dir_change_chance_walking: float = 0.01 # Chance per physics frame
@export var random_fly_chance_walking: float = 0.01 # Chance per physics frame
@export var min_fly_height: float = 218.0  # ← NEW: Minimum Y position for flying (above lava)

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
var is_invincible := false
var previous_state = null
var direction = 1
var walk_time = 0.0

# NEW: Egg state variables
var egg_has_touched_ground := false  # Track if egg has hit ground (for bonus)
var egg_is_bouncing := false  # Track if egg is currently bouncing
var egg_bounce_count := 0  # Track number of bounces

# References
@onready var hatch_timer = $HatchTimer
@onready var combat_area = $CombatArea # Main body collision
@onready var egg_area = $EggArea # For player collecting egg
@onready var egg_sprite = $EggSprite
@onready var vulnerable_area = $VulnerableArea # For player stomping enemy
@onready var stomp_area = $StompArea
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
	
	is_invincible = true
	enemy_animation.play("spawn")
	enemy_animation.connect("animation_finished", Callable(self, "_on_enemy_animation_finished"))
	
	if hatch_timer:
		hatch_timer.connect("timeout", _on_hatch_timer_timeout)

	# Initialize with random direction
	direction = 1 if randf() > 0.5 else -1
	
	# Add areas to groups and connect signals
	if combat_area:
		combat_area.add_to_group("enemy_combat_areas") # Add area to group
		combat_area.connect("area_entered", _on_combat_area_area_entered)
	if vulnerable_area:
		vulnerable_area.add_to_group("enemy_vulnerable_areas") # Add area to group
		vulnerable_area.connect("area_entered", _on_vulnerable_area_area_entered)
	if stomp_area:
		stomp_area.add_to_group("enemy_stomp_areas")
		# Note: stomp_area doesn't need signal connection - it's detected by players

	
	# Connect egg area signal and add it to group
	if egg_area:
		egg_area.add_to_group("egg_collection_zones") # Add area to group
		egg_area.connect("area_entered", _on_egg_area_area_entered)
		egg_area.set_deferred("monitoring", false)  # Start disabled

func _on_enemy_animation_finished():
	if enemy_animation.animation == "spawn":
		is_spawning = false
		is_invincible = false
		current_state = State.WALKING
	if enemy_animation.animation == "hatching":
		enemy_animation.play("waving") # Play waving animation after hatching

func _physics_process(delta):
	# Handle screen wrapping
	screen_wrapping()
	
	if previous_state != current_state:
		#print("Enemy %s state changed: %s -> %s" % [name, str(previous_state), str(current_state)])
		previous_state = current_state

	if is_spawning:
		velocity = Vector2.ZERO
		return
	
	# NEW: Add player head check for walking enemies
	if current_state == State.WALKING:
		check_for_standing_on_player()

	match current_state:
		State.FLYING:
			process_flying(delta)
			# Ensure egg area is disabled in flying state
			if egg_area: egg_area.monitoring = false
			# Ensure combat area is enabled in flying state
			if combat_area: combat_area.monitoring = true
		State.WALKING:
			process_walking(delta)
			if enemy_animation and enemy_animation.animation != "walk":
				#print("Enemy %s: Switching to walk animation" % name)
				enemy_animation.play("walk")
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

# NEW: Check if walking enemy is standing on a player (should stomp them)
func check_for_standing_on_player():
	if not is_on_floor():
		return
	
	# Check what we're standing on
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if not collision: continue
		
		var collider = collision.get_collider()
		if not collider or not collider.is_in_group("players"):
			continue
			
		var player = collider
		if not player.is_alive:
			continue
			
		# Check if we're actually on top of the player (not side collision)
		var collision_normal = collision.get_normal()
		if collision_normal.y < -0.7:  # Normal pointing upward (we're on top)
			print("[DEBUG] Walking enemy %s is standing on player %s - triggering stomp" % [name, player.name])
			player.die()
			return

func process_flying(delta):
	enemy_animation.play("fly")
	# Apply gravity
	velocity.y += gravity * delta

	# NEW: Safety check - don't fly too low (avoid lava)
	if global_position.y > min_fly_height:
		# Force upward movement when too low
		velocity.y = flap_force * 1.5  # Extra strong flap to get to safety
		print("[DEBUG] Enemy %s too low (y=%.1f), forcing upward!" % [name, global_position.y])
	else:
		# Normal flying behavior when at safe height
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

	# NEW: Modified landing logic - only land if above safe height
	if is_on_floor() and abs(velocity.y) < 1.0 and current_state == State.FLYING:
		# Only transition to walking if we're at a safe height
		if global_position.y <= min_fly_height:
			current_state = State.WALKING
			walk_time = 0
			if enemy_animation:
				enemy_animation.play("walk")
		else:
			# Too low to land safely - keep flying
			velocity.y = flap_force  # Flap to stay airborne
			print("[DEBUG] Enemy %s avoided landing at unsafe height (y=%.1f)" % [name, global_position.y])


func process_walking(delta):
	enemy_animation.play("walk")
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
			enemy_animation.play("fly")

	move_and_slide()

	# If we're not on floor anymore (walked off edge), switch to flying
	if not is_on_floor():
		current_state = State.FLYING
		# Update animation to flying
		if enemy_animation:
			enemy_animation.play("fly")

func check_ground_ahead():
	# Use the pre-configured raycast
	if not is_instance_valid(ground_raycast): return false # Safety check
	ground_raycast.position.x = direction * ground_check_distance_ahead # Update position based on direction
	ground_raycast.force_raycast_update() # Force update for immediate result
	return ground_raycast.is_colliding()

func _on_combat_area_area_entered(area):
	if current_state != State.FLYING and current_state != State.WALKING:
		return # Only handle collisions when active (not when EGG, HATCHING, or DEAD)
		
	# Check if colliding with another enemy's combat area
	if area.is_in_group("enemy_combat_areas"):
		var other_enemy = area.get_parent()
		if not other_enemy or other_enemy == self or not other_enemy.is_in_group("enemies"):
			return # Ignore self-collision or non-enemy parents
		
		# NEW: Ignore collisions with eggs
		if "current_state" in other_enemy and (other_enemy.current_state == State.EGG or other_enemy.current_state == State.HATCHING or other_enemy.current_state == State.DEAD):
			return # Don't collide with eggs/hatching/dead enemies
			
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
	# Apply gravity
	velocity.y += gravity * delta
	
	# Apply horizontal damping over time (air resistance)
	velocity.x = move_toward(velocity.x, 0, 20 * delta)
	
	move_and_slide()
	
	# Handle bouncing when hitting the ground
	if is_on_floor():
		if not egg_has_touched_ground:
			egg_has_touched_ground = true
			print("[DEBUG] Egg %s touched ground for first time" % name)
		
		# Check if we should bounce
		if abs(velocity.y) > egg_min_bounce_velocity and egg_bounce_count < 5:  # Limit bounces
			# Apply bounce
			velocity.y = -velocity.y * egg_bounce_damping
			velocity.x *= egg_horizontal_damping  # Reduce horizontal velocity on bounce
			egg_is_bouncing = true
			egg_bounce_count += 1
			print("[DEBUG] Egg %s bounce #%d, new velocity: %s" % [name, egg_bounce_count, velocity])
		else:
			# Stop bouncing - egg has settled
			if egg_is_bouncing:
				egg_is_bouncing = false
				velocity = Vector2.ZERO
				print("[DEBUG] Egg %s settled after %d bounces" % [name, egg_bounce_count])
			
			# NEW: Always try to start hatching timer when settled (with debug)
			if hatch_timer:
				if hatch_timer.is_stopped():
					current_state = State.HATCHING
					hatch_timer.start()
					print("[DEBUG] Egg %s started hatching timer (%.1fs)" % [name, hatch_timer.wait_time])
				else:
					print("[DEBUG] Egg %s hatch timer already running (%.1fs remaining)" % [name, hatch_timer.time_left])
			else:
				print("[ERROR] Egg %s has no hatch timer!" % name)
	
	# Enable Egg Collection when in Egg state
	if egg_area:
		egg_area.monitoring = true
		egg_area.monitorable = true
		vulnerable_area.monitoring = false


# New function for area-based egg collection
func _on_egg_area_area_entered(area):
	print("[DEBUG EGG COLLECT] Egg %s area entered by: %s (groups: %s)" % [name, area.name, area.get_groups()])
	
	var player = area.get_parent()
	var player_index = player.player_index if player and player.has_method("player_index") else 1
	
	print("[DEBUG EGG COLLECT] Player: %s, player_index: %d" % [player.name if player else "null", player_index])
	print("[DEBUG EGG COLLECT] Current state: %s" % current_state)
	
	if (current_state == State.EGG or current_state == State.HATCHING) and area.is_in_group("player_collectors"):
		print("[DEBUG EGG COLLECT] *** COLLECTING EGG %s ***" % name)
		collect_egg(player_index)
	else:
		print("[DEBUG EGG COLLECT] Collection conditions not met")

func defeat(player_index: int, award_score := true, player_velocity: Vector2 = Vector2.ZERO):
	print("[DEBUG DEFEAT] Enemy %s defeat() called - player_index: %d" % [name, player_index])

	if is_spawning:
		print("[DEBUG DEFEAT] Enemy %s is spawning - ignoring defeat" % name)
		return # Don't defeat if spawning

	if current_state == State.EGG or current_state == State.HATCHING or current_state == State.DEAD:
		print("[DEBUG DEFEAT] Enemy %s already defeated (state: %s)" % [name, current_state])
		return # Already defeated or dead

	print("[DEBUG DEFEAT] Enemy %s changing to EGG state" % name)
	current_state = State.EGG
	is_spawning = false # Ensure we are not in spawning state
	
	# NEW: Initialize egg physics state
	egg_has_touched_ground = false
	egg_is_bouncing = false
	egg_bounce_count = 0
	
	# NEW: Calculate egg velocity based on player's speed and direction
	var player_speed_factor = player_velocity.length() / 200.0  # Normalize player speed (200 = typical max speed)
	player_speed_factor = max(0.5, min(player_speed_factor, 2.0))  # Clamp between 0.5x and 2.0x
	
	# Apply player's horizontal momentum to egg
	velocity.x = player_velocity.x * 0.7  # 70% of player's horizontal velocity
	
	# Apply upward velocity based on player's speed (faster = more upward force)
	var base_upward_force = -150.0  # Base upward velocity
	velocity.y = base_upward_force * player_speed_factor
	
	# FIX: For egg waves, don't apply velocity (eggs should just fall)
	if player_velocity == Vector2.ZERO:
		velocity.x = randf_range(-50, 50)  # Small random horizontal velocity
		velocity.y = 0  # No initial vertical velocity for spawned eggs
	
	print("[DEBUG] Egg defeated with player velocity: %s, speed factor: %.2f, egg velocity: %s" % [player_velocity, player_speed_factor, velocity])
	
	if enemy_animation: enemy_animation.visible = false
	if egg_sprite: egg_sprite.visible = true

	print("[DEBUG DEFEAT] Enemy %s disabling areas..." % name)

	# Disable combat area IMMEDIATELY
	if combat_area:
		print("[DEBUG DEFEAT] Disabling combat area for %s" % name)
		combat_area.monitoring = false
		combat_area.monitorable = false
	
	# Disable stomp area IMMEDIATELY (this was missing!)
	if stomp_area:
		print("[DEBUG DEFEAT] Disabling stomp area for %s" % name)
		stomp_area.monitoring = false
		stomp_area.monitorable = false
	
	# Disable vulnerable area IMMEDIATELY
	if vulnerable_area:
		print("[DEBUG DEFEAT] Disabling vulnerable area for %s" % name)
		vulnerable_area.monitoring = false
		vulnerable_area.monitorable = false
	
	# Enable egg area for collection IMMEDIATELY
	if egg_area:
		print("[DEBUG DEFEAT] Enabling egg area for %s" % name)
		egg_area.monitoring = true
		egg_area.monitorable = true

	print("[DEBUG DEFEAT] Enemy %s defeat complete - now in EGG state" % name)	

	# Change collision layers for the main body
	set_collision_layer_value(3, false) # Turn off enemy layer
	set_collision_layer_value(4, true) # Turn on egg layer
	set_collision_mask_value(1, false) # Don't collide with player
	set_collision_mask_value(2, true) # Do collide with environment only
	set_collision_mask_value(3, false) # Don't collide with other enemies
	
	# Signal to score manager to add points (only if awarded)
	if award_score:
		ScoreManager.add_score(player_index, points_value)
	
	print("Enemy %s defeated" % name)

func collect_egg(player_index):
	print("[DEBUG EGG COLLECT] collect_egg() called for %s by player %d" % [name, player_index])
	
	if current_state == State.DEAD: 
		print("[DEBUG EGG COLLECT] Already dead - ignoring collection")
		return
		
	print("[DEBUG EGG COLLECT] Setting %s to DEAD state" % name)
	current_state = State.DEAD
	
	var base_egg_score = 50
	var is_air_catch = not egg_has_touched_ground

	# Store the egg's world position before cleanup
	var egg_world_position = global_position

	# Add base score
	ScoreManager.add_score(player_index, base_egg_score)
	
	# Add bonus if air catch
	if is_air_catch:
		ScoreManager.add_bonus_score(player_index, 100, "Air Catch", egg_world_position)
	
	print("[DEBUG EGG COLLECT] Disabling all areas for %s..." % name)
	
	# Disable all areas IMMEDIATELY
	if combat_area:
		print("[DEBUG EGG COLLECT] Disabling combat area")
		combat_area.monitoring = false
		combat_area.monitorable = false
	if egg_area:
		print("[DEBUG EGG COLLECT] Disabling egg area")
		egg_area.monitoring = false
		egg_area.monitorable = false
	if stomp_area:
		print("[DEBUG EGG COLLECT] Disabling stomp area")
		stomp_area.monitoring = false
		stomp_area.monitorable = false
	if vulnerable_area:
		print("[DEBUG EGG COLLECT] Disabling vulnerable area")
		vulnerable_area.monitoring = false
		vulnerable_area.monitorable = false
	
	print("[DEBUG EGG COLLECT] All areas disabled for %s, queuing free..." % name)
	queue_free()

func _on_vulnerable_area_area_entered(area):
	print("[DEBUG] %s vulnerable area entered by: %s" % [name, area.name])
	
	if is_spawning:
		print("[DEBUG] %s is spawning, ignoring stomp" % name)
		return # Don't allow stomping while spawn

	if area.is_in_group("player_stomp_areas"):
		var player = area.get_parent()
		var player_index = player.player_index if player and player.has_method("player_index") else 1
		
		# New position check: player must be higher to stomp enemy
		var position_tolerance = 20.0  # Allow some tolerance for player position
		if player.global_position.y > global_position.y + position_tolerance:
			print("[DEBUG] Player%d is not high enough to stomp %s" % [player_index, name])
			return # Not high enough to stomp
		
		print("[DEBUG] %s being stomped by Player%d" % [name, player_index])
		print("STOMP!!")
		if player and player.is_in_group("players"):
			# Pass player's velocity to defeat function
			defeat(player_index, true, player.velocity)
			player.velocity.y = player.joust_bounce_velocity
	else:
		print("[DEBUG] %s vulnerable area entered by non-player-stomp area: %s (groups: %s)" % [name, area.name, area.get_groups()])

func _on_hatch_timer_timeout():
	print("[DEBUG] Hatch timer timeout for %s (current state: %s)" % [name, current_state])
	if current_state != State.HATCHING: 
		print("[WARNING] Hatch timer fired but egg %s is not in HATCHING state!" % name)
		return # Only hatch if in hatching state

	if enemy_animation:
		if egg_sprite:
			egg_sprite.visible = false # Hide egg sprite
		enemy_animation.visible = true
		enemy_animation.position.y += 18
		enemy_animation.play("hatching") # Play hatching animation
		# Don't reconnect if already connected
		if not enemy_animation.is_connected("animation_finished", Callable(self, "_on_enemy_animation_finished")):
			enemy_animation.connect("animation_finished", Callable(self, "_on_enemy_animation_finished"))
	
	# Spawn rescue bird
	spawn_rescue_bird()
	print("[DEBUG] Egg %s started hatching process" % name)

func spawn_rescue_bird():
	var rescue_bird_scene = preload("res://scenes/entities/rescue_bird.tscn")
	var rescue_bird = rescue_bird_scene.instantiate()
	print("[DEBUG] Rescue bird instantiated: ", rescue_bird)

	# Determine which side to spawn from (left or right)
	var viewport_size = get_viewport_rect().size
	var spawn_y = global_position.y
	var spawn_x = 0.0
	var target_x = global_position.x

	# Calculate distance to each side
	var distance_to_left = global_position.x
	var distance_to_right = viewport_size.x - global_position.x
	
	# Spawn from the farthest side
	if distance_to_left > distance_to_right:
		# Egg is closer to right side, spawn bird from left
		spawn_x = -50
		rescue_bird.direction = 1
		print("[DEBUG] Egg closer to right side - rescue bird spawning from left (distance_to_left: %.1f, distance_to_right: %.1f)" % [distance_to_left, distance_to_right])
	else:
		# Egg is closer to left side, spawn bird from right
		spawn_x = viewport_size.x + 50
		rescue_bird.direction = -1
		print("[DEBUG] Egg closer to left side - rescue bird spawning from right (distance_to_left: %.1f, distance_to_right: %.1f)" % [distance_to_left, distance_to_right])

	rescue_bird.global_position = Vector2(spawn_x, spawn_y)
	rescue_bird.target_x = target_x
	rescue_bird.target_enemy = self
	print("[DEBUG] Rescue bird position: ", rescue_bird.global_position, " target_x: ", target_x)


	get_tree().current_scene.add_child(rescue_bird)

func rescue_from_hatching():
	if current_state == State.HATCHING:
		current_state = State.FLYING
		enemy_animation.play("fly") # Switch back to flying animation

		if enemy_animation: 
			enemy_animation.position.y -= 18 # Reset position adjustment
			enemy_animation.visible = true
		if egg_sprite: 
			egg_sprite.visible = false	

		# Reset collision layers, etc. (reuse your previous hatching logic)
		set_collision_layer_value(3, true) # Turn on enemy layer
		set_collision_layer_value(4, false) # Turn off egg layer
		set_collision_mask_value(1, true) # Collide with player again
		set_collision_mask_value(2, true) # Ensure it collides with environment

		if combat_area: combat_area.monitoring = true
		if egg_area: egg_area.monitoring = false 

		# Restore vulnerable and stomp areas using set_collision_layer_value/mask_value
		if vulnerable_area:
			vulnerable_area.set_collision_layer_value(7, true) # Layer 7 (default for vulnerable)
			vulnerable_area.set_collision_mask_value(6, true)  # Mask 6 (default for stomp)
			vulnerable_area.monitoring = true
		if stomp_area:
			stomp_area.set_collision_layer_value(6, true) # Layer 6 (default for stomp)
			stomp_area.set_collision_mask_value(7, true)  # Mask 7 (default for vulnerable)
			stomp_area.monitoring = true


# NEW: Special function for egg wave spawning (bypasses spawn protection)
func spawn_as_egg():
	print("[DEBUG EGG SPAWN] Spawning %s directly as egg" % name)
	
	# Force stop spawning state and animation
	is_spawning = false
	is_invincible = false
	current_state = State.EGG
	
	# Initialize egg physics state
	egg_has_touched_ground = false
	egg_is_bouncing = false
	egg_bounce_count = 0
	
	# Set egg appearance
	if enemy_animation: 
		enemy_animation.visible = false
		enemy_animation.stop()
	if egg_sprite: 
		egg_sprite.visible = true

	# Set egg physics (small random velocity for variety)
	velocity.x = randf_range(-30, 30)  # Small random horizontal velocity
	velocity.y = randf_range(0, 50)    # Small downward velocity
	
	# Set collision layers for egg
	set_collision_layer_value(3, false) # Turn off enemy layer
	set_collision_layer_value(4, true) # Turn on egg layer
	set_collision_mask_value(1, false) # Don't collide with player body
	set_collision_mask_value(2, true) # Do collide with environment
	set_collision_mask_value(3, false) # Don't collide with other enemies
	
	# Disable all combat areas
	if stomp_area:
		stomp_area.monitoring = false
		stomp_area.monitorable = false
	if vulnerable_area:
		vulnerable_area.monitoring = false
		vulnerable_area.monitorable = false
	
	# Enable egg collection
	if egg_area:
		egg_area.monitoring = true
		egg_area.monitorable = true
	
	print("[DEBUG EGG SPAWN] %s successfully spawned as egg" % name)
