extends Control

# Test runner for multi-player high score system

@onready var test_output = $VBoxContainer/ScrollContainer/TestOutput
@onready var run_button = $VBoxContainer/RunTestsButton
@onready var progress_bar = $VBoxContainer/ProgressBar
@onready var status_label = $VBoxContainer/StatusLabel

var test_runner: Node

func _ready():
	run_button.connect("pressed", _run_tests)
	status_label.text = "Ready to run multi-player high score tests (Standalone Mode)"

func _run_tests():
	run_button.disabled = true
	status_label.text = "Running basic validation tests..."
	progress_bar.value = 0
	test_output.text = "Multi-player High Score Test Runner (Standalone)\n"
	test_output.text += "=" * 50 + "\n\n"
	test_output.text += "Note: This is a basic test runner.\n"
	test_output.text += "For full GUT framework support, install the GUT addon.\n\n"
	test_output.text += "Running basic validation tests...\n\n"
	
	# Run basic validation
	_run_basic_validation()

func _run_basic_validation():
	"""Run basic validation tests without GUT framework"""
	var tests_passed = 0
	var tests_failed = 0
	var test_output_text = ""
	
	# Test 1: ScoreManager exists
	test_output_text += "Test 1: ScoreManager availability... "
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		test_output_text += "PASS\n"
		tests_passed += 1
	else:
		test_output_text += "FAIL\n"
		tests_failed += 1
	
	progress_bar.value = 25
	
	# Test 2: Multi-player methods exist
	test_output_text += "Test 2: Multi-player methods... "
	if score_manager and score_manager.has_method("check_all_players_for_qualifying_scores"):
		test_output_text += "PASS\n"
		tests_passed += 1
	else:
		test_output_text += "FAIL\n"
		tests_failed += 1
	
	progress_bar.value = 50
	
	# Test 3: HighScoreValidator exists
	test_output_text += "Test 3: HighScoreValidator class... "
	var validator = HighScoreValidator.new()
	if validator:
		test_output_text += "PASS\n"
		tests_passed += 1
		validator.queue_free()
	else:
		test_output_text += "FAIL\n"
		tests_failed += 1
	
	progress_bar.value = 75
	
	# Test 4: Basic score validation
	test_output_text += "Test 4: Basic score validation... "
	if validator and validator.is_valid_score(1000):
		test_output_text += "PASS\n"
		tests_passed += 1
	else:
		test_output_text += "FAIL\n"
		tests_failed += 1
	
	progress_bar.value = 100
	
	# Final results
	test_output_text += "\n" + "=".repeat(40) + "\n"
	test_output_text += "RESULTS:\n"
	test_output_text += "Tests Passed: %d\n" % tests_passed
	test_output_text += "Tests Failed: %d\n" % tests_failed
	test_output_text += "Total Tests: %d\n" % (tests_passed + tests_failed)
	
	if tests_failed == 0:
		test_output_text += "\n🎉 ALL BASIC TESTS PASSED! 🎉\n"
		status_label.text = "All basic tests passed!"
	else:
		test_output_text += "\n❌ Some tests failed\n"
		status_label.text = "Tests completed: %d passed, %d failed" % [tests_passed, tests_failed]
	
	test_output.text += test_output_text
	run_button.disabled = false

func _on_back_pressed():
	get_tree().change_scene_to_file("res://tests/test_runner.tscn")