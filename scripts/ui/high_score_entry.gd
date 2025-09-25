extends Control
class_name HighScoreEntry

# UI References
@onready var rank_label: Label = $HBoxContainer/RankLabel
@onready var name_label: Label = $HBoxContainer/NameLabel
@onready var score_label: Label = $HBoxContainer/ScoreLabel
@onready var date_label: Label = $HBoxContainer/DateLabel
@onready var session_indicator: Label = $HBoxContainer/SessionIndicator

# Entry data
var entry_data: Dictionary
var is_highlighted: bool = false

func setup_entry(data: Dictionary, show_rank: bool = true, show_date: bool = true, highlight_session: bool = true):
	"""Setup the entry with score data and display options"""
	entry_data = data
	
	# Setup rank
	if rank_label and show_rank:
		rank_label.text = str(data.get("rank", 1)) + "."
		rank_label.visible = true
	elif rank_label:
		rank_label.visible = false
	
	# Setup name
	if name_label:
		name_label.text = data.get("name", "Unknown")
		
		# Apply special styling for current session
		if highlight_session and data.get("is_current_session", false):
			name_label.modulate = Color.YELLOW
			is_highlighted = true
		else:
			name_label.modulate = Color.WHITE
			is_highlighted = false
	
	# Setup score
	if score_label:
		score_label.text = data.get("formatted_score", str(data.get("score", 0)))
	
	# Setup date
	if date_label and show_date:
		var date_text = _format_date_for_display(data.get("date", ""))
		date_label.text = date_text
		date_label.visible = date_text != ""
	elif date_label:
		date_label.visible = false
	
	# Setup session indicator
	if session_indicator:
		if highlight_session and data.get("is_current_session", false):
			session_indicator.text = "★"
			session_indicator.modulate = Color.YELLOW
			session_indicator.visible = true
		else:
			session_indicator.visible = false

func _format_date_for_display(date_string: String) -> String:
	"""Format date string for compact display"""
	if date_string == "" or date_string == "Unknown":
		return ""
	
	# Handle ISO date format (YYYY-MM-DD)
	if date_string.contains("-"):
		var parts = date_string.split("-")
		if parts.size() >= 3:
			var year = parts[0]
			var month = parts[1]
			var day = parts[2]
			
			# Return MM/DD/YY format
			return "%s/%s/%s" % [month, day, year.substr(2, 2)]
	
	# Handle other formats or return as-is
	return date_string

func highlight_entry():
	"""Temporarily highlight this entry"""
	if is_highlighted:
		return  # Already highlighted
	
	var original_modulate = modulate
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(self, "modulate", Color.CYAN, 0.3)
	tween.tween_property(self, "modulate", original_modulate, 0.3)

func set_rank_visibility(visible: bool):
	"""Show or hide the rank label"""
	if rank_label:
		rank_label.visible = visible

func set_date_visibility(visible: bool):
	"""Show or hide the date label"""
	if date_label:
		date_label.visible = visible

func get_entry_data() -> Dictionary:
	"""Get the entry data"""
	return entry_data

func is_current_session() -> bool:
	"""Check if this entry is from the current session"""
	return entry_data.get("is_current_session", false)