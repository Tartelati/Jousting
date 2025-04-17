Okay, here is the revised implementation guide incorporating the improvements and aligning more closely with the documentation using Godot 4.4 practices (`CharacterBody2D`, `_physics_process`, `move_and_slide`).

--- START OF FILE improved-movement-implementation-guide.md ---

# Improved Implementation Guide: Movement System Rework (Godot 4.4)

This guide outlines the implementation steps for the redesigned movement system using Godot 4.4's `CharacterBody2D` and best practices, based on the `movement-system-documentation.md` file.

## Preparation

1.  **Back up your project** before beginning implementation.
2.  Ensure your Player scene's root node is a `CharacterBody2D`.
3.  Identify necessary child nodes (e.g., `Sprite2D`, `AnimationPlayer`, `AudioStreamPlayer` nodes for walking/flying sounds) and update paths in the script accordingly.
4.  Define input actions in Project Settings -> Input Map (e.g., `move_left`, `move_right`, `flap`).
5.  Assign relevant nodes (Enemies, Platforms) to appropriate groups (e.g., "Enemy", "Platform") for collision detection.

## Step 1: Core Script Setup (`CharacterBody2D`)

```gdscript
extends CharacterBody2D

# --- States Enum ---
enum State { IDLE, WALKING, FLYING }

# --- State Variables ---
var current_state : State = State.IDLE
var previous_state : State = State.IDLE # Track previous state for transitions

# --- Movement Parameters ---
@export var speed_values : Array[float] = [0.0, 100.0, 200.0, 300.0] # Index 0 = Idle, 1-3 = Speed Levels
var current_speed_level : int = 0

@export var gravity : float = ProjectSettings.get_setting("physics/2d/default_gravity")
# Optional: Use different gravity multiplier while flying if needed
# @export var flying_gravity_multiplier : float = 1.0
@export var flap_force : float = -300.0 # Negative value for upward force

# --- Node References (Update paths as needed) ---
@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer
@onready var walking_audio = $WalkingAudioPlayer
@onready var flying_audio = $FlyingAudioPlayer
# @onready var flap_sfx = $FlapSoundPlayer # Example for specific SFX

# --- Internal Variables ---
# Optional: Add acceleration/deceleration rates if not instant speed changes
# @export var walk_acceleration : float = 1500.0
# @export var friction : float = 1000.0

func _ready():
	# Initialize state properly on scene start
	set_state(State.IDLE)

# --- State Management Helper ---
func set_state(new_state: State):
	if current_state == new_state: return # Avoid redundant transitions

	previous_state = current_state
	current_state = new_state
	# print("Entering state: ", State.keys()[current_state]) # Debugging

	# Optional: Add specific logic executed ONLY on entering a state here
	match new_state:
		State.IDLE:
			stop_audio()
		State.WALKING:
			play_walking_audio()
		State.FLYING:
			play_flying_audio()
```

## Step 2: Main Physics Loop (`_physics_process`)

```gdscript
func _physics_process(delta):
	# 1. Gather Input
	var direction_input = Input.get_axis("move_left", "move_right")
	var flap_input_pressed = Input.is_action_just_pressed("flap")
	# var flap_input_held = Input.is_action_pressed("flap") # Might be useful later

	# 2. Apply Gravity
	# Gravity affects flying state constantly as per docs
	if not is_on_floor() or current_state == State.FLYING:
		# Optional: Apply different gravity multiplier if needed
		# var effective_gravity = gravity * flying_gravity_multiplier if current_state == State.FLYING else gravity
		velocity.y += gravity * delta

	# 3. Handle State Logic (updates velocity and state transitions based on input)
	match current_state:
		State.IDLE:
			handle_idle_state(direction_input, flap_input_pressed)
		State.WALKING:
			handle_walking_state(delta, direction_input, flap_input_pressed)
		State.FLYING:
			handle_flying_state(delta, direction_input, flap_input_pressed)

	# 4. Apply Movement and Handle Collisions
	move_and_slide()

	# 5. Handle Specific Collision Responses (after move_and_slide)
	handle_collisions() # Check for wall bumps etc.

	# 6. Check for Automatic State Transitions (like landing)
	check_automatic_transitions()

	# 7. Update Animation & Audio based on current state and velocity/speed level
	update_animation()
	update_audio()
```

## Step 3: Idle State Logic

```gdscript
func handle_idle_state(direction_input, flap_input_pressed):
	# Stop horizontal movement completely in idle
	velocity.x = move_toward(velocity.x, 0, 5000 * delta) # Apply high friction to stop quickly if needed

	# Transition to Walking
	if direction_input != 0:
		transition_to_walking(direction_input) # Pass direction for initial facing
		# Initial velocity applied within transition function

	# Transition to Flying
	elif flap_input_pressed: # Use elif to prevent walk+flap in same frame from idle
		transition_to_flying()
```

## Step 4: Walking State Logic

```gdscript
func handle_walking_state(delta, direction_input, flap_input_pressed):
	# Check for Flying Transition first
	if flap_input_pressed:
		transition_to_flying() # Speed level preserved in transition function
		return # Exit early, state changed

	var move_left_pressed = Input.is_action_just_pressed("move_left")
	var move_right_pressed = Input.is_action_just_pressed("move_right")
	var direction_just_pressed = move_left_pressed or move_right_pressed
	var target_velocity_x = 0.0

	if direction_input != 0:
		# Determine if input matches facing direction
		# Note: Adjust 'sprite.flip_h' logic based on your sprite's default orientation
		var facing_right = !sprite.flip_h
		var input_is_right = direction_input > 0
		var input_matches_facing = (facing_right and input_is_right) or (not facing_right and not input_is_right)

		if direction_just_pressed: # Only change speed level on a new press
			if input_matches_facing:
				# Accelerate (Increase speed level)
				current_speed_level = min(current_speed_level + 1, 3)
			else:
				# Decelerate (Decrease speed level - opposite direction pressed)
				current_speed_level = max(current_speed_level - 1, 0)
				play_deceleration_animation() # Trigger deceleration animation

				if current_speed_level == 0:
					# Transition to Idle if speed level drops to 0 via opposite input
					transition_to_idle()
					return # Exit early, state changed

		# Always update facing direction if there's input
		sprite.flip_h = direction_input < 0

		# Calculate target horizontal velocity based on current speed level
		target_velocity_x = direction_input * speed_values[current_speed_level]

	else: # No direction input
		# Player stops moving horizontally.
		# If you want gradual deceleration when input is released, implement it here.
		# For now, follow doc implication that speed level only changes on input *press*.
		target_velocity_x = 0.0
		# If stopped completely, transition to idle
		if is_zero_approx(velocity.x) and current_speed_level == 0:
			 transition_to_idle()

	# Apply horizontal velocity (can use lerp or move_toward for smoother feel)
	# velocity.x = lerp(velocity.x, target_velocity_x, walk_acceleration * delta)
	velocity.x = target_velocity_x # Instant speed change based on level

	# Check if fallen off an edge
	if not is_on_floor():
		transition_to_flying() # Treat falling as entering flying state
```

## Step 5: Flying State Logic

```gdscript
func handle_flying_state(delta, direction_input, flap_input_pressed):
	# 1. Handle Vertical Movement (Flapping)
	if flap_input_pressed:
		velocity.y = flap_force # Apply upward impulse
		# if flap_sfx: flap_sfx.play() # Play flap sound effect

	# 2. Handle Sprite Flipping (Based on direction input alone)
	if direction_input != 0:
		sprite.flip_h = direction_input < 0

	# 3. Handle Horizontal Speed Changes (Requires Flap + Direction)
	var effective_direction = 1.0 if not sprite.flip_h else -1.0
	var horizontal_speed_changed = false

	if flap_input_pressed and direction_input != 0:
		# Determine if input matches facing direction
		var facing_right = !sprite.flip_h
		var input_is_right = direction_input > 0
		var input_matches_facing = (facing_right and input_is_right) or (not facing_right and not input_is_right)

		if input_matches_facing:
			# Accelerate while flapping in facing direction
			current_speed_level = min(current_speed_level + 1, 3)
			horizontal_speed_changed = true
		else:
			# Decelerate while flapping in opposite direction
			current_speed_level = max(current_speed_level - 1, 0)
			horizontal_speed_changed = true
			# Optional: Play deceleration/turn animation/sound?

	# 4. Apply Horizontal Velocity
	# Horizontal velocity persists based on current_speed_level unless changed by flap+direction.
	# If speed level was changed this frame, update velocity immediately.
	# Otherwise, maintain velocity based on the existing speed level.
	velocity.x = effective_direction * speed_values[current_speed_level]
```

## Step 6: Automatic State Transitions (Landing)

```gdscript
func check_automatic_transitions():
	# Check for landing while in Flying state
	if current_state == State.FLYING and is_on_floor():
		# Docs: "preserves current flying horizontal speed level"
		transition_to_walking() # Speed level is preserved automatically
```

## Step 7: Collision Handling (Wall Bumps)

```gdscript
func handle_collisions():
	# Check collisions after move_and_slide()
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if not collider: continue # Skip if collider is invalid

		# Check if colliding with an Enemy or Platform (use groups)
		var is_standard_obstacle = collider.is_in_group("Enemy") or collider.is_in_group("Platform")

		# Ignore collisions handled by specific areas (e.g., StompArea, VulnerableArea - assuming they are Area2Ds)
		# If Stomp/Vulnerable are part of the main collision shape, more complex logic needed here.

		if is_standard_obstacle and current_state == State.WALKING:
			# Check if it's a horizontal collision (wall bump)
			# Normal points away from the wall collided with. X component will be +/- 1 for vertical walls.
			if abs(collision.get_normal().x) > 0.7: # Adjust threshold if needed
				# Player collision response:
				# 1. Change Direction (Flip Sprite)
				sprite.flip_h = !sprite.flip_h
				# 2. Reverse Horizontal Velocity (Bounce slightly) - Optional
				# velocity.x = collision.get_normal().x * bounce_speed # Needs bounce_speed var
				# OR just stop horizontal movement against the wall:
				velocity.x = 0

				# 3. Reduce Speed Level by one
				current_speed_level = max(current_speed_level - 1, 0) # Min level is 0 (Idle)

				# 4. Transition to Idle if speed becomes 0 due to collision
				if current_speed_level == 0:
					transition_to_idle()
				# else:
					# velocity.x = (-direction_input or sign(velocity.x)) * speed_values[current_speed_level] # Update velocity if not idle?

				# Stop checking collisions for this frame after handling one wall bump
				break

	# Note: Enemy collision behavior (flip direction, maintain speed)
	# should be implemented in the Enemy's script. The enemy script would
	# check if get_slide_collision(i).get_collider() is the Player or another Enemy/Platform.
```

## Step 8: State Transition Functions

```gdscript
func transition_to_idle():
	if current_state == State.IDLE: return
	set_state(State.IDLE)
	current_speed_level = 0
	# velocity.x = 0 # Let friction handle stopping in _physics_process
	# Ensure audio stops (handled in set_state or update_audio)

func transition_to_walking(initial_direction = 0.0):
	# Called from IDLE or FLYING (landing)
	if current_state == State.WALKING: return
	set_state(State.WALKING)

	if previous_state == State.IDLE:
		current_speed_level = 1 # Start at speed 1 from idle
		if initial_direction != 0.0:
			sprite.flip_h = initial_direction < 0
			# Apply initial velocity for immediate movement feel
			velocity.x = initial_direction * speed_values[current_speed_level]
	# If previous_state == State.FLYING, speed level is preserved automatically.
	# Ensure horizontal velocity matches preserved speed level on landing.
	elif previous_state == State.FLYING:
		 var facing_direction = 1.0 if not sprite.flip_h else -1.0
		 velocity.x = facing_direction * speed_values[current_speed_level]


	velocity.y = 0 # Ensure vertical velocity is zeroed on landing/starting walk
	# Ensure audio starts (handled in set_state or update_audio)

func transition_to_flying():
	# Called from IDLE or WALKING
	if current_state == State.FLYING: return
	set_state(State.FLYING)

	if previous_state == State.IDLE:
		current_speed_level = 0 # Start flying with 0 horizontal speed level from idle
		velocity.x = 0 # Explicitly set horizontal velocity to 0

	# If previous_state == State.WALKING, speed level is preserved automatically
	# Velocity x based on the preserved speed level will be applied in the flying state logic.

	# Optional: Give initial small upward boost even without flap?
	# velocity.y = min(velocity.y, flap_force * 0.5)

	# Ensure audio starts (handled in set_state or update_audio)
```

## Step 9: Audio Implementation

```gdscript
func update_audio():
	# --- Walking Audio ---
	var walking_audio_should_play = (current_state == State.WALKING and current_speed_level > 0 and is_on_floor())

	if walking_audio_should_play:
		if not walking_audio.playing:
			walking_audio.play()

		# Adjust pitch based on speed level (1, 2, 3)
		var target_pitch = 1.0
		if current_speed_level == 1: target_pitch = 1.0
		elif current_speed_level == 2: target_pitch = 1.2 # Example value
		elif current_speed_level == 3: target_pitch = 1.4 # Example value
		# Smooth pitch changes if desired:
		# walking_audio.pitch_scale = lerp(walking_audio.pitch_scale, target_pitch, delta * 10.0)
		walking_audio.pitch_scale = target_pitch
	else:
		if walking_audio.playing:
			walking_audio.stop()

	# --- Flying Audio ---
	var flying_audio_should_play = (current_state == State.FLYING)

	if flying_audio_should_play:
		if not flying_audio.playing:
			# Assuming flying_audio is a looping wind/hover sound
			flying_audio.play()
		# Add logic for specific flying speed/action sounds here if needed
		# e.g., change volume/pitch based on speed_level or velocity.y
	else:
		if flying_audio.playing:
			flying_audio.stop()

# --- Helper functions (called by state transitions mostly) ---
func play_walking_audio():
	if flying_audio.playing: flying_audio.stop()
	# Play is handled by update_audio based on speed level

func play_flying_audio():
	if walking_audio.playing: walking_audio.stop()
	# Play is handled by update_audio

func stop_audio():
	if walking_audio.playing: walking_audio.stop()
	if flying_audio.playing: flying_audio.stop()
```

## Step 10: Animation Implementation

```gdscript
func update_animation():
	if not animation_player or not animation_player.is_valid(): return # Guard clause

	var anim_name = "idle" # Default animation

	match current_state:
		State.IDLE:
			anim_name = "idle"
		State.WALKING:
			if not is_on_floor(): # Should transition to FLYING state, but as fallback show fall anim
				anim_name = "fall" # Or "fly"
			elif current_speed_level > 0:
				# Assumes animations named "walk_1", "walk_2", "walk_3" exist
				anim_name = "walk_" + str(current_speed_level)
			else:
				anim_name = "idle" # Show idle if walking state but speed level is 0
		State.FLYING:
			# Use different animations for rising/falling if available
			if velocity.y < -5: # Moving up significantly (adjust threshold)
				anim_name = "fly_up" # Or just "fly" / "flap"
			elif velocity.y > 5: # Falling significantly
				anim_name = "fall" # Or just "fly"
			else: # Near zero vertical velocity
			 	anim_name = "fly_hover" # Or just "fly"

	# Play the animation only if it's different from the current one
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

func play_deceleration_animation():
	# Called specifically when opposite direction input causes deceleration
	if animation_player and animation_player.is_valid():
		# Play a short, specific animation. Might need priority or interrupt logic.
		animation_player.play("decelerate") # Assumes "decelerate" animation exists
```

## Testing

1.  Implement each state and test its core mechanics individually (movement, speed changes).
2.  Thoroughly test state transitions:
    *   Idle -> Walking (starts Speed 1)
    *   Idle -> Flying (flap input, starts Speed 0 horizontal)
    *   Walking -> Flying (flap input, preserves speed level)
    *   Flying -> Walking (landing on platform, preserves speed level)
    *   Walking/Flying -> Idle (speed level becomes 0 via input or collision)
3.  Verify audio feedback: walking sound starts/stops correctly, pitch scales with speed, flying sound plays.
4.  Test collision handling: Player bumps wall -> flips direction, speed reduces, transitions to idle if speed becomes 0.
5.  Implement and test enemy collision behavior separately (Enemy flips direction, maintains speed).
6.  Fine-tune parameters (`speed_values`, `gravity`, `flap_force`, audio pitch multipliers, animation speeds) for optimal game feel.
7.  Check edge cases (spamming inputs, collision at corners, etc.).

## Final Notes

*   This guide assumes instant speed changes based on levels. Replace direct velocity assignments with `move_toward` or `lerp` if smooth acceleration/deceleration *within* a speed level is desired.
*   Remember to create the corresponding animations ("idle", "walk_1", "walk_2", "walk_3", "fly", "fall", "decelerate", etc.) in your `AnimationPlayer`.
*   Adjust node paths (`$Sprite2D`, `$AnimationPlayer`, etc.) to match your scene structure.
*   Use groups effectively for collision detection ("Enemy", "Platform").
*   Consider adding coyote time (allowing jumps shortly after leaving a ledge) and jump buffering (registering jump input slightly before landing) for better platforming feel if applicable, though this guide focuses purely on the documented system.

--- END OF FILE improved-movement-implementation-guide.md ---