extends Control

# Simple test runner for the high score system tests

@onready var test_output = $VBoxContainer/ScrollContainer/TestOutput
@onready var run_button = $VBoxContainer/RunTestsButton
@onready var progress_bar = $VBoxContainer/ProgressBar
@onready var status_label = $VBoxContainer/StatusLabel

var test_classes = [
	# Unit Tests
	"res://tests/unit/test_high_score_validator.gd",
	"res://tests/unit/test_multi_player_high_scores.gd",
	"res://tests/unit/test_notification_system.gd",
	"res://tests/unit/test_high_score_display.gd",
	"res://tests/unit/test_game_over_ui.gd",
	
	# Integration Tests
	"res://tests/integration_multi_player_high_scores_test.gd",
	"res://tests/integration_notification_system_test.gd",
	"res://tests/integration_high_score_display_test.gd",
]

func _ready():
	run_button.connect("pressed", _run_tests)
	status_label.text = "Ready to run tests"
	test_output.text = "Simple Test Runner\n" + "=".repeat(50) + "\n\n"
	test_output.text += "Click 'Run Tests' to execute all test suites.\n\n"

func _run_tests():
	run_button.disabled = true
	status_label.text = "Running tests..."
	progress_bar.value = 0
	test_output.text = "Simple Test Runner\n" + "=".repeat(50) + "\n\n"
	
	var total_passed = 0
	var total_failed = 0
	var total_tests = 0
	
	for i in range(test_classes.size()):
		var test_class_path = test_classes[i]
		test_output.text += "Running: " + test_class_path + "\n"
		
		# Load and instantiate test class
		var test_script = load(test_class_path)
		if test_script:
			var test_instance = test_script.new()
			add_child(test_instance)
			
			# Run tests
			await test_instance.run_tests()
			
			# Get results
			var summary = test_instance.get_test_summary()
			total_passed += summary.passed
			total_failed += summary.failed
			total_tests += summary.total
			
			test_output.text += "  Passed: %d, Failed: %d\n\n" % [summary.passed, summary.failed]
			
			# Clean up
			test_instance.queue_free()
		else:
			test_output.text += "  ERROR: Could not load test class\n\n"
			total_failed += 1
		
		progress_bar.value = (i + 1.0) / test_classes.size() * 100
		await get_tree().process_frame
	
	# Final summary
	test_output.text += "=".repeat(50) + "\n"
	test_output.text += "FINAL RESULTS:\n"
	test_output.text += "Total Tests: %d\n" % total_tests
	test_output.text += "Passed: %d\n" % total_passed
	test_output.text += "Failed: %d\n" % total_failed
	
	if total_failed == 0:
		test_output.text += "\n🎉 ALL TESTS PASSED! 🎉\n"
		status_label.text = "All tests passed!"
	else:
		test_output.text += "\n❌ Some tests failed\n"
		status_label.text = "Tests completed: %d passed, %d failed" % [total_passed, total_failed]
	
	run_button.disabled = false