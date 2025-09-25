extends Control

signal restart
signal main_menu

# UI References
@onready var score_summary_container = $VBoxContainer/ScoreSummaryContainer
@onready var current_player_container = $VBoxContainer/CurrentPlayerContainer
@onready var current_player_label = $VBoxContainer/CurrentPlayerContainer/CurrentPlayerLabel
@onready var score_label = $VBoxContainer/CurrentPlayerContainer/ScoreLabel
@onready var rank_label = $VBoxContainer/CurrentPlayerContainer/RankLabel
@onready var name_entry = $VBoxContainer/CurrentPlayerContainer/NameEntry
@onready var validation_message = $VBoxContainer/CurrentPlayerContainer/ValidationMessage
@onready var character_count = $VBoxContainer/CurrentPlayerContainer/CharacterCount
@onready var submit_button = $VBoxContainer/CurrentPlayerContainer/ButtonContainer/SubmitNameButton
@onready var skip_button = $VBoxContainer/CurrentPlayerContainer/ButtonContainer/SkipButton
@onready var progress_label = $VBoxContainer/CurrentPlayerContainer/ProgressLabel
@onready var final_summary_container = $VBoxContainer/FinalSummaryContainer
@onready var final_scores_list = $VBoxContainer/FinalSummaryContainer/FinalScoresList

# State variables
var score_manager: Node
var validator: HighScoreValidator
var current_player_index: int = -1
var remaining_players: Array[int] = []
var all_player_scores: Dictionary = {}

func _ready():
	# Get references
	score_manager = get_node("/root/ScoreManager")
	validator = HighScoreValidator.new()
	
	# Initialize multi-player high score processing
	_initialize_multi_player_processing()
	
	# Connect button signals
	$VBoxContainer/RestartButton.connect("pressed", _on_restart_pressed)
	$VBoxContainer/MainMenuButton.connect("pressed", _on_main_menu_pressed)
	
	# Play game over music
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_music("game_over")
	
	# Animate the game over screen
	_animate_entrance()

func _initialize_multi_player_processing():
	"""Initialize the multi-player high score processing workflow"""
	# Get all player scores for summary
	all_player_scores = score_manager.scores.duplicate()
	
	# Check which players qualify for high scores
	var qualifying_players = score_manager.check_all_players_for_qualifying_scores()
	remaining_players = qualifying_players.duplicate()
	
	# Create score summary for all players
	_create_score_summary()
	
	if remaining_players.size() > 0:
		# Start with the first qualifying player
		_process_next_player()
	else:
		# No qualifying players, show final summary
		_show_final_summary()

func _create_score_summary():
	"""Create a summary of all players' scores"""
	# Clear existing summary
	for child in score_summary_container.get_children():
		child.queue_free()
	
	# Add title
	var title_label = Label.new()
	title_label.text = "GAME OVER - Final Scores"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_summary_container.add_child(title_label)
	
	# Sort players by score (highest first)
	var sorted_players = all_player_scores.keys()
	sorted_players.sort_custom(func(a, b): return all_player_scores[a] > all_player_scores[b])
	
	# Add each player's score
	for i in range(sorted_players.size()):
		var player_index = sorted_players[i]
		var player_score = all_player_scores[player_index]
		var is_qualifying = player_index in remaining_players
		
		var player_container = HBoxContainer.new()
		
		# Rank
		var rank_label = Label.new()
		rank_label.text = "#%d" % (i + 1)
		rank_label.custom_minimum_size.x = 40
		player_container.add_child(rank_label)
		
		# Player name
		var name_label = Label.new()
		name_label.text = "Player %d" % player_index
		name_label.custom_minimum_size.x = 100
		player_container.add_child(name_label)
		
		# Score
		var score_label = Label.new()
		score_label.text = _format_score(player_score)
		score_label.custom_minimum_size.x = 120
		player_container.add_child(score_label)
		
		# Status
		var status_label = Label.new()
		if is_qualifying:
			status_label.text = "🏆 HIGH SCORE!"
			status_label.modulate = Color.GOLD
		else:
			status_label.text = "Good game!"
			status_label.modulate = Color.LIGHT_GRAY
		player_container.add_child(status_label)
		
		score_summary_container.add_child(player_container)

func _process_next_player():
	"""Process the next qualifying player for name entry"""
	current_player_index = score_manager.get_next_qualifying_player()
	
	if current_player_index == -1:
		# No more players to process
		_show_final_summary()
		return
	
	# Show current player container
	current_player_container.show()
	final_summary_container.hide()
	
	# Get player data
	var player_data = score_manager.get_player_high_score_data(current_player_index)
	var player_score = player_data.score
	var player_rank = player_data.rank
	var is_personal_best = player_data.is_personal_best
	
	# Update UI for current player
	current_player_label.text = "Player %d achieved a high score!" % current_player_index
	score_label.text = "Score: %s" % _format_score(player_score)
	
	if is_personal_best:
		rank_label.text = "🌟 NEW PERSONAL BEST! 🌟 (Rank #%d)" % player_rank
		rank_label.modulate = Color.GOLD
	else:
		rank_label.text = "Rank: #%d" % player_rank
		rank_label.modulate = Color.WHITE
	
	# Update progress
	var remaining_count = score_manager.get_remaining_qualifying_players().size()
	progress_label.text = "(%d of %d qualifying players)" % (remaining_players.size() - remaining_count + 1, remaining_players.size())
	
	# Setup name entry
	name_entry.text = ""
	name_entry.grab_focus()
	
	# Connect signals for real-time validation
	if not name_entry.is_connected("text_changed", _on_name_text_changed):
		name_entry.connect("text_changed", _on_name_text_changed)
	if not name_entry.is_connected("text_submitted", _on_name_submitted):
		name_entry.connect("text_submitted", _on_name_submitted)
	if not submit_button.is_connected("pressed", _on_submit_pressed):
		submit_button.connect("pressed", _on_submit_pressed)
	if not skip_button.is_connected("pressed", _on_skip_pressed):
		skip_button.connect("pressed", _on_skip_pressed)
	
	# Initial validation state
	_update_validation_display("")

func _show_final_summary():
	"""Show final summary of all high score submissions"""
	current_player_container.hide()
	final_summary_container.show()
	
	# Clear existing final scores
	for child in final_scores_list.get_children():
		child.queue_free()
	
	# Add title
	var title_label = Label.new()
	title_label.text = "🎉 Session Complete! 🎉"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_scores_list.add_child(title_label)
	
	# Get session summary
	var summary = score_manager.get_multi_player_session_summary()
	
	if summary.session_high_scores.size() > 0:
		var subtitle_label = Label.new()
		subtitle_label.text = "New High Scores Added:"
		subtitle_label.add_theme_font_size_override("font_size", 16)
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle_label.modulate = Color.GOLD
		final_scores_list.add_child(subtitle_label)
		
		# Sort session high scores by rank
		summary.session_high_scores.sort_custom(func(a, b): return a.rank < b.rank)
		
		for entry in summary.session_high_scores:
			var entry_container = HBoxContainer.new()
			
			var rank_label = Label.new()
			rank_label.text = "#%d" % entry.rank
			rank_label.custom_minimum_size.x = 40
			entry_container.add_child(rank_label)
			
			var name_label = Label.new()
			name_label.text = entry.name
			name_label.custom_minimum_size.x = 150
			entry_container.add_child(name_label)
			
			var score_label = Label.new()
			score_label.text = _format_score(entry.score)
			score_label.custom_minimum_size.x = 120
			entry_container.add_child(score_label)
			
			final_scores_list.add_child(entry_container)
	else:
		var no_scores_label = Label.new()
		no_scores_label.text = "No new high scores this session."
		no_scores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_scores_label.modulate = Color.LIGHT_GRAY
		final_scores_list.add_child(no_scores_label)
	
	# Show encouragement message
	var encouragement_label = Label.new()
	encouragement_label.text = "Thanks for playing! Try again to beat your scores!"
	encouragement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encouragement_label.modulate = Color.CYAN
	final_scores_list.add_child(encouragement_label)

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
		_submit_current_player_score()

func _on_submit_pressed():
	"""Handle submit button press"""
	_submit_current_player_score()

func _on_skip_pressed():
	"""Handle skip button press - submit with default name"""
	name_entry.text = ""
	_submit_current_player_score()

func _submit_current_player_score():
	"""Submit the current player's high score"""
	var player_name = name_entry.text.strip_edges()
	
	# Use default name if empty
	if player_name.is_empty():
		player_name = "Player %d" % current_player_index
	
	# Submit to score manager using multi-player method
	var result = score_manager.submit_multi_player_high_score(current_player_index, player_name)
	
	if result.success:
		_show_submission_success(player_name, result.rank)
		# Process next player after a short delay
		await get_tree().create_timer(2.0).timeout
		_process_next_player()
	else:
		_show_submission_error("Failed to save high score. Please try again.")

func _show_submission_success(player_name: String, rank: int):
	"""Show success message for current submission"""
	validation_message.text = "✅ High Score Saved! %s ranked #%d" % [player_name, rank]
	validation_message.modulate = Color.GREEN
	
	# Show success notification through ScoreManager
	if score_manager.has_method("show_high_score_feedback"):
		var success_message = "✅ Player %d High Score Saved!\n%s ranked #%d" % [current_player_index, player_name, rank]
		score_manager.show_high_score_feedback(success_message, "success")
	
	# Disable input during transition
	name_entry.editable = false
	submit_button.disabled = true
	skip_button.disabled = true

func _show_submission_error(error_message: String):
	"""Show error message for current submission"""
	validation_message.text = "❌ " + error_message
	validation_message.modulate = Color.RED
	
	# Show error notification through ScoreManager
	if score_manager.has_method("show_high_score_feedback"):
		score_manager.show_high_score_feedback("❌ " + error_message, "error")
	
	# Flash the validation message
	var tween = create_tween()
	tween.tween_property(validation_message, "modulate", Color.WHITE, 0.5)
	tween.tween_delay(2.0)
	tween.tween_property(validation_message, "modulate", Color.RED, 0.5)

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

func _on_restart_pressed():
	emit_signal("restart")

func _on_main_menu_pressed():
	emit_signal("main_menu")