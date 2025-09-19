# Manual GameOver UI Test Guide

This document provides a comprehensive manual testing guide for the enhanced GameOver UI name entry and validation system.

## Prerequisites

1. Ensure the high score save system is properly implemented
2. Have a game session ready where you can achieve a qualifying high score
3. Access to the GameOver scene for testing

## Test Scenarios

### Test 1: Basic Name Entry Display

**Objective**: Verify that the name entry UI appears correctly for qualifying scores

**Steps**:
1. Start a game session
2. Achieve a score that qualifies for the high score list (higher than existing scores)
3. Trigger game over

**Expected Results**:
- ✅ High score container becomes visible
- ✅ "NEW HIGH SCORE!" message is displayed prominently
- ✅ Name entry field is visible and focused
- ✅ Character count shows "0/20 characters"
- ✅ Submit and Skip buttons are visible
- ✅ Validation message area is empty initially

### Test 2: Real-time Name Validation

**Objective**: Test that validation feedback appears as the user types

**Steps**:
1. Achieve a qualifying high score to show name entry
2. Type various names and observe real-time feedback

**Test Cases**:

#### Valid Name
- **Input**: "TestPlayer"
- **Expected**: Character count shows "10/20 characters", no validation errors, submit button enabled

#### Name Too Long
- **Input**: "ThisNameIsWayTooLongForTheCharacterLimit"
- **Expected**: 
  - Character count shows "42/20 characters" in red
  - Validation message: "Name too long (max 20 characters)" in red
  - Submit button disabled

#### Invalid Characters
- **Input**: "Test@Player#123"
- **Expected**:
  - Validation message: "Some characters will be removed: 'TestPlayer123'" in yellow
  - Character count in yellow
  - Submit button remains enabled

#### Whitespace Only
- **Input**: "   " (spaces only)
- **Expected**:
  - Validation message: "Name cannot be only spaces" in red
  - Submit button disabled

#### Empty Name
- **Input**: "" (empty)
- **Expected**:
  - Character count shows "0/20 characters"
  - No validation errors
  - Submit button enabled (will use "Anonymous")

### Test 3: Character Count Display

**Objective**: Verify character count updates correctly and uses appropriate colors

**Steps**:
1. Type names of various lengths
2. Observe character count display

**Test Cases**:
- **0 characters**: "0/20 characters" in white
- **10 characters**: "10/20 characters" in white  
- **20 characters**: "20/20 characters" in white
- **25 characters**: "25/20 characters" in red

### Test 4: Submit Button State

**Objective**: Verify submit button is properly enabled/disabled based on validation

**Test Cases**:
- **Valid name**: Button enabled
- **Empty name**: Button enabled (will use Anonymous)
- **Name too long**: Button disabled
- **Whitespace only**: Button disabled
- **Invalid characters**: Button enabled (characters will be filtered)

### Test 5: Name Submission

**Objective**: Test successful name submission

**Steps**:
1. Enter a valid name: "TestPlayer"
2. Click Submit button OR press Enter key
3. Observe the result

**Expected Results**:
- ✅ High score container disappears
- ✅ High score list is updated with new entry
- ✅ Success feedback is shown (if implemented)
- ✅ Game over screen remains functional

### Test 6: Skip Functionality

**Objective**: Test skip button behavior

**Steps**:
1. Enter any text in name field
2. Click Skip button
3. Observe the result

**Expected Results**:
- ✅ Name field is cleared
- ✅ Score is submitted with "Anonymous" name
- ✅ High score container disappears
- ✅ High score list shows "Anonymous" entry

### Test 7: Enter Key Submission

**Objective**: Test keyboard submission

**Steps**:
1. Enter a valid name
2. Press Enter key while name field is focused
3. Observe the result

**Expected Results**:
- ✅ Score is submitted with entered name
- ✅ Same behavior as clicking Submit button

### Test 8: Personal Best Detection

**Objective**: Test personal best message display

**Setup**: Ensure there's an existing score for a player name in the high score list

**Steps**:
1. Achieve a score higher than the existing score for that player name
2. Observe the high score message

**Expected Results**:
- ✅ Message shows "NEW PERSONAL BEST!" instead of "NEW HIGH SCORE!"
- ✅ All other functionality works the same

### Test 9: Non-Qualifying Score

**Objective**: Verify behavior when score doesn't qualify

**Steps**:
1. Achieve a score that doesn't qualify for high score list
2. Trigger game over

**Expected Results**:
- ✅ High score container remains hidden
- ✅ Regular game over screen is shown
- ✅ No name entry interface appears

### Test 10: Error Handling

**Objective**: Test error feedback for failed submissions

**Setup**: This may require temporarily modifying the save system to simulate failures

**Steps**:
1. Enter a valid name
2. Submit (with simulated save failure)
3. Observe error handling

**Expected Results**:
- ✅ Error message is displayed in red
- ✅ Name entry remains available for retry
- ✅ User can attempt submission again

### Test 11: Visual Feedback and Colors

**Objective**: Verify proper color coding for different states

**Visual Checks**:
- ✅ High score message in gold/yellow color
- ✅ Error messages in red
- ✅ Warning messages in yellow
- ✅ Character count in red when over limit
- ✅ Character count in yellow for warnings
- ✅ Character count in white for normal state

### Test 12: Accessibility and Usability

**Objective**: Test user experience aspects

**Checks**:
- ✅ Name field automatically receives focus
- ✅ Tab navigation works between fields
- ✅ Text is readable and appropriately sized
- ✅ Buttons are appropriately sized and positioned
- ✅ Feedback messages are clear and helpful

## Edge Cases to Test

### Edge Case 1: Rapid Typing
- Type very quickly and observe if validation keeps up
- Expected: Validation should update smoothly without lag

### Edge Case 2: Copy/Paste Long Text
- Copy a very long text and paste into name field
- Expected: Text should be truncated and validation should trigger

### Edge Case 3: Special Unicode Characters
- Try entering emoji or special Unicode characters
- Expected: Characters should be filtered out appropriately

### Edge Case 4: Multiple Rapid Submissions
- Try clicking submit button multiple times rapidly
- Expected: Should not cause duplicate submissions or errors

## Performance Tests

### Performance Test 1: Validation Speed
- Enter a 20-character name and observe response time
- Expected: Validation should be instantaneous

### Performance Test 2: UI Responsiveness
- Interact with UI elements while validation is running
- Expected: UI should remain responsive

## Regression Tests

After implementing the enhanced UI, verify that:
- ✅ Existing game over functionality still works
- ✅ High score display is still correct
- ✅ Game restart and main menu buttons still work
- ✅ Game over music and animations still play
- ✅ Multi-player scenarios still work correctly

## Test Results Template

Use this template to record your test results:

```
Test Date: ___________
Tester: ___________
Game Version: ___________

Test 1 - Basic Name Entry Display: ✅/❌
Test 2 - Real-time Validation: ✅/❌
Test 3 - Character Count: ✅/❌
Test 4 - Submit Button State: ✅/❌
Test 5 - Name Submission: ✅/❌
Test 6 - Skip Functionality: ✅/❌
Test 7 - Enter Key Submission: ✅/❌
Test 8 - Personal Best Detection: ✅/❌
Test 9 - Non-Qualifying Score: ✅/❌
Test 10 - Error Handling: ✅/❌
Test 11 - Visual Feedback: ✅/❌
Test 12 - Accessibility: ✅/❌

Edge Cases: ✅/❌
Performance: ✅/❌
Regression: ✅/❌

Notes:
_________________________________
_________________________________
_________________________________
```

## Troubleshooting Common Issues

### Issue: Name entry doesn't appear
- **Check**: Score actually qualifies for high score list
- **Check**: High score container visibility in scene
- **Check**: ScoreManager is properly initialized

### Issue: Validation messages don't update
- **Check**: Signal connections for text_changed
- **Check**: Validator is properly instantiated
- **Check**: UI references are correct

### Issue: Submit button doesn't work
- **Check**: Button signal connections
- **Check**: ScoreManager submit_high_score method exists
- **Check**: Button is not disabled by validation

### Issue: Character count is wrong
- **Check**: String length calculation
- **Check**: Unicode character handling
- **Check**: Text field content vs display

This manual testing guide ensures comprehensive coverage of the enhanced GameOver UI functionality and helps identify any issues before release.