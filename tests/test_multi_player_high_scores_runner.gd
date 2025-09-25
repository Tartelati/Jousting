extends Control

# Test runner for multi-player high score system

@onready var test_output = $VBoxContainer/ScrollContainer/TestOutput
@onready var run_button = $VBoxContainer/RunTestsButton
@onready var progress_bar = $VBoxContainer/ProgressBar
@onready var status_label = $VBoxContainer/StatusLabel

var gut_instance: GUT

func _ready():
	run_button.connect("pressed", _run_tests)
	status_label.text = "Ready to run multi-player high score tests"

func _run_tests():
	run_button.disabled = true
	status_label.text = "Running tests..."
	progress_bar.value = 0
	test_output.text = ""
	
	# Create GUT instance
	gut_instance = GUT.new()
	add_child(gut_instance)
	
	# Configure GUT
	gut_instance.log_level = gut_instance.LOG_LEVEL_ALL_ASSERTS
	gut_instance.should_print_to_console = false
	gut_instance.should_print_summary = true
	
	# Connect to GUT signals
	gut_instance.connect("tests_finished", _on_tests_finished)
	gut_instance.connect("test_script_run", _on_test_script_run)
	
	# Add test scripts
	gut_instance.add_script("res://tests/unit/test_multi_player_high_scores.gd")
	gut_instance.add_script("res://tests/integration_multi_player_high_scores_test.gd")
	
	# Run tests
	gut_instance.test_scripts()

func _on_test_script_run(script_name: String):
	progress_bar.value += 50  # Two scripts, so 50% each
	status_label.text = "Running: " + script_name.get_file()

func _on_tests_finished():
	run_button.disabled = false
	progress_bar.value = 100
	
	# Get test results
	var summary = gut_instance.get_summary()
	var total_tests = summary.get_totals()
	
	status_label.text = "Tests completed: %d passed, %d failed" % [total_tests.passing, total_tests.failing]
	
	# Display detailed results
	var output_text = "=== MULTI-PLAYER HIGH SCORE TESTS ===\n\n"
	output_text += "Total Tests: %d\n" % total_tests.tests
	output_text += "Passed: %d\n" % total_tests.passing
	output_text += "Failed: %d\n" % total_tests.failing
	output_text += "Pending: %d\n\n" % total_tests.pending
	
	if total_tests.failing > 0:
		output_text += "FAILURES:\n"
		var failures = gut_instance.get_fail_count()
		for i in range(failures):
			var failure = gut_instance.get_fail_at(i)
			if failure:
				output_text += "- %s\n" % failure
	else:
		output_text += "🎉 ALL TESTS PASSED! 🎉\n"
	
	output_text += "\n=== DETAILED OUTPUT ===\n"
	output_text += gut_instance.get_log_text()
	
	test_output.text = output_text
	
	# Clean up
	gut_instance.queue_free()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://tests/test_runner.tscn")