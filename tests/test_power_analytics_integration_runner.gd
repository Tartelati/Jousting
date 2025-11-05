extends Node

# Integration test runner for PowerAnalytics system
# This script runs comprehensive integration tests for the power system analytics

func _ready():
	print("Starting Power Analytics Integration Tests...")
	run_integration_tests()

func run_integration_tests():
	"""Run all power analytics integration tests"""
	var test_integration = preload("res://tests/integration_power_analytics_test.gd").new()
	add_child(test_integration)
	
	test_integration.setup()
	await test_integration.run_tests()
	test_integration.cleanup()
	
	print("\nPower Analytics Integration Tests Complete!")
	print("Check console output for detailed results.")
	
	# Auto-quit after tests (useful for automated testing)
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()