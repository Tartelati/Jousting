extends Control

# Dictionaries to hold references for each player's HUD elements
var score_labels := {}
var lives_containers := {}
var life_indicators := {}
var power_indicators := {}
var power_bars := {}
var power_icons := {}

@onready var wave_label = $MarginContainer/VBoxContainer/TopRow/WaveLabel

func _ready():
	# Dynamically find all player HUD containers (assumes naming convention: P1HudLives, P2HudLives, etc.)
	for i in range(1, 5): # Supports up to 4 players
		var lives_path = "P%dHudLives/LivesContainer" % i
		var score_path = "P%dHudScore/ScoreLabel" % i
		var power_path = "PowerIndicators/P%dPowerIndicator" % i
		
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
		if has_node(power_path):
			power_indicators[i] = get_node(power_path)
			power_bars[i] = get_node(power_path + "/PowerContainer/PowerBar")
			power_icons[i] = get_node(power_path + "/PowerContainer/PowerIcon")

	# Connect to ScoreManager signals
	ScoreManager.connect("score_changed", _on_score_changed)
	ScoreManager.connect("lives_changed", _on_lives_changed)
	ScoreManager.connect("bonus_awarded", _on_bonus_awarded)  # NEW
	
	# Connect to PowerManager signals
	_connect_power_manager_signals()

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

func _connect_power_manager_signals():
	"""Connect to PowerManager signals for power UI updates"""
	var power_manager = get_node_or_null("/root/PowerManager")
	if power_manager:
		if not power_manager.is_connected("power_activated", _on_power_activated):
			power_manager.connect("power_activated", _on_power_activated)
		if not power_manager.is_connected("power_expired", _on_power_expired):
			power_manager.connect("power_expired", _on_power_expired)
		if not power_manager.is_connected("power_warning", _on_power_warning):
			power_manager.connect("power_warning", _on_power_warning)

func show_power_indicator(player_index: int, power_type: int, duration: float):
	"""Show power indicator for a player"""
	if power_indicators.has(player_index):
		var indicator = power_indicators[player_index]
		var bar = power_bars[player_index]
		var icon = power_icons[player_index]
		
		indicator.visible = true
		bar.max_value = 100.0
		bar.value = 100.0
		
		# Get power manager for power-specific styling
		var power_manager = get_node_or_null("/root/PowerManager")
		if power_manager:
			# Set power-specific icon texture
			var icon_texture = power_manager.get_power_icon_texture(power_type)
			if icon_texture:
				icon.texture = icon_texture
			
			# Set power-specific colors
			var power_color = power_manager.get_power_color(power_type)
			icon.modulate = power_color
			bar.modulate = power_color
			
			# Add power type label
			_update_power_type_display(player_index, power_type)
		else:
			# Fallback styling
			match power_type:
				0: # INVINCIBILITY
					icon.modulate = Color(1.0, 0.8, 0.3)  # Golden
					bar.modulate = Color(1.0, 0.8, 0.3)
		
		# Start countdown animation
		_animate_power_duration(player_index, duration)
		
		# Show activation effect
		_show_power_activation_effect(player_index)

func hide_power_indicator(player_index: int):
	"""Hide power indicator for a player"""
	if power_indicators.has(player_index):
		var indicator = power_indicators[player_index]
		indicator.visible = false
		
		# Reset colors and textures
		if power_bars.has(player_index):
			power_bars[player_index].modulate = Color.WHITE
		if power_icons.has(player_index):
			power_icons[player_index].modulate = Color.WHITE
			# Reset to default icon
			var default_icon = load("res://assets/sprites/life.png")
			if default_icon:
				power_icons[player_index].texture = default_icon
		
		# Clear any power type display
		_clear_power_type_display(player_index)

func _animate_power_duration(player_index: int, duration: float):
	"""Animate the power duration bar countdown"""
	if not power_bars.has(player_index):
		return
	
	var bar = power_bars[player_index]
	var tween = create_tween()
	tween.tween_property(bar, "value", 0.0, duration)
	
	# Store tween reference for warning effects
	bar.set_meta("duration_tween", tween)

func _show_power_warning(player_index: int):
	"""Show warning effects when power is about to expire"""
	if not power_indicators.has(player_index):
		return
	
	var indicator = power_indicators[player_index]
	var bar = power_bars[player_index]
	
	# Create flashing warning effect
	var warning_tween = create_tween()
	warning_tween.set_loops(6)  # Flash 3 times (6 half-cycles)
	warning_tween.tween_property(indicator, "modulate:a", 0.3, 0.25)
	warning_tween.tween_property(indicator, "modulate:a", 1.0, 0.25)
	
	# Change bar color to red for warning
	bar.modulate = Color(1.0, 0.3, 0.3)

# Power Manager signal handlers
func _on_power_activated(player_index: int, power_type: int, duration: float):
	"""Handle power activation signal"""
	show_power_indicator(player_index, power_type, duration)

func _on_power_expired(player_index: int, _power_type: int):
	"""Handle power expiration signal"""
	hide_power_indicator(player_index)

func _on_power_warning(player_index: int, _power_type: int, _remaining_time: float):
	"""Handle power warning signal"""
	_show_power_warning(player_index)

# NEW: Handle bonus events
func _on_bonus_awarded(player_index: int, bonus_amount: int, _bonus_type: String, world_position: Vector2 = Vector2.ZERO):
	show_bonus_text(player_index, bonus_amount, world_position)

func _update_power_type_display(player_index: int, power_type: int):
	"""Update power type display with name/icon"""
	if not power_indicators.has(player_index):
		return
	
	var indicator = power_indicators[player_index]
	var power_container = indicator.get_node_or_null("PowerContainer")
	if not power_container:
		return
	
	# Add or update power type label
	var type_label = power_container.get_node_or_null("PowerTypeLabel")
	if not type_label:
		type_label = Label.new()
		type_label.name = "PowerTypeLabel"
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_font_size_override("font_size", 10)
		power_container.add_child(type_label)
		power_container.move_child(type_label, 0)  # Move to top
	
	# Set power type text
	var power_manager = get_node_or_null("/root/PowerManager")
	if power_manager and power_manager.has_method("_get_power_name"):
		type_label.text = power_manager._get_power_name(power_type)
	else:
		match power_type:
			0: # INVINCIBILITY
				type_label.text = "INVINCIBILITY"
			_:
				type_label.text = "POWER"

func _clear_power_type_display(player_index: int):
	"""Clear power type display"""
	if not power_indicators.has(player_index):
		return
	
	var indicator = power_indicators[player_index]
	var power_container = indicator.get_node_or_null("PowerContainer")
	if not power_container:
		return
	
	var type_label = power_container.get_node_or_null("PowerTypeLabel")
	if type_label:
		type_label.queue_free()

func _show_power_activation_effect(player_index: int):
	"""Show visual effect when power is activated"""
	if not power_indicators.has(player_index):
		return
	
	var indicator = power_indicators[player_index]
	
	# Create brief flash effect
	var flash_tween = create_tween()
	flash_tween.tween_property(indicator, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	flash_tween.tween_property(indicator, "modulate", Color.WHITE, 0.2)
	
	# Create scale pulse effect
	var scale_tween = create_tween()
	scale_tween.tween_property(indicator, "scale", Vector2(1.2, 1.2), 0.15)
	scale_tween.tween_property(indicator, "scale", Vector2(1.0, 1.0), 0.15)

func get_power_status_for_player(player_index: int) -> Dictionary:
	"""Get current power status for a player"""
	var power_manager = get_node_or_null("/root/PowerManager")
	if not power_manager:
		return {"active": false}
	
	if power_manager.is_power_active(player_index):
		return {
			"active": true,
			"type": power_manager.get_active_power_type(player_index),
			"remaining_time": power_manager.get_remaining_duration(player_index)
		}
	else:
		return {"active": false}

func update_all_power_indicators():
	"""Update all power indicators based on current power states"""
	for player_index in range(1, 5):
		var status = get_power_status_for_player(player_index)
		if status.active:
			show_power_indicator(player_index, status.type, status.remaining_time)
		else:
			hide_power_indicator(player_index)
