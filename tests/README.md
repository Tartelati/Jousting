# High Score System Testing

This directory contains tests and validation examples for the high score system components.

## Files

### HighScoreValidator Tests
- `unit/test_high_score_validator.gd` - Comprehensive unit tests for validator
- `test_runner.gd` - Simple test runner for validator tests
- `test_runner.tscn` - Scene file for running validator tests
- `integration_example.gd` - Integration example showing real-world usage

### HighScoreStorage Tests
- `unit/test_high_score_storage.gd` - Comprehensive unit tests for storage
- `test_storage_runner.gd` - Base class for storage tests
- `integration_storage_test.gd` - Integration tests for storage functionality
- `integration_storage_test.tscn` - Scene file for running storage tests

### Documentation
- `manual_validation.md` - Manual test cases for verification
- `README.md` - This documentation file

## Running Tests

### HighScoreValidator Tests

#### Option 1: Test Runner (Recommended)
1. Open the `test_runner.tscn` scene in Godot
2. Run the scene
3. Check the console output for test results

#### Option 2: Integration Example
1. Open Godot editor
2. Create a new scene
3. Add a Node and attach `integration_example.gd` as its script
4. Run the scene
5. Check the output in the console

### HighScoreStorage Tests

#### Option 1: Integration Tests (Recommended)
1. Open the `integration_storage_test.tscn` scene in Godot
2. Run the scene
3. Check the console output for comprehensive test results

#### Option 2: Unit Tests
1. Open the `test_storage_runner.tscn` scene in Godot
2. Run the scene to execute comprehensive unit tests
3. Check console output for detailed test results

#### Option 3: Manual Testing
1. Create a new scene with a Node
2. Attach `manual_storage_test.gd` as the script
3. Run the scene to verify basic functionality
4. Follow console output for step-by-step verification

## Features Tested

### HighScoreValidator Features

### Core Validation
- ✅ Score range validation (0 to 99,999,999)
- ✅ Reasonable score checking with game duration
- ✅ Player name sanitization and length limits
- ✅ Character filtering (alphanumeric + spaces only)

### Data Integrity
- ✅ High score entry validation
- ✅ Missing field detection and default value assignment
- ✅ Data type conversion (string to int for scores)
- ✅ Date and timestamp validation

### List Operations
- ✅ High score list validation
- ✅ Duplicate entry removal
- ✅ Batch validation with error reporting

### Utility Functions
- ✅ Score submission validation
- ✅ Score improvement detection
- ✅ Session ID generation
- ✅ Error and warning collection

### Edge Cases
- ✅ Empty and whitespace-only names
- ✅ Names with only special characters
- ✅ Extremely long names (truncation)
- ✅ Negative and excessive scores
- ✅ Malformed dates and timestamps
- ✅ Empty score lists
- ✅ Invalid data types

### HighScoreStorage Features

#### Core File Operations
- ✅ Save high scores to file with metadata and checksums
- ✅ Load high scores with format validation
- ✅ Handle empty score arrays
- ✅ Support multiple score entries
- ✅ Atomic save operations with verification

#### Data Integrity
- ✅ File integrity verification with magic headers
- ✅ Checksum validation for corruption detection
- ✅ Version tracking for migration support
- ✅ Automatic data sanitization
- ✅ Format validation on load

#### Backup and Recovery
- ✅ Automatic backup creation before saves
- ✅ Backup file management with configurable paths
- ✅ Recovery from corrupted main files
- ✅ Restore from backup functionality
- ✅ Graceful degradation when both files are corrupted

#### Error Handling
- ✅ Graceful handling of non-existent files
- ✅ Corruption detection and automatic recovery
- ✅ File permission error handling
- ✅ Disk space error management
- ✅ Comprehensive error code mapping

#### Configuration
- ✅ Custom save file locations
- ✅ Configurable backup settings (enable/disable)
- ✅ Debug logging options
- ✅ Runtime configuration changes
- ✅ Automatic backup path generation

#### Migration Support
- ✅ Legacy format detection and conversion
- ✅ Automatic format migration on load
- ✅ Backward compatibility with old save files
- ✅ Version tracking and upgrade paths

## Requirements Coverage

The HighScoreValidator implementation covers the following requirements:

### Requirement 2.4
- ✅ Name length validation (max 20 characters)
- ✅ Character filtering (alphanumeric and spaces only)

### Requirement 2.5
- ✅ Invalid character removal
- ✅ Default name assignment for empty inputs

### Requirement 5.4
- ✅ Score validation for impossible values
- ✅ Data integrity checking
- ✅ Corruption detection capabilities

### HighScoreStorage Requirements

#### Requirement 1.3
- ✅ Automatic data validation before saving
- ✅ Data integrity verification on load
- ✅ Checksum validation for corruption detection

#### Requirement 1.4
- ✅ Graceful error handling for storage failures
- ✅ Fallback behavior when storage is unavailable
- ✅ Automatic recovery from backup files

#### Requirement 5.1
- ✅ Backup and recovery mechanisms
- ✅ Corruption detection and handling
- ✅ Automatic backup creation before saves

#### Requirement 5.2
- ✅ Error handling for disk space issues
- ✅ Appropriate error messages for storage failures
- ✅ Comprehensive error code system

#### Requirement 5.3
- ✅ File permission error handling
- ✅ Logging of storage errors for debugging
- ✅ Debug logging with configurable verbosity

## Integration with ScoreManager

The HighScoreValidator is designed to integrate seamlessly with the existing ScoreManager:

```gdscript
# In ScoreManager
var validator = HighScoreValidator.new()

func submit_high_score(player_index: int, player_name: String) -> bool:
    var score = get_score(player_index)
    var result = validator.validate_score_submission(player_name, score, player_index)
    
    if result.valid:
        # Use sanitized data
        var clean_name = result.sanitized_data.name
        var clean_score = result.sanitized_data.score
        # Proceed with saving...
        return true
    else:
        # Handle validation errors
        for error in result.errors:
            print("Validation error: ", error)
        return false
```

The HighScoreStorage can be integrated with the ScoreManager as follows:

```gdscript
# In ScoreManager
var storage: HighScoreStorage

func _ready():
    # Initialize storage with configuration
    var config = {
        "save_location": "user://high_scores.save",
        "backup_enabled": true,
        "debug_logging": false
    }
    storage = HighScoreStorage.new(config)
    
    # Load existing high scores
    high_scores = storage.load_high_scores()

func save_high_scores():
    var save_result = storage.save_high_scores(high_scores)
    if save_result != HighScoreStorage.StorageError.SUCCESS:
        print("Failed to save high scores: ", save_result)
        # Handle error appropriately - storage will attempt backup recovery
        
func handle_storage_error(error: HighScoreStorage.StorageError):
    match error:
        HighScoreStorage.StorageError.DISK_FULL:
            show_error_message("Disk full - unable to save high scores")
        HighScoreStorage.StorageError.PERMISSION_DENIED:
            show_error_message("Permission denied - check file permissions")
        HighScoreStorage.StorageError.CORRUPTION_DETECTED:
            show_error_message("Save file corrupted - attempting recovery")
        _:
            show_error_message("Unknown storage error occurred")
```

## Next Steps

Both the HighScoreValidator and HighScoreStorage are now complete and ready for integration:

### HighScoreValidator
- ✅ Complete implementation with comprehensive validation
- ✅ Full test coverage including edge cases
- ✅ Ready for integration into ScoreManager

### HighScoreStorage  
- ✅ Complete implementation with robust file operations
- ✅ Comprehensive error handling and recovery mechanisms
- ✅ Full test coverage including unit and integration tests
- ✅ Manual testing utilities for verification
- ✅ Complete documentation and usage examples
- ✅ Ready for integration into ScoreManager

Both the HighScoreValidator and HighScoreStorage components are now complete and fully tested. The next step is task 3: "Create configuration management system" followed by task 4: "Enhance ScoreManager with new persistence features" which will integrate both components into the existing ScoreManager.