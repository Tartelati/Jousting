extends CharacterBody2D

@export_group("Movement")
@export var gravity: float = 800.0
@export var flap_force: float = -300.0
@export var base_speed: float = 100.0
@export var max_speed_level: int = 3
@export var speed_multipliers: Array[float] = [0.0, 1.0, 2.0, 3.0] # Multipliers for each level
@export var level_deceleration_time: float = 0.3  # Time to decrease one speed level
@export var max_fall_speed: float = 400.0

@export_group("Collision")
@export var joust_bounce_velocity: float = -150.0
@export var side_collision_bounce_x: float = 200.0
@export var side_collision_bounce_y: float = -100.0
@export var collision_y_threshold: float = 10.0 # Threshold for determining win/loss/bounce

@export_group("Screen Wrap")
@export var screen_wrap_buffer: float = 10.0

@export_group("Respawn")
@export var respawn_delay: float = 2.0

# --- Movement State Machine ---
enum MoveState { IDLE, MOVING, DECELERATING }
var move_state = MoveState.IDLE
# --- End Movement State Machine ---

# Internal state variables (not exported)
var current_speed_level = 0  # 0=stopped, 1=base, 2=2x, 3=3x
var current_direction = 0  # -1=left, 0=none, 1=right
var target_direction_during_decel = 0 # Direction player intends to move after decelerating
var deceleration_timer = 0.0
# var is_changing_direction = false # Replaced by DECELERATING state
# var current_speed_value: float = 0.0  # No longer needed, set velocity.x directly
# var target_speed_value: float = 0.0   # Target speed during deceleration - Removed for level-step deceleration
# var _just_stomped = false # Removed - relying on separate signal handling

# Input Cooldown
var horizontal_input_cooldown: float = 0.15 # Seconds (adjust as needed)
var last_horizontal_input_processed_time: float = 0.0 

#state tracking
var is_flapping = false
var is_alive = true

#references
@onready var sprite = $Sprite2D
@onready var flap_sound = $FlapSound
@onready var collision_sound = $CollisionSound
@onready var death_sound = $DeathSound
@onready var combat_area = $CombatArea # Main body collision
@onready var collection_area = $CollectionArea # For collecting eggs
@onready var stomp_area = $StompArea # For stomping enemies


func _ready():
	# Add to player group for easy access
	add_to_group("players")
	
	# Connect combat area signal
	if combat_area:
		combat_area.connect("area_entered", _on_combat_area_area_entered)
	
	# Connect collection_area signal and add it to group
	if collection_area:
		collection_area.add_to_group("player_collectors") # Add area to group
		collection_area.connect("area_entered", _on_collection_area_area_entered)
		
	# Connect stomp_area signal and add it to group
	if stomp_area:
		stomp_area.add_to_group("player_stomp_areas") # Add area to group
		# Connect the signal from the StompArea node to this script's function
		# IMPORTANT: Ensure this signal is connected in the Godot Editor as well, 
		# or uncomment the line below if you prefer connecting via code.
		stomp_area.connect("area_entered", _on_stomp_area_area_entered) 

func _physics_process(delta):
	if not is_alive:
		return
		
	# Apply gravity only when not on floor
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	
	# Handle flapping
	if Input.is_action_just_pressed("Flap"):
		velocity.y = flap_force
		is_flapping = true
		flap_sound.play()
	else:
		is_flapping = false
	
	# --- State Machine Based Horizontal Movement ---
	var input_direction = _get_input_direction() # Get input for state logic AND sprite flip
	
	# Handle sprite flipping based on input or current direction, but NOT during deceleration
	if move_state != MoveState.DECELERATING:
		if input_direction != 0:
			sprite.flip_h = (input_direction < 0)
		elif current_direction != 0: # Keep facing last direction if stopping (and not decelerating)
			sprite.flip_h = (current_direction < 0)

	match move_state:
		MoveState.IDLE:
			_state_idle(input_direction)
		MoveState.MOVING:
			_state_moving(input_direction, delta)
		MoveState.DECELERATING:
			_state_decelerating(input_direction, delta)
			
	# _apply_horizontal_velocity() # Removed - velocity.x is set within state functions
	# --- End State Machine Based Horizontal Movement ---
	
	# Handle screen wrapping
	screen_wrapping()
	
	# Update animation based on movement
	update_animation()
	
	# Move the character
	move_and_slide()

func screen_wrapping():
	var viewport_rect = get_viewport_rect().size
	
	# Check if player is about to go off the left edge
	if global_position.x < screen_wrap_buffer:
		# Immediately teleport to right side with same velocity
		global_position.x = viewport_rect.x - screen_wrap_buffer
		# No need to change velocity, keep momentum
	
	# Check if player is about to go off the right edge
	elif global_position.x > viewport_rect.x - screen_wrap_buffer:
	# Immediately teleport to left side with same velocity
		global_position.x = screen_wrap_buffer
	# No need to change velocity, keep momentum


# --- Horizontal Movement State Functions ---

func _get_input_direction() -> int:
	"""Gets the horizontal input direction (-1 for left, 1 for right, 0 for none)."""
	if Input.is_action_pressed("move_left"):
		return -1
	elif Input.is_action_pressed("move_right"):
		return 1
	else:
		return 0

func _state_idle(input_direction: int):
	"""Handles logic when the player is not moving horizontally."""
	current_speed_level = 0
	velocity.x = 0 # Ensure velocity is zero when idle
	current_direction = 0 
	if input_direction != 0:
		# Start moving
		current_direction = input_direction
		current_speed_level = 1
		# Set velocity directly
		velocity.x = base_speed * speed_multipliers[current_speed_level] * current_direction
		move_state = MoveState.MOVING

func _state_moving(input_direction: int, delta: float):
	"""Handles logic when the player is actively moving."""
	# Player continues moving even if input_direction is 0
	
	var current_time = Time.get_ticks_msec() / 1000.0 # Get current time in seconds
	
	if input_direction == current_direction:
		# Pressing same direction - accelerate on *just pressed* with cooldown
		if (Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right")) \
		and (current_time > last_horizontal_input_processed_time + horizontal_input_cooldown):
			current_speed_level = min(current_speed_level + 1, max_speed_level)
			last_horizontal_input_processed_time = current_time # Update timestamp
	elif input_direction != 0 and input_direction != current_direction:
		# Pressed opposite direction - start decelerating (cooldown applied in _enter_decelerating_state)
		target_direction_during_decel = input_direction # Store intended direction
		_enter_decelerating_state() 
		# Velocity for this frame remains as it was, deceleration starts next frame
		return # Exit early to avoid applying normal moving velocity this frame
		
	# Update velocity based on the current level and direction
	velocity.x = base_speed * speed_multipliers[current_speed_level] * current_direction

func _state_decelerating(input_direction: int, delta: float):
	"""Handles logic when the player is decelerating by pressing the opposite direction."""
	
	# --- Handle Input During Deceleration ---
	if input_direction == current_direction: 
		# Pressed original direction again - cancel deceleration
		move_state = MoveState.MOVING
		# Keep current (potentially reduced) speed level and direction
		# Velocity will be updated correctly in MOVING state next frame
		return 
	var current_time = Time.get_ticks_msec() / 1000.0 # Get current time in seconds
	
	# --- Handle Input During Deceleration ---
	if input_direction == current_direction: 
		# Pressed original direction again - cancel deceleration
		move_state = MoveState.MOVING
		# Keep current (potentially reduced) speed level and direction
		# Velocity will be updated correctly in MOVING state next frame
		return 
	elif input_direction == target_direction_during_decel:
		# Pressing the target direction (accelerating the brake) with cooldown
		if (Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right")) \
		and (current_time > last_horizontal_input_processed_time + horizontal_input_cooldown):
			# Decrease speed level immediately if possible
			if current_speed_level > 0:
				current_speed_level -= 1
				last_horizontal_input_processed_time = current_time # Update timestamp
				deceleration_timer = 0.0 # Reset timer for the new level drop
				# Update velocity immediately for the new lower level
				if current_speed_level > 0:
					velocity.x = base_speed * speed_multipliers[current_speed_level] * current_direction
				else: # Reached level 0
					velocity.x = 0
					current_direction = 0
					move_state = MoveState.IDLE
					return # Exit early, now idle
	# If input_direction is 0 (keys released), continue decelerating based on timer.

	# --- Timer-Based Deceleration ---
	# Only proceed with timer logic if not already transitioned to IDLE
	if move_state == MoveState.DECELERATING:
		deceleration_timer += delta
		
		if deceleration_timer >= level_deceleration_time:
			# Time to decrease a speed level
			current_speed_level -= 1
			deceleration_timer = 0.0 # Reset timer for next level drop
			
			if current_speed_level <= 0:
				# Reached speed 0, stop completely
				current_speed_level = 0
				velocity.x = 0
				current_direction = 0
				move_state = MoveState.IDLE
			else:
				# Still moving, update velocity for the new lower level
				velocity.x = base_speed * speed_multipliers[current_speed_level] * current_direction
		# else: 
			# Velocity remains at the speed of the current level until timer completes
			# No interpolation needed for this stepped deceleration approach

func _enter_decelerating_state():
	"""Sets up variables needed when entering the DECELERATING state."""
	if current_speed_level <= 0: return # Cannot decelerate if already stopped
	
	var current_time = Time.get_ticks_msec() / 1000.0 # Get current time in seconds
	# Check cooldown before allowing deceleration to start
	if current_time <= last_horizontal_input_processed_time + horizontal_input_cooldown:
		return # Ignore input if still within cooldown
		
	move_state = MoveState.DECELERATING
	deceleration_timer = 0.0
	
	# Immediately decrease speed level by 1
	current_speed_level -= 1
	last_horizontal_input_processed_time = current_time # Update timestamp as deceleration input was processed
	
	# Update velocity to the new lower speed level (still in original direction)
	if current_speed_level > 0:
		velocity.x = base_speed * speed_multipliers[current_speed_level] * current_direction
	else: # If dropping to level 0 immediately
		velocity.x = 0
		current_direction = 0
		move_state = MoveState.IDLE # Go straight to IDLE if starting deceleration from level 1

# Removed _apply_horizontal_velocity function

# --- End Refactored Horizontal Movement Functions ---

func bounce_from_wall(new_velocity):
	"""Handles bouncing from a wall by directly modifying player state"""
	# Apply the new velocity
	velocity = new_velocity
	
	# Update direction based on new velocity
	current_direction = sign(velocity.x)
	
	# Force the character into MOVING state
	move_state = MoveState.MOVING
	
	# Set speed level based on velocity
	var speed_value = abs(velocity.x) / base_speed
	for i in range(speed_multipliers.size() - 1, -1, -1):
		if speed_value >= speed_multipliers[i] * 0.9:  # 90% threshold
			current_speed_level = i
			break
	
	# Flip sprite based on new direction
	sprite.flip_h = (current_direction < 0)
	
	# Play collision sound
	collision_sound.play()


func update_animation():
	# This would be replaced with proper animation states
	# when using AnimatedSprite2D
	if is_flapping:
		sprite.modulate = Color(1, 1, 0.8)  # Slight yellow tint when flapping
	else:
		sprite.modulate = Color(1, 1, 1)  # Normal color otherwise

# --- Collision Handling ---

func _on_combat_area_area_entered(area):
	"""Handles collisions with the main player body (e.g., side collisions, getting hit)."""
	# This function assumes a stomp was NOT successful (that's handled by _on_stomp_area_area_entered 
	# triggering the enemy's _on_vulnerable_area_area_entered which calls defeat()).
	if not is_alive: return
		
	# Check if colliding with an enemy's main combat area
	# Assuming enemy combat areas are in a group like "enemy_combat_areas"
	# (This group needs to be added to the enemy's CombatArea node in the editor)
	if area.is_in_group("enemy_combat_areas"): 
		var enemy = area.get_parent()
		if not enemy or not enemy.is_in_group("enemies"): return # Ensure parent is valid enemy
		
		# Skip if enemy is in egg or hatching state
		if "current_state" in enemy and (enemy.current_state == enemy.State.EGG or enemy.current_state == enemy.State.HATCHING):
			return

		# Player didn't stomp successfully (handled by StompArea signal)
		# Determine if it's a side collision or player death
		
		# Simple approach: If player is moving downwards significantly, assume they lost.
		# A more robust check might involve comparing relative positions slightly, 
		# but this requires careful tuning. Let's stick to velocity for now.
		if velocity.y > 50: # Threshold for downward velocity indicating player lost joust
			die()
		else:
			# Assume side collision - bounce off each other
			var direction_to_enemy = sign(global_position.x - enemy.global_position.x)
			# Ensure direction is not zero if perfectly aligned
			if direction_to_enemy == 0: direction_to_enemy = 1 
			
			velocity.x = direction_to_enemy * side_collision_bounce_x
			velocity.y = side_collision_bounce_y # Small upward bounce for player
			
			# Apply bounce to enemy as well (if enemy has velocity)
			if "velocity" in enemy:
				enemy.velocity.x = -direction_to_enemy * side_collision_bounce_x
				enemy.velocity.y = side_collision_bounce_y # Small upward bounce for enemy
			
			collision_sound.play()

func _on_stomp_area_area_entered(area):
	"""Handles the PLAYER'S reaction to successfully stomping an enemy."""
	# The enemy handles its own defeat via its _on_vulnerable_area_area_entered signal.
	if not is_alive: return

	# Check if the area entered is an enemy's vulnerable spot
	# Assuming enemy vulnerable areas are in a group like "enemy_vulnerable_areas"
	# (This group needs to be added to the enemy's VulnerableArea node in the editor)
	if area.is_in_group("enemy_vulnerable_areas"):
		var enemy = area.get_parent()
		if not enemy or not enemy.is_in_group("enemies"): return # Ensure parent is valid enemy

		# Skip if enemy is already in egg or hatching state (shouldn't happen if layers/masks correct)
		if "current_state" in enemy and (enemy.current_state == enemy.State.EGG or enemy.current_state == enemy.State.HATCHING):
			return
			
		# Player wins - Stomped successfully!
		# We don't call enemy.defeat() here. The enemy does that itself.
		# We just handle the player's bounce.
		
		# Add a small upward bounce for the player
		velocity.y = joust_bounce_velocity
		
		# Play victory sound (optional)
		if has_node("VictorySound"):
			$VictorySound.play()

func die():
	is_alive = false
	death_sound.play()
	sprite.modulate = Color(1, 0.5, 0.5)  # Red tint
	
	# Notify game manager
	get_node("/root/ScoreManager").lose_life()
	
	# Wait and respawn
	await get_tree().create_timer(respawn_delay).timeout
	respawn()

func respawn():
	is_alive = true
	position = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y / 2)
	velocity = Vector2.ZERO
	sprite.modulate = Color(1, 1, 1)  # Reset color

# --- Signal Handlers ---

func _on_collection_area_area_entered(area):
	print("[DEBUG Player] CollectionArea entered by: %s (Parent: %s)" % [area.name, area.get_parent().name if area.get_parent() else "None"]) # DEBUG
	
	# Check if the area entered is an enemy's egg collection zone (for defeated enemies)
	# Note: This check seems redundant with the connection logic in _ready, 
	# but keeping it for now. Ideally, the signal connection ensures this.
	if area.is_in_group("egg_collection_zones") and area.get_parent().is_in_group("enemies"):
		var enemy = area.get_parent()
		
		# Print more debug info to understand the state
		print("Enemy current_state: ", enemy.current_state if "current_state" in enemy else "unknown")
		print("Enemy State.EGG value: ", enemy.State.EGG if "State" in enemy else "unknown")
		
		# Check if enemy is in EGG state (or hatching, as eggs might be collectible briefly during hatch)
		if "current_state" in enemy and (enemy.current_state == enemy.State.EGG or enemy.current_state == enemy.State.HATCHING):
			print("Egg Collected by player via collection area!")
			enemy.collect_egg() # Assuming the enemy script has a collect_egg method
