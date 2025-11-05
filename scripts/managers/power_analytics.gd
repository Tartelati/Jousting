class_name PowerAnalytics
extends Node

# Analytics data structures
var analytics_data: Dictionary = {
	"session_start_time": 0.0,
	"total_spawn_attempts": 0,
	"successful_spawns": 0,
	"power_collections": {},  # power_type -> count
	"power_activations": {},  # power_type -> count
	"power_effectiveness": {},  # power_type -> {total_duration: float, enemies_defeated: int}
	"player_behavior": {},  # player_index -> behavior data
	"spawn_locations": [],  # Array of spawn position data
	"performance_metrics": {
		"frame_drops": 0,
		"audio_stutters": 0,
		"memory_usage_peaks": [],
		"power_processing_times": []
	},
	"error_reports": [],
	"balance_data": {
		"spawn_rate_effectiveness": {},  # enemy_type -> actual vs expected spawn rates
		"power_duration_usage": {},  # power_type -> average usage vs full duration
		"player_preference_patterns": {}  # Which powers are collected most by which players
	}
}

# Performance monitoring
var frame_time_samples: Array[float] = []
var memory_usage_samples: Array[int] = []
var last_frame_time: float = 0.0
var performance_monitoring_enabled: bool = true

# Telemetry settings
var telemetry_enabled: bool = true
var analytics_file_path: String = "user://power_analytics.json"
var session_id: String = ""

# References
var power_manager: Node
var config_manager

# Signals for real-time analytics
signal analytics_updated(metric_type: String, data: Dictionary)
signal performance_warning(warning_type: String, details: Dictionary)
signal balance_insight_discovered(insight_type: String, data: Dictionary)

func _ready():
	_initialize_session()
	_find_managers()
	_setup_performance_monitoring()
	_load_historical_data()

func _initialize_session():
	"""Initialize analytics session"""
	analytics_data.session_start_time = Time.get_time_dict_from_system().unix
	session_id = "power_session_%d_%d" % [analytics_data.session_start_time, randi() % 10000]
	print("[PowerAnalytics] Session initialized: %s" % session_id)

func _find_managers():
	"""Find power manager and config manager references"""
	power_manager = get_node_or_null("/root/PowerManager")
	if power_manager:
		# Connect to power manager signals
		if power_manager.has_signal("power_activated"):
			power_manager.power_activated.connect(_on_power_activated)
		if power_manager.has_signal("power_expired"):
			power_manager.power_expired.connect(_on_power_expired)
		
		# Get config manager reference
		if power_manager.has_method("get_configuration_manager"):
			config_manager = power_manager.get_configuration_manager()

func _setup_performance_monitoring():
	"""Setup performance monitoring systems"""
	if performance_monitoring_enabled:
		# Create timer for regular performance sampling
		var perf_timer = Timer.new()
		perf_timer.wait_time = 0.1  # Sample every 100ms
		perf_timer.timeout.connect(_sample_performance_metrics)
		add_child(perf_timer)
		perf_timer.start()

func _load_historical_data():
	"""Load historical analytics data if available"""
	if FileAccess.file_exists(analytics_file_path):
		var file = FileAccess.open(analytics_file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				var historical_data = json.data
				_merge_historical_data(historical_data)
				print("[PowerAnalytics] Loaded historical data")

func _merge_historical_data(historical_data: Dictionary):
	"""Merge historical data with current session"""
	# Merge cumulative statistics
	if historical_data.has("total_spawn_attempts"):
		analytics_data.total_spawn_attempts += historical_data.total_spawn_attempts
	if historical_data.has("successful_spawns"):
		analytics_data.successful_spawns += historical_data.successful_spawns
	
	# Merge power collection data
	if historical_data.has("power_collections"):
		for power_type in historical_data.power_collections:
			if not analytics_data.power_collections.has(power_type):
				analytics_data.power_collections[power_type] = 0
			analytics_data.power_collections[power_type] += historical_data.power_collections[power_type]

# Public Analytics Interface

func track_spawn_attempt(enemy_type: String, spawn_position: Vector2):
	"""Track a power egg spawn attempt"""
	analytics_data.total_spawn_attempts += 1
	
	# Track spawn location for visualization
	analytics_data.spawn_locations.append({
		"position": {"x": spawn_position.x, "y": spawn_position.y},
		"enemy_type": enemy_type,
		"timestamp": Time.get_time_dict_from_system().unix,
		"successful": false
	})
	
	# Limit spawn location history to prevent memory bloat
	if analytics_data.spawn_locations.size() > 1000:
		analytics_data.spawn_locations = analytics_data.spawn_locations.slice(-500)
	
	emit_signal("analytics_updated", "spawn_attempt", {"enemy_type": enemy_type, "position": spawn_position})

func track_successful_spawn(enemy_type: String, _spawn_position: Vector2, power_type: int):
	"""Track a successful power egg spawn"""
	analytics_data.successful_spawns += 1
	
	# Update the last spawn location entry
	if analytics_data.spawn_locations.size() > 0:
		var last_spawn = analytics_data.spawn_locations[-1]
		last_spawn.successful = true
		last_spawn.power_type = power_type
	
	# Update balance data
	if not analytics_data.balance_data.spawn_rate_effectiveness.has(enemy_type):
		analytics_data.balance_data.spawn_rate_effectiveness[enemy_type] = {
			"attempts": 0,
			"successes": 0,
			"expected_rate": 0.15  # Default, will be updated from config
		}
	
	var spawn_data = analytics_data.balance_data.spawn_rate_effectiveness[enemy_type]
	spawn_data.attempts += 1
	spawn_data.successes += 1
	
	# Update expected rate from config if available
	if config_manager and config_manager.has_method("get_enemy_spawn_rate"):
		spawn_data.expected_rate = config_manager.get_enemy_spawn_rate("invincibility", enemy_type)
	
	emit_signal("analytics_updated", "successful_spawn", {"enemy_type": enemy_type, "power_type": power_type})

func track_power_collection(player_index: int, power_type: int, collection_position: Vector2):
	"""Track power collection by player"""
	# Update collection statistics
	if not analytics_data.power_collections.has(power_type):
		analytics_data.power_collections[power_type] = 0
	analytics_data.power_collections[power_type] += 1
	
	# Track player behavior
	if not analytics_data.player_behavior.has(player_index):
		analytics_data.player_behavior[player_index] = {
			"collections": {},
			"activations": {},
			"total_power_time": 0.0,
			"enemies_defeated_with_power": 0,
			"collection_positions": []
		}
	
	var player_data = analytics_data.player_behavior[player_index]
	if not player_data.collections.has(power_type):
		player_data.collections[power_type] = 0
	player_data.collections[power_type] += 1
	
	# Track collection position for behavior analysis
	player_data.collection_positions.append({
		"position": {"x": collection_position.x, "y": collection_position.y},
		"power_type": power_type,
		"timestamp": Time.get_time_dict_from_system().unix
	})
	
	# Limit position history
	if player_data.collection_positions.size() > 100:
		player_data.collection_positions = player_data.collection_positions.slice(-50)
	
	emit_signal("analytics_updated", "power_collection", {
		"player_index": player_index,
		"power_type": power_type,
		"position": collection_position
	})

func track_power_activation(player_index: int, power_type: int, duration: float):
	"""Track power activation"""
	# Update activation statistics
	if not analytics_data.power_activations.has(power_type):
		analytics_data.power_activations[power_type] = 0
	analytics_data.power_activations[power_type] += 1
	
	# Initialize effectiveness tracking
	if not analytics_data.power_effectiveness.has(power_type):
		analytics_data.power_effectiveness[power_type] = {
			"total_duration": 0.0,
			"enemies_defeated": 0,
			"activations": 0,
			"full_duration_usage": 0
		}
	
	var effectiveness_data = analytics_data.power_effectiveness[power_type]
	effectiveness_data.total_duration += duration
	effectiveness_data.activations += 1
	
	# Track player behavior
	if analytics_data.player_behavior.has(player_index):
		var player_data = analytics_data.player_behavior[player_index]
		if not player_data.activations.has(power_type):
			player_data.activations[power_type] = 0
		player_data.activations[power_type] += 1

func track_power_expiration(_player_index: int, power_type: int, actual_duration: float, full_duration: float):
	"""Track power expiration and usage effectiveness"""
	if analytics_data.power_effectiveness.has(power_type):
		var effectiveness_data = analytics_data.power_effectiveness[power_type]
		
		# Track if player used full duration
		if actual_duration >= full_duration * 0.95:  # 95% threshold for "full usage"
			effectiveness_data.full_duration_usage += 1
		
		# Update balance data
		if not analytics_data.balance_data.power_duration_usage.has(power_type):
			analytics_data.balance_data.power_duration_usage[power_type] = {
				"total_possible": 0.0,
				"total_used": 0.0,
				"usage_efficiency": 0.0
			}
		
		var duration_data = analytics_data.balance_data.power_duration_usage[power_type]
		duration_data.total_possible += full_duration
		duration_data.total_used += actual_duration
		duration_data.usage_efficiency = duration_data.total_used / duration_data.total_possible

func track_enemy_defeat_with_power(player_index: int, power_type: int, _enemy_type: String):
	"""Track enemy defeated while power is active"""
	if analytics_data.power_effectiveness.has(power_type):
		analytics_data.power_effectiveness[power_type].enemies_defeated += 1
	
	if analytics_data.player_behavior.has(player_index):
		analytics_data.player_behavior[player_index].enemies_defeated_with_power += 1

func track_performance_issue(issue_type: String, details: Dictionary):
	"""Track performance issues"""
	match issue_type:
		"frame_drop":
			analytics_data.performance_metrics.frame_drops += 1
		"audio_stutter":
			analytics_data.performance_metrics.audio_stutters += 1
		"memory_spike":
			analytics_data.performance_metrics.memory_usage_peaks.append(details)
	
	emit_signal("performance_warning", issue_type, details)

func track_error(error_type: String, error_message: String, context: Dictionary = {}):
	"""Track system errors for health monitoring"""
	var error_report = {
		"type": error_type,
		"message": error_message,
		"context": context,
		"timestamp": Time.get_time_dict_from_system().unix,
		"session_id": session_id
	}
	
	analytics_data.error_reports.append(error_report)
	
	# Limit error report history
	if analytics_data.error_reports.size() > 100:
		analytics_data.error_reports = analytics_data.error_reports.slice(-50)

# Performance Monitoring

func _sample_performance_metrics():
	"""Sample performance metrics"""
	if not performance_monitoring_enabled:
		return
	
	var current_time = Time.get_time_dict_from_system().unix
	var frame_time = get_process_delta_time()
	
	# Track frame time
	frame_time_samples.append(frame_time)
	if frame_time_samples.size() > 600:  # Keep 60 seconds of samples at 10Hz
		frame_time_samples = frame_time_samples.slice(-300)
	
	# Detect frame drops (>20ms frame time = <50 FPS)
	if frame_time > 0.02:
		track_performance_issue("frame_drop", {
			"frame_time": frame_time,
			"timestamp": current_time
		})
	
	# Sample memory usage (simplified - using available memory info)
	var total_memory = 0
	
	# Use basic memory info as fallback
	total_memory = OS.get_static_memory_peak_usage()
	
	if total_memory > 0:
		memory_usage_samples.append(total_memory)
		if memory_usage_samples.size() > 600:
			memory_usage_samples = memory_usage_samples.slice(-300)
		
		# Detect memory spikes (>50MB increase in 1 second)
		if memory_usage_samples.size() >= 10:
			var recent_avg = 0
			var older_avg = 0
			for i in range(5):
				recent_avg += memory_usage_samples[-(i+1)]
				older_avg += memory_usage_samples[-(i+6)]
			recent_avg /= 5
			older_avg /= 5
			
			if recent_avg - older_avg > 50 * 1024 * 1024:  # 50MB spike
				track_performance_issue("memory_spike", {
					"increase": recent_avg - older_avg,
					"timestamp": current_time
				})

# Analytics and Balance Analysis

func get_spawn_rate_analysis() -> Dictionary:
	"""Analyze spawn rate effectiveness"""
	var analysis = {}
	
	for enemy_type in analytics_data.balance_data.spawn_rate_effectiveness:
		var spawn_data = analytics_data.balance_data.spawn_rate_effectiveness[enemy_type]
		var actual_rate = float(spawn_data.successes) / float(spawn_data.attempts) if spawn_data.attempts > 0 else 0.0
		var expected_rate = spawn_data.expected_rate
		var deviation = abs(actual_rate - expected_rate)
		
		analysis[enemy_type] = {
			"actual_rate": actual_rate,
			"expected_rate": expected_rate,
			"deviation": deviation,
			"sample_size": spawn_data.attempts,
			"recommendation": _get_spawn_rate_recommendation(actual_rate, expected_rate, spawn_data.attempts)
		}
	
	return analysis

func _get_spawn_rate_recommendation(actual: float, expected: float, sample_size: int) -> String:
	"""Get recommendation for spawn rate adjustment"""
	if sample_size < 50:
		return "Need more data (minimum 50 samples)"
	
	var deviation = abs(actual - expected)
	if deviation < 0.02:  # Within 2%
		return "Spawn rate is well balanced"
	elif actual > expected:
		return "Consider reducing spawn rate by %.1f%%" % ((actual - expected) * 100)
	else:
		return "Consider increasing spawn rate by %.1f%%" % ((expected - actual) * 100)

func get_power_effectiveness_analysis() -> Dictionary:
	"""Analyze power effectiveness"""
	var analysis = {}
	
	for power_type in analytics_data.power_effectiveness:
		var effectiveness_data = analytics_data.power_effectiveness[power_type]
		var avg_enemies_per_activation = float(effectiveness_data.enemies_defeated) / float(effectiveness_data.activations) if effectiveness_data.activations > 0 else 0.0
		var full_usage_rate = float(effectiveness_data.full_duration_usage) / float(effectiveness_data.activations) if effectiveness_data.activations > 0 else 0.0
		
		analysis[power_type] = {
			"average_enemies_defeated": avg_enemies_per_activation,
			"full_duration_usage_rate": full_usage_rate,
			"total_activations": effectiveness_data.activations,
			"effectiveness_score": _calculate_effectiveness_score(avg_enemies_per_activation, full_usage_rate),
			"recommendation": _get_effectiveness_recommendation(avg_enemies_per_activation, full_usage_rate)
		}
	
	return analysis

func _calculate_effectiveness_score(avg_enemies: float, usage_rate: float) -> float:
	"""Calculate overall effectiveness score (0-100)"""
	var enemy_score = min(avg_enemies * 20, 60)  # Max 60 points for enemy defeats
	var usage_score = usage_rate * 40  # Max 40 points for duration usage
	return enemy_score + usage_score

func _get_effectiveness_recommendation(avg_enemies: float, usage_rate: float) -> String:
	"""Get recommendation for power balance"""
	if avg_enemies < 1.0:
		return "Power may be too weak - consider increasing duration or effect"
	elif avg_enemies > 5.0:
		return "Power may be too strong - consider reducing duration or spawn rate"
	elif usage_rate < 0.5:
		return "Players not using full duration - consider reducing duration or increasing effect"
	else:
		return "Power appears well balanced"

func get_player_behavior_analysis() -> Dictionary:
	"""Analyze player behavior patterns"""
	var analysis = {}
	
	for player_index in analytics_data.player_behavior:
		var player_data = analytics_data.player_behavior[player_index]
		var total_collections = 0
		var preferred_power = -1
		var max_collections = 0
		
		# Find preferred power type
		for power_type in player_data.collections:
			var count = player_data.collections[power_type]
			total_collections += count
			if count > max_collections:
				max_collections = count
				preferred_power = power_type
		
		# Calculate collection efficiency (collections vs activations)
		var total_activations = 0
		for power_type in player_data.activations:
			total_activations += player_data.activations[power_type]
		
		var collection_efficiency = float(total_activations) / float(total_collections) if total_collections > 0 else 0.0
		
		analysis[player_index] = {
			"total_collections": total_collections,
			"preferred_power_type": preferred_power,
			"collection_efficiency": collection_efficiency,
			"average_power_time": player_data.total_power_time / float(total_activations) if total_activations > 0 else 0.0,
			"combat_effectiveness": float(player_data.enemies_defeated_with_power) / float(total_activations) if total_activations > 0 else 0.0
		}
	
	return analysis

func get_performance_report() -> Dictionary:
	"""Get performance analysis report"""
	var avg_frame_time = 0.0
	if frame_time_samples.size() > 0:
		for sample in frame_time_samples:
			avg_frame_time += sample
		avg_frame_time /= frame_time_samples.size()
	
	var avg_memory = 0
	if memory_usage_samples.size() > 0:
		for sample in memory_usage_samples:
			avg_memory += sample
		avg_memory /= memory_usage_samples.size()
	
	return {
		"average_frame_time": avg_frame_time,
		"average_fps": 1.0 / avg_frame_time if avg_frame_time > 0 else 0.0,
		"frame_drops": analytics_data.performance_metrics.frame_drops,
		"audio_stutters": analytics_data.performance_metrics.audio_stutters,
		"average_memory_usage": avg_memory,
		"memory_spikes": analytics_data.performance_metrics.memory_usage_peaks.size(),
		"performance_score": _calculate_performance_score()
	}

func _calculate_performance_score() -> float:
	"""Calculate overall performance score (0-100)"""
	var score = 100.0
	
	# Deduct for frame drops
	score -= min(analytics_data.performance_metrics.frame_drops * 2, 30)
	
	# Deduct for audio issues
	score -= min(analytics_data.performance_metrics.audio_stutters * 5, 20)
	
	# Deduct for memory spikes
	score -= min(analytics_data.performance_metrics.memory_usage_peaks.size() * 3, 25)
	
	return max(score, 0.0)

# Debug Visualization Data

func get_spawn_visualization_data() -> Array:
	"""Get spawn location data for debug visualization"""
	return analytics_data.spawn_locations.duplicate()

func get_collection_heatmap_data() -> Dictionary:
	"""Get collection position data for heatmap visualization"""
	var heatmap_data = {}
	
	for player_index in analytics_data.player_behavior:
		var player_data = analytics_data.player_behavior[player_index]
		heatmap_data[player_index] = player_data.collection_positions.duplicate()
	
	return heatmap_data

# Data Persistence

func save_analytics_data():
	"""Save analytics data to file"""
	var file = FileAccess.open(analytics_file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(analytics_data)
		file.store_string(json_string)
		file.close()
		print("[PowerAnalytics] Analytics data saved")
		return true
	else:
		print("[PowerAnalytics] Failed to save analytics data")
		return false

func export_analytics_report(file_path: String = "") -> bool:
	"""Export comprehensive analytics report"""
	if file_path == "":
		file_path = "user://power_analytics_report_%d.json" % Time.get_time_dict_from_system().unix
	
	var report = {
		"session_info": {
			"session_id": session_id,
			"start_time": analytics_data.session_start_time,
			"duration": Time.get_time_dict_from_system().unix - analytics_data.session_start_time
		},
		"spawn_analysis": get_spawn_rate_analysis(),
		"effectiveness_analysis": get_power_effectiveness_analysis(),
		"player_behavior": get_player_behavior_analysis(),
		"performance_report": get_performance_report(),
		"raw_data": analytics_data
	}
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(report, "\t")
		file.store_string(json_string)
		file.close()
		print("[PowerAnalytics] Report exported to: %s" % file_path)
		return true
	else:
		print("[PowerAnalytics] Failed to export report")
		return false

# Signal handlers

func _on_power_activated(player_index: int, power_type: int, duration: float):
	"""Handle power activation signal"""
	track_power_activation(player_index, power_type, duration)

func _on_power_expired(_player_index: int, _power_type: int):
	"""Handle power expiration signal"""
	# We would need additional data to track actual vs full duration
	# This would require modifications to the power manager to provide this info
	pass

func _exit_tree():
	"""Save analytics data when exiting"""
	save_analytics_data()