extends Control
class_name HighScoreDisplay

# UI References
@onready var score_list: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var placeholder_label: Label = $PlaceholderLabel
@onready var title_label: Label = $TitleLabel

# Configuration
var max_visible_scores: int = 10
var show_rank_numbers: bool = true
var show_dates: bool = true
var highlight_current_session: bool = true
var animate_updates: bool = true

# Score entry scene for dynamic creation
var score_entry_scene: PackedScene

# Current session tracking
var current_session_scores: Array[Dictionary] = []

signal back_pressed()

func _ready():
	# Load the score entry scene
	score_entry_scene = preload("res://scenes/ui/high_score_entry.tscn")
	
	# Set up initial UI
	_setup_ui()
	
	# Connect to ScoreManager signals
	var score_manager = get_node("/root/ScoreManager")
	if score_manager:
		score_manager.high_score_saved.connect(_on_high_score_saved)
		score_manager.high_score_changed.connect(_on_high_score_changed)
	
	# Load and display high scores
	refresh_display()

func _setup_ui():
	"""Initialize UI components and styling"""
	# Set up title
	if title_label:
		title_label.text = "HIGH SCORES"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Set up placeholder
	if placeholder_label:
		placeholder_label.text = "No high scores yet!\nPlay the game to set your first high score."
		placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder_label.visible = false
	
	# Set up scroll container
	if scroll_container:
		scroll_container.scroll_horizontal_enabled = false

func refresh_display():
	"""Refresh the high score display with current data"""
	var score_manager = get_node("/root/ScoreManager")
	if not score_manager:
		_show_placeholder("Score Manager not available")
		return
	
	var formatted_scores = score_manager.get_formatted_high_scores()
	
	if formatted_scores.is_empty():
		_show_placeholder("No high scores yet!\nPlay the game to set your first high score.")
		return
	
	_hide_placeholder()
	_populate_score_list(formatted_scores)

func _show_placeholder(message: String = ""):
	"""Show placeholder text when no scores are available"""
	if placeholder_label:
		if message != "":
			placeholder_label.text = message
		placeholder_label.visible = true
	
	if scroll_container:
		scroll_container.visible = false

func _hide_placeholder():
	"""Hide placeholder and show score list"""
	if placeholder_label:
		placeholder_label.visible = false
	
	if scroll_container:
		scroll_container.visible = true

func _populate_score_list(formatted_scores: Array[Dictionary]):
	"""Populate the score list with formatted score entries"""
	# Clear existing entries
	_clear_score_list()
	
	# Limit to max visible scores
	var scores_to_show = formatted_scores.slice(0, min(formatted_scores.size(), max_visible_scores))
	
	# Create score entry for each score
	for score_data in scores_to_show:
		var entry = _create_score_entry(score_data)
		if entry:
			score_list.add_child(entry)
			
			# Add animation if enabled
			if animate_updates:
				_animate_entry_appearance(entry)

func _clear_score_list():
	"""Clear all score entries from the list"""
	if not score_list:
		return
	
	for child in score_list.get_children():
		child.queue_free()

func _create_score_entry(score_data: Dictionary) -> Control:
	"""Create a single score entry UI element"""
	if not score_entry_scene:
		# Fallback: create simple label if scene not available
		return _create_simple_score_entry(score_data)
	
	var entry = score_entry_scene.instantiate()
	if entry.has_method("setup_entry"):
		entry.setup_entry(score_data, show_rank_numbers, show_dates, highlight_current_session)
	
	return entry

func _create_simple_score_entry(score_data: Dictionary) -> Control:
	"""Create a simple score entry as fallback"""
	var container = HBoxContainer.new()
	container.custom_minimum_size.y = 40
	
	# Rank
	if show_rank_numbers:
		var rank_label = Label.new()
		rank_label.text = str(score_data.rank) + "."
		rank_label.custom_minimum_size.x = 40
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		container.add_child(rank_label)
	
	# Name
	var name_label = Label.new()
	name_label.text = score_data.name
	name_label.custom_minimum_size.x = 200
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Highlight current session scores
	if highlight_current_session and score_data.get("is_current_session", false):
		name_label.modulate = Color.YELLOW
		name_label.text = "★ " + name_label.text
	
	container.add_child(name_label)
	
	# Score
	var score_label = Label.new()
	score_label.text = score_data.formatted_score
	score_label.custom_minimum_size.x = 120
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(score_label)
	
	# Date
	if show_dates and score_data.has("date"):
		var date_label = Label.new()
		date_label.text = _format_date_display(score_data.date)
		date_label.custom_minimum_size.x = 100
		date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		date_label.modulate = Color(0.8, 0.8, 0.8)  # Slightly dimmed
		container.add_child(date_label)
	
	return container

func _format_date_display(date_string: String) -> String:
	"""Format date string for display"""
	if date_string == "" or date_string == "Unknown":
		return ""
	
	# Handle different date formats
	if date_string.contains("-"):
		var parts = date_string.split("-")
		if parts.size() >= 3:
			return "%s/%s/%s" % [parts[1], parts[2], parts[0].substr(2, 2)]
	
	return date_string

func _animate_entry_appearance(entry: Control):
	"""Animate the appearance of a new score entry"""
	if not animate_updates:
		return
	
	# Start invisible and small
	entry.modulate.a = 0.0
	entry.scale = Vector2(0.8, 0.8)
	
	# Animate to full visibility and size
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(entry, "modulate:a", 1.0, 0.3)
	tween.tween_property(entry, "scale", Vector2.ONE, 0.3)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

func set_display_options(options: Dictionary):
	"""Configure display options"""
	if options.has("max_visible_scores"):
		max_visible_scores = options.max_visible_scores
	
	if options.has("show_rank_numbers"):
		show_rank_numbers = options.show_rank_numbers
	
	if options.has("show_dates"):
		show_dates = options.show_dates
	
	if options.has("highlight_current_session"):
		highlight_current_session = options.highlight_current_session
	
	if options.has("animate_updates"):
		animate_updates = options.animate_updates
	
	# Refresh display with new options
	refresh_display()

func highlight_score_update(rank: int):
	"""Highlight a specific score entry (e.g., newly added)"""
	if not score_list or rank < 1:
		return
	
	var entry_index = rank - 1
	if entry_index >= score_list.get_child_count():
		return
	
	var entry = score_list.get_child(entry_index)
	if not entry:
		return
	
	# Create enhanced highlight animation with multiple effects
	var original_modulate = entry.modulate
	var original_scale = entry.scale
	
	# Multi-stage animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Pulsing color effect
	var color_tween = tween.tween_method(_animate_highlight_color.bind(entry, original_modulate), 0.0, 1.0, 2.0)
	color_tween.set_trans(Tween.TRANS_SINE)
	
	# Scale bounce effect
	tween.tween_property(entry, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(entry, "scale", original_scale, 0.3).set_delay(0.2)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Add sparkle effect if this is a top 3 score
	if rank <= 3:
		_add_sparkle_effect(entry)

func _animate_highlight_color(entry: Control, original_color: Color, progress: float):
	"""Animate the highlight color transition"""
	var highlight_color = Color.YELLOW
	if progress <= 0.5:
		# Fade to highlight color
		var t = progress * 2.0
		entry.modulate = original_color.lerp(highlight_color, t)
	else:
		# Fade back to original
		var t = (progress - 0.5) * 2.0
		entry.modulate = highlight_color.lerp(original_color, t)

func _add_sparkle_effect(entry: Control):
	"""Add sparkle particles for top scores"""
	# Create simple sparkle effect using labels
	for i in range(5):
		var sparkle = Label.new()
		sparkle.text = "✨"
		sparkle.modulate = Color(1, 1, 1, 0)
		sparkle.z_index = 10
		
		# Random position around the entry
		var offset = Vector2(randf_range(-50, 50), randf_range(-20, 20))
		sparkle.position = entry.position + offset
		
		entry.get_parent().add_child(sparkle)
		
		# Animate sparkle
		var sparkle_tween = create_tween()
		sparkle_tween.set_parallel(true)
		sparkle_tween.tween_property(sparkle, "modulate:a", 1.0, 0.3)
		sparkle_tween.tween_property(sparkle, "position", sparkle.position + Vector2(0, -30), 1.0)
		sparkle_tween.tween_property(sparkle, "modulate:a", 0.0, 0.5).set_delay(0.5)
		sparkle_tween.tween_callback(sparkle.queue_free).set_delay(1.0)

func scroll_to_rank(rank: int):
	"""Scroll to show a specific rank"""
	if not scroll_container or not score_list:
		return
	
	var entry_index = rank - 1
	if entry_index >= score_list.get_child_count():
		return
	
	var entry = score_list.get_child(entry_index)
	if not entry:
		return
	
	# Calculate scroll position
	var entry_position = entry.position.y
	var container_height = scroll_container.size.y
	var content_height = score_list.size.y
	
	if content_height > container_height:
		var scroll_ratio = entry_position / content_height
		var max_scroll = content_height - container_height
		scroll_container.scroll_vertical = int(scroll_ratio * max_scroll)

# Signal handlers
func _on_high_score_saved(player_name: String, score: int, rank: int):
	"""Handle new high score being saved"""
	refresh_display()
	
	# Highlight the new score
	if animate_updates:
		# Wait a frame for the display to update
		await get_tree().process_frame
		highlight_score_update(rank)
		scroll_to_rank(rank)

func _on_high_score_changed(new_high_score):
	"""Handle high score list changes"""
	refresh_display()

func animate_list_update(updated_scores: Array[Dictionary], new_entry_rank: int = -1):
	"""Animate the high score list update with smooth transitions"""
	if not animate_updates:
		refresh_display()
		return
	
	# Store current entries for comparison
	var old_entries = []
	for child in score_list.get_children():
		old_entries.append(child)
	
	# Create new entries off-screen
	var new_entries = []
	for score_data in updated_scores.slice(0, min(updated_scores.size(), max_visible_scores)):
		var entry = _create_score_entry(score_data)
		if entry:
			entry.modulate.a = 0.0
			entry.position.x = -300  # Start off-screen left
			new_entries.append(entry)
	
	# Animate transition
	_animate_list_transition(old_entries, new_entries, new_entry_rank)

func _animate_list_transition(old_entries: Array, new_entries: Array, highlight_rank: int):
	"""Animate the transition between old and new score lists"""
	var transition_duration = 0.5
	var stagger_delay = 0.1
	
	# Fade out old entries
	var fade_out_tween = create_tween()
	fade_out_tween.set_parallel(true)
	
	for i in range(old_entries.size()):
		var entry = old_entries[i]
		var delay = i * stagger_delay
		fade_out_tween.tween_property(entry, "modulate:a", 0.0, transition_duration).set_delay(delay)
		fade_out_tween.tween_property(entry, "position:x", 300, transition_duration).set_delay(delay)
	
	# Add new entries and fade them in
	await get_tree().create_timer(transition_duration + (old_entries.size() * stagger_delay)).timeout
	
	# Clear old entries
	for entry in old_entries:
		if is_instance_valid(entry):
			entry.queue_free()
	
	# Add and animate new entries
	var fade_in_tween = create_tween()
	fade_in_tween.set_parallel(true)
	
	for i in range(new_entries.size()):
		var entry = new_entries[i]
		score_list.add_child(entry)
		
		var delay = i * stagger_delay
		fade_in_tween.tween_property(entry, "modulate:a", 1.0, transition_duration).set_delay(delay)
		fade_in_tween.tween_property(entry, "position:x", 0, transition_duration).set_delay(delay)
		
		# Highlight the new entry if specified
		if highlight_rank > 0 and i == highlight_rank - 1:
			fade_in_tween.tween_callback(func(): highlight_score_update(highlight_rank)).set_delay(delay + transition_duration)

func show_score_comparison(old_score: int, new_score: int, player_name: String):
	"""Show a comparison animation between old and new scores"""
	# Create temporary comparison display
	var comparison_container = VBoxContainer.new()
	comparison_container.name = "ScoreComparison"
	add_child(comparison_container)
	
	# Position at center of screen
	comparison_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# Create comparison labels
	var title_label = Label.new()
	title_label.text = "Score Improvement!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	comparison_container.add_child(title_label)
	
	var old_score_label = Label.new()
	old_score_label.text = "Previous: %s" % _format_score_display(old_score)
	old_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	old_score_label.modulate = Color.GRAY
	comparison_container.add_child(old_score_label)
	
	var new_score_label = Label.new()
	new_score_label.text = "New Best: %s" % _format_score_display(new_score)
	new_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_score_label.modulate = Color.GREEN
	new_score_label.add_theme_font_size_override("font_size", 20)
	comparison_container.add_child(new_score_label)
	
	var improvement = new_score - old_score
	var improvement_label = Label.new()
	improvement_label.text = "Improvement: +%s" % _format_score_display(improvement)
	improvement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	improvement_label.modulate = Color.YELLOW
	comparison_container.add_child(improvement_label)
	
	# Animate the comparison display
	comparison_container.modulate.a = 0.0
	comparison_container.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(comparison_container, "modulate:a", 1.0, 0.5)
	tween.tween_property(comparison_container, "scale", Vector2.ONE, 0.5)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	# Auto-dismiss after delay
	tween.tween_callback(func():
		var dismiss_tween = create_tween()
		dismiss_tween.set_parallel(true)
		dismiss_tween.tween_property(comparison_container, "modulate:a", 0.0, 0.3)
		dismiss_tween.tween_property(comparison_container, "scale", Vector2(0.8, 0.8), 0.3)
		dismiss_tween.tween_callback(comparison_container.queue_free).set_delay(0.3)
	).set_delay(3.0)

func _format_score_display(score: int) -> String:
	"""Format score for display with thousands separators"""
	return _format_score(score) if has_method("_format_score") else str(score)

func _input(event):
	"""Handle input for navigation"""
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		emit_signal("back_pressed")
		accept_event()

func _on_back_button_pressed():
	"""Handle back button press"""
	emit_signal("back_pressed")