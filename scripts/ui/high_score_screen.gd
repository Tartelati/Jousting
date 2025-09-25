extends Control
class_name HighScoreScreen

# UI References
@onready var high_score_display: HighScoreDisplay = $HighScoreDisplay

signal back_to_main_menu()

func _ready():
	# Connect the back signal from the display
	if high_score_display:
		high_score_display.back_pressed.connect(_on_back_pressed)
	
	# Configure display options
	_configure_display()

func _configure_display():
	"""Configure the high score display with appropriate settings"""
	if not high_score_display:
		return
	
	var display_options = {
		"max_visible_scores": 10,
		"show_rank_numbers": true,
		"show_dates": true,
		"highlight_current_session": true,
		"animate_updates": true
	}
	
	high_score_display.set_display_options(display_options)

func refresh_scores():
	"""Refresh the high score display"""
	if high_score_display:
		high_score_display.refresh_display()

func _on_back_pressed():
	"""Handle back navigation"""
	emit_signal("back_to_main_menu")

func _input(event):
	"""Handle input for screen-level navigation"""
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		accept_event()