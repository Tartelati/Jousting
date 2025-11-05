extends Node

# Test runner for PowerManager error handling tests

func _ready():
	print("=== PowerManager Error Handling Tests ===")
	
	# Load and run the error handling test
	var test_scene = preload("res://tests/unit/test_power_manager_error_handling.gd")
	var test_instance = test_scene.new()
	
	add_child(test_instance)
	
	# Run all test methods
	var test_methods = []
	for method in test_instance.get_method_list():
		if method.name.begins_with("test_"):
			test_methods.append(method.name)
	
	print("Found %d error handling tests" % test_methods.size())
	
	var passed = 0
	var failed = 0
	
	for test_method in test_methods:
		print("\n--- Running %s ---" % test_method)
		
		# Setup
		if test_instance.has_method("before_each"):
			test_instance.before_each()
		
		# Run test
		try:
			test_instance.call(test_method)
			print("✓ PASSED: %s" % test_method)
			passed += 1
		except:
			print("✗ FAILED: %s" % test_method)
			failed += 1
	
	print("\n=== Error Handling Test Results ===")
	print("Passed: %d" % passed)
	print("Failed: %d" % failed)
	print("Total: %d" % (passed + failed))
	
	if failed == 0:
		print("🎉 All error handling tests passed!")
	else:
		print("⚠️  Some error handling tests failed")
	
	# Exit after tests
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()