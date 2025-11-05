# Manual Power System Comprehensive Test Guide

This guide provides instructions for manually running and verifying the comprehensive power system test suite.

## Test Files Created

The comprehensive test suite consists of the following files:

### Unit Tests
- `tests/unit/test_power_system_comprehensive.gd` - Core power system functionality tests
- `tests/unit/test_power_system_performance.gd` - Performance and load testing
- `tests/unit/test_power_manager_error_handling.gd` - Error handling and edge cases (existing)

### Integration Tests
- `tests/integration_power_system_comprehensive_test.gd` - End-to-end integration testing
- `tests/test_player_power_integration.gd` - Player-power integration (existing)
- `tests/integration_power_egg_test.gd` - Power egg functionality (existing)

### Test Runner
- `tests/test_power_system_comprehensive_runner.gd` - Comprehensive test runner
- `tests/test_power_system_comprehensive_runner.tscn` - Test runner scene

## Running the Tests

### Method 1: Using the Test Runner Scene
1. Open Godot Editor
2. Navigate to `tests/test_power_system_comprehensive_runner.tscn`
3. Run the scene (F6 or click Play Scene)
4. Watch the console output for test results

### Method 2: Running Individual Test Files
1. Open Godot Editor
2. Navigate to any test file (e.g., `tests/unit/test_power_system_comprehensive.gd`)
3. Run the scene containing the test script
4. Check console output for results

### Method 3: Command Line (if Godot is in PATH)
```bash
godot --headless --script tests/test_power_system_comprehensive_runner.gd
```

## Test Coverage

The comprehensive test suite covers all requirements from the power system specification:

### ✅ Power Activation/Deactivation Logic
- Basic power activation and deactivation
- Power state tracking and validation
- Power replacement scenarios
- Invalid input handling

### ✅ Spawn Probability Verification
- 15% base spawn rate for EnemyBase
- 20% spawn rate for EnemyHunter  
- 25% spawn rate for ShadowLord
- Statistical validation with large sample sizes
- Invalid enemy type handling

### ✅ Power Duration and Expiration Timing
- Duration tracking accuracy
- Automatic expiration after configured time
- Warning signals at 3 seconds remaining
- Manual expiration handling
- Timer system failure recovery

### ✅ Player Invincibility Collision Detection
- Collision mask changes during invincibility
- Visual effect activation/deactivation
- Sprite modulation changes
- Combat area monitoring
- Enemy defeat on contact simulation

### ✅ Multi-Player Power Independence
- Independent power tracking for 4 players
- Simultaneous power activation
- Selective power deactivation
- Power replacement per player
- Cross-player interference prevention

### ✅ Performance Testing
- Single power activation performance
- Multiple simultaneous powers performance
- Spawn probability calculation performance
- Memory usage stability
- Concurrent operations performance
- Large-scale stress testing

### ✅ Error Handling and Edge Cases
- Invalid player indices
- Invalid power types
- Missing player references
- Corrupted power data
- Configuration system failures
- Timer system failures
- Memory leak prevention

## Expected Test Results

When running the comprehensive test suite, you should see:

### Unit Tests
- **Comprehensive Unit Tests**: ~25 tests covering core functionality
- **Error Handling Tests**: ~15 tests covering edge cases
- **Performance Unit Tests**: ~8 tests covering performance metrics

### Integration Tests
- **Comprehensive Integration Tests**: End-to-end flow validation
- **Player Power Integration Tests**: Player-power system integration

### Performance Benchmarks
- Power activation: < 1 second for 1000 operations
- Power updates: < 2 seconds for 600 update cycles
- Memory stability: No memory leaks after 100 cycles

## Troubleshooting

### Common Issues

1. **PowerManager not found**
   - Ensure PowerManager is properly configured as an autoload
   - Check that the power system is fully implemented

2. **Player scene loading failures**
   - Verify player scene paths are correct
   - Ensure player scenes have required components

3. **Performance test timeouts**
   - Performance tests may take longer on slower systems
   - Adjust timeout thresholds if needed

4. **Signal connection errors**
   - Ensure PowerManager signals are properly defined
   - Check signal parameter compatibility

### Verification Steps

1. **All tests pass**: Look for "🎉 ALL TESTS PASSED!" message
2. **No critical errors**: No "❌ CRITICAL" messages in output
3. **Performance within limits**: All benchmarks complete within expected timeframes
4. **Memory stability**: No memory leaks detected
5. **Requirements coverage**: All requirements validated

## Test Maintenance

### Adding New Tests
1. Add test methods to appropriate test files
2. Follow naming convention: `test_[functionality]`
3. Use TestBase assertion methods
4. Include requirement references in comments

### Updating Test Expectations
1. Adjust performance thresholds as needed
2. Update spawn rate tolerances for statistical tests
3. Modify timeout values for slower systems

### Test Data Cleanup
- Tests automatically clean up after themselves
- PowerManager state is reset between tests
- No manual cleanup required

## Requirements Validation Summary

This comprehensive test suite validates all power system requirements:

- ✅ **Requirement 1**: Power Egg Spawning System
- ✅ **Requirement 2**: Power Collection and Activation  
- ✅ **Requirement 3**: Invincibility Power Implementation
- ✅ **Requirement 4**: Power Duration and Management
- ✅ **Requirement 5**: Audio and Visual Feedback
- ✅ **Requirement 6**: Multi-Player Power Support
- ✅ **Requirement 7**: Power System Configuration

The test suite provides comprehensive coverage of all power system functionality, ensuring the implementation meets all specified requirements and performs reliably under various conditions.