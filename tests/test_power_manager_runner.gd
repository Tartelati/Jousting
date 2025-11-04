extends Node

# Test runner for PowerManager unit tests

func _ready():
	print("Starting PowerManager Unit Tests...")
	
	# Load and run the test
	var test_scene = preload("res://tests/unit/test_power_manager.gd")
	var test_instance = test_scene.new()
	
	add_child(test_instance)
	
	# Run tests
	await test_instance.run_tests()
	
	# Get results
	var summary = test_instance.get_test_summary()
	
	# Print final summary
	print("\n" + "=".repeat(60))
	print("POWER MANAGER TEST SUMMARY")
	print("=".repeat(60))
	print("Total Tests: %d" % summary.total)
	print("Passed: %d" % summary.passed)
	print("Failed: %d" % summary.failed)
	
	if summary.failed == 0:
		print("🎉 ALL POWER MANAGER TESTS PASSED!")
	else:
		print("❌ %d POWER MANAGER TESTS FAILED" % summary.failed)
	
	print("=".repeat(60))
	
	# Clean up
	test_instance.queue_free()
	
	# Exit after a short delay
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()