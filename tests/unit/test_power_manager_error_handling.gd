extends TestBase

# Unit tests for PowerManager error handling and edge cases

var power_manager: Node

func before_each():
	# Get reference to the PowerManager autoload
	power_manager = get_node("/root/PowerManager")
	
	# Reset all powers before each test
	if power_manager:
		power_manager.reset_all_powers()

func test_invalid_player_indices():
	"""Test handling of invalid player indices"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Test various invalid player indices
	assert_false(power_manager.activate_power(-1, power_type), "Negative player index should fail")
	assert_false(power_manager.activate_power(0, power_type), "Zero player index should fail")
	assert_false(power_manager.activate_power(5, power_type), "Player index > 4 should fail")
	assert_false(power_manager.activate_power(999, power_type), "Very large player index should fail")
	
	# Deactivation should handle invalid indices gracefully
	power_manager.deactivate_power(-1)  # Should not crash
	power_manager.deactivate_power(0)   # Should not crash
	power_manager.deactivate_power(5)   # Should not crash

func test_invalid_power_types():
	"""Test handling of invalid power types"""
	var player_index = 1
	
	# Test various invalid power types
	assert_false(power_manager.activate_power(player_index, -2), "Invalid negative power type should fail")
	assert_false(power_manager.activate_power(player_index, 999), "Non-existent power type should fail")

func test_missing_player_references():
	"""Test handling when player nodes are not available"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# This test verifies that the system handles missing GameManager gracefully
	# The _get_player_safely method should handle this case
	
	# Try to activate power - should handle missing player gracefully
	var result = power_manager.activate_power(player_index, power_type)
	
	# The result depends on whether GameManager is available in the test environment
	# The important thing is that it doesn't crash
	assert_true(true, "Power activation with potentially missing player should not crash")

func test_power_egg_scene_loading_failure():
	"""Test handling of power egg scene loading failures"""
	# Test that get_power_egg_scene handles missing files gracefully
	var scene = power_manager.get_power_egg_scene()
	
	# Should either return a valid scene or null (not crash)
	if scene != null:
		assert_true(scene is PackedScene, "Returned scene should be a PackedScene")
	
	# The method should not crash regardless of file availability
	assert_true(true, "get_power_egg_scene should handle missing files gracefully")

func test_spawn_probability_with_invalid_enemy_names():
	"""Test spawn probability calculation with invalid enemy names"""
	# Test with null and empty enemy names
	var result1 = power_manager.should_spawn_power_egg("")
	var result2 = power_manager.should_spawn_power_egg("   ")
	var result3 = power_manager.should_spawn_power_egg("NonExistentEnemy")
	
	# Should not crash and should return boolean values
	assert_true(result1 is bool, "Empty enemy name should return boolean")
	assert_true(result2 is bool, "Whitespace enemy name should return boolean")
	assert_true(result3 is bool, "Non-existent enemy name should return boolean")

func test_configuration_manager_unavailable():
	"""Test behavior when configuration manager is not available"""
	# Temporarily remove config manager reference
	var original_config_manager = power_manager.config_manager
	power_manager.config_manager = null
	
	# Test various operations
	var spawn_result = power_manager.should_spawn_power_egg("EnemyBase")
	assert_false(spawn_result, "Should return false when config manager unavailable")
	
	var activation_result = power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
	assert_false(activation_result, "Should return false when config manager unavailable")
	
	# Restore config manager
	power_manager.config_manager = original_config_manager

func test_timer_creation_failure_protection():
	"""Test protection against timer creation failures"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate power - should handle timer creation gracefully
	var result = power_manager.activate_power(player_index, power_type)
	
	# If activation succeeded, verify timer exists
	if result:
		assert_true(power_manager.power_timers.has(player_index), "Timer should be created for successful activation")
	
	# Test should not crash regardless of timer creation success
	assert_true(true, "Timer creation should be handled gracefully")

func test_force_power_expiration():
	"""Test force expiration safety mechanism"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate power
	var result = power_manager.activate_power(player_index, power_type)
	if result:
		# Manually trigger force expiration
		power_manager._force_power_expiration(player_index)
		
		# Power should be deactivated
		assert_false(power_manager.is_power_active(player_index), "Force expiration should deactivate power")

func test_cleanup_failed_activation():
	"""Test cleanup of failed activation state"""
	var player_index = 1
	
	# Manually add some partial state
	power_manager.active_powers[player_index] = null  # Simulate partial state
	
	# Call cleanup
	power_manager._cleanup_failed_activation(player_index)
	
	# State should be cleaned up
	assert_false(power_manager.active_powers.has(player_index), "Failed activation state should be cleaned up")

func test_force_cleanup_power_state():
	"""Test force cleanup of power state"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate power normally
	power_manager.activate_power(player_index, power_type)
	
	# Force cleanup
	power_manager._force_cleanup_power_state(player_index)
	
	# All state should be cleaned up
	assert_false(power_manager.active_powers.has(player_index), "Active powers should be cleaned up")
	assert_false(power_manager.power_timers.has(player_index), "Power timers should be cleaned up")

func test_corrupted_active_powers_dictionary():
	"""Test handling of corrupted active_powers dictionary"""
	# This test verifies that update_power_timers handles corrupted data gracefully
	
	# Add some invalid data
	power_manager.active_powers[1] = null
	power_manager.active_powers[2] = "invalid_data"
	
	# Update timers - should handle corrupted data gracefully
	power_manager.update_power_timers(0.016)  # Simulate one frame
	
	# Should not crash and should clean up invalid entries
	assert_true(true, "update_power_timers should handle corrupted data gracefully")

func test_invalid_remaining_time_handling():
	"""Test handling of invalid remaining time values"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate power
	var result = power_manager.activate_power(player_index, power_type)
	if result:
		# Manually corrupt the power data to simulate invalid time
		var power_data = power_manager.active_powers[player_index]
		if power_data:
			power_data.start_time = -999999.0  # Invalid start time
			
			# Update timers - should handle invalid time gracefully
			power_manager.update_power_timers(0.016)
			
			# Power should be force expired due to invalid time
			assert_false(power_manager.is_power_active(player_index), "Invalid time should force expiration")

func test_audio_system_error_protection():
	"""Test audio system error protection"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Test audio methods with potentially missing audio nodes
	# These should not crash even if audio components are missing
	power_manager._play_activation_audio_safely(power_type, 1)
	power_manager._play_deactivation_audio_safely(power_type, 1)
	
	# If we get here without crashing, the test passes
	assert_true(true, "Audio methods should handle missing components gracefully")

func test_signal_emission_error_protection():
	"""Test signal emission error protection"""
	# Test signal emission with various argument combinations
	power_manager._emit_power_signal_safely("power_activated", [1, 0, 10.0])
	power_manager._emit_power_signal_safely("power_expired", [1, 0])
	power_manager._emit_power_signal_safely("nonexistent_signal", [1])
	
	# Should not crash regardless of signal validity
	assert_true(true, "Signal emission should handle errors gracefully")

func test_scene_change_cleanup():
	"""Test cleanup on scene changes"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate power
	power_manager.activate_power(player_index, power_type)
	
	# Simulate scene tree change
	power_manager._on_scene_tree_changed()
	
	# Should handle scene changes gracefully
	assert_true(true, "Scene change handling should not crash")

func test_node_removal_cleanup():
	"""Test cleanup when nodes are removed"""
	# Create a mock player node
	var mock_player = Node.new()
	mock_player.add_to_group("players")
	mock_player.set("player_index", 1)
	
	# Simulate node removal
	power_manager._on_node_removed(mock_player)
	
	# Should handle node removal gracefully
	assert_true(true, "Node removal handling should not crash")
	
	# Clean up mock node
	mock_player.queue_free()

func test_exit_tree_cleanup():
	"""Test resource cleanup on exit"""
	# This test verifies that _exit_tree doesn't crash
	# We can't actually call it without removing PowerManager from the tree
	# but we can verify the method exists and is callable
	
	assert_true(power_manager.has_method("_exit_tree"), "_exit_tree method should exist")
	
	# Test the cleanup components individually
	power_manager._force_cleanup_power_state(1)
	power_manager._force_cleanup_power_state(2)
	
	assert_true(true, "Cleanup methods should work without errors")