# Manual Power Analytics System Test

## Overview
This document provides manual testing procedures for the Power Analytics and Telemetry system (Task 12).

## Test Environment Setup

1. **Enable Debug Mode**
   - Press F7 to enable debug mode
   - Press F1 to open the debug UI
   - Navigate to the "Analytics" tab

2. **Enable Performance Monitoring**
   - In the debug UI, check "Performance Monitoring"
   - Navigate to the "Performance" tab to view metrics

3. **Enable Visualizations**
   - Press F11 to toggle spawn visualization
   - Press F12 to toggle collection heatmap
   - Press Insert to toggle power timer display
   - Press Home to toggle performance overlay

## Test Procedures

### 1. Spawn Rate Analytics Test

**Objective**: Verify spawn attempt and success tracking

**Steps**:
1. Start a game with enemies
2. Defeat 20-30 enemies
3. Open debug UI → Analytics tab
4. Verify spawn statistics show:
   - Total spawn attempts > 0
   - Successful spawns tracked
   - Spawn rate approximately matches configuration (15% default)

**Expected Results**:
- Spawn attempts increment with each enemy defeat
- Successful spawns show golden power eggs
- Actual spawn rate within 5% of expected rate (with sufficient sample size)

### 2. Collection Analytics Test

**Objective**: Verify power collection tracking

**Steps**:
1. Force spawn power eggs using F2 (debug hotkey)
2. Collect power eggs with different players
3. Check Analytics tab for:
   - Power collection counts by type
   - Player behavior data
   - Collection positions in heatmap

**Expected Results**:
- Collection counts increment correctly
- Each player's collections tracked separately
- Heatmap shows collection locations (F12 to visualize)

### 3. Power Effectiveness Analytics Test

**Objective**: Verify power usage effectiveness tracking

**Steps**:
1. Activate invincibility power (F3 or collect power egg)
2. Defeat enemies while invincible
3. Let power expire naturally
4. Check Analytics tab for:
   - Average enemies defeated per activation
   - Power duration usage efficiency
   - Effectiveness score

**Expected Results**:
- Enemy defeats during power tracked
- Duration usage calculated (used vs. total time)
- Effectiveness score reflects power utility

### 4. Multi-Player Analytics Test

**Objective**: Verify independent player tracking

**Steps**:
1. Start 2-4 player game
2. Have different players collect and use powers
3. Verify Analytics tab shows:
   - Separate behavior data for each player
   - Individual collection patterns
   - Player-specific effectiveness metrics

**Expected Results**:
- Each player tracked independently
- Player behavior analysis shows preferences
- No cross-contamination between player data

### 5. Performance Monitoring Test

**Objective**: Verify performance metrics tracking

**Steps**:
1. Enable performance overlay (Home key)
2. Activate multiple powers simultaneously
3. Create high-activity scenarios (many enemies, effects)
4. Check Performance tab for:
   - Frame rate metrics
   - Performance score
   - Issue detection (frame drops, audio stutters)

**Expected Results**:
- Real-time FPS display
- Performance score reflects system load
- Warnings for performance issues

### 6. Balance Analysis Test

**Objective**: Verify balance analysis tools

**Steps**:
1. Generate significant test data (50+ spawn attempts)
2. Click "Balance Analysis" button in debug UI
3. Review console output for:
   - Spawn rate recommendations
   - Power effectiveness analysis
   - Balance insights

**Expected Results**:
- Recommendations based on actual vs. expected rates
- Effectiveness analysis with actionable insights
- Clear balance recommendations

### 7. Visualization System Test

**Objective**: Verify debug visualization features

**Steps**:
1. Enable spawn visualization (F11)
2. Enable collection heatmap (F12)
3. Enable timer display (Insert)
4. Play game and observe:
   - Spawn location markers (yellow/red circles)
   - Collection heatmap (colored dots)
   - Power timer displays

**Expected Results**:
- Visual markers appear at spawn locations
- Successful spawns show different colors
- Collection heatmap shows player activity patterns
- Timer displays show remaining power duration

### 8. Data Export Test

**Objective**: Verify analytics data export

**Steps**:
1. Generate test data through gameplay
2. Click "Export Report" button in debug UI
3. Check user:// directory for exported files
4. Open exported JSON file and verify:
   - Session information
   - Spawn analysis data
   - Player behavior data
   - Performance metrics

**Expected Results**:
- Export completes successfully
- JSON file contains comprehensive analytics data
- Data structure is well-organized and readable

### 9. Error Reporting Test

**Objective**: Verify error tracking and health monitoring

**Steps**:
1. Create error conditions (invalid player indices, missing components)
2. Check Analytics tab for error reports
3. Verify error details include:
   - Error type and message
   - Timestamp and session ID
   - Context information

**Expected Results**:
- Errors tracked without crashing system
- Error reports contain useful debugging information
- System continues functioning after errors

### 10. Real-Time Updates Test

**Objective**: Verify real-time analytics updates

**Steps**:
1. Keep debug UI open during gameplay
2. Perform various power system actions
3. Observe real-time updates in:
   - Statistics counters
   - Performance metrics
   - Active power displays

**Expected Results**:
- Analytics update immediately after events
- No significant lag in data display
- Consistent data across different UI sections

## Performance Benchmarks

### Acceptable Performance Criteria:
- **Frame Rate**: Should maintain 60 FPS with analytics enabled
- **Memory Usage**: No significant memory leaks during extended play
- **Processing Overhead**: Analytics processing should not cause noticeable gameplay lag

### Performance Test Procedure:
1. Enable performance monitoring
2. Play for 10+ minutes with active power usage
3. Monitor performance overlay for:
   - Consistent frame rate
   - Stable memory usage
   - Low performance issue count

## Troubleshooting

### Common Issues:

1. **Analytics Not Updating**
   - Verify PowerAnalytics node is in scene tree
   - Check debug mode is enabled
   - Ensure proper signal connections

2. **Visualization Not Showing**
   - Press appropriate hotkeys (F11, F12, Insert, Home)
   - Verify PowerVisualization node exists
   - Check if visualization data is being generated

3. **Export Failing**
   - Check file permissions in user:// directory
   - Verify sufficient disk space
   - Ensure analytics data exists before export

4. **Performance Issues**
   - Disable unnecessary visualizations
   - Reduce performance monitoring frequency
   - Check for memory leaks in long sessions

## Success Criteria

The analytics system passes manual testing if:

✅ All spawn attempts and successes are accurately tracked  
✅ Power collections and activations are recorded per player  
✅ Effectiveness metrics provide meaningful insights  
✅ Performance monitoring detects and reports issues  
✅ Balance analysis provides actionable recommendations  
✅ Visualizations display correctly and update in real-time  
✅ Data export produces comprehensive, well-structured reports  
✅ Error tracking captures issues without system failure  
✅ System maintains good performance with analytics enabled  
✅ Multi-player scenarios work correctly with independent tracking  

## Notes

- Test with different player counts (1-4 players)
- Verify system works across different game modes
- Test with various enemy types and spawn rates
- Ensure compatibility with existing power system features
- Document any performance impact or limitations discovered