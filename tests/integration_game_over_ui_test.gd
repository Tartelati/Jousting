extends Control

# Integration test for GameOver UI name entry workflow
# This test simulates the complete user experience of entering a name for a high score

@onready var test_label = $VBoxContainer/TestLabel
@onready var start_button = $VBoxContainer/StartButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var game_over_container = $VBoxContainer/GameOverContainer

var game_over_scene: PackedScene
var game_over_instance: Control
var score_manager: Node
var test_step: int = 0
var test_results: Array[String] = []

func _ready():
	"""Initialize the integration test"""
	start_button.connect("pressed", _start_integration_test)
	status_label.text = "Ready to test GameOver UI integration"

func _start_integration_test():
	"""Start the complete integration test workflow"""
	test_results.clear()
	test_step = 0
	start_button.disabled = true
	status_label.text = "Starting integration test..."
	
	_setup_test_environment()
	_run_test_sequence()

func _setup_test_environment():
	"""Setup the test environment with mock data"""
	# Create mock ScoreManager
	score_manager = Node.new()
	score_manager.name = "ScoreManager"
	score_manager.set_script(load("res://scripts/managers/score_manager.gd"))
	
	# Initialize with test data - qualifying score
	score_manager.scores = {1: 75000}
	score_manager.high_scores = [
		{"name": "David Lacassagne", "score": 999_999_999},
		{"name": "TestPlayer", "score": 50000},
		{"name": "AnotherPlayer", "score": 30000}
	]
	score_manager.config = {
		"max_high_scores": 10,
		"auto_save": true,
		"debug_logging": true
	}
	
	# Mock the submit_high_score method
	score_manager.submit_high_score = _mock_submit_high_score
	
	# Add to scene tree
	add_child(score_manager)
	
	# Load and instantiate GameOver scene
	game_over_scene = load("res://scenes/ui/game_over.tscn")
	game_over_instance = game_over_scene.instantiate()
	
	# Add to container for display
	game_over_container.add_child(game_over_instance)
	
	_log_result("✅ Test environment setup complete")

func _mock_submit_high_score(player_index: int, player_name: String) -> Dictionary:
	"""Mock implementation of submit_high_score for testing"""
	_log_result("📝 Submitting high score: Player %d, Name: '%s', Score: %d" % [player_index, player_name, score_manager.scores[player_index]])
	
	# Simulate successful submission
	return {
		"success": true,
		"rank": 2,
		"is_personal_best": true,
		"previous_score": 0,
		"message": "High score saved successfully!"
	}

func _run_test_sequence():
	"""Run the complete test sequence"""
	await _test_initial_display()
	await _test_name_entry_validation()
	await _test_successful_submission()
	await _test_error_handling()
	_complete_test()

func _test_initial_display():
	"""Test 1: Initial display shows correctly for qualifying score"""
	_log_result("🧪 Test 1: Testing initial display...")
	
	# Trigger the GameOver screen setup
	game_over_instance._ready()
	
	# Wait a frame for UI updates
	await get_tree().process_frame
	
	# Check that high score container is visible
	var high_score_container = game_over_instance.get_node("VBoxContainer/HighScoreContainer")
	if high_score_container.visible:
		_log_result("✅ High score container is visible for qualifying score")
	else:
		_log_result("❌ High score container should be visible for qualifying score")
	
	# Check that the message is displayed
	var high_score_message = game_over_instance.get_node("VBoxContainer/HighScoreContainer/HighScoreMessage")
	if high_score_message.text.contains("HIGH SCORE"):
		_log_result("✅ High score achievement message is displayed")
	else:
		_log_result("❌ High score achievement message not found")
	
	# Check that name entry field is ready
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	if name_entry.visible and name_entry.editable:
		_log_result("✅ Name entry field is ready for input")
	else:
		_log_result("❌ Name entry field is not ready")

func _test_name_entry_validation():
	"""Test 2: Name entry validation works correctly"""
	_log_result("🧪 Test 2: Testing name entry validation...")
	
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	var validation_message = game_over_instance.get_node("VBoxContainer/HighScoreContainer/ValidationMessage")
	var character_count = game_over_instance.get_node("VBoxContainer/HighScoreContainer/CharacterCount")
	var submit_button = game_over_instance.get_node("VBoxContainer/HighScoreContainer/ButtonContainer/SubmitNameButton")
	
	# Test valid name
	name_entry.text = "TestPlayer"
	game_over_instance._on_name_text_changed("TestPlayer")
	await get_tree().process_frame
	
	if character_count.text == "10/20 characters" and validation_message.text == "":
		_log_result("✅ Valid name shows correct character count and no errors")
	else:
		_log_result("❌ Valid name validation failed")
	
	# Test name too long
	name_entry.text = "ThisNameIsWayTooLongForTheCharacterLimit"
	game_over_instance._on_name_text_changed("ThisNameIsWayTooLongForTheCharacterLimit")
	await get_tree().process_frame
	
	if validation_message.text.begins_with("Name too long") and submit_button.disabled:
		_log_result("✅ Long name properly rejected and button disabled")
	else:
		_log_result("❌ Long name validation failed")
	
	# Test invalid characters
	name_entry.text = "Test@Player#"
	game_over_instance._on_name_text_changed("Test@Player#")
	await get_tree().process_frame
	
	if validation_message.text.begins_with("Some characters"):
		_log_result("✅ Invalid characters detected and warning shown")
	else:
		_log_result("❌ Invalid character detection failed")
	
	# Reset to valid name for next test
	name_entry.text = "IntegrationTest"
	game_over_instance._on_name_text_changed("IntegrationTest")
	await get_tree().process_frame

func _test_successful_submission():
	"""Test 3: Successful score submission"""
	_log_result("🧪 Test 3: Testing successful score submission...")
	
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	var high_score_container = game_over_instance.get_node("VBoxContainer/HighScoreContainer")
	
	# Set a valid name
	name_entry.text = "IntegrationTest"
	
	# Submit the score
	game_over_instance._submit_score()
	await get_tree().process_frame
	
	# Check that the high score container is hidden after successful submission
	if not high_score_container.visible:
		_log_result("✅ High score container hidden after successful submission")
	else:
		_log_result("❌ High score container should be hidden after submission")

func _test_error_handling():
	"""Test 4: Error handling for failed submissions"""
	_log_result("🧪 Test 4: Testing error handling...")
	
	# Create a new GameOver instance for error testing
	var error_test_instance = game_over_scene.instantiate()
	game_over_container.add_child(error_test_instance)
	
	# Mock a failing submit_high_score method
	score_manager.submit_high_score = func(player_index: int, player_name: String) -> Dictionary:
		return {
			"success": false,
			"rank": -1,
			"is_personal_best": false,
			"previous_score": 0,
			"message": "Save failed - disk full"
		}
	
	# Setup the error test instance
	error_test_instance._ready()
	await get_tree().process_frame
	
	var name_entry = error_test_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	var validation_message = error_test_instance.get_node("VBoxContainer/HighScoreContainer/ValidationMessage")
	
	# Set a valid name and submit
	name_entry.text = "ErrorTest"
	error_test_instance._submit_score()
	await get_tree().process_frame
	
	# Check that error message is displayed
	if validation_message.text.contains("failed"):
		_log_result("✅ Error message displayed for failed submission")
	else:
		_log_result("❌ Error message not displayed properly")
	
	# Cleanup
	error_test_instance.queue_free()

func _complete_test():
	"""Complete the integration test and show results"""
	_log_result("🏁 Integration test completed!")
	
	var passed_count = 0
	var total_count = 0
	
	for result in test_results:
		total_count += 1
		if result.begins_with("✅"):
			passed_count += 1
	
	var summary = "\n=== INTEGRATION TEST SUMMARY ===\n"
	summary += "Passed: %d/%d tests\n" % [passed_count, total_count]
	
	if passed_count == total_count:
		summary += "🎉 ALL TESTS PASSED!"
	else:
		summary += "⚠️ Some tests failed - check details above"
	
	_log_result(summary)
	
	start_button.disabled = false
	start_button.text = "Run Test Again"

func _log_result(message: String):
	"""Log a test result"""
	test_results.append(message)
	status_label.text += "\n" + message
	print("[GameOver UI Integration Test] " + message)

# Test utility methods for manual testing
func _input(event):
	"""Handle input for manual testing"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_test_valid_name_entry()
			KEY_2:
				_test_invalid_name_entry()
			KEY_3:
				_test_skip_functionality()

func _test_valid_name_entry():
	"""Manual test: Enter a valid name"""
	if game_over_instance:
		var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
		name_entry.text = "ManualTest"
		game_over_instance._on_name_text_changed("ManualTest")
		_log_result("Manual test: Valid name entered")

func _test_invalid_name_entry():
	"""Manual test: Enter an invalid name"""
	if game_over_instance:
		var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
		name_entry.text = "ThisNameIsWayTooLongForValidation"
		game_over_instance._on_name_text_changed("ThisNameIsWayTooLongForValidation")
		_log_result("Manual test: Invalid name entered")

func _test_skip_functionality():
	"""Manual test: Test skip button"""
	if game_over_instance:
		game_over_instance._on_skip_pressed()
		_log_result("Manual test: Skip button pressed")