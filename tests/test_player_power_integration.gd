extends TestBase

# Integration test for Player Power System
# This test verifies that players can activate and use powers correctly

var power_manager: Node
var test_player: CharacterBody2D

func _ready():
	print("Starting Player Power Integration Test...")
	run_integration_tests()

func run_integration_tests():
	"""Run integration tests for Player Power System"""
	
	# Get PowerManager
	power_manager = get_node("/root/PowerManager")
	if not power_manager:
		print("❌ CRITICAL: PowerManager autoload not found!")
		return
	
	print("✓ PowerManager autoload found")
	
	# Load and instantiate a player
	var player_scene = preload("res://scenes/entities/player1.tscn")
	test_player = player_scene.instantiate()
	test_player.player_index = 1
	add_child(test_player)
	
	print("✓ Test player instantiated")
	
	# Wait a frame for initialization
	await get_tree().process_frame
	
	# Run tests
	test_power_activation_integration()
	test_invincibility_mechanics()
	test_power_cleanup()
	
	print("\n🎉 Player Power Integration Tests Complete!")
	
	# Clean up
	if test_player:
		test_player.queue_free()

func test_power_activation_integration():
	"""Test power activation through PowerManager to Player"""
	print("\n--- Testing Power Activation Integration ---")
	
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Test initial state
	if not test_player.is_power_active:
		print("✓ Player has no power active initially")
	else:
		print("❌ Player should not have power active initially")
	
	# Activate power through PowerManager
	var result = power_manager.activate_power(player_index, power_type)
	
	# Wait a frame for signal processing
	await get_tree().process_frame
	
	if result and test_player.is_power_active:
		print("✓ Power activation successful - player received power")
	else:
		print("❌ Power activation failed - player did not receive power")
	
	# Check power type
	if test_player.active_power_type == power_type:
		print("✓ Correct power type activated on player")
	else:
		print("❌ Wrong power type on player (expected: %d, got: %d)" % [power_type, test_player.active_power_type])

func test_invincibility_mechanics():
	"""Test invincibility power mechanics"""
	print("\n--- Testing Invincibility Mechanics ---")
	
	# Check collision mask changes
	var enemy_collision_disabled = not test_player.get_collision_mask_value(3)
	if enemy_collision_disabled:
		print("✓ Enemy collision layer disabled during invincibility")
	else:
		print("❌ Enemy collision layer should be disabled during invincibility")
	
	# Check visual effects (if nodes exist)
	if test_player.power_overlay:
		if test_player.power_overlay.visible:
			print("✓ Power overlay visible during invincibility")
		else:
			print("❌ Power overlay should be visible during invincibility")
	else:
		print("ℹ Power overlay node not present in scene (optional)")
	
	# Check sprite modulation
	var sprite_tinted = test_player.animated_sprite.modulate != Color.WHITE
	if sprite_tinted:
		print("✓ Player sprite tinted during invincibility")
	else:
		print("❌ Player sprite should be tinted during invincibility")

func test_power_cleanup():
	"""Test power deactivation and cleanup"""
	print("\n--- Testing Power Cleanup ---")
	
	# Deactivate power
	power_manager.deactivate_power(1)
	
	# Wait a frame for signal processing
	await get_tree().process_frame
	
	# Check player state
	if not test_player.is_power_active:
		print("✓ Power deactivated on player")
	else:
		print("❌ Power should be deactivated on player")
	
	# Check collision mask restored
	var enemy_collision_enabled = test_player.get_collision_mask_value(3)
	if enemy_collision_enabled:
		print("✓ Enemy collision layer restored after power deactivation")
	else:
		print("❌ Enemy collision layer should be restored after power deactivation")
	
	# Check visual effects cleaned up
	if test_player.power_overlay:
		if not test_player.power_overlay.visible:
			print("✓ Power overlay hidden after deactivation")
		else:
			print("❌ Power overlay should be hidden after deactivation")
	
	# Check sprite modulation restored
	var sprite_normal = test_player.animated_sprite.modulate == Color.WHITE
	if sprite_normal:
		print("✓ Player sprite modulation restored")
	else:
		print("❌ Player sprite modulation should be restored")