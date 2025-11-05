extends TestBase

# Test class for PowerAnalytics system
class_name TestPowerAnalytics

var power_analytics: Node  # PowerAnalytics
var test_spawn_position: Vector2 = Vector2(400, 300)

func _init():
	test_name = "Power Analytics System Tests"

func setup():
	# Create PowerAnalytics instance
	power_analytics = preload("res://scripts/managers/power_analytics.gd").new()
	power_analytics.name = "TestPowerAnalytics"
	add_child(power_analytics)
	
	# Disable file operations for testing
	power_analytics.telemetry_enabled = false
	power_analytics.analytics_file_path = "user://test_power_analytics.json"

func cleanup():
	if power_analytics:
		power_analytics.queue_free()
		power_analytics = null

func run_tests():
	print("\n=== Power Analytics System Tests ===")
	
	# Basic functionality tests
	test_session_initialization()
	test_spawn_tracking()
	test_collection_tracking()
	test_power_activation_tracking()
	test_effectiveness_tracking()
	
	# Analysis tests
	test_spawn_rate_analysis()
	test_effectiveness_analysis()
	test_player_behavior_analysis()
	test_performance_monitoring()
	
	# Data management tests
	test_data_persistence()
	test_analytics_export()
	
	print("=== Power Analytics Tests Complete ===\n")

func test_session_initialization():
	"""Test analytics session initialization"""
	print("\n--- Testing Session Initialization ---")
	
	assert_test(power_analytics.session_id != "", "Session ID should be generated")
	assert_test(power_analytics.analytics_data.session_start_time > 0, "Session start time should be set")
	assert_test(power_analytics.analytics_data.has("total_spawn_attempts"), "Analytics data should have spawn attempts")
	assert_test(power_analytics.analytics_data.has("power_collections"), "Analytics data should have collections tracking")
	
	print("✓ Session initialization working correctly")

func test_spawn_tracking():
	"""Test spawn attempt and success tracking"""
	print("\n--- Testing Spawn Tracking ---")
	
	var initial_attempts = power_analytics.analytics_data.total_spawn_attempts
	var initial_successes = power_analytics.analytics_data.successful_spawns
	
	# Track spawn attempt
	power_analytics.track_spawn_attempt("EnemyBase", test_spawn_position)
	assert_test(power_analytics.analytics_data.total_spawn_attempts == initial_attempts + 1, "Spawn attempts should increment")
	
	# Track successful spawn
	power_analytics.track_successful_spawn("EnemyBase", test_spawn_position, 0)
	assert_test(power_analytics.analytics_data.successful_spawns == initial_successes + 1, "Successful spawns should increment")
	
	# Check spawn location tracking
	assert_test(power_analytics.analytics_data.spawn_locations.size() > 0, "Spawn locations should be tracked")
	var last_spawn = power_analytics.analytics_data.spawn_locations[-1]
	assert_test(last_spawn.successful == true, "Last spawn should be marked as successful")
	assert_test(last_spawn.enemy_type == "EnemyBase", "Enemy type should be tracked")
	
	print("✓ Spawn tracking working correctly")

func test_collection_tracking():
	"""Test power collection tracking"""
	print("\n--- Testing Collection Tracking ---")
	
	var player_index = 1
	var power_type = 0  # Invincibility
	
	# Track collection
	power_analytics.track_power_collection(player_index, power_type, test_spawn_position)
	
	# Check collection statistics
	assert_test(power_analytics.analytics_data.power_collections.has(power_type), "Power collections should be tracked by type")
	assert_test(power_analytics.analytics_data.power_collections[power_type] == 1, "Collection count should increment")
	
	# Check player behavior tracking
	assert_test(power_analytics.analytics_data.player_behavior.has(player_index), "Player behavior should be tracked")
	var player_data = power_analytics.analytics_data.player_behavior[player_index]
	assert_test(player_data.collections.has(power_type), "Player collections should be tracked by power type")
	assert_test(player_data.collections[power_type] == 1, "Player collection count should increment")
	
	print("✓ Collection tracking working correctly")

func test_power_activation_tracking():
	"""Test power activation tracking"""
	print("\n--- Testing Power Activation Tracking ---")
	
	var player_index = 1
	var power_type = 0  # Invincibility
	var duration = 10.0
	
	# Track activation
	power_analytics.track_power_activation(player_index, power_type, duration)
	
	# Check activation statistics
	assert_test(power_analytics.analytics_data.power_activations.has(power_type), "Power activations should be tracked")
	assert_test(power_analytics.analytics_data.power_activations[power_type] == 1, "Activation count should increment")
	
	# Check effectiveness tracking initialization
	assert_test(power_analytics.analytics_data.power_effectiveness.has(power_type), "Power effectiveness should be tracked")
	var effectiveness_data = power_analytics.analytics_data.power_effectiveness[power_type]
	assert_test(effectiveness_data.total_duration == duration, "Total duration should be tracked")
	assert_test(effectiveness_data.activations == 1, "Activation count should be tracked")
	
	print("✓ Power activation tracking working correctly")

func test_effectiveness_tracking():
	"""Test power effectiveness tracking"""
	print("\n--- Testing Effectiveness Tracking ---")
	
	var player_index = 1
	var power_type = 0  # Invincibility
	
	# Setup initial activation
	power_analytics.track_power_activation(player_index, power_type, 10.0)
	
	# Track enemy defeat
	power_analytics.track_enemy_defeat_with_power(player_index, power_type, "EnemyBase")
	
	# Check effectiveness data
	var effectiveness_data = power_analytics.analytics_data.power_effectiveness[power_type]
	assert_test(effectiveness_data.enemies_defeated == 1, "Enemy defeats should be tracked")
	
	# Track power expiration
	power_analytics.track_power_expiration(player_index, power_type, 8.0, 10.0)
	
	# Check balance data
	assert_test(power_analytics.analytics_data.balance_data.power_duration_usage.has(power_type), "Duration usage should be tracked")
	var duration_data = power_analytics.analytics_data.balance_data.power_duration_usage[power_type]
	assert_test(duration_data.total_used == 8.0, "Used duration should be tracked")
	assert_test(duration_data.total_possible == 10.0, "Possible duration should be tracked")
	
	print("✓ Effectiveness tracking working correctly")

func test_spawn_rate_analysis():
	"""Test spawn rate analysis"""
	print("\n--- Testing Spawn Rate Analysis ---")
	
	# Generate test data
	for i in range(100):
		power_analytics.track_spawn_attempt("EnemyBase", test_spawn_position)
		if i < 15:  # 15% success rate
			power_analytics.track_successful_spawn("EnemyBase", test_spawn_position, 0)
	
	# Get analysis
	var analysis = power_analytics.get_spawn_rate_analysis()
	
	assert_test(analysis.has("EnemyBase"), "Analysis should include EnemyBase")
	var enemy_data = analysis["EnemyBase"]
	assert_test(abs(enemy_data.actual_rate - 0.15) < 0.02, "Actual rate should be approximately 15%")
	assert_test(enemy_data.sample_size >= 100, "Sample size should be tracked")
	assert_test(enemy_data.has("recommendation"), "Analysis should include recommendations")
	
	print("✓ Spawn rate analysis working correctly")

func test_effectiveness_analysis():
	"""Test power effectiveness analysis"""
	print("\n--- Testing Effectiveness Analysis ---")
	
	var power_type = 0
	
	# Generate test data
	for i in range(10):
		power_analytics.track_power_activation(1, power_type, 10.0)
		power_analytics.track_enemy_defeat_with_power(1, power_type, "EnemyBase")
		power_analytics.track_enemy_defeat_with_power(1, power_type, "EnemyBase")
		power_analytics.track_power_expiration(1, power_type, 9.0, 10.0)
	
	# Get analysis
	var analysis = power_analytics.get_power_effectiveness_analysis()
	
	assert_test(analysis.has(power_type), "Analysis should include power type")
	var power_data = analysis[power_type]
	assert_test(power_data.average_enemies_defeated == 2.0, "Average enemies defeated should be calculated")
	assert_test(power_data.total_activations == 10, "Total activations should be tracked")
	assert_test(power_data.has("effectiveness_score"), "Effectiveness score should be calculated")
	
	print("✓ Effectiveness analysis working correctly")

func test_player_behavior_analysis():
	"""Test player behavior analysis"""
	print("\n--- Testing Player Behavior Analysis ---")
	
	var player_index = 1
	var power_type = 0
	
	# Generate test data
	for i in range(5):
		power_analytics.track_power_collection(player_index, power_type, test_spawn_position)
		power_analytics.track_power_activation(player_index, power_type, 10.0)
	
	# Get analysis
	var analysis = power_analytics.get_player_behavior_analysis()
	
	assert_test(analysis.has(player_index), "Analysis should include player")
	var player_data = analysis[player_index]
	assert_test(player_data.total_collections == 5, "Total collections should be tracked")
	assert_test(player_data.collection_efficiency == 1.0, "Collection efficiency should be calculated")
	assert_test(player_data.has("preferred_power_type"), "Preferred power type should be identified")
	
	print("✓ Player behavior analysis working correctly")

func test_performance_monitoring():
	"""Test performance monitoring"""
	print("\n--- Testing Performance Monitoring ---")
	
	# Track some performance issues
	power_analytics.track_performance_issue("frame_drop", {"frame_time": 0.025})
	power_analytics.track_performance_issue("audio_stutter", {"duration": 0.1})
	power_analytics.track_performance_issue("memory_spike", {"increase": 50 * 1024 * 1024})
	
	# Get performance report
	var report = power_analytics.get_performance_report()
	
	assert_test(report.has("frame_drops"), "Frame drops should be tracked")
	assert_test(report.has("audio_stutters"), "Audio stutters should be tracked")
	assert_test(report.has("performance_score"), "Performance score should be calculated")
	assert_test(report.frame_drops >= 1, "Frame drop should be recorded")
	assert_test(report.audio_stutters >= 1, "Audio stutter should be recorded")
	
	print("✓ Performance monitoring working correctly")

func test_data_persistence():
	"""Test analytics data persistence"""
	print("\n--- Testing Data Persistence ---")
	
	# Add some test data
	power_analytics.track_spawn_attempt("EnemyBase", test_spawn_position)
	power_analytics.track_successful_spawn("EnemyBase", test_spawn_position, 0)
	
	# Save data
	var save_success = power_analytics.save_analytics_data()
	assert_test(save_success, "Analytics data should save successfully")
	
	# Check if file exists
	assert_test(FileAccess.file_exists(power_analytics.analytics_file_path), "Analytics file should be created")
	
	print("✓ Data persistence working correctly")

func test_analytics_export():
	"""Test analytics report export"""
	print("\n--- Testing Analytics Export ---")
	
	# Add some test data
	power_analytics.track_power_collection(1, 0, test_spawn_position)
	power_analytics.track_power_activation(1, 0, 10.0)
	
	# Export report
	var export_path = "user://test_analytics_report.json"
	var export_success = power_analytics.export_analytics_report(export_path)
	assert_test(export_success, "Analytics report should export successfully")
	
	# Check if export file exists
	assert_test(FileAccess.file_exists(export_path), "Export file should be created")
	
	# Verify export content
	var file = FileAccess.open(export_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		assert_test(content.length() > 0, "Export file should have content")
		assert_test(content.contains("session_info"), "Export should contain session info")
		assert_test(content.contains("spawn_analysis"), "Export should contain spawn analysis")
	
	print("✓ Analytics export working correctly")

func test_error_tracking():
	"""Test error tracking and health monitoring"""
	print("\n--- Testing Error Tracking ---")
	
	# Track some errors
	power_analytics.track_error("power_activation_failed", "Player not found", {"player_index": 1})
	power_analytics.track_error("spawn_failed", "PowerManager not available", {})
	
	# Check error reports
	assert_test(power_analytics.analytics_data.error_reports.size() >= 2, "Errors should be tracked")
	
	var first_error = power_analytics.analytics_data.error_reports[0]
	assert_test(first_error.type == "power_activation_failed", "Error type should be tracked")
	assert_test(first_error.message == "Player not found", "Error message should be tracked")
	assert_test(first_error.has("timestamp"), "Error timestamp should be tracked")
	assert_test(first_error.has("session_id"), "Error session ID should be tracked")
	
	print("✓ Error tracking working correctly")

func test_visualization_data():
	"""Test visualization data generation"""
	print("\n--- Testing Visualization Data ---")
	
	# Add test data
	power_analytics.track_spawn_attempt("EnemyBase", test_spawn_position)
	power_analytics.track_successful_spawn("EnemyBase", test_spawn_position, 0)
	power_analytics.track_power_collection(1, 0, test_spawn_position)
	
	# Get visualization data
	var spawn_data = power_analytics.get_spawn_visualization_data()
	var heatmap_data = power_analytics.get_collection_heatmap_data()
	
	assert_test(spawn_data.size() > 0, "Spawn visualization data should be available")
	assert_test(heatmap_data.has(1), "Heatmap data should include player data")
	
	var player_heatmap = heatmap_data[1]
	assert_test(player_heatmap.size() > 0, "Player heatmap should have collection data")
	
	print("✓ Visualization data generation working correctly")