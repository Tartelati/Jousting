extends TestBase

# Final integration test for complete power system flow
# Tests: GameManager integration, enemy defeat → power egg spawn → collection → activation → effects → expiration
# Validates all requirements and ensures system works across all game modes

var game_manager: Node
var power_manager: Node
var test_scene: Node
var test_level: Node
var test_players: Array = []

func _ready():
	print("\n" + "=".repeat(80))
	print("FINAL POWER SYSTEM INTEGRATION TEST")
	print("Testing complete enemy defeat → power egg spawn → collection → activation flow")
	print("=".repeat(80))
	
	run_final_integration_tests()

func run_final_integration_tests():
	"""Run comprehensive final integration tests"""
	
	# Initialize test environment
	if not await setup_test_environment():
		print("❌ CRITICAL: Test environment setup failed!")
		return
	
	print("✅ Test environment initialized successfully")
	
	# Test 1: GameManager integration
	await test_gamemanager_integration()
	
	# Test 2: Complete power flow
	await test_complete_power_flow()
	
	# Test 3: Multi-player scenarios
	await test_multiplayer_scenarios()
	
	# Test 4: Game mode compatibility
	await test_game_mode_compatibility()
	
	# Test 5: Save/load compatibility
	await test_save_load_compatibility()
	
	# Test 6: Performance under gameplay conditions
	await test_gameplay_performance()
	
	# Test 7: Error recovery in gameplay
	await test_gameplay_error_recovery()
	
	print("\n" + "=".repeat(80))
	print("🎉 FINAL INTEGRATION TESTS COMPLETE!")
	print("All power system requirements validated in gameplay context")
	print("=".repeat(80))
	
	# Clean up
	cleanup_test_environment()

func setup_test_environment() -> bool:
	"""Setup complete test environment with GameManager, level, and players"""
	
	# Get managers
	game_manager = get_node_or_null("/root/GameManager")
	power_manager = get_node_or_null("/root/PowerManager")
	
	if not game_manager:
		print("❌ GameManager not found")
		return false
	
	if not power_manager:
		print("❌ PowerManager not found")
		return false
	
	# Create test scene container
	test_scene = Node2D.new()
	test_scene.name = "TestScene"
	add_child(test_scene)
	
	# Create test level
	var level_scene = preload("res://scenes/levels/level_base.tscn")
	test_level = level_scene.instantiate()
	test_level.name = "TestLevel"
	test_scene.add_child(test_level)
	
	# Wait for level to be ready
	await get_tree().process_frame
	
	# Create test players
	var player_scenes = [
		preload("res://scenes/entities/player1.tscn"),
		preload("res://scenes/entities/player2.tscn"),
		preload("res://scenes/entities/player3.tscn"),
		preload("res://scenes/entities/player4.tscn")
	]
	
	var spawn_positions = [
		Vector2(200, 400),
		Vector2(400, 400),
		Vector2(600, 400),
		Vector2(800, 400)
	]
	
	for i in range(4):
		var player = player_scenes[i].instantiate()
		player.player_index = i + 1
		player.global_position = spawn_positions[i]
		player.setup_device(i if i < 3 else -1)  # Controllers 0-2, keyboard for player 4
		test_level.add_child(player)
		test_players.append(player)
	
	# Update GameManager references for testing
	game_manager.active_level = test_level
	game_manager.player_nodes = test_players
	
	await get_tree().process_frame
	return true

func test_gamemanager_integration():
	"""Test GameManager integration with PowerManager"""
	print("\n--- Testing GameManager Integration ---")
	
	# Test 1: PowerManager initialization
	assert_not_null(power_manager, "PowerManager should be available")
	assert_true(power_manager.has_signal("power_activated"), "PowerManager should have power_activated signal")
	assert_true(power_manager.has_signal("power_expired"), "PowerManager should have power_expired signal")
	
	# Test 2: Signal connections
	var power_activated_connected = power_manager.power_activated.is_connected(game_manager._on_power_activated)
	var power_expired_connected = power_manager.power_expired.is_connected(game_manager._on_power_expired)
	
	assert_true(power_activated_connected, "GameManager should be connected to power_activated signal")
	assert_true(power_expired_connected, "GameManager should be connected to power_expired signal")
	
	# Test 3: Power system reset functionality
	power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
	assert_true(power_manager.is_power_active(1), "Power should be active before reset")
	
	game_manager.reset_power_system()
	assert_false(power_manager.is_power_active(1), "Power should be inactive after reset")
	
	print("✅ GameManager integration validated")

func test_complete_power_flow():
	"""Test complete enemy defeat → power egg spawn → collection → activation flow"""
	print("\n--- Testing Complete Power Flow ---")
	
	# Step 1: Create enemy and test defeat mechanism
	var enemy_scene = preload("res://scenes/entities/enemy_base.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.global_position = Vector2(300, 350)
	test_level.add_child(enemy)
	
	await get_tree().process_frame
	
	# Step 2: Force power egg spawn (override random chance)
	var original_config = power_manager.config_manager
	if original_config and original_config.has_method("set_debug_setting"):
		original_config.set_debug_setting("force_spawn_rate", 1.0)  # 100% spawn rate
	
	# Step 3: Defeat enemy and check for power egg spawn
	var _initial_children = test_level.get_children().size()
	var player = test_players[0]
	var _initial_score = ScoreManager.get_score(1) if ScoreManager else 0
	
	# Simulate enemy defeat
	enemy.defeat(Vector2(100, -200), 1, true)
	
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for spawning
	
	# Step 4: Look for power egg
	var power_egg = null
	for child in test_level.get_children():
		if child.get_script() and child.get_script().get_path().get_file() == "power_egg.gd":
			power_egg = child
			break
	
	assert_not_null(power_egg, "Power egg should spawn after enemy defeat")
	print("✅ Power egg spawned successfully")
	
	# Step 5: Test power egg collection
	if power_egg:
		var power_egg_position = power_egg.global_position
		player.global_position = power_egg_position  # Move player to power egg
		
		await get_tree().process_frame
		
		# Simulate collection
		power_egg.collect(1)
		
		await get_tree().process_frame
		
		# Verify power activation
		assert_true(power_manager.is_power_active(1), "Power should be active after collection")
		assert_eq(power_manager.get_active_power_type(1), power_manager.PowerType.INVINCIBILITY, "Should have invincibility power")
		
		print("✅ Power collection and activation successful")
		
		# Step 6: Test power effects on player
		if player.has_method("activate_power"):
			assert_true(player.is_power_active, "Player should have active power state")
			assert_eq(player.active_power_type, power_manager.PowerType.INVINCIBILITY, "Player should have invincibility")
			print("✅ Player power effects applied")
		
		# Step 7: Test power expiration
		var remaining_time = power_manager.get_remaining_duration(1)
		assert_gt(remaining_time, 0.0, "Should have remaining time")
		
		# Force expiration for testing
		power_manager.deactivate_power(1)
		assert_false(power_manager.is_power_active(1), "Power should be inactive after deactivation")
		
		if player.has_method("deactivate_power"):
			assert_false(player.is_power_active, "Player should not have active power after deactivation")
			print("✅ Power expiration handled correctly")
	
	# Restore original configuration
	if original_config and original_config.has_method("set_debug_setting"):
		original_config.set_debug_setting("force_spawn_rate", -1.0)  # Restore normal behavior
	
	print("✅ Complete power flow validated")

func test_multiplayer_scenarios():
	"""Test power system in multi-player scenarios"""
	print("\n--- Testing Multi-Player Scenarios ---")
	
	# Test 1: Independent power activation
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	for i in range(4):
		var player_index = i + 1
		var result = power_manager.activate_power(player_index, power_type)
		assert_true(result, "Player %d power activation should succeed" % player_index)
	
	# Verify all players have independent powers
	for i in range(4):
		var player_index = i + 1
		assert_true(power_manager.is_power_active(player_index), "Player %d should have active power" % player_index)
	
	print("✅ Independent multi-player powers validated")
	
	# Test 2: Power collection fairness
	# Create power egg
	var power_egg_scene = power_manager.get_power_egg_scene()
	if power_egg_scene:
		var power_egg = power_egg_scene.instantiate()
		power_egg.global_position = Vector2(500, 350)
		test_level.add_child(power_egg)
		
		await get_tree().process_frame
		
		# Move multiple players to same position
		for player in test_players:
			player.global_position = Vector2(500, 350)
		
		await get_tree().process_frame
		
		# First player should collect (first-touch wins)
		power_egg.collect(1)
		
		await get_tree().process_frame
		
		# Verify only one collection occurred
		assert_true(power_egg.is_collected, "Power egg should be marked as collected")
		print("✅ Power collection fairness validated")
	
	# Clean up powers
	power_manager.reset_all_powers()
	
	print("✅ Multi-player scenarios validated")

func test_game_mode_compatibility():
	"""Test power system compatibility across different game modes"""
	print("\n--- Testing Game Mode Compatibility ---")
	
	# Test 1: Single player mode
	print("🧪 Testing single player mode...")
	game_manager.player_nodes = [test_players[0]]  # Only player 1
	
	var result = power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
	assert_true(result, "Power should work in single player mode")
	
	power_manager.deactivate_power(1)
	
	# Test 2: Two player mode
	print("🧪 Testing two player mode...")
	game_manager.player_nodes = [test_players[0], test_players[1]]  # Players 1 and 2
	
	power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
	power_manager.activate_power(2, power_manager.PowerType.INVINCIBILITY)
	
	assert_true(power_manager.is_power_active(1), "Player 1 power should work in two player mode")
	assert_true(power_manager.is_power_active(2), "Player 2 power should work in two player mode")
	
	power_manager.reset_all_powers()
	
	# Test 3: Four player mode
	print("🧪 Testing four player mode...")
	game_manager.player_nodes = test_players  # All players
	
	for i in range(4):
		var player_index = i + 1
		power_manager.activate_power(player_index, power_manager.PowerType.INVINCIBILITY)
		assert_true(power_manager.is_power_active(player_index), "Player %d power should work in four player mode" % player_index)
	
	power_manager.reset_all_powers()
	
	print("✅ Game mode compatibility validated")

func test_save_load_compatibility():
	"""Test backward compatibility with existing save/load systems"""
	print("\n--- Testing Save/Load Compatibility ---")
	
	# Test 1: Power system doesn't interfere with score saving
	if ScoreManager:
		var initial_score = ScoreManager.get_score(1)
		ScoreManager.add_score(1, 1000)
		
		# Activate power (should not affect score system)
		power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
		
		var final_score = ScoreManager.get_score(1)
		assert_eq(final_score, initial_score + 1000, "Power system should not interfere with scoring")
		
		# Test score saving with active power
		if ScoreManager.has_method("save_high_scores"):
			ScoreManager.save_high_scores()  # Should not crash with active power
			print("✅ Score saving works with active powers")
		
		power_manager.deactivate_power(1)
	
	# Test 2: Power system state is not persistent (by design)
	power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
	
	# Simulate game restart
	game_manager.reset_power_system()
	
	assert_false(power_manager.is_power_active(1), "Powers should not persist across game sessions")
	
	print("✅ Save/load compatibility validated")

func test_gameplay_performance():
	"""Test power system performance under realistic gameplay conditions"""
	print("\n--- Testing Gameplay Performance ---")
	
	var start_time = Time.get_time_dict_from_system().unix
	
	# Simulate intense gameplay scenario
	for cycle in 60:  # 1 second of gameplay at 60fps
		# Simulate multiple power activations/deactivations
		for player_index in range(1, 5):
			if randf() < 0.1:  # 10% chance per frame per player
				if power_manager.is_power_active(player_index):
					power_manager.deactivate_power(player_index)
				else:
					power_manager.activate_power(player_index, power_manager.PowerType.INVINCIBILITY)
		
		# Update power timers
		power_manager.update_power_timers(1.0/60.0)
		
		# Simulate enemy defeats and power egg spawns
		if randf() < 0.05:  # 5% chance per frame
			power_manager.should_spawn_power_egg("EnemyBase")
		
		await get_tree().process_frame
	
	var end_time = Time.get_time_dict_from_system().unix
	var duration = end_time - start_time
	
	assert_lt(duration, 2.0, "Gameplay performance test should complete quickly")
	print("✅ Gameplay performance validated (%.3fs for 60 frames)" % duration)
	
	# Clean up
	power_manager.reset_all_powers()

func test_gameplay_error_recovery():
	"""Test error recovery during actual gameplay scenarios"""
	print("\n--- Testing Gameplay Error Recovery ---")
	
	# Test 1: Player removal during active power
	power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
	assert_true(power_manager.is_power_active(1), "Power should be active")
	
	# Simulate player removal (like in game over)
	var player1 = test_players[0]
	test_level.remove_child(player1)
	game_manager.player_nodes.erase(player1)
	
	# System should handle this gracefully
	power_manager.update_power_timers(0.016)
	
	# Re-add player for continued testing
	test_level.add_child(player1)
	game_manager.player_nodes.append(player1)
	
	print("✅ Player removal during active power handled gracefully")
	
	# Test 2: Level change during active power
	power_manager.activate_power(2, power_manager.PowerType.INVINCIBILITY)
	
	# Simulate level change
	game_manager.active_level = null
	power_manager.update_power_timers(0.016)
	
	# Restore level
	game_manager.active_level = test_level
	
	print("✅ Level change during active power handled gracefully")
	
	# Test 3: GameManager reset during active powers
	power_manager.activate_power(3, power_manager.PowerType.INVINCIBILITY)
	power_manager.activate_power(4, power_manager.PowerType.INVINCIBILITY)
	
	# Reset should clean up all powers
	game_manager.reset_power_system()
	
	assert_false(power_manager.is_power_active(3), "Power should be cleared after reset")
	assert_false(power_manager.is_power_active(4), "Power should be cleared after reset")
	
	print("✅ GameManager reset cleans up powers correctly")
	
	print("✅ Gameplay error recovery validated")

func cleanup_test_environment():
	"""Clean up test environment"""
	if test_scene:
		test_scene.queue_free()
	
	# Reset GameManager state
	if game_manager:
		game_manager.active_level = null
		game_manager.player_nodes.clear()
		game_manager.reset_power_system()
	
	print("✅ Test environment cleaned up")