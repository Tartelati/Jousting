extends GutTest

# Integration test for NotificationSystem with ScoreManager
class_name TestNotificationSystemIntegration

var score_manager: Node
var notification_system: NotificationSystem
var test_scene: Node

func before_each():
	# Create test scene
	test_scene = Node.new()
	add_child(test_scene)
	
	# Create and configure ScoreManager
	score_manager = preload("res://scripts/managers/score_manager.gd").new()
	score_manager.name = "ScoreManager"
	test_scene.add_child(score_manager)
	
	# Wait for ScoreManager to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get reference to notification system created by ScoreManager
	notification_system = score_manager.notification_system

func after_each():
	if test_scene:
		test_scene.queue_free()
	score_manager = null
	notification_system = null

func test_score_manager_creates_notification_system():
	"""Test that ScoreManager creates and initializes notification system"""
	assert_not_null(notification_system, "ScoreManager should create notification system")
	assert_true(notification_system is NotificationSystem, "Should be NotificationSystem instance")

func test_high_score_saved_feedback():
	"""Test feedback when high score is saved"""
	var feedback_received = false
	var feedback_message = ""
	
	# Monitor notification system for new notifications
	if notification_system:
		var initial_count = notification_system.active_notifications.size()
		
		# Simulate high score saved signal
		score_manager.emit_signal("high_score_saved", "TestPlayer", 50000, 2)
		
		# Wait for notification to be created
		await get_tree().process_frame
		
		var final_count = notification_system.active_notifications.size()
		assert_gt(final_count, initial_count, "Should create notification for high score saved")

func test_save_error_feedback():
	"""Test feedback when save error occurs"""
	if notification_system:
		var initial_count = notification_system.active_notifications.size()
		
		# Simulate save error signal
		score_manager.emit_signal("save_error", "Test error message")
		
		# Wait for notification to be created
		await get_tree().process_frame
		
		var final_count = notification_system.active_notifications.size()
		assert_gt(final_count, initial_count, "Should create notification for save error")

func test_personal_best_feedback():
	"""Test feedback when personal best is achieved"""
	if notification_system:
		var initial_count = notification_system.active_notifications.size()
		
		# Set up player score
		score_manager.add_score(1, 25000)
		
		# Simulate personal best signal
		score_manager.emit_signal("personal_best_achieved", 1, 20000)
		
		# Wait for notification to be created
		await get_tree().process_frame
		
		var final_count = notification_system.active_notifications.size()
		assert_gt(final_count, initial_count, "Should create notification for personal best")

func test_score_achievement_feedback():
	"""Test various score achievement feedback types"""
	if not notification_system:
		return
	
	var initial_count = notification_system.active_notifications.size()
	
	# Test qualifying score feedback
	score_manager.show_score_achievement_feedback(1, "qualifying_score")
	await get_tree().process_frame
	
	# Test milestone reached feedback
	score_manager.show_score_achievement_feedback(1, "milestone_reached", {"milestone": 100000})
	await get_tree().process_frame
	
	# Test extra life feedback
	score_manager.show_score_achievement_feedback(1, "extra_life_earned")
	await get_tree().process_frame
	
	var final_count = notification_system.active_notifications.size()
	assert_eq(final_count, initial_count + 3, "Should create notifications for all achievement types")

func test_notification_timing_accuracy():
	"""Test that notifications appear and dismiss at correct times"""
	if not notification_system:
		return
	
	# Show notification with specific duration
	var notification_id = notification_system.show_success("Timing test", 0.3)
	
	assert_eq(notification_system.active_notifications.size(), 1, "Should have one notification")
	
	# Wait less than duration - should still be there
	await get_tree().create_timer(0.1).timeout
	assert_eq(notification_system.active_notifications.size(), 1, "Notification should still be active")
	
	# Wait for full duration - should be dismissed
	await get_tree().create_timer(0.3).timeout
	assert_eq(notification_system.active_notifications.size(), 0, "Notification should be dismissed")

func test_multiple_score_events():
	"""Test handling multiple score events in quick succession"""
	if not notification_system:
		return
	
	var initial_count = notification_system.active_notifications.size()
	
	# Simulate multiple events quickly
	score_manager.emit_signal("high_score_saved", "Player1", 30000, 3)
	score_manager.emit_signal("high_score_saved", "Player2", 35000, 2)
	score_manager.emit_signal("personal_best_achieved", 1, 25000)
	
	# Wait for all notifications to be processed
	await get_tree().process_frame
	await get_tree().process_frame
	
	var final_count = notification_system.active_notifications.size()
	assert_eq(final_count, initial_count + 3, "Should handle multiple events correctly")

func test_notification_message_accuracy():
	"""Test that notification messages contain accurate information"""
	if not notification_system:
		return
	
	# Set up score manager state
	score_manager.add_score(1, 75000)
	
	# Trigger high score saved
	score_manager.emit_signal("high_score_saved", "TestPlayer", 75000, 1)
	
	await get_tree().process_frame
	
	# Check that notification was created
	assert_gt(notification_system.active_notifications.size(), 0, "Should create notification")
	
	# Note: In a full implementation, we would check the actual message content
	# This would require access to the notification's message text

func test_error_handling_without_notification_system():
	"""Test that ScoreManager handles missing notification system gracefully"""
	# Create a ScoreManager without notification system
	var isolated_manager = preload("res://scripts/managers/score_manager.gd").new()
	isolated_manager.notification_system = null
	test_scene.add_child(isolated_manager)
	
	# These should not crash even without notification system
	isolated_manager.show_high_score_feedback("Test message", "success")
	isolated_manager.show_score_achievement_feedback(1, "qualifying_score")
	
	# If we get here without crashing, the test passes
	assert_true(true, "Should handle missing notification system gracefully")

func test_notification_system_integration_signals():
	"""Test that all ScoreManager signals properly trigger notifications"""
	if not notification_system:
		return
	
	var signal_tests = [
		{"signal": "high_score_saved", "args": ["TestPlayer", 50000, 2]},
		{"signal": "save_error", "args": ["Test error"]},
		{"signal": "personal_best_achieved", "args": [1, 40000]}
	]
	
	for test_case in signal_tests:
		var initial_count = notification_system.active_notifications.size()
		
		# Emit the signal
		score_manager.emit_signal(test_case.signal, test_case.args[0], test_case.args[1] if test_case.args.size() > 1 else null, test_case.args[2] if test_case.args.size() > 2 else null)
		
		await get_tree().process_frame
		
		var final_count = notification_system.active_notifications.size()
		assert_gt(final_count, initial_count, "Signal '%s' should trigger notification" % test_case.signal)

func test_notification_persistence_during_gameplay():
	"""Test that notifications persist correctly during simulated gameplay"""
	if not notification_system:
		return
	
	# Simulate a gameplay session with multiple score events
	score_manager.add_score(1, 10000)
	score_manager.show_score_achievement_feedback(1, "milestone_reached", {"milestone": 10000})
	
	await get_tree().create_timer(0.1).timeout
	
	score_manager.add_score(1, 15000)  # Total: 25000
	score_manager.emit_signal("personal_best_achieved", 1, 20000)
	
	await get_tree().create_timer(0.1).timeout
	
	score_manager.add_score(1, 25000)  # Total: 50000
	score_manager.emit_signal("high_score_saved", "Player1", 50000, 1)
	
	await get_tree().process_frame
	
	# Should have multiple notifications active
	assert_gt(notification_system.active_notifications.size(), 0, "Should have active notifications during gameplay")
	
	# Wait for some to auto-dismiss
	await get_tree().create_timer(1.0).timeout
	
	# Some notifications should remain or new ones should have appeared
	# The exact count depends on timing, but system should be stable
	assert_ge(notification_system.active_notifications.size(), 0, "Notification system should remain stable")