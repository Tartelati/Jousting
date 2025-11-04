extends TestBase

# Unit tests for PowerManager core functionality

var power_manager: Node

func before_each():
	# Get reference to the PowerManager autoload
	power_manager = get_node("/root/PowerManager")
	
	# Reset all powers before each test
	if power_manager:
		power_manager.reset_all_powers()

func test_power_manager_exists():
	"""Test that PowerManager autoload is available"""
	assert_not_null(power_manager, "PowerManager should be available as autoload")

func test_power_type_enum():
	"""Test that power type enumeration is properly defined"""
	var PowerType = power_manager.PowerType
	assert_eq(PowerType.NONE, -1, "PowerType.NONE should be -1")
	assert_eq(PowerType.INVINCIBILITY, 0, "PowerType.INVINCIBILITY should be 0")

func test_power_activation():
	"""Test basic power activation functionality"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Initially no power should be active
	assert_false(power_manager.is_power_active(player_index), "No power should be active initially")
	
	# Activate power
	var result = power_manager.activate_power(player_index, power_type)
	assert_true(result, "Power activation should succeed")
	
	# Power should now be active
	assert_true(power_manager.is_power_active(player_index), "Power should be active after activation")
	assert_eq(power_manager.get_active_power_type(player_index), power_type, "Active power type should match")

func test_power_deactivation():
	"""Test power deactivation functionality"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate power first
	power_manager.activate_power(player_index, power_type)
	assert_true(power_manager.is_power_active(player_index), "Power should be active")
	
	# Deactivate power
	power_manager.deactivate_power(player_index)
	assert_false(power_manager.is_power_active(player_index), "Power should be inactive after deactivation")
	assert_eq(power_manager.get_active_power_type(player_index), power_manager.PowerType.NONE, "No power should be active")

func test_power_duration_tracking():
	"""Test that power duration is properly tracked"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate power
	power_manager.activate_power(player_index, power_type)
	
	# Check remaining duration
	var remaining_time = power_manager.get_remaining_duration(player_index)
	assert_gt(remaining_time, 0.0, "Remaining time should be greater than 0")
	assert_true(remaining_time <= 10.0, "Remaining time should not exceed configured duration")

func test_multiple_players_independence():
	"""Test that powers work independently for multiple players"""
	var player1 = 1
	var player2 = 2
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate power for player 1 only
	power_manager.activate_power(player1, power_type)
	
	# Check that only player 1 has active power
	assert_true(power_manager.is_power_active(player1), "Player 1 should have active power")
	assert_false(power_manager.is_power_active(player2), "Player 2 should not have active power")
	
	# Activate power for player 2
	power_manager.activate_power(player2, power_type)
	
	# Both players should now have active powers
	assert_true(power_manager.is_power_active(player1), "Player 1 should still have active power")
	assert_true(power_manager.is_power_active(player2), "Player 2 should now have active power")

func test_power_replacement():
	"""Test that new power replaces existing power for same player"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate power twice
	power_manager.activate_power(player_index, power_type)
	var first_duration = power_manager.get_remaining_duration(player_index)
	
	# Wait a bit then activate again
	await wait_frames(10)
	power_manager.activate_power(player_index, power_type)
	var second_duration = power_manager.get_remaining_duration(player_index)
	
	# Second activation should reset the duration
	assert_ge(second_duration, first_duration, "New power activation should reset duration")

func test_spawn_probability_logic():
	"""Test power egg spawn probability calculation"""
	# Test basic spawn chance
	var spawn_count = 0
	var total_tests = 100
	
	for i in total_tests:
		if power_manager.should_spawn_power_egg("EnemyBase"):
			spawn_count += 1
	
	# Should be approximately 15% for EnemyBase (allow some variance)
	var spawn_rate = float(spawn_count) / float(total_tests)
	assert_ge(spawn_rate, 0.05, "Spawn rate should be at least 5% (accounting for randomness)")
	assert_true(spawn_rate <= 0.35, "Spawn rate should be at most 35% (accounting for randomness)")

func test_enemy_specific_spawn_rates():
	"""Test that different enemies have different spawn rates"""
	# Test that the method returns different probabilities for different enemies
	# We can't test exact percentages due to randomness, but we can test the logic exists
	
	var base_config = power_manager.get_power_config(power_manager.PowerType.INVINCIBILITY)
	assert_not_null(base_config, "Power config should exist")
	
	var enemy_rates = base_config.get("enemy_spawn_rates", {})
	assert_true(enemy_rates.has("EnemyBase"), "EnemyBase spawn rate should be configured")
	assert_true(enemy_rates.has("EnemyHunter"), "EnemyHunter spawn rate should be configured")
	assert_true(enemy_rates.has("ShadowLord"), "ShadowLord spawn rate should be configured")

func test_invalid_player_index():
	"""Test handling of invalid player indices"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Test invalid indices
	assert_false(power_manager.activate_power(0, power_type), "Player index 0 should be invalid")
	assert_false(power_manager.activate_power(5, power_type), "Player index 5 should be invalid")
	assert_false(power_manager.activate_power(-1, power_type), "Negative player index should be invalid")

func test_invalid_power_type():
	"""Test handling of invalid power types"""
	var player_index = 1
	
	# Test with invalid power type (using a number that doesn't exist)
	assert_false(power_manager.activate_power(player_index, 999), "Invalid power type should fail")

func test_power_signals():
	"""Test that power events emit proper signals"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Connect to signals
	var activation_received = [false]  # Use array to avoid capture issues
	var expiration_received = [false]
	
	power_manager.power_activated.connect(func(p_idx, p_type, _duration): 
		if p_idx == player_index and p_type == power_type:
			activation_received[0] = true
	)
	
	power_manager.power_expired.connect(func(p_idx, p_type):
		if p_idx == player_index and p_type == power_type:
			expiration_received[0] = true
	)
	
	# Activate and deactivate power
	power_manager.activate_power(player_index, power_type)
	assert_true(activation_received[0], "Power activation signal should be emitted")
	
	power_manager.deactivate_power(player_index)
	assert_true(expiration_received[0], "Power expiration signal should be emitted")

func test_configuration_methods():
	"""Test power configuration getter and setter methods"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Test getting configuration
	var config = power_manager.get_power_config(power_type)
	assert_not_null(config, "Power config should be retrievable")
	assert_true(config.has("duration"), "Config should have duration")
	assert_true(config.has("spawn_chance"), "Config should have spawn_chance")
	
	# Test setting duration
	var original_duration = config.duration
	power_manager.set_power_duration(power_type, 15.0)
	var updated_config = power_manager.get_power_config(power_type)
	assert_eq(updated_config.duration, 15.0, "Duration should be updated")
	
	# Restore original duration
	power_manager.set_power_duration(power_type, original_duration)

func test_debug_info():
	"""Test debug information retrieval"""
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Get debug info with no active powers
	var debug_info = power_manager.get_debug_info()
	assert_eq(debug_info.active_powers_count, 0, "Should show 0 active powers initially")
	
	# Activate power and check debug info
	power_manager.activate_power(player_index, power_type)
	debug_info = power_manager.get_debug_info()
	assert_eq(debug_info.active_powers_count, 1, "Should show 1 active power")
	assert_true(debug_info.active_powers.has(player_index), "Debug info should include player data")

func test_reset_all_powers():
	"""Test resetting all active powers"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate powers for multiple players
	power_manager.activate_power(1, power_type)
	power_manager.activate_power(2, power_type)
	
	# Verify powers are active
	assert_true(power_manager.is_power_active(1), "Player 1 should have active power")
	assert_true(power_manager.is_power_active(2), "Player 2 should have active power")
	
	# Reset all powers
	power_manager.reset_all_powers()
	
	# Verify all powers are deactivated
	assert_false(power_manager.is_power_active(1), "Player 1 should not have active power after reset")
	assert_false(power_manager.is_power_active(2), "Player 2 should not have active power after reset")

func test_audio_components_exist():
	"""Test that audio components are properly set up"""
	# Check that audio nodes exist
	var spawn_audio = power_manager.get_node_or_null("PowerSpawnAudio")
	var activation_audio = power_manager.get_node_or_null("PowerActivationAudio")
	var ambient_audio = power_manager.get_node_or_null("PowerAmbientAudio")
	var warning_audio = power_manager.get_node_or_null("PowerWarningAudio")
	var expiration_audio = power_manager.get_node_or_null("PowerExpirationAudio")
	
	assert_not_null(spawn_audio, "PowerSpawnAudio node should exist")
	assert_not_null(activation_audio, "PowerActivationAudio node should exist")
	assert_not_null(ambient_audio, "PowerAmbientAudio node should exist")
	assert_not_null(warning_audio, "PowerWarningAudio node should exist")
	assert_not_null(expiration_audio, "PowerExpirationAudio node should exist")

func test_audio_methods_exist():
	"""Test that audio methods are available"""
	assert_true(power_manager.has_method("play_power_spawn_sound"), "play_power_spawn_sound method should exist")
	assert_true(power_manager.has_method("play_power_activation_sound"), "play_power_activation_sound method should exist")
	assert_true(power_manager.has_method("start_power_ambient_sound"), "start_power_ambient_sound method should exist")
	assert_true(power_manager.has_method("stop_power_ambient_sound"), "stop_power_ambient_sound method should exist")
	assert_true(power_manager.has_method("play_power_warning_sound"), "play_power_warning_sound method should exist")
	assert_true(power_manager.has_method("play_power_expiration_sound"), "play_power_expiration_sound method should exist")

func test_audio_calls_dont_crash():
	"""Test that audio method calls don't crash the system"""
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# These should not crash even if audio files are missing
	power_manager.play_power_spawn_sound()
	power_manager.play_power_activation_sound(power_type)
	power_manager.start_power_ambient_sound(power_type)
	power_manager.play_power_warning_sound(power_type)
	power_manager.play_power_expiration_sound(power_type)
	power_manager.stop_power_ambient_sound()
	
	# If we get here without crashing, the test passes
	assert_true(true, "Audio method calls should not crash")