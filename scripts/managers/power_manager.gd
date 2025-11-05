extends Node

# Power type enumeration
enum PowerType {
	NONE = -1,
	INVINCIBILITY = 0
}

# Audio components for power system
@onready var power_spawn_audio: AudioStreamPlayer = $PowerSpawnAudio
@onready var power_activation_audio: AudioStreamPlayer = $PowerActivationAudio
@onready var power_ambient_audio: AudioStreamPlayer = $PowerAmbientAudio
@onready var power_warning_audio: AudioStreamPlayer = $PowerWarningAudio
@onready var power_expiration_audio: AudioStreamPlayer = $PowerExpirationAudio

# Configuration and debug components
var config_manager
var debug_ui

# Power state data structure
class PowerData:
	var type: PowerType
	var start_time: float
	var duration: float
	var player_index: int
	
	func _init(power_type: PowerType, player_idx: int, power_duration: float):
		type = power_type
		player_index = player_idx
		duration = power_duration
		start_time = Time.get_time_dict_from_system().unix
	
	func is_expired() -> bool:
		return Time.get_time_dict_from_system().unix >= start_time + duration
	
	func get_remaining_time() -> float:
		var current_time = Time.get_time_dict_from_system().unix
		return max(0.0, (start_time + duration) - current_time)

# Legacy configuration system (now loaded from config manager)
var power_configs: Dictionary = {}

# Active powers tracking
var active_powers: Dictionary = {}  # player_index -> PowerData
var power_timers: Dictionary = {}   # player_index -> Timer

# Signals for power events
signal power_activated(player_index: int, power_type: PowerType, duration: float)
signal power_expired(player_index: int, power_type: PowerType)
signal power_warning(player_index: int, power_type: PowerType, remaining_time: float)

func _ready():
	print("[PowerManager] Power system initializing...")
	_setup_configuration_manager()
	_setup_debug_ui()
	_load_configuration()
	_setup_audio_streams()
	
	# ERROR HANDLING: Add memory leak prevention and proper cleanup on scene changes
	_setup_scene_change_cleanup()
	
	print("[PowerManager] Power system initialized")

func _setup_scene_change_cleanup():
	"""Setup cleanup handlers for scene changes to prevent memory leaks"""
	# Connect to scene tree signals for cleanup
	var tree = get_tree()
	if tree:
		if not tree.tree_changed.is_connected(_on_scene_tree_changed):
			tree.tree_changed.connect(_on_scene_tree_changed)
		
		# Also connect to node removal for cleanup
		if not tree.node_removed.is_connected(_on_node_removed):
			tree.node_removed.connect(_on_node_removed)

func _on_scene_tree_changed():
	"""Handle scene tree changes for cleanup"""
	# Check if any players are no longer valid
	var invalid_players = []
	for player_index in active_powers.keys():
		var player = _get_player_safely(player_index)
		if not player:
			invalid_players.append(player_index)
	
	# Clean up powers for invalid players
	for player_index in invalid_players:
		push_warning("[PowerManager] Player %d no longer valid, cleaning up power" % player_index)
		_force_cleanup_power_state(player_index)

func _on_node_removed(node: Node):
	"""Handle node removal for cleanup"""
	# Check if removed node is a player with active power
	if node.is_in_group("players") and "player_index" in node:
		var player_index = node.player_index
		if is_power_active(player_index):
			push_warning("[PowerManager] Player %d removed from scene, cleaning up power" % player_index)
			_force_cleanup_power_state(player_index)

func _exit_tree():
	"""Clean up all resources when PowerManager is removed"""
	print("[PowerManager] Cleaning up all resources...")
	
	# Clean up all active powers
	var all_players = active_powers.keys()
	for player_index in all_players:
		_force_cleanup_power_state(player_index)
	
	# Clean up backup timers metadata
	if has_meta("backup_timers"):
		remove_meta("backup_timers")
	
	print("[PowerManager] Resource cleanup complete")

func _process(delta):
	# Only process if system is enabled
	if not config_manager or not config_manager.is_system_enabled():
		return
	
	update_power_timers(delta)

# Public Interface Methods

func should_spawn_power_egg(enemy_class_name: String) -> bool:
	"""Determine if a power egg should spawn based on enemy type and spawn rates"""
	# ERROR HANDLING: Graceful fallback when PowerManager is not available
	if not config_manager:
		push_warning("[PowerManager] Configuration manager not available, falling back to normal eggs")
		return false
	
	# ERROR HANDLING: Check if system is enabled
	if not config_manager.is_system_enabled():
		return false
	
	# ERROR HANDLING: Validate enemy class name
	if enemy_class_name == null or enemy_class_name.strip_edges() == "":
		push_warning("[PowerManager] Invalid enemy class name provided: '%s', using default spawn rate" % str(enemy_class_name))
		enemy_class_name = "EnemyBase"  # Fallback to default
	
	# ERROR HANDLING: Check if invincibility power is enabled with fallback
	var invincibility_enabled = false
	if config_manager.has_method("is_power_enabled"):
		invincibility_enabled = config_manager.is_power_enabled("invincibility")
	else:
		push_error("[PowerManager] Configuration manager missing is_power_enabled method")
		return false
	
	if not invincibility_enabled:
		return false
	
	# Track spawn attempt for debug statistics (with error protection)
	if debug_ui and debug_ui.has_method("track_spawn_attempt"):
		debug_ui.track_spawn_attempt()
	
	# Check for debug force spawn rate (with error protection)
	var force_spawn_rate = -1.0
	if config_manager.has_method("get_debug_setting"):
		force_spawn_rate = config_manager.get_debug_setting("force_spawn_rate", -1.0)
	
	if force_spawn_rate >= 0.0:
		var debug_random_val = randf()
		var debug_spawn_result = debug_random_val <= force_spawn_rate
		if debug_spawn_result and debug_ui and debug_ui.has_method("track_successful_spawn"):
			debug_ui.track_successful_spawn()
		return debug_spawn_result
	
	# ERROR HANDLING: Get spawn chance from configuration with fallback
	var spawn_chance = 0.15  # Default fallback spawn rate
	if config_manager.has_method("get_enemy_spawn_rate"):
		spawn_chance = config_manager.get_enemy_spawn_rate("invincibility", enemy_class_name)
		# Validate spawn chance is within reasonable bounds
		if spawn_chance < 0.0 or spawn_chance > 1.0:
			push_warning("[PowerManager] Invalid spawn chance %.3f for %s, using default 0.15" % [spawn_chance, enemy_class_name])
			spawn_chance = 0.15
	else:
		push_warning("[PowerManager] Configuration manager missing get_enemy_spawn_rate method, using default spawn rate")
	
	# Generate random number and check against spawn chance
	var random_val = randf()
	var spawn_result = random_val <= spawn_chance
	
	if spawn_result and debug_ui and debug_ui.has_method("track_successful_spawn"):
		debug_ui.track_successful_spawn()
	
	return spawn_result

func get_power_egg_scene() -> PackedScene:
	"""Get the power egg scene for spawning with error handling"""
	# ERROR HANDLING: Resource loading error handling with fallback assets
	var power_egg_scene = null
	
	# Try to load the power egg scene
	if ResourceLoader.exists("res://scenes/entities/power_egg.tscn"):
		power_egg_scene = load("res://scenes/entities/power_egg.tscn")
		if power_egg_scene == null:
			push_error("[PowerManager] Failed to load power egg scene despite file existing")
	else:
		push_error("[PowerManager] Power egg scene file does not exist: res://scenes/entities/power_egg.tscn")
	
	# ERROR HANDLING: Validate the loaded scene
	if power_egg_scene != null and not power_egg_scene is PackedScene:
		push_error("[PowerManager] Loaded power egg resource is not a PackedScene")
		power_egg_scene = null
	
	# ERROR HANDLING: Final validation - return null if loading failed
	# The caller should handle null return and fall back to normal eggs
	if power_egg_scene == null:
		push_error("[PowerManager] Power egg scene unavailable, caller should fall back to normal eggs")
	
	return power_egg_scene

func activate_power(player_index: int, power_type: PowerType) -> bool:
	"""Activate a power for the specified player with comprehensive error handling"""
	# ERROR HANDLING: Graceful fallback when PowerManager is not available
	if not config_manager:
		push_error("[PowerManager] Configuration manager not available, power activation failed")
		return false
	
	if not config_manager.is_system_enabled():
		print("[PowerManager] Power system disabled, ignoring activation request")
		return false
	
	# ERROR HANDLING: Handle invalid player indices and missing player references
	if player_index < 1 or player_index > 4:
		push_error("[PowerManager] Invalid player index: %d (must be 1-4)" % player_index)
		return false
	
	# ERROR HANDLING: Validate player exists and is accessible
	var player = _get_player_safely(player_index)
	if not player:
		push_error("[PowerManager] Player %d not found or not accessible" % player_index)
		return false
	
	# ERROR HANDLING: Validate power type
	var power_name = _get_power_name_from_type(power_type)
	if power_name == "":
		push_error("[PowerManager] Unknown power type: %d" % power_type)
		return false
	
	# ERROR HANDLING: Check if power is enabled with method validation
	var power_enabled = false
	if config_manager.has_method("is_power_enabled"):
		power_enabled = config_manager.is_power_enabled(power_name)
	else:
		push_error("[PowerManager] Configuration manager missing is_power_enabled method")
		return false
	
	if not power_enabled:
		print("[PowerManager] Power %s is disabled" % power_name)
		return false
	
	# ERROR HANDLING: Get power configuration with validation
	var duration = 10.0  # Default fallback duration
	if config_manager.has_method("get_power_duration"):
		duration = config_manager.get_power_duration(power_name)
		# Validate duration is reasonable
		if duration <= 0.0 or duration > 300.0:  # Max 5 minutes
			push_warning("[PowerManager] Invalid duration %.1f for %s, using default 10.0s" % [duration, power_name])
			duration = 10.0
	else:
		push_warning("[PowerManager] Configuration manager missing get_power_duration method, using default duration")
	
	# Check for debug test mode duration (with error protection)
	if config_manager.has_method("get_debug_setting"):
		var test_duration = config_manager.get_debug_setting("test_mode_duration", -1.0)
		if test_duration > 0.0:
			duration = test_duration
	
	# ERROR HANDLING: Implement power activation failure recovery
	# Deactivate any existing power for this player
	if is_power_active(player_index):
		deactivate_power(player_index)
	
	# Create new power data with error checking
	var power_data = PowerData.new(power_type, player_index, duration)
	if not power_data:
		push_error("[PowerManager] Failed to create power data for player %d" % player_index)
		return false
	
	active_powers[player_index] = power_data
	
	# ERROR HANDLING: Create timer system failure protection
	var timer = _create_power_timer_safely(player_index, duration)
	if not timer:
		# Clean up partial state
		active_powers.erase(player_index)
		push_error("[PowerManager] Failed to create power timer for player %d" % player_index)
		return false
	
	power_timers[player_index] = timer
	
	# ERROR HANDLING: Audio system error protection
	_play_activation_audio_safely(power_type, player_index)
	
	# ERROR HANDLING: Signal emission with error protection
	_emit_power_signal_safely("power_activated", [player_index, power_type, duration])
	
	# ERROR HANDLING: Notification system with error protection
	_send_power_notification_safely(player_index, power_type, "activated")
	
	# ERROR HANDLING: Debug tracking with error protection
	_track_debug_activation_safely(power_type)
	
	# ERROR HANDLING: Player activation with error recovery
	if not _activate_player_power_safely(player, power_type, duration):
		# If player activation fails, clean up power manager state
		deactivate_power(player_index)
		push_error("[PowerManager] Player power activation failed for player %d, cleaned up state" % player_index)
		return false
	
	print("[PowerManager] Power %d activated for player %d (duration: %.1fs)" % [power_type, player_index, duration])
	return true

func deactivate_power(player_index: int) -> void:
	"""Deactivate the current power for the specified player with comprehensive error handling"""
	# ERROR HANDLING: Validate player index
	if player_index < 1 or player_index > 4:
		push_warning("[PowerManager] Invalid player index for deactivation: %d" % player_index)
		return
	
	if not active_powers.has(player_index):
		return
	
	var power_data = active_powers[player_index]
	if not power_data:
		push_warning("[PowerManager] Null power data for player %d during deactivation" % player_index)
		active_powers.erase(player_index)
		return
	
	var power_type = power_data.type
	
	# ERROR HANDLING: Memory leak prevention and proper cleanup
	# Clean up main timer
	if power_timers.has(player_index):
		var timer = power_timers[player_index]
		if is_instance_valid(timer):
			if timer.timeout.is_connected(_on_power_expired):
				timer.timeout.disconnect(_on_power_expired)
			timer.queue_free()
		power_timers.erase(player_index)
	
	# Clean up backup timer
	if has_meta("backup_timers"):
		var backup_timers = get_meta("backup_timers")
		if backup_timers.has(player_index):
			var backup_timer = backup_timers[player_index]
			if is_instance_valid(backup_timer):
				backup_timer.queue_free()
			backup_timers.erase(player_index)
	
	# Remove power data
	active_powers.erase(player_index)
	
	# ERROR HANDLING: Audio system error protection
	_play_deactivation_audio_safely(power_type, player_index)
	
	# ERROR HANDLING: Signal emission with error protection
	_emit_power_signal_safely("power_expired", [player_index, power_type])
	
	# ERROR HANDLING: Notification system with error protection
	_send_power_notification_safely(player_index, power_type, "expired")
	
	# ERROR HANDLING: Player deactivation with error recovery
	_deactivate_player_power_safely(player_index)
	
	print("[PowerManager] Power %d deactivated for player %d" % [power_type, player_index])

func is_power_active(player_index: int, power_type: PowerType = PowerType.NONE) -> bool:
	"""Check if a power is active for the specified player"""
	if not active_powers.has(player_index):
		return false
	
	var power_data = active_powers[player_index]
	
	# Check for expired power
	if power_data.is_expired():
		deactivate_power(player_index)
		return false
	
	# If specific power type requested, check it matches
	if power_type != PowerType.NONE:
		return power_data.type == power_type
	
	return true

func get_active_power_type(player_index: int) -> PowerType:
	"""Get the active power type for the specified player"""
	if not is_power_active(player_index):
		return PowerType.NONE
	
	return active_powers[player_index].type

func get_remaining_duration(player_index: int) -> float:
	"""Get remaining duration for the active power"""
	if not is_power_active(player_index):
		return 0.0
	
	return active_powers[player_index].get_remaining_time()

func update_power_timers(_delta: float) -> void:
	"""Update power timers and handle expiration warnings with error handling"""
	# ERROR HANDLING: Graceful fallback when system is not available
	if not config_manager or not config_manager.is_system_enabled():
		return
	
	var players_to_remove = []
	
	# ERROR HANDLING: Protect against corrupted active_powers dictionary
	var safe_player_indices = []
	if active_powers != null and typeof(active_powers) == TYPE_DICTIONARY:
		safe_player_indices = active_powers.keys()
	else:
		push_error("[PowerManager] Corrupted active_powers dictionary, clearing all powers")
		active_powers = {}
		power_timers = {}
		return
	
	for player_index in safe_player_indices:
		# ERROR HANDLING: Validate power data exists and is valid
		if not active_powers.has(player_index):
			continue
		
		var power_data = active_powers[player_index]
		if not power_data:
			push_warning("[PowerManager] Null power data for player %d, removing" % player_index)
			players_to_remove.append(player_index)
			continue
		
		# ERROR HANDLING: Protect against invalid power data
		# Check if power has expired
		if power_data.is_expired():
			players_to_remove.append(player_index)
			continue
		
		# Check for warning threshold (3 seconds remaining)
		var remaining_time = power_data.get_remaining_time()
		
		# ERROR HANDLING: Validate remaining time is reasonable
		if remaining_time < 0.0 or remaining_time > 300.0:  # Max 5 minutes
			push_warning("[PowerManager] Invalid remaining time %.1f for player %d, forcing expiration" % [remaining_time, player_index])
			players_to_remove.append(player_index)
			continue
		
		if remaining_time <= 3.0 and remaining_time > 2.9:
			# ERROR HANDLING: Audio warning with error protection
			if power_warning_audio and is_instance_valid(power_warning_audio):
				play_power_warning_sound(power_data.type)
			else:
				push_warning("[PowerManager] Failed to play warning sound for player %d" % player_index)
			
			# ERROR HANDLING: Signal emission with error protection
			_emit_power_signal_safely("power_warning", [player_index, power_data.type, remaining_time])
	
	# Clean up expired powers with error handling
	for player_index in players_to_remove:
		deactivate_power(player_index)

# Configuration Setup Methods

func _setup_configuration_manager():
	"""Setup configuration manager"""
	var PowerConfigManager = preload("res://scripts/managers/power_config_manager.gd")
	config_manager = PowerConfigManager.new()
	
	# Connect to configuration change signals
	config_manager.config_changed.connect(_on_config_changed)
	config_manager.debug_mode_changed.connect(_on_debug_mode_changed)
	config_manager.system_enabled_changed.connect(_on_system_enabled_changed)

func _setup_debug_ui():
	"""Setup debug UI if debug mode is enabled"""
	if config_manager and config_manager.is_debug_mode():
		_create_debug_ui()
		_create_debug_console()

func _create_debug_ui():
	"""Create debug UI instance"""
	var debug_ui_scene = preload("res://scenes/debug/power_debug_ui.tscn")
	debug_ui = debug_ui_scene.instantiate()
	
	# Add to current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(debug_ui)
		print("[PowerManager] Debug UI created")

func _create_debug_console():
	"""Create debug console instance"""
	var console_scene = preload("res://scenes/debug/power_console.tscn")
	var console = console_scene.instantiate()
	
	# Add to current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(console)
		print("[PowerManager] Debug console created")

func _load_configuration():
	"""Load configuration from config manager"""
	if not config_manager:
		return
	
	# Convert config manager data to legacy format for compatibility
	_update_legacy_config_format()

func _update_legacy_config_format():
	"""Update legacy power_configs dictionary from config manager"""
	power_configs.clear()
	
	# Load invincibility power configuration
	var invincibility_config = config_manager.get_power_config("invincibility")
	if invincibility_config.size() > 0:
		# Convert screen tint from dictionary to Color if needed
		var screen_tint = Color.WHITE
		var effects = invincibility_config.get("effects", {})
		if effects.has("screen_tint"):
			var tint_data = effects.screen_tint
			if tint_data is Dictionary:
				screen_tint = Color(tint_data.get("r", 0.8), tint_data.get("g", 0.8), tint_data.get("b", 1.0), tint_data.get("a", 0.3))
			else:
				screen_tint = tint_data
		
		power_configs[PowerType.INVINCIBILITY] = {
			"duration": invincibility_config.get("duration", 10.0),
			"spawn_chance": invincibility_config.get("spawn_chance", 0.15),
			"enemy_spawn_rates": invincibility_config.get("enemy_spawn_rates", {}),
			"effects": {
				"player_glow": effects.get("player_glow", true),
				"screen_tint": screen_tint,
				"particle_effect": effects.get("particle_effect", "invincibility_sparkles")
			},
			"audio": invincibility_config.get("audio", {})
		}

# Configuration Signal Handlers

func _on_config_changed(section: String, key: String, value):
	"""Handle configuration changes"""
	print("[PowerManager] Configuration changed: %s.%s = %s" % [section, key, str(value)])
	_update_legacy_config_format()

func _on_debug_mode_changed(enabled: bool):
	"""Handle debug mode changes"""
	print("[PowerManager] Debug mode %s" % ("enabled" if enabled else "disabled"))
	
	if enabled and not debug_ui:
		_create_debug_ui()
	elif not enabled and debug_ui:
		debug_ui.queue_free()
		debug_ui = null

func _on_system_enabled_changed(enabled: bool):
	"""Handle system enabled changes"""
	print("[PowerManager] Power system %s" % ("enabled" if enabled else "disabled"))
	
	if not enabled:
		# Deactivate all active powers when system is disabled
		reset_all_powers()

# Configuration Methods (Updated)

func get_power_config(power_type: PowerType) -> Dictionary:
	"""Get configuration for a specific power type"""
	return power_configs.get(power_type, {})

func set_power_duration(power_type: PowerType, duration: float) -> void:
	"""Set duration for a specific power type"""
	var power_name = _get_power_name_from_type(power_type)
	if power_name != "" and config_manager:
		config_manager.set_power_duration(power_name, duration)

func set_spawn_chance(power_type: PowerType, chance: float) -> void:
	"""Set spawn chance for a specific power type"""
	var power_name = _get_power_name_from_type(power_type)
	if power_name != "" and config_manager:
		config_manager.set_spawn_chance(power_name, chance)

func set_enemy_spawn_rate(power_type: PowerType, enemy_class: String, rate: float) -> void:
	"""Set spawn rate for a specific enemy type"""
	var power_name = _get_power_name_from_type(power_type)
	if power_name != "" and config_manager:
		config_manager.set_enemy_spawn_rate(power_name, enemy_class, rate)

func _get_power_name_from_type(power_type: PowerType) -> String:
	"""Convert power type enum to configuration name"""
	match power_type:
		PowerType.INVINCIBILITY:
			return "invincibility"
		_:
			return ""

# Debug Methods

func get_debug_info() -> Dictionary:
	"""Get debug information about active powers"""
	var debug_info = {
		"active_powers_count": active_powers.size(),
		"active_powers": {},
		"power_configs": power_configs,
		"system_enabled": config_manager.is_system_enabled() if config_manager else false,
		"debug_mode": config_manager.is_debug_mode() if config_manager else false,
		"config_manager_info": config_manager.get_debug_info() if config_manager else {}
	}
	
	for player_index in active_powers.keys():
		var power_data = active_powers[player_index]
		debug_info.active_powers[player_index] = {
			"type": power_data.type,
			"remaining_time": power_data.get_remaining_time(),
			"is_expired": power_data.is_expired()
		}
	
	return debug_info

func toggle_debug_ui():
	"""Toggle debug UI visibility"""
	if debug_ui:
		debug_ui.toggle_debug_ui()
	elif config_manager and config_manager.is_debug_mode():
		_create_debug_ui()

func enable_debug_mode():
	"""Enable debug mode and create debug UI"""
	if config_manager:
		config_manager.set_debug_mode(true)

func disable_debug_mode():
	"""Disable debug mode and hide debug UI"""
	if config_manager:
		config_manager.set_debug_mode(false)

func get_configuration_manager():
	"""Get reference to configuration manager"""
	return config_manager

func reload_configuration():
	"""Reload configuration from file"""
	if config_manager:
		config_manager.load_configuration()
		_update_legacy_config_format()
		print("[PowerManager] Configuration reloaded")

func save_configuration():
	"""Save current configuration to file"""
	if config_manager:
		config_manager.save_configuration()
		print("[PowerManager] Configuration saved")

func validate_configuration() -> Array[String]:
	"""Validate current configuration"""
	if config_manager:
		return config_manager.validate_configuration()
	return ["Configuration manager not available"]

func get_all_active_powers() -> Dictionary:
	"""Get all currently active powers by player"""
	var result = {}
	for player_index in active_powers.keys():
		var power_data = active_powers[player_index]
		if not power_data.is_expired():
			result[player_index] = {
				"type": power_data.type,
				"remaining_time": power_data.get_remaining_time(),
				"start_time": power_data.start_time,
				"duration": power_data.duration
			}
	return result

func has_any_active_powers() -> bool:
	"""Check if any player has active powers"""
	return active_powers.size() > 0

func get_players_with_power_type(power_type: PowerType) -> Array[int]:
	"""Get list of player indices who have the specified power type active"""
	var players = []
	for player_index in active_powers.keys():
		var power_data = active_powers[player_index]
		if power_data.type == power_type and not power_data.is_expired():
			players.append(player_index)
	return players

func reset_all_powers() -> void:
	"""Reset all active powers (useful for game restart)"""
	var players_to_clear = active_powers.keys()
	for player_index in players_to_clear:
		deactivate_power(player_index)
	
	print("[PowerManager] All powers reset")

# Private Methods

func _on_power_expired(player_index: int):
	"""Handle power expiration from timer"""
	deactivate_power(player_index)

# ERROR HANDLING: Helper methods for safe operations

func _get_player_safely(player_index: int) -> Node:
	"""Safely get player reference with error handling"""
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		# Try alternative paths
		var current_scene = get_tree().current_scene
		if current_scene:
			game_manager = current_scene.find_child("GameManager", true, false)
	
	if not game_manager:
		push_warning("[PowerManager] GameManager not found, cannot validate player %d" % player_index)
		return null
	
	if not "player_nodes" in game_manager:
		push_warning("[PowerManager] GameManager missing player_nodes array")
		return null
	
	var player_nodes = game_manager.player_nodes
	if not player_nodes or player_nodes.size() < player_index:
		push_warning("[PowerManager] Player %d not available in GameManager (size: %d)" % [player_index, player_nodes.size() if player_nodes else 0])
		return null
	
	var player = player_nodes[player_index - 1]  # Convert to 0-based index
	if not is_instance_valid(player):
		push_warning("[PowerManager] Player %d reference is invalid" % player_index)
		return null
	
	return player

func _create_power_timer_safely(player_index: int, duration: float) -> Timer:
	"""Create power timer with error handling and failure protection"""
	var timer = Timer.new()
	if not timer:
		push_error("[PowerManager] Failed to create Timer instance")
		return null
	
	# ERROR HANDLING: Timer system failure protection
	timer.wait_time = duration
	timer.one_shot = true
	
	# Connect with error handling
	if timer.has_signal("timeout"):
		var callable = _on_power_expired.bind(player_index)
		if callable.is_valid():
			timer.timeout.connect(callable)
		else:
			push_error("[PowerManager] Failed to create valid timeout callback")
			timer.queue_free()
			return null
	else:
		push_error("[PowerManager] Timer missing timeout signal")
		timer.queue_free()
		return null
	
	# Add to scene tree safely
	if is_inside_tree():
		add_child(timer)
		timer.start()
		
		# Create backup expiration protection
		_create_backup_expiration_timer(player_index, duration * 1.2)  # 20% longer as safety net
	else:
		push_error("[PowerManager] PowerManager not in scene tree, cannot add timer")
		timer.queue_free()
		return null
	
	return timer

func _create_backup_expiration_timer(player_index: int, max_duration: float):
	"""Create backup timer to force expiration after max duration"""
	var backup_timer = Timer.new()
	backup_timer.wait_time = max_duration
	backup_timer.one_shot = true
	backup_timer.timeout.connect(_force_power_expiration.bind(player_index))
	add_child(backup_timer)
	backup_timer.start()
	
	# Store reference for cleanup
	if not has_meta("backup_timers"):
		set_meta("backup_timers", {})
	var backup_timers = get_meta("backup_timers")
	backup_timers[player_index] = backup_timer

func _force_power_expiration(player_index: int):
	"""Force power expiration as safety measure"""
	if is_power_active(player_index):
		push_warning("[PowerManager] Force expiring power for player %d (safety timeout)" % player_index)
		deactivate_power(player_index)
	
	# Clean up backup timer reference
	if has_meta("backup_timers"):
		var backup_timers = get_meta("backup_timers")
		if backup_timers.has(player_index):
			backup_timers.erase(player_index)

func _play_activation_audio_safely(power_type: PowerType, player_index: int):
	"""Play activation audio with error protection"""
	if power_activation_audio and is_instance_valid(power_activation_audio):
		play_power_activation_sound(power_type)
	else:
		push_warning("[PowerManager] Power activation audio not available")
	
	if power_ambient_audio and is_instance_valid(power_ambient_audio):
		start_power_ambient_sound(power_type, player_index)
	else:
		push_warning("[PowerManager] Power ambient audio not available")

func _emit_power_signal_safely(signal_name: String, args: Array):
	"""Emit power signal with error protection"""
	if has_signal(signal_name):
		match args.size():
			1:
				emit_signal(signal_name, args[0])
			2:
				emit_signal(signal_name, args[0], args[1])
			3:
				emit_signal(signal_name, args[0], args[1], args[2])
			_:
				push_warning("[PowerManager] Unsupported signal argument count: %d" % args.size())
	else:
		push_warning("[PowerManager] Signal %s not found" % signal_name)

func _send_power_notification_safely(player_index: int, power_type: PowerType, event_type: String):
	"""Send power notification with error protection"""
	if has_method("_send_power_notification"):
		_send_power_notification(player_index, power_type, event_type)
	else:
		push_warning("[PowerManager] _send_power_notification method not available")

func _track_debug_activation_safely(power_type: PowerType):
	"""Track debug activation with error protection"""
	if debug_ui and is_instance_valid(debug_ui) and debug_ui.has_method("track_power_activation"):
		debug_ui.track_power_activation(power_type)
	else:
		# Debug tracking is optional, so just log at debug level
		pass

func _activate_player_power_safely(player: Node, power_type: PowerType, duration: float) -> bool:
	"""Activate player power with error recovery"""
	if not player or not is_instance_valid(player):
		push_error("[PowerManager] Invalid player reference for power activation")
		return false
	
	if not player.has_method("activate_power"):
		push_error("[PowerManager] Player missing activate_power method")
		return false
	
	player.activate_power(power_type, duration)
	return true

func _cleanup_failed_activation(player_index: int):
	"""Clean up partial state from failed power activation"""
	# Remove from active powers
	if active_powers.has(player_index):
		active_powers.erase(player_index)
	
	# Clean up timer
	if power_timers.has(player_index):
		var timer = power_timers[player_index]
		if is_instance_valid(timer):
			timer.queue_free()
		power_timers.erase(player_index)
	
	# Clean up backup timer
	if has_meta("backup_timers"):
		var backup_timers = get_meta("backup_timers")
		if backup_timers.has(player_index):
			var backup_timer = backup_timers[player_index]
			if is_instance_valid(backup_timer):
				backup_timer.queue_free()
			backup_timers.erase(player_index)

func _play_deactivation_audio_safely(power_type: PowerType, player_index: int):
	"""Play deactivation audio with error protection"""
	if power_expiration_audio and is_instance_valid(power_expiration_audio):
		play_power_expiration_sound(power_type)
	else:
		push_warning("[PowerManager] Power expiration audio not available")
	
	if power_ambient_audio and is_instance_valid(power_ambient_audio):
		stop_power_ambient_sound(player_index)
	else:
		push_warning("[PowerManager] Power ambient audio not available for stopping")

func _deactivate_player_power_safely(player_index: int):
	"""Deactivate player power with error recovery"""
	var player = _get_player_safely(player_index)
	if not player:
		push_warning("[PowerManager] Cannot deactivate player power - player %d not found" % player_index)
		return
	
	if not player.has_method("deactivate_power"):
		push_warning("[PowerManager] Player %d missing deactivate_power method" % player_index)
		return
	
	player.deactivate_power()

func _force_cleanup_power_state(player_index: int):
	"""Force cleanup of all power-related state for a player"""
	# Force remove from all tracking dictionaries
	if active_powers.has(player_index):
		active_powers.erase(player_index)
	
	if power_timers.has(player_index):
		var timer = power_timers[player_index]
		if is_instance_valid(timer):
			timer.queue_free()
		power_timers.erase(player_index)
	
	if has_meta("backup_timers"):
		var backup_timers = get_meta("backup_timers")
		if backup_timers.has(player_index):
			var backup_timer = backup_timers[player_index]
			if is_instance_valid(backup_timer):
				backup_timer.queue_free()
			backup_timers.erase(player_index)
	
	print("[PowerManager] Force cleaned power state for player %d" % player_index)

# Audio Management Methods

func _setup_audio_streams():
	"""Setup audio streams with appropriate sound files"""
	# Load power-related audio files
	if power_spawn_audio:
		var spawn_sound = load("res://assets/sounds/sfx/power_egg_spawn.wav")
		if spawn_sound:
			power_spawn_audio.stream = spawn_sound
			power_spawn_audio.volume_db = -5.0
	
	if power_activation_audio:
		# Try to load dedicated power activation sound first
		var activation_sound = load("res://assets/sounds/sfx/power_activation.wav")
		if not activation_sound:
			# Fallback to flap sound with modified pitch
			activation_sound = load("res://assets/sounds/sfx/flapsound.wav")
		if activation_sound:
			power_activation_audio.stream = activation_sound
			power_activation_audio.volume_db = 0.0
			power_activation_audio.pitch_scale = 1.5  # Higher pitch for power-up feel
	
	if power_ambient_audio:
		# Try to load dedicated ambient loop sound first
		var ambient_sound = load("res://assets/sounds/sfx/power_ambient_loop.ogg")
		if not ambient_sound:
			# Fallback to spray sound with modified pitch
			ambient_sound = load("res://assets/sounds/sfx/spray-can-shaking-and-spraying-66933.ogg")
		if ambient_sound:
			power_ambient_audio.stream = ambient_sound
			power_ambient_audio.volume_db = -15.0  # Quiet ambient sound
			power_ambient_audio.pitch_scale = 0.8   # Lower pitch for ambient feel
	
	if power_warning_audio:
		# Try to load dedicated warning sound first
		var warning_sound = load("res://assets/sounds/sfx/power_warning.wav")
		if not warning_sound:
			# Fallback to collision sound with high pitch
			warning_sound = load("res://assets/sounds/sfx/collision_sound.wav")
		if warning_sound:
			power_warning_audio.stream = warning_sound
			power_warning_audio.volume_db = -3.0
			power_warning_audio.pitch_scale = 2.0  # High pitch for urgency
	
	if power_expiration_audio:
		# Try to load dedicated expiration sound first
		var expiration_sound = load("res://assets/sounds/sfx/power_expiration.wav")
		if not expiration_sound:
			# Fallback to death sound with lower pitch
			expiration_sound = load("res://assets/sounds/sfx/death_sound.wav")
		if expiration_sound:
			power_expiration_audio.stream = expiration_sound
			power_expiration_audio.volume_db = -8.0
			power_expiration_audio.pitch_scale = 0.7  # Lower pitch for power-down feel

func play_power_spawn_sound():
	"""Play sound when power egg spawns"""
	if power_spawn_audio and power_spawn_audio.stream:
		power_spawn_audio.play()
		print("[PowerManager] Playing power spawn sound")

func play_power_activation_sound(power_type: PowerType):
	"""Play sound when power is activated"""
	if power_activation_audio and power_activation_audio.stream:
		# Adjust pitch based on power type
		match power_type:
			PowerType.INVINCIBILITY:
				power_activation_audio.pitch_scale = 1.5
		
		power_activation_audio.play()
		print("[PowerManager] Playing power activation sound for type %d" % power_type)

func start_power_ambient_sound(power_type: PowerType, player_index: int = -1):
	"""Start looping ambient sound during active power"""
	if power_ambient_audio and power_ambient_audio.stream:
		# Configure ambient sound based on power type
		match power_type:
			PowerType.INVINCIBILITY:
				power_ambient_audio.pitch_scale = 0.8
				power_ambient_audio.volume_db = -15.0
		
		# Start looping ambient sound only if no other player has ambient sound playing
		# or if this is the first active power
		var active_count = active_powers.size()
		if active_count <= 1 and not power_ambient_audio.playing:
			power_ambient_audio.play()
		print("[PowerManager] Starting ambient sound for power type %d (player %d)" % [power_type, player_index])

func stop_power_ambient_sound(_player_index: int = -1):
	"""Stop looping ambient sound only if no other players have active powers"""
	# Only stop ambient sound if no other players have active powers
	if active_powers.size() == 0:
		if power_ambient_audio and power_ambient_audio.playing:
			power_ambient_audio.stop()
			print("[PowerManager] Stopping ambient sound (no active powers)")
	else:
		print("[PowerManager] Keeping ambient sound (other players have active powers)")

func play_power_warning_sound(power_type: PowerType):
	"""Play warning sound when power is about to expire"""
	if power_warning_audio and power_warning_audio.stream:
		# Adjust warning sound based on power type
		match power_type:
			PowerType.INVINCIBILITY:
				power_warning_audio.pitch_scale = 2.0
		
		power_warning_audio.play()
		print("[PowerManager] Playing power warning sound for type %d" % power_type)

func play_power_expiration_sound(power_type: PowerType):
	"""Play sound when power expires"""
	if power_expiration_audio and power_expiration_audio.stream:
		# Adjust expiration sound based on power type
		match power_type:
			PowerType.INVINCIBILITY:
				power_expiration_audio.pitch_scale = 0.7
		
		power_expiration_audio.play()
		print("[PowerManager] Playing power expiration sound for type %d" % power_type)

func _send_power_notification(player_index: int, power_type: PowerType, event_type: String):
	"""Send notification for power events"""
	var notification_system = get_node_or_null("/root/NotificationSystem")
	if not notification_system:
		# Try to find notification system in the current scene
		var current_scene = get_tree().current_scene
		if current_scene:
			notification_system = current_scene.find_child("NotificationSystem", true, false)
	
	if notification_system and notification_system.has_method("show_notification"):
		var power_name = _get_power_name(power_type)
		var message = ""
		var notification_type = 0  # INFO
		
		match event_type:
			"activated":
				message = "Player %d: %s activated!" % [player_index, power_name]
				notification_type = 2  # INFO
			"expired":
				message = "Player %d: %s expired" % [player_index, power_name]
				notification_type = 2  # INFO
			"collected":
				message = "Player %d collected %s!" % [player_index, power_name]
				notification_type = 0  # SUCCESS
		
		if message != "":
			notification_system.show_notification(message, notification_type, 2.0)
			print("[PowerManager] Sent notification: %s" % message)

func _get_power_name(power_type: PowerType) -> String:
	"""Get human-readable power name"""
	match power_type:
		PowerType.INVINCIBILITY:
			return "Invincibility"
		_:
			return "Unknown Power"

func get_power_icon_texture(power_type: PowerType) -> Texture2D:
	"""Get icon texture for power type"""
	match power_type:
		PowerType.INVINCIBILITY:
			# Try to load invincibility icon, fallback to life icon
			var icon = load("res://assets/sprites/power_invincibility_icon.png")
			if not icon:
				icon = load("res://assets/sprites/life.png")  # Fallback
			return icon
		_:
			return load("res://assets/sprites/life.png")  # Default fallback

func get_power_color(power_type: PowerType) -> Color:
	"""Get color theme for power type"""
	match power_type:
		PowerType.INVINCIBILITY:
			return Color(1.0, 0.8, 0.3)  # Golden
		_:
			return Color.WHITE

# Input handling for debug hotkeys
func _input(event):
	"""Handle debug input events"""
	if not config_manager or not config_manager.is_debug_mode():
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				toggle_debug_ui()
			KEY_F5:
				reload_configuration()
			KEY_F6:
				save_configuration()
			KEY_F7:
				if not config_manager.is_debug_mode():
					enable_debug_mode()
				else:
					disable_debug_mode()
			KEY_F8:
				config_manager.set_system_enabled(not config_manager.is_system_enabled())
			KEY_F9:
				# Quick test: activate invincibility for player 1
				activate_power(1, PowerType.INVINCIBILITY)
			KEY_F10:
				# Quick test: deactivate all powers
				reset_all_powers()