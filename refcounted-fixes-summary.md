# RefCounted Object Cleanup Fixes

## Problem
Several test files were calling `queue_free()` on RefCounted objects (like HighScoreValidator and ScoreManager), which causes runtime errors because RefCounted objects are automatically managed by Godot's reference counting system.

## Files Fixed

### 1. tests/unit/test_high_score_validator.gd
**Issue**: `validator.queue_free()` called on HighScoreValidator (RefCounted)
**Fix**: Changed to `validator = null`

### 2. tests/test_multi_player_high_scores_runner.gd  
**Issue**: `validator.queue_free()` called on HighScoreValidator (RefCounted)
**Fix**: Changed to `validator = null`

### 3. tests/unit/test_game_over_ui.gd
**Issue**: `score_manager.queue_free()` called on ScoreManager (RefCounted)
**Fix**: Changed to `score_manager = null`
**Note**: `game_over_instance.queue_free()` kept as-is (it's a Node)

### 4. tests/integration_multi_player_high_scores_test.gd
**Issue**: `score_manager.queue_free()` called on ScoreManager (RefCounted)
**Fix**: Changed to `score_manager = null`
**Note**: `multi_player_game_over.queue_free()` kept as-is (it's a Node)

### 5. tests/unit/test_multi_player_high_scores.gd
**Issue**: `score_manager.queue_free()` called on ScoreManager (RefCounted)
**Fix**: Changed to `score_manager = null`

## Rule Applied
- **RefCounted objects**: Use `object = null` to release reference
- **Node objects**: Use `object.queue_free()` to properly remove from scene tree

## Testing Instructions
1. Open Godot editor
2. Navigate to `tests/simple_test_runner.tscn`
3. Run the scene (F6)
4. Click "Run Tests" button
5. Verify no "Invalid call. Nonexistent function 'queue_free' in base 'RefCounted'" errors appear

## Expected Result
All tests should now run without RefCounted cleanup errors. The testing framework should work properly with both RefCounted objects (HighScoreValidator, ScoreManager) and Node objects (UI components).