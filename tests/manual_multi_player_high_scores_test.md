# Manual Test Guide: Multi-Player High Score System

## Overview
This guide provides manual testing procedures for the multi-player high score handling system. These tests verify that multiple players can achieve high scores in a single session and that the system handles name entry and ranking correctly.

## Prerequisites
- Game must be running with multi-player support enabled
- At least 2 controllers connected (or keyboard + controller)
- Access to debug console for score manipulation (if needed)

## Test Scenarios

### Test 1: Two Players Both Qualify for High Scores

**Objective**: Verify that when two players both achieve qualifying scores, they are prompted individually for name entry.

**Steps**:
1. Start a new game with 2 players
2. Play until both players achieve scores that would qualify for high scores (typically > 10,000 points)
3. End the game (let both players lose all lives)
4. Observe the game over screen

**Expected Results**:
- Multi-player game over screen should appear (not single-player version)
- Score summary should show both players' final scores
- Players should be processed in order of highest score first
- First player (highest score) should be prompted for name entry
- After first player submits name, second player should be prompted
- Final summary should show both players' high score entries

**Pass Criteria**:
- ✅ Multi-player UI appears instead of single-player UI
- ✅ Both players are prompted for name entry in correct order
- ✅ Both high scores are saved correctly
- ✅ Final summary displays both entries

### Test 2: Mixed Qualification (Some Players Qualify, Others Don't)

**Objective**: Verify that only qualifying players are prompted for name entry.

**Steps**:
1. Start a new game with 3-4 players
2. Have some players achieve high scores and others achieve low scores
3. End the game

**Expected Results**:
- Only players with qualifying scores should be prompted for name entry
- Non-qualifying players should appear in the score summary but not be prompted
- Final summary should only show high scores for qualifying players

**Pass Criteria**:
- ✅ Only qualifying players are prompted for names
- ✅ Non-qualifying players are shown in summary but not prompted
- ✅ Correct number of high scores are saved

### Test 3: Personal Best Detection

**Objective**: Verify that the system correctly identifies when a player achieves a personal best.

**Steps**:
1. Play a game and achieve a moderate high score with a specific name
2. Start a new game with multiple players
3. Have one player (using same name as step 1) achieve a higher score
4. Have another player achieve a lower score than their existing high score

**Expected Results**:
- Player with improved score should see "NEW PERSONAL BEST!" message
- Player with lower score should see regular high score message
- Rankings should be calculated correctly

**Pass Criteria**:
- ✅ Personal best detection works correctly
- ✅ Appropriate messages are displayed
- ✅ Rankings are accurate

### Test 4: Name Entry Validation in Multi-Player Context

**Objective**: Verify that name validation works correctly for each player.

**Steps**:
1. Set up a multi-player session with 2+ qualifying players
2. For first player, try entering various invalid names:
   - Empty name
   - Name longer than 20 characters
   - Name with special characters
3. For second player, enter a valid name
4. Complete the process

**Expected Results**:
- Invalid names should show appropriate validation messages
- Character count should update in real-time
- Submit button should be disabled for invalid input
- Skip button should work and use default name
- Valid names should be accepted and saved

**Pass Criteria**:
- ✅ Validation works for each player individually
- ✅ Real-time feedback is provided
- ✅ Skip functionality works correctly
- ✅ Valid names are saved properly

### Test 5: Identical Scores Handling

**Objective**: Verify that players with identical scores are handled correctly.

**Steps**:
1. Set up a scenario where multiple players achieve identical qualifying scores
2. End the game and observe the processing

**Expected Results**:
- All players with identical scores should qualify
- Processing order should be consistent (by player index when scores are equal)
- All players should receive the same rank initially
- Final rankings should account for submission order

**Pass Criteria**:
- ✅ Identical scores are handled without errors
- ✅ Processing order is deterministic
- ✅ Rankings are assigned correctly

### Test 6: Session Summary Accuracy

**Objective**: Verify that the final session summary is accurate and complete.

**Steps**:
1. Complete a multi-player session with various score outcomes
2. Review the final summary screen

**Expected Results**:
- Summary should show all players who participated
- High score entries should be listed with correct names and ranks
- Session statistics should be accurate
- Encouragement message should appear

**Pass Criteria**:
- ✅ All session data is accurate
- ✅ High score entries are correctly displayed
- ✅ Summary is complete and informative

### Test 7: Navigation and Flow

**Objective**: Verify that the multi-player high score flow integrates properly with game navigation.

**Steps**:
1. Complete a multi-player high score session
2. Test navigation options:
   - Restart game
   - Return to main menu
3. Verify that high scores persist

**Expected Results**:
- Navigation buttons should work correctly
- High scores should be saved and persist
- New game should start fresh
- Main menu should show updated high scores

**Pass Criteria**:
- ✅ Navigation works correctly
- ✅ High scores persist between sessions
- ✅ Game state is properly reset

### Test 8: Performance with Many Players

**Objective**: Verify that the system performs well with maximum players (4).

**Steps**:
1. Start a game with 4 players
2. Have all players achieve qualifying scores
3. Complete the high score entry process for all players
4. Monitor for any performance issues or delays

**Expected Results**:
- System should handle 4 players without performance degradation
- UI should remain responsive throughout the process
- All players should be processed correctly

**Pass Criteria**:
- ✅ No performance issues with 4 players
- ✅ UI remains responsive
- ✅ All players processed correctly

## Error Scenarios

### Test 9: Storage Failure During Multi-Player Session

**Objective**: Verify graceful handling of storage failures during multi-player processing.

**Steps**:
1. Set up a multi-player session with qualifying players
2. Simulate storage failure (if possible) or test with read-only file system
3. Attempt to save high scores

**Expected Results**:
- System should display appropriate error messages
- Processing should continue with in-memory scores
- Users should be informed of the storage issue
- Game should remain playable

**Pass Criteria**:
- ✅ Graceful error handling
- ✅ Appropriate user feedback
- ✅ System continues to function

### Test 10: Interruption During Name Entry

**Objective**: Verify handling of interruptions during the name entry process.

**Steps**:
1. Start multi-player high score processing
2. During name entry for first player, test various interruptions:
   - Alt+Tab (if applicable)
   - Controller disconnection
   - Rapid input changes

**Expected Results**:
- System should handle interruptions gracefully
- Current state should be preserved
- User should be able to continue where they left off

**Pass Criteria**:
- ✅ Interruptions handled gracefully
- ✅ State preservation works
- ✅ Recovery is smooth

## Regression Tests

### Test 11: Single Player Compatibility

**Objective**: Verify that single-player high scores still work correctly.

**Steps**:
1. Play a single-player game and achieve a high score
2. Verify that the original single-player UI appears
3. Complete the high score entry process

**Expected Results**:
- Single-player UI should appear for single-player sessions
- Multi-player UI should not interfere with single-player functionality
- High score saving should work as before

**Pass Criteria**:
- ✅ Single-player functionality unchanged
- ✅ Correct UI appears for single-player
- ✅ High scores save correctly

### Test 12: Existing High Score Compatibility

**Objective**: Verify that existing high scores are preserved and work with new multi-player system.

**Steps**:
1. Load a save file with existing high scores
2. Play multi-player games and achieve new high scores
3. Verify that old and new scores coexist correctly

**Expected Results**:
- Existing high scores should be preserved
- New multi-player high scores should integrate correctly
- Rankings should account for both old and new scores

**Pass Criteria**:
- ✅ Existing scores preserved
- ✅ Integration works correctly
- ✅ Rankings are accurate

## Test Results Template

For each test, record:

| Test | Status | Notes | Issues Found |
|------|--------|-------|--------------|
| Test 1 | ⏳ | | |
| Test 2 | ⏳ | | |
| Test 3 | ⏳ | | |
| Test 4 | ⏳ | | |
| Test 5 | ⏳ | | |
| Test 6 | ⏳ | | |
| Test 7 | ⏳ | | |
| Test 8 | ⏳ | | |
| Test 9 | ⏳ | | |
| Test 10 | ⏳ | | |
| Test 11 | ⏳ | | |
| Test 12 | ⏳ | | |

**Legend**: ✅ Pass | ❌ Fail | ⏳ Pending | ⚠️ Issues Found

## Notes
- Record any unexpected behavior or edge cases discovered during testing
- Note performance characteristics with different numbers of players
- Document any user experience issues or suggestions for improvement