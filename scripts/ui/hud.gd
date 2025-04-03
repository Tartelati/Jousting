extends Control

@onready var score_label = $MarginContainer/VBoxContainer/TopRow/ScoreLabel
@onready var wave_label = $MarginContainer/VBoxContainer/TopRow/WaveLabel
@onready var lives_container = $MarginContainer/VBoxContainer/TopRow/LivesContainer

# Life indicator references
var life_indicators = []

func _ready():
	# Connect to score manager signals
	get_node("/root/ScoreManager").connect("score_changed", _on_score_changed)
	get_node("/root/ScoreManager").connect("lives_changed", _on_lives_changed)
	# ScoreManager is an autoload, so we can access it directly: ScoreManager.connect(...)
	# ScoreManager.connect("score_changed", _on_score_changed)
	# ScoreManager.connect("lives_changed", _on_lives_changed)
	
	# Don't connect to WaveManager here. GameManager will provide the reference.
	
	# Update initial values using direct access to autoload
	_on_score_changed(ScoreManager.score)
	_on_lives_changed(get_node("/root/ScoreManager").lives)
	
	# Find all life indicators
	for child in lives_container.get_children():
		if child is TextureRect:
			life_indicators.append(child)
	
	# Sort them by name to ensure correct order
	life_indicators.sort_custom(func(a, b): return a.name < b.name)

func setup_wave_manager_connection(wave_manager_node):
	if wave_manager_node and wave_manager_node.has_signal("wave_started"):
		if not wave_manager_node.is_connected("wave_started", _on_wave_started):
			wave_manager_node.connect("wave_started", _on_wave_started)
		# Optionally update initial wave display if needed, assuming wave_manager has current wave info
		# _on_wave_started(wave_manager_node.current_wave_number) 
	else:
		printerr("HUD: Invalid WaveManager node provided or signal missing.")

func _on_score_changed(new_score):
	score_label.text = "Score: " + str(new_score)

func _on_lives_changed(new_lives):
	# Update life indicators
	for i in range(life_indicators.size()):
		if i < new_lives:
			life_indicators[i].visible = true
		else:
			life_indicators[i].visible = false

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
