# PowerManager Manual Test Guide

This document provides manual testing procedures for the PowerManager core infrastructure.

## Test Environment Setup

1. Ensure PowerManager is loaded as an autoload in project.godot
2. Open the Godot editor and verify no errors in the output
3. Check that PowerManager appears in the Remote Inspector under autoloads

## Test Cases

### Test 1: Basic Power System Verification

**Objective**: Verify PowerManager autoload is working and basic functionality is accessible.

**Steps**:
1. Open the Godot editor
2. Go to Project > Project Settings > Autoload
3. Verify "PowerManager" is listed and enabled
4. Open the Remote Inspector (Remote > Remote Inspector)
5. Look for PowerManager in the scene tree

**Expected Results**:
- PowerManager appears in autoload list
- No errors in output console
- PowerManager node visible in Remote Inspector

### Test 2: Power Activation via Script

**Objective**: Test power activation through GDScript console.

**Steps**:
1. Open any scene in the editor
2. Add a temporary script node with this code:
```gdscript
extends Node

func _ready():
    var pm = get_node("/root/PowerManager")
    print("PowerManager found: ", pm != null)
    
    if pm:
        var result = pm.activate_power(1, pm.PowerType.INVINCIBILITY)
        print("Power activation result: ", result)
        print("Is power active: ", pm.is_power_active(1))
        print("Remaining duration: ", pm.get_remaining_duration(1))
```
3. Run the scene

**Expected Results**:
- Console shows "PowerManager found: true"
- Console shows "Power activation result: true"
- Console shows "Is power active: true"
- Console shows remaining duration around 10.0 seconds

### Test 3: Spawn Probability Testing

**Objective**: Verify spawn probability logic works correctly.

**Steps**:
1. Create a test script:
```gdscript
extends Node

func _ready():
    var pm = get_node("/root/PowerManager")
    test_spawn_rates(pm)

func test_spawn_rates(pm):
    var enemies = ["EnemyBase", "EnemyHunter", "ShadowLord"]
    
    for enemy in enemies:
        var spawn_count = 0
        for i in 100:
            if pm.should_spawn_power_egg(enemy):
                spawn_count += 1
        
        var rate = float(spawn_count) / 100.0 * 100.0
        print("%s spawn rate: %.1f%%" % [enemy, rate])
```
2. Run the script

**Expected Results**:
- EnemyBase: ~15% spawn rate
- EnemyHunter: ~20% spawn rate  
- ShadowLord: ~25% spawn rate
- Rates may vary due to randomness but should be in expected ranges

### Test 4: Multi-Player Power Independence

**Objective**: Verify powers work independently for multiple players.

**Steps**:
1. Create a test script:
```gdscript
extends Node

func _ready():
    var pm = get_node("/root/PowerManager")
    test_multi_player(pm)

func test_multi_player(pm):
    # Activate powers for players 1 and 3
    pm.activate_power(1, pm.PowerType.INVINCIBILITY)
    pm.activate_power(3, pm.PowerType.INVINCIBILITY)
    
    print("Player 1 active: ", pm.is_power_active(1))
    print("Player 2 active: ", pm.is_power_active(2))
    print("Player 3 active: ", pm.is_power_active(3))
    print("Player 4 active: ", pm.is_power_active(4))
    
    # Deactivate player 1
    pm.deactivate_power(1)
    
    print("After deactivating player 1:")
    print("Player 1 active: ", pm.is_power_active(1))
    print("Player 3 active: ", pm.is_power_active(3))
```
2. Run the script

**Expected Results**:
- Initially: Player 1 and 3 show true, Player 2 and 4 show false
- After deactivation: Player 1 shows false, Player 3 still shows true

### Test 5: Configuration System

**Objective**: Test power configuration getter/setter methods.

**Steps**:
1. Create a test script:
```gdscript
extends Node

func _ready():
    var pm = get_node("/root/PowerManager")
    test_configuration(pm)

func test_configuration(pm):
    var power_type = pm.PowerType.INVINCIBILITY
    var config = pm.get_power_config(power_type)
    
    print("Original duration: ", config.duration)
    print("Original spawn chance: ", config.spawn_chance)
    
    # Modify configuration
    pm.set_power_duration(power_type, 15.0)
    pm.set_spawn_chance(power_type, 0.25)
    
    var updated_config = pm.get_power_config(power_type)
    print("Updated duration: ", updated_config.duration)
    print("Updated spawn chance: ", updated_config.spawn_chance)
```
2. Run the script

**Expected Results**:
- Original values should match defaults (10.0 duration, 0.15 spawn chance)
- Updated values should reflect changes (15.0 duration, 0.25 spawn chance)

### Test 6: Signal System

**Objective**: Verify power event signals are emitted correctly.

**Steps**:
1. Create a test script:
```gdscript
extends Node

func _ready():
    var pm = get_node("/root/PowerManager")
    test_signals(pm)

func test_signals(pm):
    # Connect to signals
    pm.power_activated.connect(_on_power_activated)
    pm.power_expired.connect(_on_power_expired)
    
    # Activate and deactivate power
    pm.activate_power(1, pm.PowerType.INVINCIBILITY)
    await get_tree().create_timer(1.0).timeout
    pm.deactivate_power(1)

func _on_power_activated(player_index, power_type, duration):
    print("Signal: Power activated for player %d, type %d, duration %.1f" % [player_index, power_type, duration])

func _on_power_expired(player_index, power_type):
    print("Signal: Power expired for player %d, type %d" % [player_index, power_type])
```
2. Run the script

**Expected Results**:
- Console shows activation signal with correct parameters
- Console shows expiration signal after deactivation

## Integration Test Execution

To run the automated integration test:

1. Open `tests/integration_power_manager_test.tscn` in Godot
2. Run the scene (F6)
3. Check console output for test results
4. All tests should show ✓ (pass) indicators

## Troubleshooting

### PowerManager Not Found
- Check project.godot autoload configuration
- Verify script path is correct: `res://scripts/managers/power_manager.gd`
- Restart Godot editor

### Script Errors
- Check for syntax errors in power_manager.gd
- Verify all required methods are implemented
- Check console for detailed error messages

### Unexpected Behavior
- Use debug_info() method to inspect internal state
- Check signal connections are working
- Verify timer cleanup is functioning

## Success Criteria

The PowerManager core infrastructure is working correctly if:

1. ✅ PowerManager autoload is accessible
2. ✅ Power activation/deactivation works for all players (1-4)
3. ✅ Spawn probability logic returns expected rates
4. ✅ Multi-player powers work independently
5. ✅ Configuration system allows runtime changes
6. ✅ Signals are emitted for power events
7. ✅ No memory leaks or errors in console
8. ✅ Debug information is accessible and accurate