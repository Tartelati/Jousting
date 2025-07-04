extends Control

# Dictionaries to hold references for each player's HUD elements
var score_labels := {}
var lives_containers := {}
var life_indicators := {}

@onready var wave_label = $MarginContainer/VBoxContainer/TopRow/WaveLabel

func _ready():
	# Dynamically find all player HUD containers (assumes naming convention: P1HudLives, P2HudLives, etc.)
	for i in range(1, 5): # Supports up to 4 players
		var lives_path = "P%dHudLives/LivesContainer" % i
		var score_path = "P%dHudScore/ScoreLabel" % i
		if has_node(lives_path):
			lives_containers[i] = get_node(lives_path)
			# Gather life indicators for this player
			life_indicators[i] = []
			for child in lives_containers[i].get_children():
				if child is TextureRect:
					life_indicators[i].append(child)
			life_indicators[i].sort_custom(func(a, b): return a.name < b.name)
		if has_node(score_path):
			score_labels[i] = get_node(score_path)

	# Connect to ScoreManager signals
	ScoreManager.connect("score_changed", _on_score_changed)
	ScoreManager.connect("lives_changed", _on_lives_changed)
	ScoreManager.connect("bonus_awarded", _on_bonus_awarded)  # NEW

	# Initialize HUD for all players (if ScoreManager supports per-player data)
	for i in score_labels.keys():
		_on_score_changed(i, ScoreManager.get_score(i))
	for i in life_indicators.keys():
		_on_lives_changed(i, ScoreManager.get_lives(i))


func show_player_hud(player_index: int):
	var lives_node_name = "P%dHudLives" % player_index
	var score_node_name = "P%dHudScore" % player_index
	if has_node(lives_node_name):
		get_node(lives_node_name).visible = true
	if has_node(score_node_name):
		get_node(score_node_name).visible = true

func update_lives(player_index: int, lives: int):
	if life_indicators.has(player_index):
		for i in range(life_indicators[player_index].size()):
			life_indicators[player_index][i].visible = i < lives

func update_score(player_index: int, score: int):
	if score_labels.has(player_index):
		score_labels[player_index].text = str(score)

func show_bonus_text(player_index: int, bonus_amount: int, world_position: Vector2 = Vector2.ZERO):
	# Create a temporary label to show bonus points
	var bonus_label = Label.new()
	bonus_label.text = "BONUS +%d!" % bonus_amount
	bonus_label.add_theme_color_override("font_color", Color.YELLOW)
	bonus_label.add_theme_font_size_override("font_size", 24)

	# Position the bonus text
	var screen_position: Vector2
	if world_position != Vector2.ZERO:
		# Convert world position to screen position
		var camera = get_viewport().get_camera_2d()
		if camera:
			screen_position = camera.to_screen_pos(world_position)
		else:
			# Fallback: assume no camera transformation
			screen_position = world_position
		
		# Adjust position to center the text
		screen_position.x -= bonus_label.get_theme_default_font().get_string_size(bonus_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, bonus_label.get_theme_font_size("font_size")).x / 2
		screen_position.y -= 20  # Offset upward from the egg position
	else:
		# Fallback position if no world position provided
		screen_position = Vector2(100, 100)
	
	bonus_label.position = screen_position
	add_child(bonus_label)
	
	# Animate the bonus text
	var tween = create_tween()
	tween.parallel().tween_property(bonus_label, "modulate:a", 0.0, 2.0)
	tween.parallel().tween_property(bonus_label, "position:y", bonus_label.position.y - 50, 2.0)
	tween.tween_callback(bonus_label.queue_free)

	print("[HUD] Showing bonus text for Player %d: +%d points at world pos %s" % [player_index, bonus_amount, world_position])


# Example signal handlers for per-player updates
func _on_score_changed(player_index: int, new_score: int):
	update_score(player_index, new_score)

func _on_lives_changed(player_index: int, new_lives: int):
	update_lives(player_index, new_lives)

func _on_wave_started(wave_number):
	wave_label.text = "Wave: " + str(wave_number)
	
	# Show wave notification
	var wave_notification = Label.new()
	wave_notification.text = "Wave " + str(wave_number)
	wave_notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_notification.add_theme_font_size_override("font_size", 48)
	wave_notification.modulate = Color(1, 1, 1, 0)  # Start transparent
	
	add_child(wave_notification)
	wave_notification.set_anchors_preset(Control.PRESET_CENTER)
	
	# Animate the notification
	var tween = create_tween()
	tween.tween_property(wave_notification, "modulate", Color(1, 1, 1, 1), 0.5)
	tween.tween_interval(1.0)
	tween.tween_property(wave_notification, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(wave_notification.queue_free)

# NEW: Handle bonus events
func _on_bonus_awarded(player_index: int, bonus_amount: int, bonus_type: String, world_position: Vector2 = Vector2.ZERO):
	show_bonus_text(player_index, bonus_amount, world_position)
