extends Node

# Test multi-player high score handling functionality (standalone version)

var score_manager: Node
var validator: HighScoreValidator

func before_each():
	# Create fresh instances for each test
	score_manager = preload("res://scripts/managers/score_manager.gd").new()
	score_manager.name = "ScoreManager"
	add_child(score_manager)
	
	# Initialize the enhanced system
	score_manager.initialize_enhanced_system()
	
	validator = HighScoreValidator.new()

func after_each():
	if score_manager:
		score_manager.queue_free()

# Test multi-player score tracking

func test_check_all_players_for_qualifying_scores_empty():
	# Test with no players
	var qualifying = score_manager.check_all_players_for_qualifying_scores()
	assert_eq(qualifying.size(), 0, "Should have no qualifying players when no scores exist")

func test_check_all_players_for_qualifying_scores_single_qualifying():
	# Add one qualifying score
	score_manager.scores[1] = 50000
	
	var qualifying = score_manager.check_all_players_for_qualifying_scores()
	assert_eq(qualifying.size(), 1, "Should have one qualifying player")
	assert_eq(qualifying[0], 1, "Player 1 should be qualifying")
	
	var player_data = score_manager.get_player_high_score_data(1)
	assert_eq(player_data.score, 50000, "Player data should contain correct score")
	assert_true(player_data.rank > 0, "Player should have a valid rank")

func test_check_all_players_for_qualifying_scores_multiple_qualifying():
	# Add multiple qualifying scores
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	score_manager.scores[3] = 10000
	score_manager.scores[4] = 40000
	
	var qualifying = score_manager.check_all_players_for_qualifying_scores()
	assert_eq(qualifying.size(), 4, "Should have four qualifying players")
	
	# Should be sorted by score (highest first)
	assert_eq(qualifying[0], 2, "Player 2 should be first (highest score)")
	assert_eq(qualifying[1], 4, "Player 4 should be second")
	assert_eq(qualifying[2], 1, "Player 1 should be third")
	assert_eq(qualifying[3], 3, "Player 3 should be fourth")

func test_check_all_players_for_qualifying_scores_mixed():
	# Add mix of qualifying and non-qualifying scores
	score_manager.scores[1] = 100  # Too low
	score_manager.scores[2] = 50000  # Qualifying
	score_manager.scores[3] = 0  # Too low
	score_manager.scores[4] = 30000  # Qualifying
	
	var qualifying = score_manager.check_all_players_for_qualifying_scores()
	assert_eq(qualifying.size(), 2, "Should have two qualifying players")
	assert_true(2 in qualifying, "Player 2 should qualify")
	assert_true(4 in qualifying, "Player 4 should qualify")
	assert_false(1 in qualifying, "Player 1 should not qualify")
	assert_false(3 in qualifying, "Player 3 should not qualify")

# Test player processing workflow

func test_get_next_qualifying_player():
	# Setup qualifying players
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	score_manager.check_all_players_for_qualifying_scores()
	
	# Should get highest scoring player first
	var next_player = score_manager.get_next_qualifying_player()
	assert_eq(next_player, 2, "Should get Player 2 first (highest score)")
	
	# Mark player 2 as processed
	score_manager.mark_player_processed(2)
	
	# Should get next player
	next_player = score_manager.get_next_qualifying_player()
	assert_eq(next_player, 1, "Should get Player 1 next")
	
	# Mark player 1 as processed
	score_manager.mark_player_processed(1)
	
	# Should have no more players
	next_player = score_manager.get_next_qualifying_player()
	assert_eq(next_player, -1, "Should have no more qualifying players")

func test_mark_player_processed():
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	score_manager.check_all_players_for_qualifying_scores()
	
	# Initially no players processed
	assert_eq(score_manager.processed_players.size(), 0, "Should start with no processed players")
	
	# Mark player 1 as processed
	score_manager.mark_player_processed(1)
	assert_eq(score_manager.processed_players.size(), 1, "Should have one processed player")
	assert_true(1 in score_manager.processed_players, "Player 1 should be marked as processed")
	
	# Mark player 2 as processed
	score_manager.mark_player_processed(2)
	assert_eq(score_manager.processed_players.size(), 2, "Should have two processed players")
	assert_true(2 in score_manager.processed_players, "Player 2 should be marked as processed")
	
	# Marking same player again should not duplicate
	score_manager.mark_player_processed(1)
	assert_eq(score_manager.processed_players.size(), 2, "Should still have two processed players")

func test_get_remaining_qualifying_players():
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	score_manager.scores[3] = 40000
	score_manager.check_all_players_for_qualifying_scores()
	
	# Initially all players should be remaining
	var remaining = score_manager.get_remaining_qualifying_players()
	assert_eq(remaining.size(), 3, "Should have three remaining players")
	
	# Process one player
	score_manager.mark_player_processed(2)
	remaining = score_manager.get_remaining_qualifying_players()
	assert_eq(remaining.size(), 2, "Should have two remaining players")
	assert_false(2 in remaining, "Player 2 should not be in remaining list")
	
	# Process another player
	score_manager.mark_player_processed(1)
	remaining = score_manager.get_remaining_qualifying_players()
	assert_eq(remaining.size(), 1, "Should have one remaining player")
	assert_true(3 in remaining, "Player 3 should be the only remaining player")

# Test multi-player high score submission

func test_submit_multi_player_high_score_success():
	# Setup qualifying player
	score_manager.scores[1] = 50000
	score_manager.check_all_players_for_qualifying_scores()
	
	# Submit high score
	var result = score_manager.submit_multi_player_high_score(1, "TestPlayer")
	
	assert_true(result.success, "Submission should succeed")
	assert_true(result.rank > 0, "Should have valid rank")
	assert_true(1 in score_manager.processed_players, "Player should be marked as processed")

func test_submit_multi_player_high_score_non_qualifying():
	# Setup non-qualifying player
	score_manager.scores[1] = 100
	score_manager.check_all_players_for_qualifying_scores()
	
	# Try to submit high score for non-qualifying player
	var result = score_manager.submit_multi_player_high_score(1, "TestPlayer")
	
	assert_false(result.success, "Submission should fail for non-qualifying player")
	assert_eq(result.message, "Player does not have a qualifying score", "Should have appropriate error message")

func test_submit_multi_player_high_score_invalid_player():
	# Setup qualifying players
	score_manager.scores[1] = 50000
	score_manager.check_all_players_for_qualifying_scores()
	
	# Try to submit for player that doesn't exist
	var result = score_manager.submit_multi_player_high_score(5, "TestPlayer")
	
	assert_false(result.success, "Submission should fail for non-existent player")

# Test personal best detection

func test_check_player_personal_best_new_player():
	# Test with new player (no existing high scores)
	score_manager.scores[1] = 30000
	score_manager.check_all_players_for_qualifying_scores()
	
	var player_data = score_manager.get_player_high_score_data(1)
	assert_true(player_data.is_personal_best, "Should be personal best for new player")

func test_check_player_personal_best_existing_player():
	# Add existing high score for player
	score_manager.high_scores.append({"name": "Player 1", "score": 25000})
	
	# Test with higher score
	score_manager.scores[1] = 30000
	score_manager.check_all_players_for_qualifying_scores()
	
	var player_data = score_manager.get_player_high_score_data(1)
	assert_true(player_data.is_personal_best, "Should be personal best when score is higher")
	
	# Test with lower score
	score_manager.processed_players.clear()
	score_manager.scores[1] = 20000
	score_manager.check_all_players_for_qualifying_scores()
	
	player_data = score_manager.get_player_high_score_data(1)
	assert_false(player_data.is_personal_best, "Should not be personal best when score is lower")

# Test session summary

func test_get_multi_player_session_summary():
	# Setup multi-player session
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	score_manager.scores[3] = 100  # Non-qualifying
	
	score_manager.check_all_players_for_qualifying_scores()
	
	# Process some players
	score_manager.submit_multi_player_high_score(2, "HighScorer")
	score_manager.submit_multi_player_high_score(1, "MidScorer")
	
	var summary = score_manager.get_multi_player_session_summary()
	
	assert_eq(summary.total_players, 3, "Should have three total players")
	assert_eq(summary.qualifying_players, 2, "Should have two qualifying players")
	assert_eq(summary.processed_players, 2, "Should have two processed players")
	assert_eq(summary.session_high_scores.size(), 2, "Should have two session high scores")
	
	# Check player scores summary
	assert_true(summary.player_scores.has(1), "Should have Player 1 data")
	assert_true(summary.player_scores.has(2), "Should have Player 2 data")
	assert_true(summary.player_scores.has(3), "Should have Player 3 data")
	
	assert_true(summary.player_scores[1].qualified, "Player 1 should be qualified")
	assert_true(summary.player_scores[2].qualified, "Player 2 should be qualified")
	assert_false(summary.player_scores[3].qualified, "Player 3 should not be qualified")

# Test reset functionality

func test_reset_all_players_clears_multi_player_data():
	# Setup multi-player session
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 50000
	score_manager.check_all_players_for_qualifying_scores()
	score_manager.mark_player_processed(1)
	
	# Verify data exists
	assert_gt(score_manager.qualifying_players.size(), 0, "Should have qualifying players before reset")
	assert_gt(score_manager.processed_players.size(), 0, "Should have processed players before reset")
	assert_gt(score_manager.player_high_score_data.size(), 0, "Should have player data before reset")
	
	# Reset
	score_manager.reset_all_players()
	
	# Verify data is cleared
	assert_eq(score_manager.qualifying_players.size(), 0, "Should have no qualifying players after reset")
	assert_eq(score_manager.processed_players.size(), 0, "Should have no processed players after reset")
	assert_eq(score_manager.player_high_score_data.size(), 0, "Should have no player data after reset")

# Test edge cases

func test_duplicate_score_handling():
	# Test players with identical scores
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 30000
	score_manager.scores[3] = 30000
	
	var qualifying = score_manager.check_all_players_for_qualifying_scores()
	assert_eq(qualifying.size(), 3, "Should handle duplicate scores correctly")
	
	# All should have same rank initially
	for player_index in qualifying:
		var player_data = score_manager.get_player_high_score_data(player_index)
		assert_eq(player_data.score, 30000, "All players should have same score")

func test_processed_players_not_requalified():
	# Setup and process a player
	score_manager.scores[1] = 30000
	score_manager.check_all_players_for_qualifying_scores()
	score_manager.mark_player_processed(1)
	
	# Check again - processed player should not requalify
	var qualifying = score_manager.check_all_players_for_qualifying_scores()
	assert_false(1 in qualifying, "Processed player should not requalify")

func test_empty_session_summary():
	# Test summary with no players
	var summary = score_manager.get_multi_player_session_summary()
	
	assert_eq(summary.total_players, 0, "Should have zero total players")
	assert_eq(summary.qualifying_players, 0, "Should have zero qualifying players")
	assert_eq(summary.processed_players, 0, "Should have zero processed players")
	assert_eq(summary.session_high_scores.size(), 0, "Should have no session high scores")