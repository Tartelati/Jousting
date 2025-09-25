extends Control
class_name NotificationSystem

# Notification types
enum NotificationType {
	SUCCESS,
	ERROR,
	INFO,
	PERSONAL_BEST
}

# UI References
@onready var notification_container: VBoxContainer = $NotificationContainer
@onready var notification_template: PackedScene = preload("res://scenes/ui/notification_toast.tscn")

# Configuration
var max_notifications: int = 5
var default_duration: float = 3.0
var animation_duration: float = 0.3
var notification_spacing: int = 10

# Active notifications tracking
var active_notifications: Array[Control] = []

signal notification_dismissed(notification_id: String)

func _ready():
	# Set up the notification container
	if not notification_container:
		notification_container = VBoxContainer.new()
		notification_container.name = "NotificationContainer"
		add_child(notification_container)
	
	# Position container at top-right of screen
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	notification_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	
	# Configure container
	notification_container.add_theme_constant_override("separation", notification_spacing)

func show_notification(message: String, type: NotificationType = NotificationType.INFO, duration: float = -1) -> String:
	"""Show a notification with the specified message and type"""
	if duration < 0:
		duration = default_duration
	
	# Generate unique ID
	var notification_id = _generate_notification_id()
	
	# Create notification
	var notification = _create_notification(message, type, notification_id)
	if not notification:
		return ""
	
	# Add to container
	notification_container.add_child(notification)
	active_notifications.append(notification)
	
	# Limit number of notifications
	_enforce_notification_limit()
	
	# Animate entrance
	_animate_notification_entrance(notification)
	
	# Set up auto-dismiss timer
	if duration > 0:
		_setup_auto_dismiss(notification, notification_id, duration)
	
	return notification_id

func show_success(message: String, duration: float = -1) -> String:
	"""Show a success notification"""
	return show_notification(message, NotificationType.SUCCESS, duration)

func show_error(message: String, duration: float = -1) -> String:
	"""Show an error notification"""
	return show_notification(message, NotificationType.ERROR, duration)

func show_info(message: String, duration: float = -1) -> String:
	"""Show an info notification"""
	return show_notification(message, NotificationType.INFO, duration)

func show_personal_best(message: String, duration: float = 5.0) -> String:
	"""Show a personal best achievement notification with special styling"""
	return show_notification(message, NotificationType.PERSONAL_BEST, duration)

func dismiss_notification(notification_id: String):
	"""Manually dismiss a specific notification"""
	var notification = _find_notification_by_id(notification_id)
	if notification:
		_dismiss_notification(notification, notification_id)

func dismiss_all_notifications():
	"""Dismiss all active notifications"""
	for notification in active_notifications.duplicate():
		var notification_id = notification.get_meta("notification_id", "")
		_dismiss_notification(notification, notification_id)

func _create_notification(message: String, type: NotificationType, notification_id: String) -> Control:
	"""Create a notification UI element"""
	# Try to use template scene first
	var notification: Control
	
	if notification_template:
		notification = notification_template.instantiate()
		if notification.has_method("setup_notification"):
			notification.setup_notification(message, type, notification_id)
			return notification
	
	# Fallback: create simple notification
	return _create_simple_notification(message, type, notification_id)

func _create_simple_notification(message: String, type: NotificationType, notification_id: String) -> Control:
	"""Create a simple notification as fallback"""
	var notification = PanelContainer.new()
	notification.set_meta("notification_id", notification_id)
	notification.custom_minimum_size = Vector2(300, 60)
	
	# Style based on type
	var style_box = StyleBoxFlat.new()
	match type:
		NotificationType.SUCCESS:
			style_box.bg_color = Color(0.2, 0.8, 0.2, 0.9)  # Green
		NotificationType.ERROR:
			style_box.bg_color = Color(0.8, 0.2, 0.2, 0.9)  # Red
		NotificationType.PERSONAL_BEST:
			style_box.bg_color = Color(1.0, 0.8, 0.0, 0.9)  # Gold
		_:
			style_box.bg_color = Color(0.3, 0.3, 0.3, 0.9)  # Gray
	
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.WHITE
	
	notification.add_theme_stylebox_override("panel", style_box)
	
	# Create content container
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	notification.add_child(hbox)
	
	# Add icon based on type
	var icon_label = Label.new()
	match type:
		NotificationType.SUCCESS:
			icon_label.text = "✓"
		NotificationType.ERROR:
			icon_label.text = "✗"
		NotificationType.PERSONAL_BEST:
			icon_label.text = "★"
		_:
			icon_label.text = "ℹ"
	
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)
	
	# Add message label
	var message_label = Label.new()
	message_label.text = message
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(message_label)
	
	# Add close button
	var close_button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.flat = true
	close_button.pressed.connect(func(): _dismiss_notification(notification, notification_id))
	hbox.add_child(close_button)
	
	return notification

func _generate_notification_id() -> String:
	"""Generate a unique notification ID"""
	return "notification_%d_%d" % [Time.get_unix_time_from_system(), randi()]

func _find_notification_by_id(notification_id: String) -> Control:
	"""Find a notification by its ID"""
	for notification in active_notifications:
		if notification.get_meta("notification_id", "") == notification_id:
			return notification
	return null

func _enforce_notification_limit():
	"""Remove oldest notifications if we exceed the limit"""
	while active_notifications.size() > max_notifications:
		var oldest = active_notifications[0]
		var oldest_id = oldest.get_meta("notification_id", "")
		_dismiss_notification(oldest, oldest_id)

func _animate_notification_entrance(notification: Control):
	"""Animate notification entrance"""
	# Start off-screen to the right
	notification.position.x = get_viewport().get_visible_rect().size.x
	notification.modulate.a = 0.0
	
	# Animate to final position
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "position:x", 0, animation_duration)
	tween.tween_property(notification, "modulate:a", 1.0, animation_duration)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

func _animate_notification_exit(notification: Control, callback: Callable):
	"""Animate notification exit"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "position:x", get_viewport().get_visible_rect().size.x, animation_duration)
	tween.tween_property(notification, "modulate:a", 0.0, animation_duration)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_callback(callback).set_delay(animation_duration)

func _setup_auto_dismiss(notification: Control, notification_id: String, duration: float):
	"""Set up automatic dismissal of notification"""
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func(): _dismiss_notification(notification, notification_id))
	notification.add_child(timer)
	timer.start()

func _dismiss_notification(notification: Control, notification_id: String):
	"""Dismiss a notification with animation"""
	if not notification or not is_instance_valid(notification):
		return
	
	# Remove from active list
	active_notifications.erase(notification)
	
	# Animate exit and then remove
	_animate_notification_exit(notification, func():
		if is_instance_valid(notification):
			notification.queue_free()
		emit_signal("notification_dismissed", notification_id)
	)

# Configuration methods
func set_max_notifications(count: int):
	"""Set maximum number of simultaneous notifications"""
	max_notifications = max(1, count)
	_enforce_notification_limit()

func set_default_duration(duration: float):
	"""Set default notification duration"""
	default_duration = max(0.5, duration)

func set_animation_duration(duration: float):
	"""Set notification animation duration"""
	animation_duration = max(0.1, duration)