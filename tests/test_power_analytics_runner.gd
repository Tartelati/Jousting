extends Node

# Test runner for PowerAnalytics system
# This script runs comprehensive tests for the power system analytics and telemetry

func _ready():
	print("Starting Power Analytics Tests...")
	run_analytics_tests()

func run_analytics_tests():
	"""Run all power analytics tests"""
	var test_analytics = preload("res://tests/unit/test_power_analytics.gd").new()
	add_child(test_analytics)
	
	test_analytics.setup()
	test_analytics.run_tests()
	test_analytics.cleanup()
	
	print("\nPower Analytics Tests Complete!")
	print("Check console output for detailed results.")
	
	# Auto-quit after tests (useful for automated testing)
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()