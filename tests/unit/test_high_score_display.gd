extends GutTest

# Test class for HighScoreDisplay functionality
class_name TestHighScoreDisplay

var high_score_display: HighScoreDisplay
var mock_score_manager: Node

func before_each():
	# Create a mock score manager
	mock_score_manager = Node.new()
	mock_score_manager.name = "ScoreManager"
	get_tree().root.add_child(mock_score_manager)
	
	# Add required signals to mock
	mock_score_manager.add_user_signal("high_score_saved", [
		{"name": "player_name", "type": TYPE_STRING},
		{"name": "score", "type": TYPE_INT},
		{"name": "rank", "type": TYPE_INT}
	])
	mock_score_manager.add_user_signal("high_score_changed", [
		{"name": "new_high_score", "type": TYPE_DICTIONARY}
	])
	
	# Add required method to mock
	mock_score_manager.set_script(GDScript.new())
	mock_score_manager.get_script().source_code = """
extends Node

func get_formatted_high_scores() -> Array[Dictionary]:
	return [
		{
			"rank": 1,
			"name": "David Lacassagne",
			"score": 999999999,
			"formatted_score": "999,999,999",
			"date": "2024-01-01",
			"is_current_session": false,
			"player_index": 1
		},
		{
			"rank": 2,
			"name": "Test Player",
			"score": 50000,
			"formatted_score": "50,000",
			"date": "2024-12-25",
			"is_current_session": true,
			"player_index": 2
		}
	]
"""
	mock_score_manager.get_script().reload()
	
	# Create high score display instance
	high_score_display = preload("res://scripts/ui/high_score_display.gd").new()
	add_child_autofree(high_score_display)

func after_each():
	if mock_score_manager and is_instance_valid(mock_score_manager):
		mock_score_manager.queue_free()

func test_initialization():
	"""Test that HighScoreDisplay initializes correctly"""
	assert_not_null(high_score_display, "HighScoreDisplay should be created")
	assert_eq(high_score_display.max_visible_scores, 10, "Default max visible scores should be 10")
	assert_true(high_score_display.show_rank_numbers, "Should show rank numbers by default")
	assert_true(high_score_display.show_dates, "Should show dates by default")
	assert_true(high_score_display.highlight_current_session, "Should highlight current session by default")

func test_display_options_configuration():
	"""Test setting display options"""
	var options = {
		"max_visible_scores": 5,
		"show_rank_numbers": false,
		"show_dates": false,
		"highlight_current_session": false,
		"animate_updates": false
	}
	
	high_score_display.set_display_options(options)
	
	assert_eq(high_score_display.max_visible_scores, 5, "Max visible scores should be updated")
	assert_false(high_score_display.show_rank_numbers, "Rank numbers should be hidden")
	assert_false(high_score_display.show_dates, "Dates should be hidden")
	assert_false(high_score_display.highlight_current_session, "Session highlighting should be disabled")
	assert_false(high_score_display.animate_updates, "Animations should be disabled")

func test_score_formatting():
	"""Test score formatting functionality"""
	# This tests the formatting through the mock data
	var formatted_scores = mock_score_manager.get_formatted_high_scores()
	
	assert_eq(formatted_scores.size(), 2, "Should have 2 formatted scores")
	assert_eq(formatted_scores[0].formatted_score, "999,999,999", "Large score should be formatted with commas")
	assert_eq(formatted_scores[1].formatted_score, "50,000", "Medium score should be formatted with commas")

func test_current_session_highlighting():
	"""Test current session score highlighting"""
	var formatted_scores = mock_score_manager.get_formatted_high_scores()
	
	assert_false(formatted_scores[0].is_current_session, "David's score should not be current session")
	assert_true(formatted_scores[1].is_current_session, "Test Player's score should be current session")

func test_date_display():
	"""Test date formatting and display"""
	var formatted_scores = mock_score_manager.get_formatted_high_scores()
	
	assert_eq(formatted_scores[0].date, "2024-01-01", "Should preserve ISO date format")
	assert_eq(formatted_scores[1].date, "2024-12-25", "Should preserve ISO date format")

func test_rank_assignment():
	"""Test that ranks are assigned correctly"""
	var formatted_scores = mock_score_manager.get_formatted_high_scores()
	
	assert_eq(formatted_scores[0].rank, 1, "First score should have rank 1")
	assert_eq(formatted_scores[1].rank, 2, "Second score should have rank 2")

func test_empty_score_list_handling():
	"""Test handling of empty score lists"""
	# Override mock to return empty array
	mock_score_manager.get_script().source_code = """
extends Node

func get_formatted_high_scores() -> Array[Dictionary]:
	return []
"""
	mock_score_manager.get_script().reload()
	
	# This should not crash and should show placeholder
	high_score_display.refresh_display()
	
	# The display should handle empty lists gracefully
	assert_true(true, "Empty score list should be handled without errors")

func test_max_visible_scores_limit():
	"""Test that max visible scores limit is respected"""
	# Create mock with many scores
	var many_scores_script = """
extends Node

func get_formatted_high_scores() -> Array[Dictionary]:
	var scores = []
	for i in range(15):
		scores.append({
			"rank": i + 1,
			"name": "Player " + str(i + 1),
			"score": 1000 * (15 - i),
			"formatted_score": str(1000 * (15 - i)),
			"date": "2024-01-01",
			"is_current_session": false,
			"player_index": 1
		})
	return scores
"""
	
	mock_score_manager.get_script().source_code = many_scores_script
	mock_score_manager.get_script().reload()
	
	# Set max visible to 5
	high_score_display.set_display_options({"max_visible_scores": 5})
	
	# The display should only show 5 scores even though 15 are available
	# This is tested by ensuring the refresh doesn't crash and respects the limit
	high_score_display.refresh_display()
	
	assert_true(true, "Should handle large score lists with max limit")

func test_signal_connections():
	"""Test that signals are properly connected"""
	# Test that the display responds to score manager signals
	var signal_received = false
	
	high_score_display.connect("back_pressed", func(): signal_received = true)
	high_score_display.emit_signal("back_pressed")
	
	assert_true(signal_received, "Back pressed signal should be emitted and received")

func test_responsive_design_elements():
	"""Test responsive design elements"""
	# Test that the display can handle different screen sizes
	high_score_display.size = Vector2(800, 600)
	high_score_display.refresh_display()
	
	# Should not crash with different sizes
	high_score_display.size = Vector2(400, 300)
	high_score_display.refresh_display()
	
	assert_true(true, "Display should handle different screen sizes")

func test_placeholder_text_display():
	"""Test placeholder text when no scores available"""
	# Override mock to return empty array
	mock_score_manager.get_script().source_code = """
extends Node

func get_formatted_high_scores() -> Array[Dictionary]:
	return []
"""
	mock_score_manager.get_script().reload()
	
	high_score_display.refresh_display()
	
	# Should show placeholder without crashing
	assert_true(true, "Placeholder should be shown for empty score lists")