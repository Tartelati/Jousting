extends CharacterBody2D

@export var player_index: int = 1
@export var debug_input: bool = false # Toggle for input debugging

# --- States Enum ---
enum State { IDLE, WALKING, FLYING, BRAKING, DEFEATED } # Added BRAKING state

# --- State Variables ---
var current_state : State = State.IDLE
var previous_state = State.IDLE # Track previous state for transitions

# --- Movement Parameters ---
@export_group("Movement")
@export var speed_values : Array[float] = [0.0, 100.0, 150.0, 200.0] # Index 0 = Idle, 1-3 = Speed Levels
var current_speed_level : int = 0

# Use project gravity by default, can be overridden in inspector
@export var gravity : float = ProjectSettings.get_setting("physics/2d/default_gravity", 800.0)
@export var flap_force : float = -300.0 # Negative value for upward force
@export var max_fall_speed: float = 400.0 # Keep max fall speed
@export var brake_duration_per_level : float = 20.0 / 60.0 # ~20 frames at 60fps

@export_group("Collision")
@export var joust_bounce_velocity: float = -250.0 # Bounce after winning joust
@export var side_collision_bounce_x: float = 200.0 # Horizontal bounce velocity on side collision
@export var side_collision_bounce_y: float = -100.0 # Vertical bounce velocity on side collision
@export var collision_y_threshold: float = 10.0 # Y-velocity difference threshold for joust win/loss

@export_group("Screen Wrap")
@export var screen_wrap_buffer: float = 10.0

@export_group("Respawn")
@export var respawn_delay: float = 2.0

var device: int = -1 # Device ID: -1 for keyboard, 0+ for controllers

# --- Node References (Update paths as needed in the editor) ---
@onready var walking_audio = $WalkingAudioPlayer # Assumes AudioStreamPlayer node exists
@onready var flying_audio = $FlyingAudioPlayer # Assumes AudioStreamPlayer node exists
@onready var flap_sound = $FlapSound # Keep existing flap sound reference
@onready var collision_sound = $CollisionSound # Keep existing collision sound reference
@onready var death_sound = $DeathSound # Keep existing death sound reference
@onready var combat_area: Area2D = $CombatArea # Keep existing combat area reference
@onready var collection_area: Area2D = $CollectionArea # Keep existing collection area reference
@onready var stomp_area: Area2D = $StompArea # Keep existing stomp area reference
@onready var vulnerable_area: Area2D = $VulnerableArea
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


# --- Internal Variables ---
var defeated_time := 0.0
var is_respawning: bool = false
var defeated_fly_direction : int = 1
var defeated_fly_time : float = 0.0
var is_invincible := false
var is_alive := true
var brake_timer : float = 0.0
var direction_during_brake : int = 0
var hold_change_timer: float = 0.0 # Timer for hold input speed changes
@export var hold_change_interval: float = 0.2 # Time interval for hold changes

# --- Initialization ---
func _ready():
	hold_change_timer = hold_change_interval # Initialize timer
	add_to_group("players") # Keep player in group
	set_state(State.IDLE) # Initialize state properly
	animated_sprite.play("P%d_Idle" % player_index)
	
	# Validate input system on startup
	validate_input_system()

	if collection_area:
		collection_area.add_to_group("player_collectors")
	if stomp_area:
		stomp_area.add_to_group("player_stomp_areas")
	if vulnerable_area:
		vulnerable_area.add_to_group("player_vulnerable_areas")
		vulnerable_area.connect("area_entered", _on_vulnerable_area_area_entered)

	print("[DEBUG] Player", player_index, "assigned device:", device)

func setup_device(device_id: int):
	device = device_id
	var device_type = "Keyboard" if device == -1 else "Controller%d" % device
	var actions = get_input_actions()
	print("[DEBUG] Player%d assigned %s (device=%d): left='%s', right='%s', flap='%s'" % [player_index, device_type, device, actions["left"], actions["right"], actions["flap"]])
	
	# Validate MultiplayerInput is available
	if not MultiplayerInput:
		print("[ERROR] MultiplayerInput not found! Enable the multiplayer_input plugin in Project Settings.")

# Helper function to validate input system health
func validate_input_system() -> bool:
	if not MultiplayerInput:
		print("[ERROR] Player%d: MultiplayerInput plugin not available" % player_index)
		return false
	
	var actions = get_input_actions()
	for action_key in actions:
		var action_name = actions[action_key]
		if not InputMap.has_action(action_name):
			print("[ERROR] Player%d: Input action '%s' not found in InputMap" % [player_index, action_name])
			return false
	
	print("[INFO] Player%d: Input system validation passed" % player_index)
	return true

# --- State Management Helper ---
func set_state(new_state: State):
	if current_state == new_state: return # Avoid redundant transitions

	previous_state = current_state
	current_state = new_state
	print("Player entering state: ", State.keys()[current_state]) # Debugging

	# Logic executed ONLY on entering a state
	match new_state:
		State.IDLE:
			stop_audio()
			animated_sprite.play("P%d_Idle" % player_index)
			hold_change_timer = hold_change_interval # Reset hold timer
		State.WALKING:
			play_walking_audio()
			animated_sprite.play("P%d_Walk" % player_index)
			hold_change_timer = hold_change_interval # Reset hold timer
		State.FLYING:
			play_flying_audio()
			animated_sprite.play("P%d_Fly" % player_index)
			hold_change_timer = hold_change_interval # Reset hold timer
		State.BRAKING:
			# Keep walking audio playing during brake
			animated_sprite.play("P%d_Brake" % player_index)
			hold_change_timer = hold_change_interval # Reset hold timer

func get_input_actions():
	if player_index == 1:
		return {"left": "move_left", "right": "move_right", "flap": "flap"}
	elif player_index == 2:
		return {"left": "p2_move_left", "right": "p2_move_right", "flap": "p2_flap"}
	elif player_index == 3:
		return {"left": "p3_move_left", "right": "p3_move_right", "flap": "p3_flap"}
	elif player_index == 4:
		return {"left": "p4_move_left", "right": "p4_move_right", "flap": "p4_flap"}
	else:
		return {"left": "move_left", "right": "move_right", "flap": "flap"} # fallback

func get_input_this_frame() -> Dictionary:
	var actions = get_input_actions()
	var input_data = {
		"direction": MultiplayerInput.get_axis(device, actions["left"], actions["right"]),
		"flap_just_pressed": MultiplayerInput.is_action_just_pressed(device, actions["flap"]),
		"flap_held": MultiplayerInput.is_action_pressed(device, actions["flap"])
	}
	
	# Debug output (enable debug_input in inspector for testing)
	if debug_input and (input_data["direction"] != 0 or input_data["flap_just_pressed"]):
		print("[DEBUG] Player%d input: dir=%s, flap_press=%s (device=%d)" % [player_index, input_data["direction"], input_data["flap_just_pressed"], device])
	
	return input_data

# --- Main Physics Loop ---
func _physics_process(delta):
	# --- Input Handling ---
	var input_data = get_input_this_frame()
	var direction_input = input_data["direction"]
	var flap_input_just_pressed = input_data["flap_just_pressed"]
	var flap_input_held = input_data["flap_held"]

	if not is_alive:
		if current_state == State.DEFEATED:
			defeated_fly_time += delta
			defeated_time += delta
			# Sine wave: amplitude 30px, period 1.5s
			var sine_offset = 30.0 * sin(defeated_fly_time * 4.0)
			velocity.y += sine_offset * delta
			move_and_slide()
			# Check if player has left the screen horizontally
			var viewport_rect = get_viewport_rect().size
			if (defeated_fly_direction == 1 and global_position.x > viewport_rect.x + 50) or \
				(defeated_fly_direction == -1 and global_position.x < -50) or defeated_time > 3.0:
					if not is_respawning:
						is_respawning = true
						call_deferred("_start_respawn_timer")
		return

	if is_respawning or is_invincible:
		return

	# 2. Apply Gravity
	if not is_on_floor() or current_state == State.FLYING:
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed) # Apply max fall speed
	elif is_on_floor() and current_state != State.FLYING:
		# Ensure player stays grounded when walking/idle unless flapping
		velocity.y = max(velocity.y, 0) # Prevent accumulating negative velocity on floor

	# 3. Handle State Logic
	match current_state:
		State.IDLE:
			handle_idle_state(delta, direction_input, flap_input_just_pressed)
		State.WALKING:
			handle_walking_state(delta, direction_input, flap_input_just_pressed)
		State.FLYING:
			handle_flying_state(delta, direction_input, flap_input_just_pressed, flap_input_held)
		State.BRAKING:
			handle_braking_state(delta, direction_input)

	# 4. Apply Movement and Handle Collisions
	move_and_slide()

	# 5. Handle Specific Collision Responses (after move_and_slide)
	handle_collisions() # Check for wall bumps etc.

	# 6. Check for Automatic State Transitions (like landing)
	check_automatic_transitions()

	# 7. Update Audio based on current state and velocity/speed level
	update_audio()

	# 8. Screen Wrapping (moved after move_and_slide to use updated position)
	screen_wrapping()

func _start_respawn_timer():
	print("[DEBUG] _start_respawn_timer called")
	await get_tree().create_timer(2.0).timeout
	respawn()

# --- State Logic Functions ---
func handle_idle_state(delta, direction_input, flap_input_just_pressed):
	# Stop horizontal movement completely in idle
	velocity.x = move_toward(velocity.x, 0, 5000 * delta) # Apply high friction

	# Transition to Walking
	if direction_input != 0:
		transition_to_walking(direction_input)

	# Transition to Flying
	elif flap_input_just_pressed:
		transition_to_flying()

func handle_walking_state(delta, direction_input, flap_input_just_pressed):
	# Check for Flying Transition first
	if flap_input_just_pressed:
		transition_to_flying()
		return
	
	if not is_on_floor():
		set_state(State.FLYING)
		return # Exit this function immediately since we're no longer walking

	var actions = get_input_actions()
	var walking_speed_animation = {1: 1, 2: 1.4, 3: 1.8}
	var move_left_pressed = MultiplayerInput.is_action_just_pressed(device, actions["left"])
	var move_right_pressed = MultiplayerInput.is_action_just_pressed(device, actions["right"])
	var direction_just_pressed = move_left_pressed or move_right_pressed
	var target_velocity_x = 0.0

	if direction_input != 0:
		var facing_right = not animated_sprite.flip_h
		var input_is_right = direction_input > 0
		var input_matches_facing = (facing_right and input_is_right) or (not facing_right and not input_is_right)
		var original_facing_direction = 1.0 if facing_right else -1.0 # Store original direction

		if direction_just_pressed:
			if input_matches_facing:
				# Accelerate (Initial Press)
				current_speed_level = min(current_speed_level + 1, 3)
				animated_sprite.play("P%d_Walk" % player_index, walking_speed_animation[current_speed_level])
				target_velocity_x = original_facing_direction * speed_values[current_speed_level]
				hold_change_timer = hold_change_interval # Reset timer on initial press
			else:
				# --- Start Braking (Initial Press) ---
				direction_during_brake = int(original_facing_direction)
				current_speed_level = max(current_speed_level - 1, 0)
				brake_timer = brake_duration_per_level
				set_state(State.BRAKING)
				velocity.x = direction_during_brake * speed_values[current_speed_level]
				return # Exit handle_walking_state for this frame
		elif MultiplayerInput.is_action_pressed(device, actions["left"]) or MultiplayerInput.is_action_pressed(device, actions["right"]): # Check if holding
			if input_matches_facing:
				# --- Holding Logic (Acceleration) ---
				hold_change_timer -= delta
				if hold_change_timer <= 0:
					current_speed_level = min(current_speed_level + 1, 3)
					hold_change_timer = hold_change_interval # Reset timer
					print("[DEBUG] Walk Accel (Hold): New Level: ", current_speed_level) # DEBUG
			# Note: Holding opposite direction is handled by BRAKING state logic

		# Update sprite flip based on input (always happens if input != 0)
		animated_sprite.flip_h = direction_input < 0
		# Target velocity is calculated based on the current speed level and the direction the sprite is NOW facing
		target_velocity_x = (1.0 if not animated_sprite.flip_h else -1.0) * speed_values[current_speed_level]

	else: # No direction input
		hold_change_timer = hold_change_interval # Reset hold timer when input released
		# Stop horizontal movement if speed level is 0
		if current_speed_level == 0:
			target_velocity_x = 0.0
			# Transition to idle if velocity is near zero
			if is_zero_approx(velocity.x):
				transition_to_idle()
		else:
			# Keep moving at current speed level if input released (classic feel)
			target_velocity_x = (1.0 if not animated_sprite.flip_h else -1.0) * speed_values[current_speed_level]


	velocity.x = target_velocity_x # Instant speed change

	# Reset hold timer if input direction changes or is released
	if MultiplayerInput.is_action_just_released(device, actions["left"]) or MultiplayerInput.is_action_just_released(device, actions["right"]) or direction_input == 0:
		hold_change_timer = hold_change_interval

	# Check if fallen off an edge
	# If not on floor, gravity will take over (handled in _physics_process).
	# State remains WALKING (conceptually, falling after walking)
	# until flap is pressed or landing occurs.

func handle_flying_state(delta, direction_input, flap_input_just_pressed, flap_input_held):
	# Store original facing direction and movement direction
	var was_facing_right = not animated_sprite.flip_h
	var original_move_direction = sign(velocity.x)
	
	var actions = get_input_actions()
	
	# Fly animation if not floor / falling
	if not is_on_floor():
		animated_sprite.play("P%d_Fly" % player_index)
	
	# Flap animation triggered if flap input pressed or just pressed
	if flap_input_held:
		animated_sprite.play("P%d_Flap2" % player_index)
	else:
		animated_sprite.play("P%d_Fly" % player_index)
	
	# If stopped horizontally, use facing direction as the 'original' move direction
	if is_zero_approx(original_move_direction):
		original_move_direction = 1.0 if was_facing_right else -1.0

	# 1. Handle Sprite Flipping
	if direction_input != 0:
		# If direction input is held, face that direction
		animated_sprite.flip_h = direction_input < 0
	elif not is_zero_approx(velocity.x):
		# If no direction input, but moving horizontally, face movement direction
		animated_sprite.flip_h = velocity.x < 0
	# Else (no input and not moving horizontally), keep current facing direction

	# 2. Handle Flap Input (Vertical force & Horizontal logic)
	if flap_input_just_pressed:
		# Apply vertical force
		velocity.y = flap_force
		if flap_sound: flap_sound.play()

		# --- Initial Speed Change on Flap Press ---
		if direction_input != 0:
			var input_is_right = direction_input > 0
			var input_is_opposite = (original_move_direction > 0 and not input_is_right) or (original_move_direction < 0 and input_is_right)

			if input_is_opposite: # Decelerate
				current_speed_level = max(current_speed_level - 1, 0)
				velocity.x = original_move_direction * speed_values[current_speed_level]
				print("[DEBUG] Flying Decel (Press): New Level: ", current_speed_level) # DEBUG
			else: # Accelerate
				current_speed_level = min(current_speed_level + 1, 3)
				var current_facing_direction = 1.0 if not animated_sprite.flip_h else -1.0
				velocity.x = current_facing_direction * speed_values[current_speed_level]
				print("[DEBUG] Flying Accel (Press): New Level: ", current_speed_level) # DEBUG

			hold_change_timer = hold_change_interval # Reset timer after initial press change
		else:
			# Flap only (no direction input) - Maintain current horizontal velocity
			print("[DEBUG] Applying Flying Vel (Flap Only): Maintaining VelX=", velocity.x) # DEBUG
			hold_change_timer = hold_change_interval # Reset timer

	# 3. Handle Hold Logic (Only if Flapping AND Holding Direction)
	elif MultiplayerInput.is_action_pressed(device, actions["flap"]) and direction_input != 0:
		# --- Holding Logic (Acceleration/Deceleration) ---
		hold_change_timer -= delta
		if hold_change_timer <= 0:
			var input_is_right = direction_input > 0
			# Need to re-check original move direction relative to current input
			var current_original_move_direction = sign(velocity.x)
			if is_zero_approx(current_original_move_direction):
				current_original_move_direction = 1.0 if not animated_sprite.flip_h else -1.0

			var input_is_opposite = (current_original_move_direction > 0 and not input_is_right) or (current_original_move_direction < 0 and input_is_right)

			if input_is_opposite: # Decelerate
				current_speed_level = max(current_speed_level - 1, 0)
				velocity.x = current_original_move_direction * speed_values[current_speed_level]
				print("[DEBUG] Flying Decel (Hold): New Level: ", current_speed_level) # DEBUG
			else: # Accelerate
				current_speed_level = min(current_speed_level + 1, 3)
				var current_facing_direction = 1.0 if not animated_sprite.flip_h else -1.0
				velocity.x = current_facing_direction * speed_values[current_speed_level]
				print("[DEBUG] Flying Accel (Hold): New Level: ", current_speed_level) # DEBUG

			hold_change_timer = hold_change_interval # Reset timer after hold change

	# 4. Reset Hold Timer if Flap Released or No Direction Input while Flapping
	if MultiplayerInput.is_action_just_released(device, actions["flap"]) or (MultiplayerInput.is_action_pressed(device, actions["flap"]) and direction_input == 0):
		hold_change_timer = hold_change_interval


func handle_braking_state(delta, direction_input):
	# 1. If not on floor, immediately transition to flying
	if not is_on_floor():
		set_state(State.FLYING)
		return
	
	var actions = get_input_actions()
	
	# 2. If flap is pressed, immediately transition to flying
	if MultiplayerInput.is_action_just_pressed(device, actions["flap"]):
		transition_to_flying()
		return

	# Apply velocity based on the direction we were going when brake started
	# Ensure direction_during_brake is treated as float for multiplication
	velocity.x = float(direction_during_brake) * speed_values[current_speed_level]

	# Tick down timer
	brake_timer -= delta

	# Check for state change conditions
	if brake_timer <= 0:
		# Brake duration for this level finished
		# Check if the opposite direction is *still held* using is_action_pressed
		var opposite_direction_action = actions["left"] if direction_during_brake > 0 else actions["right"]
		var opposite_direction_pressed = MultiplayerInput.is_action_pressed(device, opposite_direction_action)

		if opposite_direction_pressed:
			if current_speed_level > 0:
				# --- Continue Braking (Loop) ---
				current_speed_level = max(current_speed_level - 1, 0)
				brake_timer = brake_duration_per_level # Reset timer for next level
				print("[DEBUG] Brake Loop: New Level: ", current_speed_level) # DEBUG
				# Velocity for next frame will be calculated at the start of the next handle_braking_state call
			else:
				# Braked to Speed 0, start walking in the new direction
				# Use the actual input axis value to determine the new walking direction
				var new_direction_input = MultiplayerInput.get_axis(device, actions["left"], actions["right"])
				transition_to_walking(new_direction_input)
		else:
			# Opposite key released during brake
			if current_speed_level == 0:
				transition_to_idle()
			else:
				# Transition back to walking, maintaining current speed and original brake direction
				transition_to_walking(float(direction_during_brake)) # Pass direction as float

	# Allow cancelling brake by pressing original direction again
	elif direction_input != 0 and sign(direction_input) == direction_during_brake:
		# If player presses original direction again, cancel brake immediately
		transition_to_walking(float(direction_during_brake)) # Pass direction as float

# --- Collision Handling ---

func handle_collisions():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if not collision: continue # Skip if collision data is invalid

		var collider = collision.get_collider()
		if not collider: continue

		# Player vs Player collision
		if collider.is_in_group("players"):
		   # Example: Bounce both players away from each other
			var direction_to_other = sign(global_position.x - collider.global_position.x)
			if direction_to_other == 0: direction_to_other = 1
			velocity.x = direction_to_other * side_collision_bounce_x
			velocity.y = side_collision_bounce_y
			animated_sprite.flip_h = velocity.x < 0
			current_speed_level = max(current_speed_level - 1, 0)
			if collision_sound: collision_sound.play()
		   # Optionally, also affect the other player if you want
			break

		# Check for wall bumps while walking
		if current_state == State.WALKING and (collider.is_in_group("Platform") or collider.is_in_group("players") or collider.is_in_group("enemies")):
			if abs(collision.get_normal().x) > 0.7: # Hit a vertical wall
				print("Player hit wall while walking")
				animated_sprite.flip_h = !animated_sprite.flip_h # Change direction
				velocity.x = 0 # Stop horizontal movement against wall
				current_speed_level = max(current_speed_level - 1, 0)
				if current_speed_level == 0:
					transition_to_idle()
				else:
					# Apply new velocity based on reduced speed level and new direction
					var facing_direction = 1.0 if not animated_sprite.flip_h else -1.0
					velocity.x = facing_direction * speed_values[current_speed_level]

				if collision_sound: collision_sound.play()
				break # Handle only one wall collision per frame

# --- Automatic State Transitions ---

func check_automatic_transitions():
	# Check for landing while in Flying state
	# If we are flying and detect being on the floor, transition to walking.
	if current_state == State.FLYING and is_on_floor():
			# print("Landing detected: Transitioning to WALKING") # Debug print
		transition_to_walking()

# --- State Transition Functions ---

func transition_to_idle():
	if current_state == State.IDLE: return
	set_state(State.IDLE)
	current_speed_level = 0
	# Let friction handle stopping in handle_idle_state

func transition_to_walking(initial_direction = 0.0):
	if current_state == State.WALKING: return
	set_state(State.WALKING)

	if previous_state == State.IDLE:
		current_speed_level = 1
		if initial_direction != 0.0:
			animated_sprite.flip_h = initial_direction < 0
			velocity.x = initial_direction * speed_values[current_speed_level]
	elif previous_state == State.FLYING or previous_state == State.BRAKING: # Also handle transition from BRAKING
		# Speed level preserved from flying/braking state
		var facing_direction = 1.0 if not animated_sprite.flip_h else -1.0
		# If initial_direction is provided (e.g., from braking finish), use that
		if initial_direction != 0.0:
			facing_direction = sign(initial_direction)
			animated_sprite.flip_h = facing_direction < 0
		velocity.x = facing_direction * speed_values[current_speed_level]


	velocity.y = 0 # Ensure vertical velocity is zeroed

func transition_to_flying():
	if current_state == State.FLYING: return
	set_state(State.FLYING)

	if previous_state == State.IDLE:
		current_speed_level = 0
		velocity.x = 0

	# Apply initial flap force ONLY if transitioning from a grounded state
	if previous_state == State.IDLE or previous_state == State.WALKING or previous_state == State.BRAKING:
		velocity.y = flap_force
		# Play flap sound here as well, since handle_flying_state might not run before landing check
		if flap_sound: flap_sound.play()


# --- Audio Implementation ---

func update_audio():
	# Walking Audio
	var walking_audio_should_play = (current_state == State.WALKING and current_speed_level > 0 and is_on_floor())
	if walking_audio and walking_audio.is_valid(): # Check if node exists and is valid
		if walking_audio_should_play:
			if not walking_audio.playing:
				walking_audio.play()
			var target_pitch = 1.0 + (current_speed_level * 0.2) # Example pitch scaling
			walking_audio.pitch_scale = target_pitch
		else:
			if walking_audio.playing:
				walking_audio.stop()

	# Flying Audio
	var flying_audio_should_play = (current_state == State.FLYING)
	if flying_audio and flying_audio.is_valid():
		if flying_audio_should_play:
			if not flying_audio.playing:
				flying_audio.play()
		else:
			if flying_audio.playing:
				flying_audio.stop()

func play_walking_audio():
	if flying_audio and flying_audio.is_valid() and flying_audio.playing: flying_audio.stop()
	# Actual play handled by update_audio

func play_flying_audio():
	if walking_audio and walking_audio.is_valid() and walking_audio.playing: walking_audio.stop()
	# Actual play handled by update_audio

func stop_audio():
	if walking_audio and walking_audio.is_valid() and walking_audio.playing: walking_audio.stop()
	if flying_audio and flying_audio.is_valid() and flying_audio.playing: flying_audio.stop()

# --- Screen Wrapping ---
func screen_wrapping():
	var viewport_rect = get_viewport_rect().size
	if global_position.x < -screen_wrap_buffer: # Check beyond buffer
		global_position.x = viewport_rect.x + screen_wrap_buffer
	elif global_position.x > viewport_rect.x + screen_wrap_buffer:
		global_position.x = -screen_wrap_buffer


# --- Combat / Interaction Logic ---

func _on_combat_area_area_entered(area):
	if not is_alive: return

	# Player vs Enemy Collision
	if area.is_in_group("enemy_combat_areas"):
		var enemy = area.get_parent()
		if not enemy or not enemy.is_in_group("enemies"): return # Use Enemy group

		# Skip if enemy is in egg/hatching state
		if "current_state" in enemy and "State" in enemy and \
			(enemy.current_state == enemy.State.EGG or enemy.current_state == enemy.State.HATCHING):
			return

		# --- Joust Logic ---
		var enemy_velocity_y = enemy.velocity.y if "velocity" in enemy else 0.0
		var relative_velocity_y = velocity.y - enemy_velocity_y

		if relative_velocity_y > collision_y_threshold: # Player moving down relative to enemy
			# Check if stomp area is overlapping enemy vulnerable area
			var is_stomping = false
			if stomp_area:
				for overlapping_area in stomp_area.get_overlapping_areas():
					if overlapping_area.is_in_group("enemy_vulnerable_areas") and overlapping_area.get_parent() == enemy:
						is_stomping = true
						break
			if not is_stomping:
				print("Player lost joust")
				die()
			# else: Stomp success handled by _on_stomp_area_area_entered

		elif relative_velocity_y < -collision_y_threshold: # Player moving up relative to enemy
			# Player wins joust - bounce handled by _on_stomp_area_area_entered
			print("Player won joust (velocity check)")
			# velocity.y = joust_bounce_velocity # Bounce is applied in stomp handler

		else:
			# --- Side Collision / Bounce ---
			print("Side collision player vs enemy")
			var direction_to_enemy = sign(global_position.x - enemy.global_position.x)
			if direction_to_enemy == 0: direction_to_enemy = 1

			# Player bounces
			velocity.x = direction_to_enemy * side_collision_bounce_x
			velocity.y = side_collision_bounce_y
			animated_sprite.flip_h = velocity.x < 0
			current_speed_level = max(current_speed_level - 1, 0)
			if current_speed_level == 0:
				transition_to_idle()
			else: # Need to ensure state is correct if bounced while flying/idle
				if current_state == State.FLYING: # If bounced while flying, stay flying? Or force walk?
					pass # Keep flying state, velocity updated
				else: # If bounced while idle or walking
					transition_to_walking(sign(velocity.x))


			# Tell enemy to handle bounce
			if enemy.has_method("handle_bounce"):
				enemy.handle_bounce(-direction_to_enemy, side_collision_bounce_x, side_collision_bounce_y)

			if collision_sound: collision_sound.play()

	# Player vs Platform Collision (Handled by handle_collisions using move_and_slide results)
	# elif area.is_in_group("Platform"):
	#	 pass # Wall bump logic is now in handle_collisions


func _on_stomp_area_area_entered(area):
	if not is_alive: return

	if area.is_in_group("enemy_vulnerable_areas"):
		var enemy = area.get_parent()
		if not enemy or not enemy.is_in_group("Enemy"): return

		# Skip if enemy is already defeated
		if "current_state" in enemy and "State" in enemy and \
			(enemy.current_state == enemy.State.EGG or enemy.current_state == enemy.State.HATCHING or enemy.current_state == enemy.State.DEAD):
			return

		print("Player stomp successful (signal)")
		velocity.y = joust_bounce_velocity # Apply bounce on successful stomp
		# Enemy handles its own defeat via its _on_vulnerable_area_area_entered signal

func _on_vulnerable_area_area_entered(area):
	if not is_alive or is_invincible:
		return
		
	if area.is_in_group("enemy_stomp_areas"):
		var enemy = area.get_parent()
		if not enemy or not enemy.is_in_group("enemies"): return

		print("Player was stomped by enemy!")
		die() # Or lose_life(player_index)

func _on_collection_area_area_entered(area):
	if not is_alive: return

	# Collect Eggs
	if area.is_in_group("egg_collection_zones"):
		var parent = area.get_parent()
		if parent and parent.is_in_group("enemies") and "current_state" in parent and "State" in parent and parent.has_method("collect_egg"):
			if parent.current_state == parent.State.EGG or parent.current_state == parent.State.HATCHING:
				print("Player collected egg")
				parent.collect_egg(player_index)

	# Add logic for other collectibles here


# --- Death and Respawn ---

func die():
	defeated_time = 0.0
	if not is_alive or is_invincible: return
	print("[DEBUG] die called")
	is_alive = false
	set_state(State.DEFEATED)
	
	# Play defeated animation
	animated_sprite.play("P%d_defeated" % player_index)
	
	# Disable collisions (optional: or set collision mask/layer to 0)
	set_collision_layer(0)
	set_collision_mask(0)
	
	# Set fly-off velocity 
	var fly_direction = -1 if global_position.x > get_viewport_rect().size.x / 2 else 1
	defeated_fly_time = 0.0
	defeated_fly_direction = fly_direction
	velocity = Vector2(fly_direction * 300, 0)
	animated_sprite.flip_h = fly_direction < 0

	# Notify game manager (ensure ScoreManager exists and has lose_life)
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager and score_manager.has_method("lose_life"):
		score_manager.lose_life(player_index)
	else:
		print("Error: ScoreManager or lose_life method not found!")


func respawn():
	print("[DEBUG] respawn called")
	is_alive = true
	is_invincible = true
	is_respawning = true
	set_state(State.IDLE)
	# Find valid spawn point only ONCE
	var spawn_point = null
	var spawn_points = get_tree().get_nodes_in_group("SpawnPoints")
	if spawn_points.size() > 0:
		spawn_point = spawn_points[randi() % spawn_points.size()]
	if spawn_point:
		global_position = spawn_point.global_position
	else:
		global_position = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y - 100)
   
	velocity = Vector2.ZERO
	set_collision_layer(1) # Restore to normal
	set_collision_mask(2)
	var anim_name = "P%d_spawn" % player_index
	print("[DEBUG] Playing respawn animation:", anim_name)
	print("[DEBUG] Available animations:", animated_sprite.sprite_frames.get_animation_names())
	animated_sprite.play(anim_name)
	set_physics_process(true) # Resume physics processing
		# Disconnect previous to avoid duplicate connections
	# if animated_sprite.is_connected("animation_finished", _on_respawn_animation_finished):
	# 	print("[DEBUG] Disconnecting previous animation_finished signal")
	# 	animated_sprite.disconnect("animation_finished", _on_respawn_animation_finished)
	# print("[DEBUG] Connecting animation_finished signal")
	# animated_sprite.connect("animation_finished", _on_respawn_animation_finished)

	# Fallback: Timer in case signal doesn't fire
	var frame_count = animated_sprite.sprite_frames.get_frame_count(anim_name)
	var fps = animated_sprite.sprite_frames.get_animation_speed(anim_name)
	var anim_length = 0.0
	if fps > 0:
		anim_length = frame_count / fps
	else:
		anim_length = 0.5 # fallback if FPS is zero
	await get_tree().create_timer(anim_length + 0.1).timeout
	if is_respawning:
		print("[DEBUG] Fallback: Forcing respawn end after animation duration")
		_on_respawn_animation_finished(anim_name)
	
# --- Animation Finished Callback for Respawn ---
func _on_respawn_animation_finished(anim_name):
	print("[DEBUG] _on_respawn_animation_finished called with anim_name:", anim_name)
	if anim_name == "P%d_spawn" % player_index:
		is_invincible = false
		is_respawning = false
		print("[DEBUG] Respawn animation finished, player can move again")
		# Optionally, transition to idle/walk animation here
		animated_sprite.disconnect("animation_finished", _on_respawn_animation_finished)
