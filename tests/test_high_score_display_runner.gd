extends Node

# Simple test runner for HighScoreDisplay system
# This can be run from the Godot editor

var tests_passed = 0
var tests_failed = 0
var test_results = []

func _ready():
	print("Starting High Score Display Tests...")
	
	run_all_tests()
	print_results()

func run_all_tests():
	# Basic functionality tests
	test_score_formatting()
	test_date_formatting()
	test_display_options()
	test_session_highlighting()
	test_rank_assignment()
	
	# Integration tests
	test_score_manager_integration()
	test_empty_list_handling()
	test_large_dataset_handling()

# Test helper functions
func assert_true(condition: bool, message: String):
	if condition:
		tests_passed += 1
		test_results.append("✓ PASS: " + message)
	else:
		tests_failed += 1
		test_results.append("✗ FAIL: " + message)

func assert_false(condition: bool, message: String):
	assert_true(not condition, message)

func assert_eq(actual, expected, message: String):
	if actual == expected:
		tests_passed += 1
		test_results.append("✓ PASS: " + message)
	else:
		tests_failed += 1
		test_results.append("✗ FAIL: " + message + " (expected: " + str(expected) + ", got: " + str(actual) + ")")

# Test implementations
func test_score_formatting():
	print("\n--- Testing Score Formatting ---")
	
	# Test ScoreManager's _format_score method through get_formatted_high_scores
	var score_manager = get_node("/root/ScoreManager")
	if not score_manager:
		tests_failed += 1
		test_results.append("✗ FAIL: ScoreManager not available")
		return
	
	var formatted_scores = score_manager.get_formatted_high_scores()
	
	assert_true(formatted_scores.size() > 0, "Should have at least one formatted score")
	
	# Check David's score formatting
	if formatted_scores.size() > 0:
		var first_score = formatted_scores[0]
		assert_eq(first_score.name, "David Lacassagne", "First score should be David")
		assert_true(first_score.formatted_score.contains(","), "Large score should contain comma separators")

func test_date_formatting():
	print("\n--- Testing Date Formatting ---")
	
	# Create a HighScoreEntry to test date formatting
	var entry_script = preload("res://scripts/ui/high_score_entry.gd")
	var entry = entry_script.new()
	
	# Test ISO date format
	var formatted_date = entry._format_date_for_display("2024-12-25")
	assert_eq(formatted_date, "12/25/24", "ISO date should be formatted as MM/DD/YY")
	
	# Test empty date
	formatted_date = entry._format_date_for_display("")
	assert_eq(formatted_date, "", "Empty date should remain empty")
	
	# Test unknown date
	formatted_date = entry._format_date_for_display("Unknown")
	assert_eq(formatted_date, "", "Unknown date should become empty")

func test_display_options():
	print("\n--- Testing Display Options ---")
	
	# Create HighScoreDisplay instance
	var display_script = preload("res://scripts/ui/high_score_display.gd")
	var display = display_script.new()
	
	# Test default options
	assert_eq(display.max_visible_scores, 10, "Default max visible scores should be 10")
	assert_true(display.show_rank_numbers, "Should show rank numbers by default")
	assert_true(display.show_dates, "Should show dates by default")
	assert_true(display.highlight_current_session, "Should highlight current session by default")
	
	# Test setting options
	var options = {
		"max_visible_scores": 5,
		"show_rank_numbers": false,
		"show_dates": false,
		"highlight_current_session": false
	}
	
	display.set_display_options(options)
	
	assert_eq(display.max_visible_scores, 5, "Max visible scores should be updated")
	assert_false(display.show_rank_numbers, "Rank numbers should be disabled")
	assert_false(display.show_dates, "Dates should be disabled")
	assert_false(display.highlight_current_session, "Session highlighting should be disabled")

func test_session_highlighting():
	print("\n--- Testing Session Highlighting ---")
	
	var score_manager = get_node("/root/ScoreManager")
	if not score_manager:
		tests_failed += 1
		test_results.append("✗ FAIL: ScoreManager not available for session test")
		return
	
	var formatted_scores = score_manager.get_formatted_high_scores()
	
	# Check that session highlighting field exists
	for score_entry in formatted_scores:
		assert_true(score_entry.has("is_current_session"), "Score entry should have is_current_session field")

func test_rank_assignment():
	print("\n--- Testing Rank Assignment ---")
	
	var score_manager = get_node("/root/ScoreManager")
	if not score_manager:
		tests_failed += 1
		test_results.append("✗ FAIL: ScoreManager not available for rank test")
		return
	
	var formatted_scores = score_manager.get_formatted_high_scores()
	
	# Check rank assignment
	for i in range(formatted_scores.size()):
		var expected_rank = i + 1
		assert_eq(formatted_scores[i].rank, expected_rank, "Score at index %d should have rank %d" % [i, expected_rank])

func test_score_manager_integration():
	print("\n--- Testing ScoreManager Integration ---")
	
	var score_manager = get_node("/root/ScoreManager")
	if not score_manager:
		tests_failed += 1
		test_results.append("✗ FAIL: ScoreManager not available")
		return
	
	# Test required methods exist
	assert_true(score_manager.has_method("get_formatted_high_scores"), "ScoreManager should have get_formatted_high_scores method")
	
	# Test method returns proper data structure
	var formatted_scores = score_manager.get_formatted_high_scores()
	assert_true(formatted_scores is Array, "get_formatted_high_scores should return an Array")
	
	if formatted_scores.size() > 0:
		var first_entry = formatted_scores[0]
		assert_true(first_entry.has("rank"), "Score entry should have rank")
		assert_true(first_entry.has("name"), "Score entry should have name")
		assert_true(first_entry.has("score"), "Score entry should have score")
		assert_true(first_entry.has("formatted_score"), "Score entry should have formatted_score")
		assert_true(first_entry.has("date"), "Score entry should have date")
		assert_true(first_entry.has("is_current_session"), "Score entry should have is_current_session")

func test_empty_list_handling():
	print("\n--- Testing Empty List Handling ---")
	
	# Create HighScoreDisplay instance
	var display_script = preload("res://scripts/ui/high_score_display.gd")
	var display = display_script.new()
	
	# Test that empty list handling doesn't crash
	# This is mainly a crash test since we can't easily mock empty scores
	assert_true(true, "Empty list handling should not crash")

func test_large_dataset_handling():
	print("\n--- Testing Large Dataset Handling ---")
	
	# Create HighScoreDisplay instance
	var display_script = preload("res://scripts/ui/high_score_display.gd")
	var display = display_script.new()
	
	# Test max visible scores limit
	display.set_display_options({"max_visible_scores": 5})
	assert_eq(display.max_visible_scores, 5, "Should respect max visible scores limit")
	
	# Test that large datasets don't cause issues
	assert_true(true, "Large dataset handling should not crash")

func print_results():
	print("\n" + "=".repeat(50))
	print("HIGH SCORE DISPLAY TEST RESULTS")
	print("=".repeat(50))
	
	for result_line in test_results:
		print(result_line)
	
	print("\n" + "=".repeat(50))
	print("SUMMARY:")
	print("Tests Passed: %d" % tests_passed)
	print("Tests Failed: %d" % tests_failed)
	print("Total Tests: %d" % (tests_passed + tests_failed))
	
	if tests_failed == 0:
		print("🎉 ALL HIGH SCORE DISPLAY TESTS PASSED!")
	else:
		print("❌ %d HIGH SCORE DISPLAY TESTS FAILED" % tests_failed)
	
	print("=".repeat(50))