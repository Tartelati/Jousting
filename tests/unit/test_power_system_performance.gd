extends TestBase

# Performance tests for the power system
# Tests system performance under various load conditions

var power_manager: Node

func before_each():
	power_manager = get_node("/root/PowerManager")
	if power_manager:
		power_manager.reset_all_powers()

func test_single_power_activation_performance():
	"""Test performance of single power activation"""
	var iterations = 1000
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	var start_time = Time.get_time_dict_from_system().unix
	
	for i in iterations:
		power_manager.activate_power(1, power_type)
		power_manager.deactivate_power(1)
	
	var end_time = Time.get_time_dict_from_system().unix
	var duration = end_time - start_time
	var avg_time_per_operation = duration / iterations * 1000  # Convert to milliseconds
	
	assert_lt(duration, 1.0, "1000 activation/deactivation cycles should complete in under 1 second")
	print("Average time per activation/deactivation: %.3f ms" % avg_time_per_operation)

func test_multiple_simultaneous_powers_performance():
	"""Test performance with multiple simultaneous active powers"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	var update_cycles = 600  # 10 seconds at 60fps
	
	# Activate powers for all 4 players
	for player_index in range(1, 5):
		power_manager.activate_power(player_index, power_type)
	
	var start_time = Time.get_time_dict_from_system().unix
	
	# Run update cycles
	for cycle in update_cycles:
		power_manager.update_power_timers(1.0/60.0)
		if cycle % 60 == 0:  # Every second, yield to prevent blocking
			await get_tree().process_frame
	
	var end_time = Time.get_time_dict_from_system().unix
	var duration = end_time - start_time
	var avg_time_per_update = duration / update_cycles * 1000  # Convert to milliseconds
	
	assert_lt(duration, 2.0, "600 update cycles with 4 active powers should complete in under 2 seconds")
	print("Average time per update cycle: %.3f ms" % avg_time_per_update)

func test_spawn_probability_calculation_performance():
	"""Test performance of spawn probability calculations"""
	var iterations = 10000
	var enemy_types = ["EnemyBase", "EnemyHunter", "ShadowLord"]
	
	var start_time = Time.get_time_dict_from_system().unix
	
	for i in iterations:
		for enemy_type in enemy_types:
			power_manager.should_spawn_power_egg(enemy_type)
	
	var end_time = Time.get_time_dict_from_system().unix
	var duration = end_time - start_time
	var total_calculations = iterations * enemy_types.size()
	var avg_time_per_calculation = duration / total_calculations * 1000000  # Convert to microseconds
	
	assert_lt(duration, 0.5, "30,000 spawn probability calculations should complete in under 0.5 seconds")
	print("Average time per spawn calculation: %.1f μs" % avg_time_per_calculation)

func test_memory_usage_stability():
	"""Test that memory usage remains stable over many operations"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	var cycles = 100
	
	# Record initial state
	var initial_active_count = power_manager.active_powers.size()
	var initial_timer_count = power_manager.power_timers.size()
	
	# Perform many activation/deactivation cycles
	for cycle in cycles:
		# Activate powers for all players
		for player_index in range(1, 5):
			power_manager.activate_power(player_index, power_type)
		
		# Deactivate all powers
		power_manager.reset_all_powers()
		
		# Periodically yield to prevent blocking
		if cycle % 10 == 0:
			await get_tree().process_frame
	
	# Check final state
	var final_active_count = power_manager.active_powers.size()
	var final_timer_count = power_manager.power_timers.size()
	
	assert_eq(final_active_count, initial_active_count, "Active powers count should remain stable")
	assert_eq(final_timer_count, initial_timer_count, "Timer count should remain stable")
	print("Memory stability verified over %d cycles" % cycles)

func test_concurrent_power_operations_performance():
	"""Test performance of concurrent power operations"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	var operations_per_frame = 20
	var frames = 60  # 1 second at 60fps
	
	var start_time = Time.get_time_dict_from_system().unix
	
	for frame in frames:
		# Perform multiple operations per frame
		for op in operations_per_frame:
			var player_index = (op % 4) + 1  # Cycle through players 1-4
			
			if power_manager.is_power_active(player_index):
				power_manager.deactivate_power(player_index)
			else:
				power_manager.activate_power(player_index, power_type)
		
		# Update timers
		power_manager.update_power_timers(1.0/60.0)
		await get_tree().process_frame
	
	var end_time = Time.get_time_dict_from_system().unix
	var duration = end_time - start_time
	var total_operations = operations_per_frame * frames
	var avg_time_per_operation = duration / total_operations * 1000  # Convert to milliseconds
	
	assert_lt(duration, 2.0, "1200 concurrent operations should complete in under 2 seconds")
	print("Average time per concurrent operation: %.3f ms" % avg_time_per_operation)

func test_power_data_access_performance():
	"""Test performance of power data access operations"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	var iterations = 5000
	
	# Activate powers for all players
	for player_index in range(1, 5):
		power_manager.activate_power(player_index, power_type)
	
	var start_time = Time.get_time_dict_from_system().unix
	
	# Perform many data access operations
	for i in iterations:
		for player_index in range(1, 5):
			power_manager.is_power_active(player_index)
			power_manager.get_active_power_type(player_index)
			power_manager.get_remaining_duration(player_index)
	
	var end_time = Time.get_time_dict_from_system().unix
	var duration = end_time - start_time
	var total_accesses = iterations * 4 * 3  # 4 players, 3 operations each
	var avg_time_per_access = duration / total_accesses * 1000000  # Convert to microseconds
	
	assert_lt(duration, 0.5, "60,000 data access operations should complete in under 0.5 seconds")
	print("Average time per data access: %.1f μs" % avg_time_per_access)

func test_configuration_access_performance():
	"""Test performance of configuration system access"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	var iterations = 1000
	
	var start_time = Time.get_time_dict_from_system().unix
	
	for i in iterations:
		power_manager.get_power_config(power_type)
		power_manager.set_power_duration(power_type, 10.0)
	
	var end_time = Time.get_time_dict_from_system().unix
	var duration = end_time - start_time
	var avg_time_per_config_access = duration / (iterations * 2) * 1000  # Convert to milliseconds
	
	assert_lt(duration, 0.5, "2000 configuration operations should complete in under 0.5 seconds")
	print("Average time per configuration access: %.3f ms" % avg_time_per_config_access)

func test_signal_emission_performance():
	"""Test performance of signal emission"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	var iterations = 1000
	
	# Connect signal handlers
	var signal_count = [0]  # Use array to avoid capture issues
	power_manager.power_activated.connect(func(_p_idx, _p_type, _duration): signal_count[0] += 1)
	power_manager.power_expired.connect(func(_p_idx, _p_type): signal_count[0] += 1)
	
	var start_time = Time.get_time_dict_from_system().unix
	
	for i in iterations:
		power_manager.activate_power(1, power_type)
		power_manager.deactivate_power(1)
	
	var end_time = Time.get_time_dict_from_system().unix
	var duration = end_time - start_time
	var avg_time_per_signal = duration / (iterations * 2) * 1000  # Convert to milliseconds
	
	assert_eq(signal_count[0], iterations * 2, "All signals should be emitted")
	assert_lt(duration, 1.0, "2000 signal emissions should complete in under 1 second")
	print("Average time per signal emission: %.3f ms" % avg_time_per_signal)

func test_large_scale_stress_test():
	"""Stress test with large number of operations"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	var stress_cycles = 50
	
	print("Running large-scale stress test...")
	var start_time = Time.get_time_dict_from_system().unix
	
	for cycle in stress_cycles:
		# Rapid activation/deactivation for all players
		for rapid_cycle in 10:
			for player_index in range(1, 5):
				power_manager.activate_power(player_index, power_type)
			for player_index in range(1, 5):
				power_manager.deactivate_power(player_index)
		
		# Test spawn probability calculations
		for spawn_test in 50:
			power_manager.should_spawn_power_egg("EnemyBase")
		
		# Test configuration access
		for config_test in 10:
			power_manager.get_power_config(power_type)
		
		# Yield periodically to prevent blocking
		if cycle % 10 == 0:
			await get_tree().process_frame
			print("  Completed %d/%d stress cycles" % [cycle + 1, stress_cycles])
	
	var end_time = Time.get_time_dict_from_system().unix
	var duration = end_time - start_time
	
	assert_lt(duration, 5.0, "Large-scale stress test should complete in under 5 seconds")
	print("Stress test completed in %.2f seconds" % duration)
	
	# Verify system is still functional
	var result = power_manager.activate_power(1, power_type)
	assert_true(result, "System should still be functional after stress test")
	assert_true(power_manager.is_power_active(1), "Power should be active after stress test")