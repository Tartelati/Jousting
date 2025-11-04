extends Node

# Test runner for Player Power Integration tests

func _ready():
	print("Starting Player Power Integration Tests...")
	
	# Load and run the test
	var test_scene = preload("res://tests/test_player_power_integration.gd")
	var test_instance = test_scene.new()
	
	add_child(test_instance)
	
	# Wait for tests to complete
	await get_tree().create_timer(3.0).timeout
	
	print("\n" + "=".repeat(60))
	print("PLAYER POWER INTEGRATION TEST COMPLETE")
	print("=".repeat(60))
	
	# Clean up
	test_instance.queue_free()
	
	# Exit after a short delay
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()