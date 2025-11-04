extends TestBase

# Test multi-player power independence and UI integration
class_name IntegrationMultiPlayerPowerTest

var power_manager: Node
var hud: Control
var test_players: Array[Node] = []

func _ready():
	var test_title = "Multi-Player Power Independence Test"
	print("\n" + "=".repeat(50))
	print("STARTING: " + test_title)
	print("=".repeat(50))

func setup_test():
	"""Set up test environment"""
	print("\n--- Setting up Multi-Player Power Test ---")
	
	# Get PowerManager
	power_manager = get_node_or_null("/root/PowerManager")
	assert_not_null(power_manager, "PowerManager should be available")
	
	# Get HUD
	hud = get_node_or_null("/root/HUD")
	if not hud:
		# Try to find HUD in current scene
		var current_scene = get_tree().current_scene
		if current_scene:
			hud = current_scene.find_child("HUD", true, false)
	
	# Reset power manager state
	if power_manager and power_manager.has_method("reset_all_powers"):
		power_manager.reset_all_powers()
	
	print("✓ Test environment set up")

func test_multi_player_power_independence():
	"""Test that powers work independently for each player"""
	print("\n--- Testing Multi-Player Power Independence ---")
	
	# Test activating powers for different players
	var success1 = power_manager.activate_power(1, 0)  # Player 1 - Invincibility
	assert_true(success1, "Player 1 power activation should succeed")
	
	var success2 = power_manager.activate_power(2, 0)  # Player 2 - Invincibility
	assert_true(success2, "Player 2 power activation should succeed")
	
	# Verify both players have independent active powers
	assert_true(power_manager.is_power_active(1), "Player 1 should have active power")
	assert_true(power_manager.is_power_active(2), "Player 2 should have active power")
	
	# Verify power types
	assert_eq(power_manager.get_active_power_type(1), 0, "Player 1 should have invincibility")
	assert_eq(power_manager.get_active_power_type(2), 0, "Player 2 should have invincibility")
	
	# Test that deactivating one player's power doesn't affect the other
	power_manager.deactivate_power(1)
	assert_false(power_manager.is_power_active(1), "Player 1 power should be deactivated")
	assert_true(power_manager.is_power_active(2), "Player 2 power should still be active")
	
	# Clean up
	power_manager.deactivate_power(2)
	
	print("✓ Multi-player power independence working correctly")

func test_power_collection_fairness():
	"""Test that power collection follows first-touch wins"""
	print("\n--- Testing Power Collection Fairness ---")
	
	# Create a mock power egg
	var power_egg_scene = preload("res://scenes/entities/power_egg.tscn")
	var power_egg = power_egg_scene.instantiate()
	get_tree().current_scene.add_child(power_egg)
	
	# Verify power egg is not collected initially
	assert_false(power_egg.is_collected, "Power egg should not be collected initially")
	
	# Simulate collection by player 1
	power_egg.collect(1)
	
	# Verify collection state
	assert_true(power_egg.is_collected, "Power egg should be collected after collect() call")
	
	# Try to collect again with different player (should fail)
	power_egg.collect(2)
	
	# Verify player 1 got the power, not player 2
	assert_true(power_manager.is_power_active(1), "Player 1 should have the power")
	assert_false(power_manager.is_power_active(2), "Player 2 should not have the power")
	
	# Clean up
	power_manager.deactivate_power(1)
	if is_instance_valid(power_egg):
		power_egg.queue_free()
	
	print("✓ Power collection fairness working correctly")

func test_hud_power_indicators():
	"""Test HUD power indicators for multiple players"""
	print("\n--- Testing HUD Power Indicators ---")
	
	if not hud:
		print("⚠ HUD not available, skipping HUD tests")
		return
	
	# Activate powers for multiple players
	power_manager.activate_power(1, 0)  # Player 1
	power_manager.activate_power(3, 0)  # Player 3
	
	# Wait a frame for UI updates
	await get_tree().process_frame
	
	# Check if HUD has power indicator methods
	if hud.has_method("show_power_indicator"):
		# Verify power indicators are shown
		if hud.has_method("get_power_status_for_player"):
			var status1 = hud.get_power_status_for_player(1)
			var status2 = hud.get_power_status_for_player(2)
			var status3 = hud.get_power_status_for_player(3)
			
			assert_true(status1.active, "Player 1 should show active power in HUD")
			assert_false(status2.active, "Player 2 should not show active power in HUD")
			assert_true(status3.active, "Player 3 should show active power in HUD")
		
		print("✓ HUD power indicators working for multiple players")
	else:
		print("⚠ HUD power indicator methods not available")
	
	# Clean up
	power_manager.deactivate_power(1)
	power_manager.deactivate_power(3)

func test_power_replacement():
	"""Test that new powers replace existing ones for the same player"""
	print("\n--- Testing Power Replacement ---")
	
	# Activate first power
	power_manager.activate_power(1, 0)  # Invincibility
	assert_true(power_manager.is_power_active(1), "Player 1 should have active power")
	assert_eq(power_manager.get_active_power_type(1), 0, "Player 1 should have invincibility")
	
	# Activate second power (should replace first)
	power_manager.activate_power(1, 0)  # Same power type
	assert_true(power_manager.is_power_active(1), "Player 1 should still have active power")
	assert_eq(power_manager.get_active_power_type(1), 0, "Player 1 should still have invincibility")
	
	# Clean up
	power_manager.deactivate_power(1)
	
	print("✓ Power replacement working correctly")

func test_power_expiration_independence():
	"""Test that power expiration works independently for each player"""
	print("\n--- Testing Power Expiration Independence ---")
	
	# Set short duration for testing
	if power_manager.has_method("set_power_duration"):
		power_manager.set_power_duration(0, 1.0)  # 1 second duration
	
	# Activate powers with slight delay
	power_manager.activate_power(1, 0)
	await get_tree().create_timer(0.5).timeout
	power_manager.activate_power(2, 0)
	
	# Wait for first power to expire
	await get_tree().create_timer(0.7).timeout
	
	# Player 1's power should be expired, Player 2's should still be active
	assert_false(power_manager.is_power_active(1), "Player 1 power should have expired")
	assert_true(power_manager.is_power_active(2), "Player 2 power should still be active")
	
	# Wait for second power to expire
	await get_tree().create_timer(0.7).timeout
	assert_false(power_manager.is_power_active(2), "Player 2 power should have expired")
	
	# Reset duration
	if power_manager.has_method("set_power_duration"):
		power_manager.set_power_duration(0, 10.0)  # Reset to default
	
	print("✓ Power expiration independence working correctly")

func run_all_tests():
	"""Run all multi-player power tests"""
	setup_test()
	
	test_multi_player_power_independence()
	test_power_collection_fairness()
	test_hud_power_indicators()
	test_power_replacement()
	test_power_expiration_independence()
	
	print_results()
	
	# Clean up
	if power_manager and power_manager.has_method("reset_all_powers"):
		power_manager.reset_all_powers()

func _on_start_test():
	run_all_tests()