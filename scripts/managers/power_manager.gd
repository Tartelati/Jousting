extends Node

# Power type enumeration
enum PowerType {
	NONE = -1,
	INVINCIBILITY = 0
}

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

# Configuration system
var power_configs: Dictionary = {
	PowerType.INVINCIBILITY: {
		"duration": 10.0,
		"spawn_chance": 0.15,
		"enemy_spawn_rates": {
			"EnemyBase": 0.15,
			"EnemyHunter": 0.20,
			"ShadowLord": 0.25
		},
		"effects": {
			"player_glow": true,
			"screen_tint": Color(0.8, 0.8, 1.0, 0.3),
			"particle_effect": "invincibility_sparkles"
		},
		"audio": {
			"collection": "power_collect_invincibility",
			"activation": "invincibility_start",
			"ambient": "invincibility_loop",
			"warning": "power_expire_warning",
			"expiration": "power_expire"
		}
	}
}

# Active powers tracking
var active_powers: Dictionary = {}  # player_index -> PowerData
var power_timers: Dictionary = {}   # player_index -> Timer

# Signals for power events
signal power_collected(player_index: int, power_type: PowerType)
signal power_activated(player_index: int, power_type: PowerType, duration: float)
signal power_expired(player_index: int, power_type: PowerType)
signal power_warning(player_index: int, power_type: PowerType, remaining_time: float)

func _ready():
	print("[PowerManager] Power system initialized")

func _process(delta):
	update_power_timers(delta)

# Public Interface Methods

func should_spawn_power_egg(enemy_class_name: String) -> bool:
	"""Determine if a power egg should spawn based on enemy type and spawn rates"""
	# Get base spawn chance for invincibility power
	var base_chance = power_configs[PowerType.INVINCIBILITY].spawn_chance
	
	# Check for enemy-specific spawn rates
	var enemy_rates = power_configs[PowerType.INVINCIBILITY].enemy_spawn_rates
	var spawn_chance = base_chance
	
	# Use enemy-specific rate if available
	if enemy_rates.has(enemy_class_name):
		spawn_chance = enemy_rates[enemy_class_name]
	
	# Generate random number and check against spawn chance
	var random_value = randf()
	return random_value <= spawn_chance

func get_power_egg_scene() -> PackedScene:
	"""Get the power egg scene for spawning"""
	return preload("res://scenes/entities/power_egg.tscn")

func activate_power(player_index: int, power_type: PowerType) -> bool:
	"""Activate a power for the specified player"""
	# Validate inputs
	if player_index < 1 or player_index > 4:
		push_error("[PowerManager] Invalid player index: %d" % player_index)
		return false
	
	if not power_configs.has(power_type):
		push_error("[PowerManager] Unknown power type: %d" % power_type)
		return false
	
	# Get power configuration
	var config = power_configs[power_type]
	var duration = config.duration
	
	# Deactivate any existing power for this player
	if is_power_active(player_index):
		deactivate_power(player_index)
	
	# Create new power data
	var power_data = PowerData.new(power_type, player_index, duration)
	active_powers[player_index] = power_data
	
	# Create timer for this power
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_power_expired.bind(player_index))
	add_child(timer)
	timer.start()
	power_timers[player_index] = timer
	
	# Emit activation signal
	emit_signal("power_activated", player_index, power_type, duration)
	
	print("[PowerManager] Power %d activated for player %d (duration: %.1fs)" % [power_type, player_index, duration])
	return true

func deactivate_power(player_index: int) -> void:
	"""Deactivate the current power for the specified player"""
	if not active_powers.has(player_index):
		return
	
	var power_data = active_powers[player_index]
	var power_type = power_data.type
	
	# Clean up timer
	if power_timers.has(player_index):
		var timer = power_timers[player_index]
		if is_instance_valid(timer):
			timer.queue_free()
		power_timers.erase(player_index)
	
	# Remove power data
	active_powers.erase(player_index)
	
	# Emit expiration signal
	emit_signal("power_expired", player_index, power_type)
	
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
	"""Update power timers and handle expiration warnings"""
	var players_to_remove = []
	
	for player_index in active_powers.keys():
		var power_data = active_powers[player_index]
		
		# Check if power has expired
		if power_data.is_expired():
			players_to_remove.append(player_index)
			continue
		
		# Check for warning threshold (3 seconds remaining)
		var remaining_time = power_data.get_remaining_time()
		if remaining_time <= 3.0 and remaining_time > 2.9:
			emit_signal("power_warning", player_index, power_data.type, remaining_time)
	
	# Clean up expired powers
	for player_index in players_to_remove:
		deactivate_power(player_index)

# Configuration Methods

func get_power_config(power_type: PowerType) -> Dictionary:
	"""Get configuration for a specific power type"""
	return power_configs.get(power_type, {})

func set_power_duration(power_type: PowerType, duration: float) -> void:
	"""Set duration for a specific power type"""
	if power_configs.has(power_type):
		power_configs[power_type].duration = duration

func set_spawn_chance(power_type: PowerType, chance: float) -> void:
	"""Set spawn chance for a specific power type"""
	if power_configs.has(power_type):
		power_configs[power_type].spawn_chance = clamp(chance, 0.0, 1.0)

func set_enemy_spawn_rate(power_type: PowerType, enemy_class: String, rate: float) -> void:
	"""Set spawn rate for a specific enemy type"""
	if power_configs.has(power_type):
		power_configs[power_type].enemy_spawn_rates[enemy_class] = clamp(rate, 0.0, 1.0)

# Debug Methods

func get_debug_info() -> Dictionary:
	"""Get debug information about active powers"""
	var debug_info = {
		"active_powers_count": active_powers.size(),
		"active_powers": {},
		"power_configs": power_configs
	}
	
	for player_index in active_powers.keys():
		var power_data = active_powers[player_index]
		debug_info.active_powers[player_index] = {
			"type": power_data.type,
			"remaining_time": power_data.get_remaining_time(),
			"is_expired": power_data.is_expired()
		}
	
	return debug_info

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