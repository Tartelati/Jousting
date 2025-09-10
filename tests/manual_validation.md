# Manual Validation Guide for HighScoreValidator

This document provides manual test cases to validate the HighScoreValidator implementation.

## Test Cases

### 1. Score Validation Tests

#### Valid Scores
- `is_valid_score(0)` → should return `true`
- `is_valid_score(1000)` → should return `true`
- `is_valid_score(99_999_999)` → should return `true`

#### Invalid Scores
- `is_valid_score(-1)` → should return `false`
- `is_valid_score(100_000_000)` → should return `false`

### 2. Name Sanitization Tests

#### Normal Names
- `sanitize_player_name("John")` → should return `"John"`
- `sanitize_player_name("Player 1")` → should return `"Player 1"`
- `sanitize_player_name("ABC123")` → should return `"ABC123"`

#### Empty/Whitespace Names
- `sanitize_player_name("")` → should return `"Anonymous"`
- `sanitize_player_name("   ")` → should return `"Anonymous"`

#### Invalid Characters
- `sanitize_player_name("John@Doe")` → should return `"JohnDoe"`
- `sanitize_player_name("Player#1!")` → should return `"Player1"`

#### Length Truncation
- `sanitize_player_name("ThisIsAVeryLongPlayerNameThatExceedsTheMaximumLength")` → should return `"ThisIsAVeryLongPlaye"` (20 chars)

### 3. Entry Validation Tests

#### Valid Entry
```gdscript
var entry = {
    "name": "TestPlayer",
    "score": 1000,
    "date": "2024-01-01",
    "timestamp": 1704067200,
    "player_index": 1,
    "session_id": "test_session",
    "version": "1.0.0"
}
```
- `validate_high_score_entry(entry).valid` → should return `true`

#### Missing Required Fields
```gdscript
var entry = {}
```
- `validate_high_score_entry(entry).valid` → should return `false`
- Should have errors for missing name and score

### 4. Score Submission Tests

#### Valid Submission
- `validate_score_submission("TestPlayer", 1000, 1).valid` → should return `true`

#### Submission with Sanitization
- `validate_score_submission("Test@Player!", 1000, 1).sanitized_data.name` → should return `"TestPlayer"`

### 5. Score Improvement Tests

#### New Player
```gdscript
var existing_scores = [{"name": "Player1", "score": 1000}]
```
- `is_score_improvement(500, existing_scores, "Player2")` → should return `true`

#### Existing Player Better Score
- `is_score_improvement(1500, existing_scores, "Player1")` → should return `true`

#### Existing Player Worse Score
- `is_score_improvement(500, existing_scores, "Player1")` → should return `false`

## How to Test

1. Open the Godot editor
2. Create a new scene with a Node
3. Attach a script to the node
4. Add the following test code:

```gdscript
extends Node

func _ready():
    var validator = HighScoreValidator.new()
    
    # Test score validation
    print("Testing score validation:")
    print("is_valid_score(1000): ", validator.is_valid_score(1000))
    print("is_valid_score(-1): ", validator.is_valid_score(-1))
    
    # Test name sanitization
    print("\nTesting name sanitization:")
    print("sanitize_player_name('John'): ", validator.sanitize_player_name("John"))
    print("sanitize_player_name('John@Doe'): ", validator.sanitize_player_name("John@Doe"))
    print("sanitize_player_name(''): ", validator.sanitize_player_name(""))
    
    # Test entry validation
    print("\nTesting entry validation:")
    var entry = {"name": "TestPlayer", "score": 1000}
    var result = validator.validate_high_score_entry(entry)
    print("Valid entry result: ", result.valid)
    print("Sanitized name: ", result.sanitized_data.name)
    print("Sanitized score: ", result.sanitized_data.score)
    
    # Test score submission
    print("\nTesting score submission:")
    var submission = validator.validate_score_submission("Test@Player!", 1000, 1)
    print("Submission valid: ", submission.valid)
    print("Sanitized name: ", submission.sanitized_data.name)
```

5. Run the scene and check the output in the console

## Expected Results

All tests should pass with the expected return values as documented above. Any failures indicate issues with the implementation that need to be addressed.

## Integration with ScoreManager

Once validated, the HighScoreValidator can be integrated with the existing ScoreManager by:

1. Adding a validator instance to ScoreManager
2. Using validator methods in score submission workflows
3. Implementing proper error handling based on validation results