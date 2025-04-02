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
# var target_direction = 0   # Replaced by input_direction within state logic
var deceleration_timer = 0.0
# var is_changing_direction = false # Replaced by DECELERATING state
var current_speed_value: float = 0.0  # Actual speed value (not just level)
var target_speed_value: float = 0.0   # Target speed during deceleration
# var _just_stomped = false # Removed - relying on separate signal handling

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
	
	# Handle horizontal movement
	var direction = 0
	if Input.is_action_pressed("move_left"):
		direction = -1
		sprite.flip_h = true
	elif Input.is_action_pressed("move_right"):
		direction = 1
		sprite.flip_h = false
		
	# --- State Machine Based Horizontal Movement ---
	var input_direction = _get_input_direction()
	match move_state:
		MoveState.IDLE:
			_state_idle(input_direction)
		MoveState.MOVING:
			_state_moving(input_direction, delta)
		MoveState.DECELERATING:
			_state_decelerating(input_direction, delta)
			
	_apply_horizontal_velocity() # Apply calculated velocity
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
	current_speed_value = 0
	current_direction = 0 # Explicitly set direction to 0 when idle
	if input_direction != 0:
		# Start moving
		current_direction = input_direction
		current_speed_level = 1
		# Update speed value immediately for responsiveness
		current_speed_value = base_speed * speed_multipliers[current_speed_level] * current_direction
		move_state = MoveState.MOVING

func _state_moving(input_direction: int, delta: float):
	"""Handles logic when the player is actively moving."""
	if input_direction == 0:
		# Player released keys. Keep moving with current momentum.
		# State remains MOVING. Speed is maintained unless opposite key is pressed.
		pass 
	elif input_direction == current_direction:
		# Pressing same direction - accelerate on *just pressed*
		# Check if the action was *just* pressed to avoid continuous acceleration
		if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
			current_speed_level = min(current_speed_level + 1, max_speed_level)
	elif input_direction != current_direction:
		# Pressed opposite direction - start decelerating
			_enter_decelerating_state(input_direction) # Pass the new target direction
		
	# Always update speed based on the current level while in this state
	current_speed_value = base_speed * speed_multipliers[current_speed_level] * current_direction

func _state_decelerating(input_direction: int, delta: float):
	"""Handles logic when the player is decelerating to change direction."""
	# Note: input_direction here is the direction the player is *currently holding*,
	# which initiated the deceleration. current_direction is the direction they *were* moving.
	
	deceleration_timer += delta

	if deceleration_timer >= level_deceleration_time:
		# Time to decrease a speed level
		current_speed_level -= 1
		deceleration_timer = 0 # Reset timer for next level

		if current_speed_level <= 0:
			# Reached speed 0, now change direction and start moving
			current_direction = input_direction # Use the direction held during deceleration
			current_speed_level = 1
			# Update speed value immediately
			current_speed_value = base_speed * speed_multipliers[current_speed_level] * current_direction
			move_state = MoveState.MOVING # Transition back to MOVING
		else:
			# Still decelerating, calculate new target speed for the next lower level
			var next_lower_level = max(0, current_speed_level - 1)
			# Target speed is based on the original direction of movement during deceleration
			target_speed_value = base_speed * speed_multipliers[next_lower_level] * current_direction 
	else:
		# Smoothly interpolate speed during this level's deceleration
		var t = deceleration_timer / level_deceleration_time
		# Speed at the start of *this* deceleration level (based on original direction)
		var speed_at_this_level = base_speed * speed_multipliers[current_speed_level] * current_direction
		current_speed_value = lerp(speed_at_this_level, target_speed_value, t)

func _enter_decelerating_state(new_target_direction: int):
	"""Sets up variables needed when entering the DECELERATING state."""
	# new_target_direction is the direction the player just pressed
	move_state = MoveState.DECELERATING
	deceleration_timer = 0.0
	# Calculate the speed target for the *next lower* level (relative to current level)
	var next_lower_level = max(0, current_speed_level - 1)
	# Target speed is based on the original direction of movement during deceleration
	target_speed_value = base_speed * speed_multipliers[next_lower_level] * current_direction 

func _apply_horizontal_velocity():
	"""Applies the calculated horizontal speed to the velocity and updates sprite flip."""
	velocity.x = current_speed_value
	# Update sprite direction based on the actual movement direction
	if current_direction < 0:
		sprite.flip_h = true
	elif current_direction > 0:
		sprite.flip_h = false
	# If current_direction is 0 (e.g., after full stop), sprite retains last flip

# --- End Refactored Horizontal Movement Functions ---


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

func _on_collection_area_area_entered(area):
	#Debug print to check if this function is being called
	print("Player collection area detected collision with: ", area.name)
	
	# Check if the area entered is an enemy's egg collection zone
	if area.is_in_group("egg_collection_zones") and area.get_parent().is_in_group("enemies"):
		var enemy = area.get_parent()
		
		# Print more debug info to understand the state
		print("Enemy current_state: ", enemy.current_state if "current_state" in enemy else "unknown")
		print("Enemy State.EGG value: ", enemy.State.EGG if "State" in enemy else "unknown")
		
		# Check if enemy is in EGG state
		if "current_state" in enemy and (enemy.current_state == enemy.State.EGG or enemy.current_state == enemy.State.HATCHING):
			print("Egg Collected by player via collection area!")
			enemy.collect_egg()
