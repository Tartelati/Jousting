extends PanelContainer
class_name NotificationToast

# UI References
@onready var panel: Panel = $Panel
@onready var icon_label: Label = $HBoxContainer/IconLabel
@onready var message_label: Label = $HBoxContainer/MessageLabel
@onready var close_button: Button = $HBoxContainer/CloseButton

# Notification types (duplicated to avoid circular dependency)
enum NotificationType {
	SUCCESS,
	ERROR,
	INFO,
	PERSONAL_BEST
}

# Properties
var notification_id: String = ""
var notification_type: NotificationType

signal dismiss_requested(notification_id: String)

func _ready():
	# Connect close button
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

func setup_notification(message: String, type: NotificationType, id: String):
	"""Set up the notification with the provided data"""
	notification_id = id
	notification_type = type
	set_meta("notification_id", id)
	
	# Set message
	if message_label:
		message_label.text = message
	
	# Set icon and styling based on type
	_apply_notification_style(type)

func _apply_notification_style(type: NotificationType):
	"""Apply styling based on notification type"""
	var style_box = StyleBoxFlat.new()
	var icon_text = "ℹ"
	
	match type:
		NotificationType.SUCCESS:
			style_box.bg_color = Color(0.2, 0.8, 0.2, 0.9)  # Green
			icon_text = "✓"
		NotificationType.ERROR:
			style_box.bg_color = Color(0.8, 0.2, 0.2, 0.9)  # Red
			icon_text = "✗"
		NotificationType.PERSONAL_BEST:
			style_box.bg_color = Color(1.0, 0.8, 0.0, 0.9)  # Gold
			icon_text = "★"
			# Add special effects for personal best
			_add_personal_best_effects()
		_:
			style_box.bg_color = Color(0.3, 0.3, 0.3, 0.9)  # Gray
			icon_text = "ℹ"
	
	# Apply corner radius and border
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.WHITE
	
	# Apply style
	if panel:
		panel.add_theme_stylebox_override("panel", style_box)
	
	# Set icon
	if icon_label:
		icon_label.text = icon_text

func _add_personal_best_effects():
	"""Add special visual effects for personal best notifications"""
	if not icon_label:
		return
	
	# Create pulsing animation for the star icon
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(icon_label, "modulate", Color(1.5, 1.5, 0.5), 0.5)
	tween.tween_property(icon_label, "modulate", Color.WHITE, 0.5)
	
	# Add scale animation
	var scale_tween = create_tween()
	scale_tween.set_loops()
	scale_tween.tween_property(icon_label, "scale", Vector2(1.2, 1.2), 0.5)
	scale_tween.tween_property(icon_label, "scale", Vector2.ONE, 0.5)

func _on_close_pressed():
	"""Handle close button press"""
	emit_signal("dismiss_requested", notification_id)