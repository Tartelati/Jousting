class_name PowerEgg
extends RigidBody2D

# Power egg properties
@export var power_type: int = 0  # 0 = INVINCIBILITY (PowerManager.PowerType.INVINCIBILITY)
@export var collection_points: int = 200
@export var timeout_duration: float = 15.0

# Physics properties (same as normal eggs)
@export var egg_bounce_damping: float = 0.7
@export var egg_horizontal_damping: float = 0.8
@export var egg_min_bounce_velocity: float = 50.0
@export var egg_settling_threshold: float = 10.0

# Visual components
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var glow_effect: AnimatedSprite2D = $GlowEffect
@onready var collection_area: Area2D = $CollectionArea
@onready var spawn_effect: GPUParticles2D = $SpawnEffect
@onready var timeout_timer: Timer = $TimeoutTimer

# Audio components
@onready var spawn_sound: AudioStreamPlayer2D = $SpawnSound
@onready var collection_sound: AudioStreamPlayer2D = $CollectionSound

# State tracking
var is_collected: bool = false
var spawn_time: float
var egg_has_touched_ground: bool = false
var egg_is_bouncing: bool = false
var egg_bounce_count: int = 0

func _ready():
	add_to_group("power_eggs")
	spawn_time = Time.get_time_dict_from_system().unix
	
	_setup_visual_appearance()
	_setup_physics_properties()
	_setup_collection_detection()
	_start_timeout_timer()
	_play_spawn_effects()

func _setup_visual_appearance():
	# Set power-specific visual properties
	match power_type:
		0:  # INVINCIBILITY
			if sprite:
				sprite.modulate = Color(1.0, 0.8, 0.3)  # Golden color
				sprite.play("default")
			if glow_effect:
				glow_effect.modulate = Color(1.0, 0.9, 0.4, 0.8)  # Golden glow
				glow_effect.play("glow")
				# Create pulsing glow effect
				var tween = create_tween()
				tween.set_loops()
				tween.tween_property(glow_effect, "modulate:a", 0.4, 1.0)
				tween.tween_property(glow_effect, "modulate:a", 0.8, 1.0)

func _setup_physics_properties():
	# Set same physics properties as normal eggs
	gravity_scale = 1.0
	mass = 1.0
	
	# Set collision layers - same as normal eggs
	# Layer 4 = egg, Mask 2 = environment (platforms)
	collision_layer = 16  # Layer 4 (egg) = 2^4 = 16
	collision_mask = 6    # Layer 2 (environment) = 2^2 = 4, Layer 1 (player) = 2^1 = 2, so 4+2 = 6
	
	# Enable contact monitoring for bouncing
	contact_monitor = true
	max_contacts_reported = 10

func _setup_collection_detection():
	if collection_area:
		collection_area.add_to_group("power_egg_collection_zones")
		collection_area.connect("area_entered", _on_collection_area_entered)
		collection_area.monitoring = true
		collection_area.monitorable = true
		
		# Set collection area collision
		# Layer 5 = pickup (egg collection) = 2^5 = 32
		# Mask 5 = pickup (egg collection) = 2^5 = 32 (to detect player collectors)
		collection_area.collision_layer = 32  # Layer 5 (pickup)
		collection_area.collision_mask = 32   # Mask 5 (pickup) to detect player collectors

func _start_timeout_timer():
	if timeout_timer:
		timeout_timer.wait_time = timeout_duration
		timeout_timer.timeout.connect(_on_timeout)
		timeout_timer.start()

func _play_spawn_effects():
	# Play spawn sound through PowerManager for consistency
	var power_manager = get_node_or_null("/root/PowerManager")
	if power_manager and power_manager.has_method("play_power_spawn_sound"):
		power_manager.play_power_spawn_sound()
	elif spawn_sound:
		# Fallback to local sound if PowerManager not available
		spawn_sound.play()
	
	if spawn_effect:
		spawn_effect.emitting = true
		# Configure spawn particles for power egg
		spawn_effect.amount = 30
		spawn_effect.lifetime = 2.0
		var particle_material = spawn_effect.process_material as ParticleProcessMaterial
		if particle_material:
			particle_material.emission.set_param_min(20.0)
			particle_material.emission.set_param_max(40.0)
			particle_material.initial_velocity_min = 30.0
			particle_material.initial_velocity_max = 80.0
			particle_material.scale_min = 0.3
			particle_material.scale_max = 1.0
			particle_material.color = Color(1.0, 0.9, 0.4, 1.0)  # Golden particles

func _physics_process(delta):
	if is_collected:
		return
	
	# Handle bouncing physics (same as normal eggs)
	_handle_bouncing()
	
	# Apply horizontal damping over time (air resistance)
	linear_velocity.x = move_toward(linear_velocity.x, 0, 20 * delta)

func _handle_bouncing():
	# Check if we're on the ground
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, 10)
	)
	query.collision_mask = 2  # Environment layer
	var result = space_state.intersect_ray(query)
	
	var is_on_ground = result != null
	
	if is_on_ground:
		if not egg_has_touched_ground:
			egg_has_touched_ground = true
		
		# Check if we should bounce
		if abs(linear_velocity.y) > egg_min_bounce_velocity and egg_bounce_count < 5:
			# Apply bounce
			linear_velocity.y = -linear_velocity.y * egg_bounce_damping
			linear_velocity.x *= egg_horizontal_damping
			egg_is_bouncing = true
			egg_bounce_count += 1
		else:
			# Stop bouncing - egg has settled
			if egg_is_bouncing:
				egg_is_bouncing = false
				linear_velocity = Vector2.ZERO

func _on_collection_area_entered(area):
	if is_collected:
		return
	
	print("[DEBUG POWER EGG] Collection area entered by: %s (groups: %s)" % [area.name, area.get_groups()])
	
	if area.is_in_group("player_collectors"):
		var player = area.get_parent()
		if player and player.is_in_group("players") and player.has_method("get") and "player_index" in player:
			var player_index = player.player_index
			print("[DEBUG POWER EGG] Collecting power egg for player %d" % player_index)
			
			# Ensure first-touch wins by immediately setting collected flag
			if not is_collected:
				is_collected = true
				collect(player_index)

func collect(player_index: int):
	# Double-check collection state for thread safety
	if is_collected:
		return
	
	print("[DEBUG POWER EGG] PowerEgg collected by player %d" % player_index)
	
	# Immediately disable collection area to prevent double collection
	if collection_area:
		collection_area.monitoring = false
		collection_area.monitorable = false
	
	_play_collection_effects()
	_award_points(player_index)
	_activate_power(player_index)
	_cleanup()

func _play_collection_effects():
	# Play collection sound with proper power egg collection audio
	if collection_sound:
		# Load and play power egg collection sound
		var collection_audio = load("res://assets/sounds/sfx/power_egg_collect.wav")
		if collection_audio:
			collection_sound.stream = collection_audio
			collection_sound.volume_db = -2.0
			collection_sound.pitch_scale = 1.2  # Slightly higher pitch for satisfying pickup
		collection_sound.play()
	
	# Create collection burst effect
	if spawn_effect:
		spawn_effect.emitting = false
		spawn_effect.amount = 60
		var particle_material = spawn_effect.process_material as ParticleProcessMaterial
		if particle_material:
			# Configure burst effect
			particle_material.direction = Vector3(0, -1, 0)
			particle_material.initial_velocity_min = 80.0
			particle_material.initial_velocity_max = 150.0
			particle_material.angular_velocity_min = -180.0
			particle_material.angular_velocity_max = 180.0
			particle_material.scale_min = 0.5
			particle_material.scale_max = 2.0
			particle_material.color = Color(1.0, 0.8, 0.2, 1.0)  # Bright golden burst
		spawn_effect.emitting = true
		
		# Create screen flash effect for collection
		_create_collection_flash()

func _award_points(player_index: int):
	# Award base points for power egg collection
	ScoreManager.add_score(player_index, collection_points)
	
	# Add bonus if air catch
	var is_air_catch = not egg_has_touched_ground
	if is_air_catch:
		ScoreManager.add_bonus_score(player_index, 100, "Power Air Catch", global_position)

func _activate_power(player_index: int):
	var power_manager = get_node_or_null("/root/PowerManager")
	if power_manager and power_manager.has_method("activate_power"):
		# Track collection for debug statistics
		if power_manager.debug_ui and power_manager.debug_ui.has_method("track_power_collection"):
			power_manager.debug_ui.track_power_collection(power_type)
		
		# Send collection notification before activation
		if power_manager.has_method("_send_power_notification"):
			power_manager._send_power_notification(player_index, power_type, "collected")
		
		var success = power_manager.activate_power(player_index, power_type)
		if success:
			print("[DEBUG POWER EGG] Power activated successfully for player %d" % player_index)
		else:
			print("[DEBUG POWER EGG] Failed to activate power for player %d" % player_index)
	else:
		print("[DEBUG POWER EGG] PowerManager not found or invalid")

func _create_collection_flash():
	"""Create a brief screen flash effect when power egg is collected"""
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.9, 0.4, 0.3)  # Golden flash
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Get the main scene to add the flash overlay
	var main_scene = get_tree().current_scene
	if main_scene:
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		main_scene.add_child(flash)
		
		# Animate the flash
		var tween = create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.2)
		tween.tween_callback(flash.queue_free)

func _cleanup():
	# Disable all areas
	if collection_area:
		collection_area.monitoring = false
		collection_area.monitorable = false
	
	# Stop timer
	if timeout_timer:
		timeout_timer.stop()
	
	# Queue for removal
	queue_free()

func _on_timeout():
	if not is_collected:
		print("[DEBUG POWER EGG] PowerEgg timed out after %d seconds" % timeout_duration)
		_cleanup()

# Screen wrapping (same as normal eggs)
func _integrate_forces(state):
	if is_collected:
		return
	
	var viewport_rect = get_viewport_rect().size
	var buffer = 10
	
	# Check if power egg is about to go off the left edge
	if state.transform.origin.x < buffer:
		state.transform.origin.x = viewport_rect.x - buffer
	
	# Check if power egg is about to go off the right edge
	elif state.transform.origin.x > viewport_rect.x - buffer:
		state.transform.origin.x = buffer