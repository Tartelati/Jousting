extends Node

# Test runner for PowerEgg integration tests

func _ready():
	print("PowerEgg Test Runner Starting...")
	
	# Load and run the integration test
	var test_scene = preload("res://tests/integration_power_egg_test.gd")
	var test_instance = test_scene.new()
	add_child(test_instance)
	
	# Wait a frame then run tests
	await get_tree().process_frame
	test_instance.run_tests()
	
	# Wait a bit then exit
	await get_tree().create_timer(2.0).timeout
	print("\nPowerEgg tests completed. Exiting...")
	get_tree().quit()