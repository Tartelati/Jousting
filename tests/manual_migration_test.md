# Manual Migration Testing Guide

This guide provides step-by-step instructions for manually testing the data migration and version compatibility system.

## Prerequisites

- Godot project with high score save system implemented
- Access to the user data directory (usually `%APPDATA%/Godot/app_userdata/[project_name]/` on Windows)
- Text editor for creating test files

## Test Scenarios

### Scenario 1: Legacy Array Format Migration

**Purpose**: Test migration from the original simple array format.

**Steps**:
1. Close the game if running
2. Navigate to the user data directory
3. Create a file named `high_scores.save` with the following content (use a hex editor or Godot's FileAccess):
   ```
   [
     {"name": "LegacyPlayer1", "score": 25000},
     {"name": "LegacyPlayer2", "score": 18000},
     {"name": "OldChamp", "score": 50000}
   ]
   ```
4. Start the game
5. Navigate to the high scores display

**Expected Results**:
- All legacy scores should be visible
- David Lacassagne should still be at the top
- Legacy players should have enhanced fields (date, timestamp, version)
- A migration backup file should be created (`high_scores_pre_migration_legacy.backup`)
- The main save file should be updated to the new format

### Scenario 2: Version 1.0 Format Migration

**Purpose**: Test migration from v1.0 structured format.

**Steps**:
1. Close the game if running
2. Create a `high_scores.save` file with v1.0 format:
   ```
   {
     "magic": "HSCORE",
     "timestamp": 1704067200,
     "scores": [
       {"name": "V1Player", "score": 15000, "date": "2024-01-01"},
       {"name": "AnotherV1", "score": 12000, "date": "2024-01-02"}
     ],
     "checksum": "test123"
   }
   ```
3. Start the game
4. Check high scores display

**Expected Results**:
- V1.0 scores should be migrated successfully
- Migration backup should be created (`high_scores_pre_migration_1.0.backup`)
- Migrated entries should have `version` field indicating migration source
- File should be updated to v1.1 format

### Scenario 3: Save File Location Recovery

**Purpose**: Test recovery of save files from alternate locations.

**Steps**:
1. Close the game if running
2. Delete the main `high_scores.save` file if it exists
3. Create a save file in an alternate location (e.g., `scores.save` or `data/high_scores.save`):
   ```
   [
     {"name": "RecoveredPlayer", "score": 30000},
     {"name": "FoundPlayer", "score": 22000}
   ]
   ```
4. Start the game
5. Check high scores display

**Expected Results**:
- Game should find and load the alternate save file
- Scores should be displayed correctly
- Main save file should be recreated at the standard location
- Console should show recovery messages (if debug logging enabled)

### Scenario 4: Corrupted File Recovery

**Purpose**: Test recovery from corrupted main file using backup.

**Steps**:
1. Ensure you have a valid backup file from previous tests
2. Create a corrupted main save file:
   ```
   This is not valid save data - corrupted file
   ```
3. Start the game
4. Check high scores display

**Expected Results**:
- Game should detect corruption
- Should attempt to restore from backup
- If backup exists and is valid, scores should be recovered
- Console should show recovery attempt messages

### Scenario 5: Migration with Game Update Simulation

**Purpose**: Simulate a game update scenario where save format changes.

**Steps**:
1. Create a legacy save file as in Scenario 1
2. Start the game and let it migrate
3. Play the game and achieve some new high scores
4. Close the game
5. Restart the game

**Expected Results**:
- Original migrated scores should still be present
- New scores should coexist with migrated ones
- All scores should have proper version tracking
- No data loss should occur

### Scenario 6: Multiple Migration Sources

**Purpose**: Test handling of saves that have been migrated multiple times.

**Steps**:
1. Start with a legacy format file
2. Let the game migrate it to v1.1
3. Manually edit the save file to simulate a v1.0 format with some migrated entries
4. Restart the game

**Expected Results**:
- Game should handle mixed migration sources correctly
- Migration history should be tracked properly
- No duplicate entries should be created

## Validation Checklist

For each test scenario, verify:

- [ ] No crashes or errors occur during migration
- [ ] All original score data is preserved
- [ ] David Lacassagne remains at the top of the list
- [ ] Enhanced fields are added to migrated entries
- [ ] Migration backups are created before migration
- [ ] Save file is updated to current format after migration
- [ ] Console shows appropriate migration messages (if debug enabled)
- [ ] New high scores can be submitted after migration
- [ ] Game performance is not significantly impacted

## Troubleshooting

### Common Issues

1. **Migration backup not created**:
   - Check file permissions in user data directory
   - Verify backup_enabled is true in configuration

2. **Scores not migrated**:
   - Check original file format is valid
   - Verify migration detection logic
   - Check console for error messages

3. **Performance issues during migration**:
   - Check size of original save file
   - Monitor memory usage during migration
   - Verify migration is not running repeatedly

### Debug Information

Enable debug logging by setting `debug_logging: true` in the storage configuration to see detailed migration information in the console.

## Test Data Cleanup

After testing, clean up test files:
- Remove all `high_scores*.save` files
- Remove all `*_pre_migration_*.backup` files
- Remove any alternate location save files created during testing

## Reporting Issues

When reporting migration issues, include:
- Original save file format and content
- Expected vs actual results
- Console output (if debug logging enabled)
- Steps to reproduce the issue
- System information (OS, Godot version)