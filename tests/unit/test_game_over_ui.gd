extends GutTest

# Test class for GameOver UI name entry and validation functionality
class_name TestGameOverUI

var game_over_scene: PackedScene
var game_over_instance: Control
var score_manager: Node
var mock_validator: HighScoreValidator

func before_each():
	"""Setup before each test"""
	# Load the game over scene
	game_over_scene = load("res://scenes/ui/game_over.tscn")
	game_over_instance = game_over_scene.instantiate()
	
	# Setup mock score manager
	score_manager = Node.new()
	score_manager.name = "ScoreManager"
	score_manager.set_script(load("res://scripts/managers/score_manager.gd"))
	
	# Initialize score manager with test data
	score_manager.scores = {1: 50000}
	score_manager.high_scores = [
		{"name": "David Lacassagne", "score": 999_999_999},
		{"name": "TestPlayer", "score": 10000}
	]
	score_manager.config = {
		"max_high_scores": 10,
		"auto_save": true,
		"debug_logging": false
	}
	
	# Add to scene tree
	add_child_autofree(score_manager)
	add_child_autofree(game_over_instance)
	
	# Setup validator
	mock_validator = HighScoreValidator.new()

func after_each():
	"""Cleanup after each test"""
	if game_over_instance:
		game_over_instance.queue_free()
	if score_manager:
		score_manager.queue_free()

func test_name_entry_shows_for_qualifying_score():
	"""Test that name entry UI shows when player achieves qualifying score"""
	# Setup qualifying score
	score_manager.scores = {1: 50000}  # Higher than TestPlayer's 10000
	
	# Trigger ready
	game_over_instance._ready()
	
	# Check that high score container is visible
	var high_score_container = game_over_instance.get_node("VBoxContainer/HighScoreContainer")
	assert_true(high_score_container.visible, "High score container should be visible for qualifying scores")

func test_name_entry_hidden_for_non_qualifying_score():
	"""Test that name entry UI is hidden when score doesn't qualify"""
	# Setup non-qualifying score
	score_manager.scores = {1: 5000}  # Lower than existing scores
	
	# Trigger ready
	game_over_instance._ready()
	
	# Check that high score container is hidden
	var high_score_container = game_over_instance.get_node("VBoxContainer/HighScoreContainer")
	assert_false(high_score_container.visible, "High score container should be hidden for non-qualifying scores")

func test_real_time_name_validation():
	"""Test real-time validation feedback as user types"""
	# Setup qualifying score
	score_manager.scores = {1: 50000}
	game_over_instance._ready()
	
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	var validation_message = game_over_instance.get_node("VBoxContainer/HighScoreContainer/ValidationMessage")
	var character_count = game_over_instance.get_node("VBoxContainer/HighScoreContainer/CharacterCount")
	
	# Test valid name
	name_entry.text = "TestPlayer"
	game_over_instance._on_name_text_changed("TestPlayer")
	
	assert_eq(character_count.text, "10/20 characters", "Character count should be correct")
	assert_eq(validation_message.text, "", "No validation message for valid name")

func test_name_length_validation():
	"""Test validation for names that are too long"""
	score_manager.scores = {1: 50000}
	game_over_instance._ready()
	
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	var validation_message = game_over_instance.get_node("VBoxContainer/HighScoreContainer/ValidationMessage")
	var submit_button = game_over_instance.get_node("VBoxContainer/HighScoreContainer/ButtonContainer/SubmitNameButton")
	
	# Test name that's too long
	var long_name = "ThisNameIsWayTooLongForTheLimit"
	name_entry.text = long_name
	game_over_instance._on_name_text_changed(long_name)
	
	assert_true(validation_message.text.begins_with("Name too long"), "Should show length validation error")
	assert_true(submit_button.disabled, "Submit button should be disabled for invalid names")

func test_invalid_character_filtering():
	"""Test that invalid characters are detected and filtered"""
	score_manager.scores = {1: 50000}
	game_over_instance._ready()
	
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	var validation_message = game_over_instance.get_node("VBoxContainer/HighScoreContainer/ValidationMessage")
	
	# Test name with invalid characters
	var invalid_name = "Test@Player#123"
	name_entry.text = invalid_name
	game_over_instance._on_name_text_changed(invalid_name)
	
	assert_true(validation_message.text.begins_with("Some characters"), "Should show character filtering warning")

func test_empty_name_handling():
	"""Test handling of empty or whitespace-only names"""
	score_manager.scores = {1: 50000}
	game_over_instance._ready()
	
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	var validation_message = game_over_instance.get_node("VBoxContainer/HighScoreContainer/ValidationMessage")
	
	# Test empty name
	name_entry.text = ""
	game_over_instance._on_name_text_changed("")
	
	# Empty should be allowed (will default to Anonymous)
	assert_eq(validation_message.text, "", "Empty name should be allowed")
	
	# Test whitespace-only name
	name_entry.text = "   "
	game_over_instance._on_name_text_changed("   ")
	
	assert_true(validation_message.text.begins_with("Name cannot be only spaces"), "Should reject whitespace-only names")

func test_submit_button_state():
	"""Test that submit button is properly enabled/disabled based on validation"""
	score_manager.scores = {1: 50000}
	game_over_instance._ready()
	
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	var submit_button = game_over_instance.get_node("VBoxContainer/HighScoreContainer/ButtonContainer/SubmitNameButton")
	
	# Valid name should enable button
	name_entry.text = "ValidName"
	game_over_instance._on_name_text_changed("ValidName")
	assert_false(submit_button.disabled, "Submit button should be enabled for valid names")
	
	# Invalid name should disable button
	name_entry.text = "ThisNameIsWayTooLongForTheCharacterLimit"
	game_over_instance._on_name_text_changed("ThisNameIsWayTooLongForTheCharacterLimit")
	assert_true(submit_button.disabled, "Submit button should be disabled for invalid names")

func test_skip_button_functionality():
	"""Test that skip button submits with Anonymous name"""
	score_manager.scores = {1: 50000}
	
	# Mock the submit_high_score method
	score_manager.submit_high_score = func(player_index: int, player_name: String) -> Dictionary:
		return {
			"success": true,
			"rank": 2,
			"is_personal_best": true,
			"previous_score": 0,
			"message": "Success"
		}
	
	game_over_instance._ready()
	
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	
	# Set some text in name entry
	name_entry.text = "SomeText"
	
	# Trigger skip button
	game_over_instance._on_skip_pressed()
	
	# Name entry should be cleared (skip uses empty name which becomes Anonymous)
	assert_eq(name_entry.text, "", "Name entry should be cleared when skip is pressed")

func test_enter_key_submission():
	"""Test that pressing Enter in name field submits the score"""
	score_manager.scores = {1: 50000}
	
	# Mock the submit_high_score method
	var submitted_name = ""
	score_manager.submit_high_score = func(player_index: int, player_name: String) -> Dictionary:
		submitted_name = player_name
		return {
			"success": true,
			"rank": 2,
			"is_personal_best": true,
			"previous_score": 0,
			"message": "Success"
		}
	
	game_over_instance._ready()
	
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	name_entry.text = "TestPlayer"
	
	# Simulate Enter key press
	game_over_instance._on_name_submitted("TestPlayer")
	
	assert_eq(submitted_name, "TestPlayer", "Should submit the entered name when Enter is pressed")

func test_character_count_display():
	"""Test that character count is displayed correctly"""
	score_manager.scores = {1: 50000}
	game_over_instance._ready()
	
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	var character_count = game_over_instance.get_node("VBoxContainer/HighScoreContainer/CharacterCount")
	
	# Test various lengths
	name_entry.text = "Test"
	game_over_instance._on_name_text_changed("Test")
	assert_eq(character_count.text, "4/20 characters", "Should show correct character count")
	
	name_entry.text = "A very long player name"
	game_over_instance._on_name_text_changed("A very long player name")
	assert_eq(character_count.text, "22/20 characters", "Should show correct character count even when over limit")

func test_validation_message_colors():
	"""Test that validation messages use appropriate colors"""
	score_manager.scores = {1: 50000}
	game_over_instance._ready()
	
	var name_entry = game_over_instance.get_node("VBoxContainer/HighScoreContainer/NameEntry")
	var validation_message = game_over_instance.get_node("VBoxContainer/HighScoreContainer/ValidationMessage")
	var character_count = game_over_instance.get_node("VBoxContainer/HighScoreContainer/CharacterCount")
	
	# Test error color for too long name
	name_entry.text = "ThisNameIsWayTooLongForTheLimit"
	game_over_instance._on_name_text_changed("ThisNameIsWayTooLongForTheLimit")
	assert_eq(validation_message.modulate, Color.RED, "Error messages should be red")
	assert_eq(character_count.modulate, Color.RED, "Character count should be red when over limit")
	
	# Test warning color for filtered characters
	name_entry.text = "Test@Player"
	game_over_instance._on_name_text_changed("Test@Player")
	assert_eq(validation_message.modulate, Color.YELLOW, "Warning messages should be yellow")

func test_personal_best_message():
	"""Test that personal best achievement is properly displayed"""
	# Setup score that would be a personal best
	score_manager.scores = {1: 50000}
	score_manager.high_scores = [
		{"name": "David Lacassagne", "score": 999_999_999},
		{"name": "TestPlayer", "score": 30000}  # Lower than current score
	]
	
	game_over_instance._ready()
	
	var high_score_message = game_over_instance.get_node("VBoxContainer/HighScoreContainer/HighScoreMessage")
	
	# Should show personal best message since 50000 > 30000
	assert_true(high_score_message.text.contains("PERSONAL BEST"), "Should show personal best message when appropriate")

func test_score_formatting():
	"""Test that scores are properly formatted with thousands separators"""
	score_manager.scores = {1: 1234567}
	game_over_instance._ready()
	
	var formatted = game_over_instance._format_score(1234567)
	assert_eq(formatted, "1,234,567", "Should format scores with thousands separators")
	
	formatted = game_over_instance._format_score(100)
	assert_eq(formatted, "100", "Should not add separators to small numbers")

func test_success_feedback():
	"""Test that success feedback is properly displayed"""
	score_manager.scores = {1: 50000}
	
	# Mock successful submission
	score_manager.submit_high_score = func(player_index: int, player_name: String) -> Dictionary:
		return {
			"success": true,
			"rank": 2,
			"is_personal_best": true,
			"previous_score": 0,
			"message": "Success"
		}
	
	game_over_instance._ready()
	
	var high_score_container = game_over_instance.get_node("VBoxContainer/HighScoreContainer")
	var high_score_label = game_over_instance.get_node("VBoxContainer/HighScoreLabel")
	
	# Submit a score
	game_over_instance._submit_score()
	
	# High score container should be hidden after successful submission
	assert_false(high_score_container.visible, "High score container should be hidden after successful submission")

func test_error_feedback():
	"""Test that error feedback is properly displayed"""
	score_manager.scores = {1: 50000}
	
	# Mock failed submission
	score_manager.submit_high_score = func(player_index: int, player_name: String) -> Dictionary:
		return {
			"success": false,
			"rank": -1,
			"is_personal_best": false,
			"previous_score": 0,
			"message": "Save failed"
		}
	
	game_over_instance._ready()
	
	var validation_message = game_over_instance.get_node("VBoxContainer/HighScoreContainer/ValidationMessage")
	
	# Submit a score
	game_over_instance._submit_score()
	
	# Should show error message
	assert_true(validation_message.text.contains("failed"), "Should show error message when submission fails")
	assert_eq(validation_message.modulate, Color.RED, "Error message should be red")