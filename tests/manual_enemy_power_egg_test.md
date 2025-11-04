# Manual Enemy Power Egg Integration Test

## Test Overview
This test verifies that the enemy defeat mechanics properly integrate with the power system to spawn power eggs based on configured spawn rates.

## Prerequisites
- PowerManager must be initialized in the scene
- Enemy scenes (enemy_base, enemy_hunter, shadowlord) must be available
- PowerEgg scene must be available

## Test Cases

### Test Case 1: Enemy Class Name Mapping
**Objective**: Verify that enemies correctly identify their class names for spawn rate lookup

**Steps**:
1. Spawn an enemy_base in the scene
2. Call `_get_enemy_class_name()` method
3. Verify it returns "EnemyBase"

**Expected Result**: Method returns "EnemyBase"

**Steps**:
1. Spawn an enemy_hunter in the scene
2. Call `_get_enemy_class_name()` method
3. Verify it returns "EnemyHunter"

**Expected Result**: Method returns "EnemyHunter"

**Steps**:
1. Spawn a shadowlord in the scene
2. Call `_get_enemy_class_name()` method
3. Verify it returns "ShadowLord"

**Expected Result**: Method returns "ShadowLord"

### Test Case 2: Power Egg Spawn Decision
**Objective**: Verify that PowerManager correctly determines when to spawn power eggs

**Steps**:
1. Call `PowerManager.should_spawn_power_egg("EnemyBase")` multiple times
2. Observe that approximately 15% of calls return true
3. Call `PowerManager.should_spawn_power_egg("EnemyHunter")` multiple times
4. Observe that approximately 20% of calls return true
5. Call `PowerManager.should_spawn_power_egg("ShadowLord")` multiple times
6. Observe that approximately 25% of calls return true

**Expected Result**: Spawn rates match configured percentages within reasonable variance

### Test Case 3: Power Egg Spawning
**Objective**: Verify that enemies spawn power eggs when conditions are met

**Steps**:
1. Spawn an enemy in the scene
2. Force the enemy to flying state
3. Call `defeat()` method on the enemy
4. Observe whether a power egg or normal egg is spawned
5. Repeat multiple times to observe spawn rate distribution

**Expected Result**: 
- Power eggs spawn at the configured rate for the enemy type
- Power eggs have golden appearance and glow effect
- Power eggs have same physics as normal eggs
- Enemy transitions to DEAD state when power egg is spawned

### Test Case 4: Normal Egg Fallback
**Objective**: Verify that normal eggs are spawned when power eggs are not selected

**Steps**:
1. Spawn an enemy in the scene
2. Force the enemy to flying state
3. Call `defeat()` method on the enemy
4. When normal egg is spawned, verify enemy transitions to EGG state
5. Verify normal egg behavior (bouncing, collection, hatching)

**Expected Result**: 
- Normal eggs spawn when power egg is not selected
- Enemy transitions to EGG state for normal eggs
- Normal egg physics and behavior work correctly

### Test Case 5: PowerManager Integration
**Objective**: Verify that enemy defeat properly integrates with PowerManager

**Steps**:
1. Ensure PowerManager is available in scene tree
2. Spawn an enemy and defeat it
3. When power egg spawns, verify it can be collected
4. Verify power activation occurs when power egg is collected
5. Verify player receives power effect

**Expected Result**: 
- PowerManager methods are called correctly
- Power eggs integrate with power activation system
- Player receives power effects when collecting power eggs

## Debug Information
- Enable debug prints in enemy_base.gd defeat() method
- Monitor console output for spawn decisions
- Check PowerManager debug info for active powers
- Verify ScoreManager integration for points

## Pass/Fail Criteria
- ✅ All enemy types correctly identify their class names
- ✅ Spawn rates match configured percentages (±5% variance acceptable)
- ✅ Power eggs spawn with correct visual appearance
- ✅ Power eggs have same physics as normal eggs
- ✅ Normal egg fallback works when power egg not selected
- ✅ PowerManager integration functions correctly
- ✅ No errors or crashes during enemy defeat process