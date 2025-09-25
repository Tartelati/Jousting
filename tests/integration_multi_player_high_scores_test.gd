extends TestBase

# Integration tests for multi-player high score system (standalone version)

var score_manager: Node
var multi_player_game_over: Control
var game_over_scene = preload("res://scenes/ui/multi_player_game_over.tscn")

func before_each():
	super.before_each()
	# Setup ScoreManager
	score_manager = preload("res://scripts/managers/score_manager.gd").new()
	score_manager.name = "ScoreManager"
	add_child(score_manager)
	score_manager.initialize_enhanced_system()
	
	# Create multi-player game over UI
	multi_player_game_over = game_over_scene.instantiate()
	add_child(multi_player_game_over)

func after_each():
	if multi_player_game_over:
		multi_player_game_over.queue_free()
	if score_manager:
		score_manager = null
	super.after_each()

# Test multi-player workflow integration

func test_multi_player_workflow_two_players():
	# Setup two qualifying players
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	
	# Check qualification
	var qualifying = score_manager.check_all_players_for_qualifying_scores()
	assert_eq(qualifying.size(), 2, "Should have two qualifying players")
	
	# Process first player (highest score)
	var next_player = score_manager.get_next_qualifying_player()
	assert_eq(next_player, 2, "Should process Player 2 first (highest score)")
	
	var result = score_manager.submit_multi_player_high_score(2, "HighScorer")
	assert_true(result.success, "First player submission should succeed")
	
	# Process second player
	next_player = score_manager.get_next_qualifying_player()
	assert_eq(next_player, 1, "Should process Player 1 next")
	
	result = score_manager.submit_multi_player_high_score(1, "MidScorer")
	assert_true(result.success, "Second player submission should succeed")
	
	# No more players
	next_player = score_manager.get_next_qualifying_player()
	assert_eq(next_player, -1, "Should have no more players to process")
	
	# Check final summary
	var summary = score_manager.get_multi_player_session_summary()
	assert_eq(summary.session_high_scores.size(), 2, "Should have two session high scores")

func test_multi_player_workflow_mixed_qualification():
	# Setup mixed players (some qualifying, some not)
	score_manager.scores[1] = 100  # Too low
	score_manager.scores[2] = 50000  # Qualifying
	score_manager.scores[3] = 0  # Too low
	score_manager.scores[4] = 30000  # Qualifying
	
	var qualifying = score_manager.check_all_players_for_qualifying_scores()
	assert_eq(qualifying.size(), 2, "Should have two qualifying players")
	assert_true(2 in qualifying, "Player 2 should qualify")
	assert_true(4 in qualifying, "Player 4 should qualify")
	
	# Process qualifying players
	var result1 = score_manager.submit_multi_player_high_score(2, "Player2")
	var result2 = score_manager.submit_multi_player_high_score(4, "Player4")
	
	assert_true(result1.success, "Player 2 submission should succeed")
	assert_true(result2.success, "Player 4 submission should succeed")
	
	# Try to process non-qualifying player
	var result3 = score_manager.submit_multi_player_high_score(1, "Player1")
	assert_false(result3.success, "Non-qualifying player submission should fail")

func test_multi_player_personal_best_detection():
	# Add existing high scores
	score_manager.high_scores = [
		{"name": "David Lacassagne", "score": 999_999_999},
		{"name": "Player 1", "score": 25000},
		{"name": "Player 2", "score": 20000}
	]
	
	# Setup current session scores
	score_manager.scores[1] = 30000  # Better than existing
	score_manager.scores[2] = 15000  # Worse than existing
	score_manager.scores[3] = 35000  # New player
	
	var qualifying = score_manager.check_all_players_for_qualifying_scores()
	
	# Check personal best detection
	var player1_data = score_manager.get_player_high_score_data(1)
	var player2_data = score_manager.get_player_high_score_data(2)
	var player3_data = score_manager.get_player_high_score_data(3)
	
	assert_true(player1_data.is_personal_best, "Player 1 should have personal best")
	assert_false(player2_data.is_personal_best, "Player 2 should not have personal best")
	assert_true(player3_data.is_personal_best, "Player 3 should have personal best (new player)")

func test_multi_player_ranking_system():
	# Setup players with different scores
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	score_manager.scores[3] = 40000
	score_manager.scores[4] = 20000
	
	score_manager.check_all_players_for_qualifying_scores()
	
	# Check rankings
	var player1_data = score_manager.get_player_high_score_data(1)
	var player2_data = score_manager.get_player_high_score_data(2)
	var player3_data = score_manager.get_player_high_score_data(3)
	var player4_data = score_manager.get_player_high_score_data(4)
	
	# Player 2 should have best rank (highest score)
	assert_lt(player2_data.rank, player3_data.rank, "Player 2 should rank higher than Player 3")
	assert_lt(player3_data.rank, player1_data.rank, "Player 3 should rank higher than Player 1")
	assert_lt(player1_data.rank, player4_data.rank, "Player 1 should rank higher than Player 4")

# Test UI integration

func test_multi_player_ui_initialization():
	# Setup multi-player scores
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	
	# Wait for UI to initialize
	await wait_frames(2)
	
	# Check that UI components exist
	assert_not_null(multi_player_game_over.get_node_or_null("VBoxContainer/ScoreSummaryContainer"), "Score summary container should exist")
	assert_not_null(multi_player_game_over.get_node_or_null("VBoxContainer/CurrentPlayerContainer"), "Current player container should exist")
	assert_not_null(multi_player_game_over.get_node_or_null("VBoxContainer/FinalSummaryContainer"), "Final summary container should exist")

func test_multi_player_ui_player_processing():
	# Setup qualifying players
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	
	# Wait for UI initialization
	await wait_frames(2)
	
	# Check that current player container is visible for first player
	var current_container = multi_player_game_over.get_node("VBoxContainer/CurrentPlayerContainer")
	var final_container = multi_player_game_over.get_node("VBoxContainer/FinalSummaryContainer")
	
	assert_true(current_container.visible, "Current player container should be visible")
	assert_false(final_container.visible, "Final summary should be hidden initially")

# Test error handling

func test_multi_player_invalid_submission():
	# Setup qualifying player
	score_manager.scores[1] = 30000
	score_manager.check_all_players_for_qualifying_scores()
	
	# Try to submit with invalid name (too long)
	var long_name = "ThisNameIsWayTooLongForTheValidationSystem"
	var result = score_manager.submit_multi_player_high_score(1, long_name)
	
	# Should still succeed but with sanitized name
	assert_true(result.success, "Should succeed with sanitized name")

func test_multi_player_storage_failure_handling():
	# Setup qualifying player
	score_manager.scores[1] = 30000
	score_manager.check_all_players_for_qualifying_scores()
	
	# Disable auto-save to simulate storage failure
	score_manager.config.auto_save = false
	
	var result = score_manager.submit_multi_player_high_score(1, "TestPlayer")
	
	# Should still succeed (in-memory) even if storage fails
	assert_true(result.success, "Should succeed even with storage disabled")

# Test session management

func test_multi_player_session_reset():
	# Setup multi-player session
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	score_manager.check_all_players_for_qualifying_scores()
	score_manager.submit_multi_player_high_score(1, "Player1")
	
	# Verify session data exists
	var summary_before = score_manager.get_multi_player_session_summary()
	assert_gt(summary_before.total_players, 0, "Should have players before reset")
	
	# Reset session
	score_manager.reset_all_players()
	
	# Verify session data is cleared
	var summary_after = score_manager.get_multi_player_session_summary()
	assert_eq(summary_after.total_players, 0, "Should have no players after reset")
	assert_eq(summary_after.session_high_scores.size(), 0, "Should have no session high scores after reset")

func test_multi_player_concurrent_submissions():
	# Setup multiple qualifying players
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	score_manager.scores[3] = 40000
	
	score_manager.check_all_players_for_qualifying_scores()
	
	# Submit all players simultaneously (simulate concurrent access)
	var results = []
	results.append(score_manager.submit_multi_player_high_score(1, "Player1"))
	results.append(score_manager.submit_multi_player_high_score(2, "Player2"))
	results.append(score_manager.submit_multi_player_high_score(3, "Player3"))
	
	# All should succeed
	for result in results:
		assert_true(result.success, "All concurrent submissions should succeed")
	
	# All should be processed
	assert_eq(score_manager.processed_players.size(), 3, "All players should be processed")

# Test performance with many players

func test_multi_player_many_players_performance():
	# Setup many players (stress test)
	for i in range(1, 21):  # 20 players
		score_manager.scores[i] = 10000 + (i * 1000)  # Varying scores
	
	var start_time = Time.get_ticks_msec()
	
	# Check qualification (should be fast)
	var qualifying = score_manager.check_all_players_for_qualifying_scores()
	
	var qualification_time = Time.get_ticks_msec() - start_time
	
	assert_lt(qualification_time, 100, "Qualification check should complete quickly")
	assert_eq(qualifying.size(), 20, "All players should qualify")
	
	# Process all players (should also be reasonably fast)
	start_time = Time.get_ticks_msec()
	
	for player_index in qualifying:
		score_manager.submit_multi_player_high_score(player_index, "Player%d" % player_index)
	
	var processing_time = Time.get_ticks_msec() - start_time
	
	assert_lt(processing_time, 500, "Processing all players should complete in reasonable time")
	
	# Verify all processed
	assert_eq(score_manager.processed_players.size(), 20, "All players should be processed")
