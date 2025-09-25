extends TestBase

# Test class for NotificationSystem (standalone version)
class_name TestNotificationSystem

var notification_system: NotificationSystem
var test_scene: Node

func before_each():
	super.before_each()
	# Create test scene
	test_scene = Node.new()
	add_child(test_scene)
	
	# Create notification system
	notification_system = preload("res://scripts/ui/notification_system.gd").new()
	notification_system.name = "TestNotificationSystem"
	test_scene.add_child(notification_system)
	
	# Wait for ready
	await get_tree().process_frame

func after_each():
	if test_scene:
		test_scene.queue_free()
	notification_system = null
	super.after_each()

func test_notification_system_initialization():
	"""Test that notification system initializes correctly"""
	assert_not_null(notification_system, "Notification system should be created")
	assert_not_null(notification_system.notification_container, "Notification container should exist")
	assert_eq(notification_system.active_notifications.size(), 0, "Should start with no active notifications")

func test_show_success_notification():
	"""Test showing success notifications"""
	var message = "Test success message"
	var notification_id = notification_system.show_success(message)
	
	assert_ne(notification_id, "", "Should return valid notification ID")
	assert_eq(notification_system.active_notifications.size(), 1, "Should have one active notification")
	
	# Check notification content
	var notification = notification_system.active_notifications[0]
	assert_not_null(notification, "Notification should exist")
	assert_eq(notification.get_meta("notification_id"), notification_id, "Notification should have correct ID")

func test_show_error_notification():
	"""Test showing error notifications"""
	var message = "Test error message"
	var notification_id = notification_system.show_error(message)
	
	assert_ne(notification_id, "", "Should return valid notification ID")
	assert_eq(notification_system.active_notifications.size(), 1, "Should have one active notification")

func test_show_personal_best_notification():
	"""Test showing personal best notifications"""
	var message = "New personal best!"
	var notification_id = notification_system.show_personal_best(message)
	
	assert_ne(notification_id, "", "Should return valid notification ID")
	assert_eq(notification_system.active_notifications.size(), 1, "Should have one active notification")

func test_multiple_notifications():
	"""Test showing multiple notifications"""
	var id1 = notification_system.show_success("Message 1")
	var id2 = notification_system.show_error("Message 2")
	var id3 = notification_system.show_info("Message 3")
	
	assert_eq(notification_system.active_notifications.size(), 3, "Should have three active notifications")
	assert_ne(id1, id2, "Notification IDs should be unique")
	assert_ne(id2, id3, "Notification IDs should be unique")

func test_notification_limit():
	"""Test that notification limit is enforced"""
	notification_system.set_max_notifications(2)
	
	# Add more notifications than the limit
	notification_system.show_success("Message 1")
	notification_system.show_success("Message 2")
	notification_system.show_success("Message 3")  # Should remove oldest
	
	assert_eq(notification_system.active_notifications.size(), 2, "Should enforce notification limit")

func test_dismiss_notification():
	"""Test dismissing specific notifications"""
	var id1 = notification_system.show_success("Message 1")
	var id2 = notification_system.show_success("Message 2")
	
	assert_eq(notification_system.active_notifications.size(), 2, "Should have two notifications")
	
	notification_system.dismiss_notification(id1)
	
	# Wait for animation to complete
	await get_tree().create_timer(0.5).timeout
	
	assert_eq(notification_system.active_notifications.size(), 1, "Should have one notification after dismissal")

func test_dismiss_all_notifications():
	"""Test dismissing all notifications"""
	notification_system.show_success("Message 1")
	notification_system.show_error("Message 2")
	notification_system.show_info("Message 3")
	
	assert_eq(notification_system.active_notifications.size(), 3, "Should have three notifications")
	
	notification_system.dismiss_all_notifications()
	
	# Wait for animations to complete
	await get_tree().create_timer(0.5).timeout
	
	assert_eq(notification_system.active_notifications.size(), 0, "Should have no notifications after dismiss all")

func test_auto_dismiss():
	"""Test automatic dismissal of notifications"""
	var notification_id = notification_system.show_success("Auto dismiss test", 0.2)  # Very short duration
	
	assert_eq(notification_system.active_notifications.size(), 1, "Should have one notification")
	
	# Wait for auto-dismiss
	await get_tree().create_timer(0.5).timeout
	
	assert_eq(notification_system.active_notifications.size(), 0, "Notification should be auto-dismissed")

func test_notification_id_generation():
	"""Test that notification IDs are unique"""
	var ids = []
	for i in range(10):
		var id = notification_system.show_success("Message %d" % i)
		assert_false(id in ids, "Notification ID should be unique")
		ids.append(id)

func test_configuration_methods():
	"""Test notification system configuration"""
	# Test max notifications
	notification_system.set_max_notifications(5)
	assert_eq(notification_system.max_notifications, 5, "Should update max notifications")
	
	# Test default duration
	notification_system.set_default_duration(2.5)
	assert_eq(notification_system.default_duration, 2.5, "Should update default duration")
	
	# Test animation duration
	notification_system.set_animation_duration(0.5)
	assert_eq(notification_system.animation_duration, 0.5, "Should update animation duration")

func test_notification_signals():
	"""Test that notification signals are emitted correctly"""
	var signal_received = false
	var received_id = ""
	
	notification_system.notification_dismissed.connect(func(id): 
		signal_received = true
		received_id = id
	)
	
	var notification_id = notification_system.show_success("Test signal", 0.1)
	
	# Wait for auto-dismiss
	await get_tree().create_timer(0.3).timeout
	
	assert_true(signal_received, "Should emit notification_dismissed signal")
	assert_eq(received_id, notification_id, "Should emit correct notification ID")

func test_find_notification_by_id():
	"""Test finding notifications by ID"""
	var id1 = notification_system.show_success("Message 1")
	var id2 = notification_system.show_error("Message 2")
	
	var notification1 = notification_system._find_notification_by_id(id1)
	var notification2 = notification_system._find_notification_by_id(id2)
	var notification_invalid = notification_system._find_notification_by_id("invalid_id")
	
	assert_not_null(notification1, "Should find notification by valid ID")
	assert_not_null(notification2, "Should find notification by valid ID")
	assert_null(notification_invalid, "Should return null for invalid ID")

func test_notification_types():
	"""Test different notification types are handled correctly"""
	var success_id = notification_system.show_notification("Success", NotificationSystem.NotificationType.SUCCESS)
	var error_id = notification_system.show_notification("Error", NotificationSystem.NotificationType.ERROR)
	var info_id = notification_system.show_notification("Info", NotificationSystem.NotificationType.INFO)
	var pb_id = notification_system.show_notification("Personal Best", NotificationSystem.NotificationType.PERSONAL_BEST)
	
	assert_ne(success_id, "", "Success notification should be created")
	assert_ne(error_id, "", "Error notification should be created")
	assert_ne(info_id, "", "Info notification should be created")
	assert_ne(pb_id, "", "Personal best notification should be created")
	
	assert_eq(notification_system.active_notifications.size(), 4, "Should have four notifications of different types")
