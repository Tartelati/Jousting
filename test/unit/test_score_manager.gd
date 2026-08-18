extends GutTest
# ============================================================
# Unit tests for ScoreManager (autoload).
# These lock in the CURRENT public behavior of the singleton:
# scoring, extra-life thresholds, lives, and high-score rules.
# ============================================================

func before_each():
	# Isolate from persisted state written by previous runs/tests.
	var save_path := "user://high_scores.save"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	ScoreManager.reset_all_players()
	ScoreManager.high_scores = [{"name": "David Lacassagne", "score": 999_999_999}]


# ---------------- Scoring ----------------

func test_add_score_increments_and_emits():
	var events: Array = []
	ScoreManager.score_changed.connect(func(idx, sc): events.append([idx, sc]))

	ScoreManager.add_score(1, 100)

	assert_eq(ScoreManager.get_score(1), 100, "score should accumulate")
	assert_eq(events, [[1, 100]], "score_changed should emit (player, new_score)")


func test_add_score_accumulates_multiple_calls():
	ScoreManager.add_score(1, 100)
	ScoreManager.add_score(1, 250)

	assert_eq(ScoreManager.get_score(1), 350)


func test_get_score_defaults_to_zero_for_unknown_player():
	assert_eq(ScoreManager.get_score(99), 0)


func test_reset_score_zeroes_and_emits():
	watch_signals(ScoreManager)

	ScoreManager.add_score(1, 500)
	ScoreManager.reset_score(1)

	assert_eq(ScoreManager.get_score(1), 0)
	assert_signal_emitted(ScoreManager, "score_changed", "reset_score should emit score_changed")


# ---------------- Lives & extra-life thresholds ----------------

func test_get_lives_defaults_to_three():
	assert_eq(ScoreManager.get_lives(99), 3)


func test_extra_life_granted_every_1000_points():
	ScoreManager.add_score(1, 1000)
	assert_eq(ScoreManager.get_lives(1), 4, "crossing 1000 points grants one extra life")

	# +500 more (total 1500) is not a full new thousand -> no award
	ScoreManager.add_score(1, 500)
	assert_eq(ScoreManager.get_lives(1), 4, "1500 total does not cross the next 1000 boundary")

	# +600 more (total 2100) crosses 2000 -> second award
	ScoreManager.add_score(1, 600)
	assert_eq(ScoreManager.get_lives(1), 5, "crossing 2000 grants a second extra life")


func test_extra_life_capped_at_max_lives():
	ScoreManager.reset_lives(1)
	ScoreManager.gain_life(1)  # 4
	ScoreManager.gain_life(1)  # 5

	ScoreManager.add_score(1, 10_000)

	assert_eq(ScoreManager.get_lives(1), ScoreManager.max_lives, "lives never exceed max_lives")


func test_gain_life_respects_max_lives():
	ScoreManager.reset_lives(1)
	ScoreManager.gain_life(1)
	ScoreManager.gain_life(1)
	ScoreManager.gain_life(1)  # already at max

	assert_eq(ScoreManager.get_lives(1), ScoreManager.max_lives)


func test_lose_life_decrements():
	ScoreManager.reset_lives(1)
	ScoreManager.lose_life(1)

	assert_eq(ScoreManager.get_lives(1), 2)


func test_reset_all_players_clears_everything():
	ScoreManager.add_score(1, 500)
	ScoreManager.reset_all_players()

	assert_eq(ScoreManager.get_score(1), 0)
	assert_eq(ScoreManager.get_lives(1), 3, "lives fall back to the default after reset")
	assert_eq(ScoreManager.scores.size(), 0)


# ---------------- High scores ----------------

func test_update_high_scores_keeps_david_first_and_caps_at_five():
	ScoreManager.add_score(1, 5000)
	ScoreManager.add_score(2, 4000)

	var names: Array = ScoreManager.high_scores.map(func(e): return e.name)

	assert_eq(names[0], "David Lacassagne", "David stays at the top")
	assert_true("Player 1" in names)
	assert_true("Player 2" in names)
	assert_lte(ScoreManager.high_scores.size(), 5, "update_high_scores caps the list at 5")


func test_try_submit_high_score_rejects_david_name():
	var result := ScoreManager.try_submit_high_score(1_000_000, "David Lacassagne")

	assert_false(result, "the joke entry can never be (re)submitted")


func test_try_submit_high_score_sorts_desc_and_keeps_david_first():
	ScoreManager.try_submit_high_score(100, "Alice")
	ScoreManager.try_submit_high_score(9000, "Bob")
	ScoreManager.try_submit_high_score(500, "Carol")

	assert_eq(ScoreManager.high_scores[0].name, "David Lacassagne")
	assert_eq(ScoreManager.high_scores[1].name, "Bob")
	assert_eq(ScoreManager.high_scores[1].score, 9000)
	assert_true(ScoreManager.try_submit_high_score(250, "Dana"))


# ---------------- Bonus signals ----------------

func test_add_bonus_score_emits_with_world_position():
	watch_signals(ScoreManager)

	ScoreManager.add_bonus_score(2, 50, "egg", Vector2(10, 20))

	assert_signal_emitted_with_parameters(
		ScoreManager, "bonus_awarded", [2, 50, "egg", Vector2(10, 20)]
	)
