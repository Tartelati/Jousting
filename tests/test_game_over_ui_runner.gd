extends Control

# Test runner for GameOver UI tests
# This script can be attached to a scene to run the UI tests

@onready var test_label = $VBoxContainer/TestLabel
@onready var run_button = $VBoxContainer/RunButton
@onready var results_label = $VBoxContainer/ResultsLabel

var gut_instance: GUT

func _ready():
	# Setup UI
	if not has_node("VBoxContainer"):
		_create_ui()
	
	# Connect button
	run_button.connect("pressed", _run_tests)
	
	# Initialize GUT
	gut_instance = GUT.new()
	add_child(gut_instance)

func _create_ui():
	"""Create the test runner UI if it doesn't exist"""
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	add_child(vbox)
	
	var label = Label.new()
	label.name = "TestLabel"
	label.text = "GameOver UI Test Runner"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var button = Button.new()
	button.name = "RunButton"
	button.text = "Run UI Tests"
	vbox.add_child(button)
	
	var results = Label.new()
	results.name = "ResultsLabel"
	results.text = "Click 'Run UI Tests' to start testing"
	results.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(results)
	
	# Update references
	test_label = label
	run_button = button
	results_label = results

func _run_tests():
	"""Run the GameOver UI tests"""
	results_label.text = "Running tests..."
	run_button.disabled = true
	
	# Configure GUT
	gut_instance.log_level = 1  # Show all output
	gut_instance.yield_between_tests = true
	gut_instance.export_path = "user://test_results/"
	
	# Add test script
	gut_instance.add_script("res://tests/unit/test_game_over_ui.gd")
	
	# Connect to completion signal
	if not gut_instance.is_connected("tests_finished", _on_tests_finished):
		gut_instance.connect("tests_finished", _on_tests_finished)
	
	# Run tests
	gut_instance.test_scripts()

func _on_tests_finished(test_results):
	"""Handle test completion"""
	var passed = gut_instance.get_pass_count()
	var failed = gut_instance.get_fail_count()
	var total = passed + failed
	
	var result_text = "Tests completed!\n"
	result_text += "Passed: %d\n" % passed
	result_text += "Failed: %d\n" % failed
	result_text += "Total: %d\n" % total
	
	if failed > 0:
		result_text += "\nSome tests failed. Check console for details."
	else:
		result_text += "\nAll tests passed! ✅"
	
	results_label.text = result_text
	run_button.disabled = false
	
	# Print summary to console
	print("=== GameOver UI Test Results ===")
	print("Passed: %d, Failed: %d, Total: %d" % [passed, failed, total])
	if failed > 0:
		print("❌ Some tests failed")
	else:
		print("✅ All tests passed!")