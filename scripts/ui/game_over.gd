extends Control

signal restart
signal main_menu

# UI References
@onready var score_label = $VBoxContainer/ScoreLabel
@onready var high_score_label = $VBoxContainer/HighScoreLabel
@onready var high_score_container = $VBoxContainer/HighScoreContainer
@onready var high_score_message = $VBoxContainer/HighScoreContainer/HighScoreMessage
@onready var name_entry = $VBoxContainer/HighScoreContainer/NameEntry
@onready var validation_message = $VBoxContainer/HighScoreContainer/ValidationMessage
@onready var character_count = $VBoxContainer/HighScoreContainer/CharacterCount
@onready var submit_button = $VBoxContainer/HighScoreContainer/ButtonContainer/SubmitNameButton
@onready var skip_button = $VBoxContainer/HighScoreContainer/ButtonContainer/SkipButton

# State variables
var final_score: int = 0
var qualifying_player_index: int = 1
var score_manager: Node
var validator: HighScoreValidator
var is_personal_best: bool = false
var current_rank: int = -1

func _ready():
	# Get references
	score_manager = get_node("/root/ScoreManager")
	validator = HighScoreValidator.new()
	
	# Calculate final score and determine qualifying player
	_calculate_final_score()
	
	# Update score displays
	score_label.text = "Final Score: %s" % _format_score(final_score)
	high_score_label.text = "High Score: %s" % _format_score(_get_current_high_score())
	
	# Check if score qualifies for high score list
	var qualifies = _check_high_score_qualification()
	
	if qualifies:
		_setup_name_entry()
	else:
		_setup_non_qualifying_display()
	
	# Connect button signals
	$VBoxContainer/RestartButton.connect("pressed", _on_restart_pressed)
	$VBoxContainer/MainMenuButton.connect("pressed", _on_main_menu_pressed)
	
	# Play game over music
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_music("game_over")
	
	# Animate the game over screen
	_animate_entrance()

func _calculate_final_score():
	"""Calculate the highest score from all players and determine which player achieved it"""
	final_score = 0
	qualifying_player_index = 1
	
	for player_index in score_manager.scores:
		var player_score = score_manager.scores[player_index]
		if player_score > final_score:
			final_score = player_score
			qualifying_player_index = player_index

func _get_current_high_score() -> int:
	"""Get the current highest score from the high score list"""
	if score_manager.high_scores.is_empty():
		return 0
	return score_manager.high_scores[0].score

func _check_high_score_qualification() -> bool:
	"""Check if the final score qualifies for the high score list"""
	if final_score <= 0:
		return false
	
	# Check if list has room or if score beats existing scores
	if score_manager.high_scores.size() < score_manager.config.max_high_scores:
		return true
	
	# Check if score beats any existing score (skip developer entry at index 0)
	for i in range(1, score_manager.high_scores.size()):
		if final_score > score_manager.high_scores[i].score:
			return true
	
	return false

func _setup_name_entry():
	"""Setup the name entry UI for qualifying scores"""
	high_score_container.show()
	
	# Determine if this is a personal best
	_check_personal_best()
	
	# Update message based on achievement type
	if is_personal_best:
		high_score_message.text = "🎉 NEW PERSONAL BEST! 🎉"
	else:
		high_score_message.text = "🎉 NEW HIGH SCORE! 🎉"
	
	# Calculate rank
	current_rank = _calculate_rank()
	
	# Setup name entry
	name_entry.text = ""
	name_entry.grab_focus()
	
	# Connect signals for real-time validation
	name_entry.connect("text_changed", _on_name_text_changed)
	name_entry.connect("text_submitted", _on_name_submitted)
	submit_button.connect("pressed", _on_submit_pressed)
	skip_button.connect("pressed", _on_skip_pressed)
	
	# Initial validation state
	_update_validation_display("")

func _setup_non_qualifying_display():
	"""Setup display for non-qualifying scores"""
	high_score_container.hide()
	
	# Maybe show an encouraging message
	if final_score > 0:
		var encouragement = _get_encouragement_message()
		if encouragement != "":
			# Could add a label for encouragement, but keeping it simple for now
			pass

func _check_personal_best():
	"""Check if this score is a personal best for any existing player name"""
	# This is a simplified check - in a full implementation, we'd track player identities
	# For now, we'll assume it's a personal best if it's higher than previous scores
	is_personal_best = final_score > _get_current_high_score()

func _calculate_rank() -> int:
	"""Calculate what rank this score would achieve"""
	var rank = 1
	for entry in score_manager.high_scores:
		if final_score <= entry.score:
			rank += 1
		else:
			break
	return rank

func _on_name_text_changed(new_text: String):
	"""Handle real-time validation as user types"""
	_update_validation_display(new_text)

func _update_validation_display(text: String):
	"""Update validation feedback and character count"""
	var sanitized = validator.sanitize_player_name(text)
	var char_count = text.length()
	var is_valid = true
	var message = ""
	
	# Update character count
	character_count.text = "%d/20 characters" % char_count
	
	# Validation checks
	if char_count > 20:
		message = "Name too long (max 20 characters)"
		is_valid = false
		character_count.modulate = Color.RED
	elif text.strip_edges().is_empty() and char_count > 0:
		message = "Name cannot be only spaces"
		is_valid = false
		character_count.modulate = Color.YELLOW
	elif sanitized != text and not text.is_empty():
		message = "Some characters will be removed: '%s'" % sanitized
		character_count.modulate = Color.YELLOW
	else:
		character_count.modulate = Color.WHITE
	
	# Update validation message
	validation_message.text = message
	
	# Update submit button state
	submit_button.disabled = not is_valid and not text.is_empty()
	
	# Color coding for validation message
	if message.begins_with("Name too long") or message.begins_with("Name cannot be"):
		validation_message.modulate = Color.RED
	elif message.begins_with("Some characters"):
		validation_message.modulate = Color.YELLOW
	else:
		validation_message.modulate = Color.WHITE

func _on_name_submitted(text: String):
	"""Handle when user presses Enter in the name field"""
	if not submit_button.disabled:
		_submit_score()

func _on_submit_pressed():
	"""Handle submit button press"""
	_submit_score()

func _on_skip_pressed():
	"""Handle skip button press - submit with Anonymous"""
	name_entry.text = ""
	_submit_score()

func _submit_score():
	"""Submit the high score with validation"""
	var player_name = name_entry.text.strip_edges()
	
	# Validate the submission
	var validation_result = validator.validate_score_submission(player_name, final_score, qualifying_player_index)
	
	if validation_result.valid:
		var sanitized_name = validation_result.sanitized_data.name
		
		# Submit to score manager
		var result = score_manager.submit_high_score(qualifying_player_index, sanitized_name)
		
		if result.success:
			_show_success_feedback(sanitized_name, result.rank)
		else:
			_show_error_feedback("Failed to save high score. Please try again.")
	else:
		# Show validation errors
		var error_msg = "Invalid input: " + validation_result.errors[0]
		_show_error_feedback(error_msg)

func _show_success_feedback(player_name: String, rank: int):
	"""Show success message and hide name entry"""
	high_score_container.hide()
	
	# Update the high score display
	high_score_label.text = "High Score: %s" % _format_score(_get_current_high_score())
	
	# Could add a success animation or message here
	_animate_success()

func _show_error_feedback(error_message: String):
	"""Show error message to user"""
	validation_message.text = error_message
	validation_message.modulate = Color.RED
	
	# Flash the validation message
	var tween = create_tween()
	tween.tween_property(validation_message, "modulate", Color.WHITE, 0.5)
	tween.tween_delay(2.0)
	tween.tween_property(validation_message, "modulate", Color.RED, 0.5)

func _get_encouragement_message() -> String:
	"""Get an encouraging message for non-qualifying scores"""
	if final_score == 0:
		return ""
	
	var messages = [
		"Keep practicing!",
		"You're getting better!",
		"Try again for a higher score!",
		"Good effort!"
	]
	
	return messages[randi() % messages.size()]

func _format_score(score: int) -> String:
	"""Format score with thousands separators"""
	var score_str = str(score)
	var formatted = ""
	var count = 0
	
	for i in range(score_str.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			formatted = "," + formatted
		formatted = score_str[i] + formatted
		count += 1
	
	return formatted

func _animate_entrance():
	"""Animate the game over screen entrance"""
	modulate = Color(1, 1, 1, 0)  # Start transparent
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 1.0)

func _animate_success():
	"""Animate success feedback"""
	var tween = create_tween()
	tween.tween_property(high_score_label, "modulate", Color.GREEN, 0.3)
	tween.tween_property(high_score_label, "modulate", Color.WHITE, 0.3)

func _on_restart_pressed():
	emit_signal("restart")

func _on_main_menu_pressed():
	emit_signal("main_menu")
