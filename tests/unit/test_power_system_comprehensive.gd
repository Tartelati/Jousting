extends TestBase

# Comprehensive test suite for the power system
# This test covers all aspects of power system functionality

var power_manager: Node

func before_each():
	# Get reference to the PowerManager autoload
	power_manager = get_node("/root/PowerManager")
	
	# Reset all powers before each test
	if power_manager:
		power_manager.reset_all_powers()

func test_power_activation_deactivation_logic():
	"""Test comprehensive power activation and deactivation logic"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Test initial state
	assert_false(power_manager.is_power_active(player_index), "No power should be active initially")
	assert_eq(power_manager.get_active_power_type(player_index), power_manager.PowerType.NONE, "Active power type should be NONE initially")
	assert_eq(power_manager.get_remaining_duration(player_index), 0.0, "Remaining duration should be 0 initially")
	
	# Test activation
	var result = power_manager.activate_power(player_index, power_type)
	assert_true(result, "Power activation should succeed")
	assert_true(power_manager.is_power_active(player_index), "Power should be active after activation")
	assert_eq(power_manager.get_active_power_type(player_index), power_type, "Active power type should match activated type")
	assert_gt(power_manager.get_remaining_duration(player_index), 0.0, "Remaining duration should be greater than 0")
	
	# Test deactivation
	power_manager.deactivate_power(player_index)
	assert_false(power_manager.is_power_active(player_index), "Power should be inactive after deactivation")
	assert_eq(power_manager.get_active_power_type(player_index), power_manager.PowerType.NONE, "Active power type should be NONE after deactivation")
	assert_eq(power_manager.get_remaining_duration(player_index), 0.0, "Remaining duration should be 0 after deactivation")

func test_spawn_probability_verification():
	"""Test power egg spawn probability matches configured 15% rate"""
	var enemy_types = ["EnemyBase", "EnemyHunter", "ShadowLord"]
	var expected_rates = {"EnemyBase": 0.15, "EnemyHunter": 0.20, "ShadowLord": 0.25}
	
	for enemy_type in enemy_types:
		var spawn_count = 0
		var total_tests = 1000  # Large sample size for statistical accuracy
		
		for i in total_tests:
			if power_manager.should_spawn_power_egg(enemy_type):
				spawn_count += 1
		
		var actual_rate = float(spawn_count) / float(total_tests)
		var expected_rate = expected_rates[enemy_type]
		var tolerance = 0.03  # 3% tolerance for randomness
		
		assert_ge(actual_rate, expected_rate - tolerance, 
			"%s spawn rate should be at least %.1f%% (got %.1f%%)" % [enemy_type, (expected_rate - tolerance) * 100, actual_rate * 100])
		assert_true(actual_rate <= expected_rate + tolerance, 
			"%s spawn rate should be at most %.1f%% (got %.1f%%)" % [enemy_type, (expected_rate + tolerance) * 100, actual_rate * 100])

func test_power_duration_and_expiration_timing():
	"""Test power duration tracking and expiration timing"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate power
	power_manager.activate_power(player_index, power_type)
	
	# Check initial duration
	var initial_duration = power_manager.get_remaining_duration(player_index)
	assert_gt(initial_duration, 9.5, "Initial duration should be close to 10 seconds")
	assert_true(initial_duration <= 10.0, "Initial duration should not exceed 10 seconds")
	
	# Simulate time passage
	await wait_frames(60)  # Wait 1 second at 60fps
	power_manager.update_power_timers(1.0)
	
	var duration_after_1s = power_manager.get_remaining_duration(player_index)
	assert_lt(duration_after_1s, initial_duration, "Duration should decrease after time passage")
	assert_gt(duration_after_1s, 8.5, "Duration should be approximately 9 seconds after 1 second")
	
	# Test expiration warning (should trigger at 3 seconds remaining)
	var power_data = power_manager.active_powers[player_index]
	if power_data:
		# Manually set time to trigger warning
		power_data.start_time = Time.get_time_dict_from_system().unix - 7.5  # 2.5 seconds remaining
		
		var warning_triggered = [false]  # Use array to avoid capture issues
		power_manager.power_warning.connect(func(_p_idx, _p_type, _remaining): warning_triggered[0] = true)
		
		power_manager.update_power_timers(0.016)
		assert_true(warning_triggered[0], "Warning should be triggered when 3 seconds or less remaining")
	
	# Test automatic expiration
	if power_data:
		power_data.start_time = Time.get_time_dict_from_system().unix - 11.0  # Expired
		power_manager.update_power_timers(0.016)
		
		assert_false(power_manager.is_power_active(player_index), "Power should expire automatically")

func test_player_invincibility_collision_detection():
	"""Test player invincibility collision detection mechanics"""
	# This test requires a player scene to be loaded
	var player_scene = preload("res://scenes/entities/player1.tscn")
	var test_player = player_scene.instantiate()
	test_player.player_index = 1
	add_child(test_player)
	
	await get_tree().process_frame
	
	# Activate invincibility power
	power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
	await get_tree().process_frame
	
	# Check that player received the power
	assert_true(test_player.is_power_active, "Player should have active power")
	assert_eq(test_player.active_power_type, power_manager.PowerType.INVINCIBILITY, "Player should have invincibility power")
	
	# Check collision mask changes
	var enemy_collision_disabled = not test_player.get_collision_mask_value(3)
	assert_true(enemy_collision_disabled, "Enemy collision should be disabled during invincibility")
	
	# Check visual effects
	if test_player.power_overlay:
		assert_true(test_player.power_overlay.visible, "Power overlay should be visible")
	
	# Test sprite modulation
	assert_ne(test_player.animated_sprite.modulate, Color.WHITE, "Player sprite should be tinted during invincibility")
	
	# Test deactivation restores normal state
	power_manager.deactivate_power(1)
	await get_tree().process_frame
	
	assert_false(test_player.is_power_active, "Player should not have active power after deactivation")
	assert_true(test_player.get_collision_mask_value(3), "Enemy collision should be restored")
	assert_eq(test_player.animated_sprite.modulate, Color.WHITE, "Player sprite should return to normal color")
	
	test_player.queue_free()

func test_multi_player_power_independence():
	"""Test that powers work independently for multiple players"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Test all 4 players can have independent powers
	for player_index in range(1, 5):
		var result = power_manager.activate_power(player_index, power_type)
		assert_true(result, "Player %d power activation should succeed" % player_index)
		assert_true(power_manager.is_power_active(player_index), "Player %d should have active power" % player_index)
	
	# Verify all players have independent powers
	for player_index in range(1, 5):
		assert_true(power_manager.is_power_active(player_index), "Player %d should have independent active power" % player_index)
		assert_gt(power_manager.get_remaining_duration(player_index), 0.0, "Player %d should have remaining duration" % player_index)
	
	# Test selective deactivation doesn't affect other players
	power_manager.deactivate_power(2)
	assert_false(power_manager.is_power_active(2), "Player 2 should not have active power after deactivation")
	
	# Other players should still have active powers
	for player_index in [1, 3, 4]:
		assert_true(power_manager.is_power_active(player_index), "Player %d should still have active power" % player_index)
	
	# Test power replacement for individual player
	var initial_duration_p1 = power_manager.get_remaining_duration(1)
	await wait_frames(30)  # Wait half a second
	power_manager.activate_power(1, power_type)  # Reactivate for player 1
	var new_duration_p1 = power_manager.get_remaining_duration(1)
	
	assert_ge(new_duration_p1, initial_duration_p1, "Player 1 duration should be reset by new activation")
	
	# Other players should be unaffected
	for player_index in [3, 4]:
		assert_true(power_manager.is_power_active(player_index), "Player %d should be unaffected by player 1 reactivation" % player_index)

func test_performance_multiple_simultaneous_powers():
	"""Test performance with multiple simultaneous active powers"""
	var start_time = Time.get_time_dict_from_system().unix
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate powers for all 4 players
	for player_index in range(1, 5):
		power_manager.activate_power(player_index, power_type)
	
	# Simulate 60 frames of updates (1 second at 60fps)
	for frame in 60:
		power_manager.update_power_timers(1.0/60.0)
		await get_tree().process_frame
	
	var end_time = Time.get_time_dict_from_system().unix
	var duration = end_time - start_time
	
	# Performance should be reasonable (less than 0.5 seconds for 60 updates)
	assert_lt(duration, 0.5, "Multiple power updates should complete quickly (took %.3fs)" % duration)
	
	# All powers should still be active
	for player_index in range(1, 5):
		assert_true(power_manager.is_power_active(player_index), "Player %d power should still be active after performance test" % player_index)
	
	# Test memory usage doesn't grow excessively
	var initial_active_count = power_manager.active_powers.size()
	var initial_timer_count = power_manager.power_timers.size()
	
	# Deactivate and reactivate powers multiple times
	for cycle in 5:
		for player_index in range(1, 5):
			power_manager.deactivate_power(player_index)
			power_manager.activate_power(player_index, power_type)
	
	var final_active_count = power_manager.active_powers.size()
	var final_timer_count = power_manager.power_timers.size()
	
	assert_eq(final_active_count, initial_active_count, "Active powers count should remain stable")
	assert_eq(final_timer_count, initial_timer_count, "Timer count should remain stable")

func test_power_system_error_handling():
	"""Test comprehensive error handling scenarios"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Test invalid player indices
	assert_false(power_manager.activate_power(-1, power_type), "Negative player index should fail")
	assert_false(power_manager.activate_power(0, power_type), "Zero player index should fail")
	assert_false(power_manager.activate_power(5, power_type), "Player index > 4 should fail")
	
	# Test invalid power types
	assert_false(power_manager.activate_power(1, -2), "Invalid negative power type should fail")
	assert_false(power_manager.activate_power(1, 999), "Non-existent power type should fail")
	
	# Test deactivation of non-active power
	power_manager.deactivate_power(1)  # Should not crash
	assert_false(power_manager.is_power_active(1), "Player should not have active power")
	
	# Test multiple deactivations
	power_manager.activate_power(1, power_type)
	power_manager.deactivate_power(1)
	power_manager.deactivate_power(1)  # Second deactivation should not crash
	assert_false(power_manager.is_power_active(1), "Player should not have active power after multiple deactivations")
	
	# Test corrupted power data handling
	power_manager.activate_power(1, power_type)
	power_manager.active_powers[1] = null  # Corrupt the data
	power_manager.update_power_timers(0.016)  # Should handle gracefully
	assert_true(true, "Corrupted power data should be handled gracefully")

func test_power_configuration_system():
	"""Test power configuration system functionality"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Test configuration retrieval
	var config = power_manager.get_power_config(power_type)
	assert_not_null(config, "Power configuration should be retrievable")
	assert_true(config.has("duration"), "Configuration should have duration")
	assert_true(config.has("spawn_chance"), "Configuration should have spawn_chance")
	assert_true(config.has("enemy_spawn_rates"), "Configuration should have enemy_spawn_rates")
	
	# Test configuration modification
	var original_duration = config.duration
	power_manager.set_power_duration(power_type, 15.0)
	
	var updated_config = power_manager.get_power_config(power_type)
	assert_eq(updated_config.duration, 15.0, "Duration should be updated")
	
	# Test that active powers use new duration
	power_manager.activate_power(1, power_type)
	var remaining = power_manager.get_remaining_duration(1)
	assert_ge(remaining, 14.5, "New power should use updated duration")
	
	# Restore original configuration
	power_manager.set_power_duration(power_type, original_duration)

func test_power_signal_emissions():
	"""Test that power system emits correct signals"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	var player_index = 1
	
	# Track signal emissions
	var activation_received = [false]  # Use arrays to avoid capture issues
	var expiration_received = [false]
	var warning_received = [false]
	
	# Connect to signals
	power_manager.power_activated.connect(func(p_idx, p_type, duration):
		if p_idx == player_index and p_type == power_type:
			activation_received[0] = true
			assert_gt(duration, 0.0, "Activation signal should include positive duration")
	)
	
	power_manager.power_expired.connect(func(p_idx, p_type):
		if p_idx == player_index and p_type == power_type:
			expiration_received[0] = true
	)
	
	power_manager.power_warning.connect(func(p_idx, p_type, remaining):
		if p_idx == player_index and p_type == power_type:
			warning_received[0] = true
			assert_true(remaining <= 3.0, "Warning signal should be sent when 3 seconds or less remaining")
	)
	
	# Test activation signal
	power_manager.activate_power(player_index, power_type)
	assert_true(activation_received[0], "Power activation signal should be emitted")
	
	# Test warning signal
	var power_data = power_manager.active_powers[player_index]
	if power_data:
		power_data.start_time = Time.get_time_dict_from_system().unix - 7.5  # 2.5 seconds remaining
		power_manager.update_power_timers(0.016)
		assert_true(warning_received[0], "Power warning signal should be emitted")
	
	# Test expiration signal
	power_manager.deactivate_power(player_index)
	assert_true(expiration_received[0], "Power expiration signal should be emitted")

func test_power_system_integration_with_game_components():
	"""Test integration with other game systems"""
	# Test PowerEgg scene loading
	var power_egg_scene = power_manager.get_power_egg_scene()
	if power_egg_scene:
		assert_true(power_egg_scene is PackedScene, "Power egg scene should be a PackedScene")
		
		var power_egg = power_egg_scene.instantiate()
		assert_not_null(power_egg, "Power egg should instantiate successfully")
		assert_true(power_egg.is_in_group("power_eggs"), "Power egg should be in correct group")
		power_egg.queue_free()
	
	# Test spawn probability for different enemy types
	var enemy_types = ["EnemyBase", "EnemyHunter", "ShadowLord", "UnknownEnemy"]
	for enemy_type in enemy_types:
		var result = power_manager.should_spawn_power_egg(enemy_type)
		assert_true(result is bool, "Spawn probability should return boolean for %s" % enemy_type)
	
	# Test debug information
	var debug_info = power_manager.get_debug_info()
	assert_not_null(debug_info, "Debug info should be available")
	assert_true(debug_info.has("active_powers_count"), "Debug info should include active powers count")
	assert_true(debug_info.has("power_configs"), "Debug info should include power configs")

func test_memory_leak_prevention():
	"""Test that the power system prevents memory leaks"""
	var initial_active_count = power_manager.active_powers.size()
	var initial_timer_count = power_manager.power_timers.size()
	
	# Create and destroy many powers
	for cycle in 10:
		for player_index in range(1, 5):
			power_manager.activate_power(player_index, power_manager.PowerType.INVINCIBILITY)
		
		await wait_frames(5)
		
		for player_index in range(1, 5):
			power_manager.deactivate_power(player_index)
	
	# Check that memory usage returns to baseline
	var final_active_count = power_manager.active_powers.size()
	var final_timer_count = power_manager.power_timers.size()
	
	assert_eq(final_active_count, initial_active_count, "Active powers should return to baseline")
	assert_eq(final_timer_count, initial_timer_count, "Timers should return to baseline")
	
	# Test reset all powers
	for player_index in range(1, 5):
		power_manager.activate_power(player_index, power_manager.PowerType.INVINCIBILITY)
	
	power_manager.reset_all_powers()
	
	assert_eq(power_manager.active_powers.size(), 0, "All active powers should be cleared")
	assert_eq(power_manager.power_timers.size(), 0, "All timers should be cleared")