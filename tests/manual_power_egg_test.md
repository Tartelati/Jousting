# PowerEgg Manual Testing Guide

This document provides manual testing procedures for the PowerEgg entity and collection system.

## Prerequisites

1. Ensure PowerManager is loaded in the scene tree at `/root/PowerManager`
2. Ensure ScoreManager is available for score tracking
3. Have at least one player in the scene for collection testing

## Test Cases

### Test 1: PowerEgg Scene Loading
**Objective**: Verify PowerEgg scene loads correctly

**Steps**:
1. Open Godot editor
2. Navigate to `scenes/entities/power_egg.tscn`
3. Open the scene
4. Verify the scene structure includes:
   - PowerEgg (RigidBody2D) with script attached
   - AnimatedSprite2D for main sprite
   - GlowEffect (AnimatedSprite2D) for visual effects
   - CollectionArea (Area2D) for player interaction
   - SpawnEffect (GPUParticles2D) for spawn effects
   - TimeoutTimer for cleanup
   - SpawnSound and CollectionSound audio players

**Expected Result**: Scene loads without errors and contains all required nodes

### Test 2: PowerEgg Instantiation
**Objective**: Verify PowerEgg can be instantiated programmatically

**Steps**:
1. Open a test scene or create a new scene
2. Add a script to instantiate PowerEgg:
   ```gdscript
   var power_egg_scene = preload("res://scenes/entities/power_egg.tscn")
   var power_egg = power_egg_scene.instantiate()
   add_child(power_egg)
   ```
3. Run the scene

**Expected Result**: 
- PowerEgg appears in the scene
- Golden color/glow effect is visible
- No error messages in console
- PowerEgg is added to "power_eggs" group

### Test 3: PowerEgg Physics
**Objective**: Verify PowerEgg has correct physics properties

**Steps**:
1. Instantiate a PowerEgg in a scene with platforms
2. Position it above a platform
3. Run the scene and observe physics behavior

**Expected Result**:
- PowerEgg falls due to gravity
- Bounces when hitting platforms (similar to normal eggs)
- Eventually settles on the platform
- Collision layers are correct (egg layer 4, environment mask 2)

### Test 4: PowerEgg Visual Appearance
**Objective**: Verify PowerEgg has distinctive visual appearance

**Steps**:
1. Instantiate both a PowerEgg and a normal egg in the same scene
2. Compare their visual appearance

**Expected Result**:
- PowerEgg has golden color (Color(1.0, 0.8, 0.3))
- PowerEgg has glow effect with golden tint
- PowerEgg is visually distinct from normal eggs
- Glow effect animates/pulses

### Test 5: PowerEgg Collection Area
**Objective**: Verify collection area is properly configured

**Steps**:
1. Instantiate a PowerEgg
2. Check the CollectionArea node properties in the inspector

**Expected Result**:
- CollectionArea is in "power_egg_collection_zones" group
- Collision layer is 32 (pickup layer)
- Collision mask is 32 (pickup layer)
- Monitoring and monitorable are enabled
- Area has appropriate collision shape (circle with radius ~20)

### Test 6: PowerEgg Timeout System
**Objective**: Verify PowerEgg disappears after timeout

**Steps**:
1. Instantiate a PowerEgg in a scene
2. Wait 15 seconds without collecting it
3. Observe behavior

**Expected Result**:
- PowerEgg remains visible for 15 seconds
- After 15 seconds, PowerEgg disappears (queue_free called)
- No memory leaks or errors

### Test 7: PowerEgg Collection by Player
**Objective**: Verify player can collect PowerEgg

**Steps**:
1. Set up a scene with a player and a PowerEgg
2. Move the player to touch the PowerEgg
3. Observe collection behavior

**Expected Result**:
- When player touches PowerEgg, collection is triggered
- PowerEgg disappears immediately
- Score increases by 200 points (base collection points)
- If collected before touching ground, bonus "Power Air Catch" score added
- PowerManager.activate_power() is called for the collecting player

### Test 8: PowerEgg Collection Sound Effects
**Objective**: Verify audio feedback during PowerEgg lifecycle

**Steps**:
1. Instantiate a PowerEgg (should play spawn sound)
2. Collect the PowerEgg with a player (should play collection sound)

**Expected Result**:
- Spawn sound plays when PowerEgg is created
- Collection sound plays when PowerEgg is collected
- No audio errors or missing sound warnings

### Test 9: PowerEgg Integration with PowerManager
**Objective**: Verify PowerEgg properly integrates with PowerManager

**Steps**:
1. Ensure PowerManager is in the scene tree
2. Instantiate and collect a PowerEgg with a player
3. Check PowerManager state

**Expected Result**:
- PowerManager.activate_power() is called with correct player_index and power_type
- Power activation succeeds (returns true)
- Player receives invincibility power effect
- Debug messages show successful power activation

### Test 10: Multiple PowerEgg Handling
**Objective**: Verify multiple PowerEggs work independently

**Steps**:
1. Instantiate multiple PowerEggs in different locations
2. Collect them with different players
3. Let some timeout without collection

**Expected Result**:
- Each PowerEgg operates independently
- Collection by one player doesn't affect other PowerEggs
- Timeout system works for each PowerEgg individually
- No interference between multiple PowerEggs

### Test 11: PowerEgg Screen Wrapping
**Objective**: Verify PowerEgg handles screen boundaries correctly

**Steps**:
1. Instantiate a PowerEgg near screen edge
2. Give it horizontal velocity to move off-screen
3. Observe behavior

**Expected Result**:
- PowerEgg wraps around screen edges (like normal eggs)
- No visual glitches during wrapping
- Physics properties maintained after wrapping

### Test 12: PowerEgg Error Handling
**Objective**: Verify PowerEgg handles error conditions gracefully

**Steps**:
1. Test collection when PowerManager is not available
2. Test collection with invalid player index
3. Test double collection attempts

**Expected Result**:
- Missing PowerManager: Collection still awards points, logs warning
- Invalid player index: Handled gracefully, no crashes
- Double collection: Second attempt ignored, no errors
- All error conditions logged appropriately

## Integration Testing

### Test 13: Enemy → PowerEgg Spawn Flow
**Objective**: Verify complete enemy defeat to PowerEgg spawn workflow

**Steps**:
1. Set up scene with enemy and player
2. Defeat enemy (stomp or joust)
3. Observe egg spawning behavior

**Expected Result**:
- Based on spawn chance, sometimes PowerEgg spawns instead of normal egg
- PowerEgg inherits enemy's position and physics
- PowerEgg has same bounce behavior as normal egg
- Visual distinction is immediately apparent

### Test 14: PowerEgg → Power Activation Flow
**Objective**: Verify complete PowerEgg collection to power activation workflow

**Steps**:
1. Spawn PowerEgg (manually or via enemy defeat)
2. Collect with player
3. Verify power activation

**Expected Result**:
- Collection triggers power activation
- Player receives invincibility power
- Visual effects appear on player
- Power duration timer starts
- All systems work together seamlessly

## Performance Testing

### Test 15: Multiple PowerEgg Performance
**Objective**: Verify performance with many PowerEggs

**Steps**:
1. Instantiate 10+ PowerEggs simultaneously
2. Monitor frame rate and memory usage
3. Collect some, let others timeout

**Expected Result**:
- No significant frame rate drops
- Memory usage remains stable
- All PowerEggs function correctly
- Cleanup happens properly

## Debugging Tips

1. **Enable Debug Output**: PowerEgg includes debug print statements for collection events
2. **Check Groups**: Verify PowerEgg is in "power_eggs" group and CollectionArea is in "power_egg_collection_zones"
3. **Collision Layers**: Use Godot's collision layer visualization to verify layer setup
4. **PowerManager**: Check `/root/PowerManager` exists and has required methods
5. **Player Setup**: Ensure player CollectionArea has correct collision mask (56) to detect PowerEggs

## Common Issues

1. **PowerEgg Not Collecting**: Check player CollectionArea collision mask includes layer 5 (pickup)
2. **No Visual Effects**: Verify GlowEffect node is present and modulate color is set
3. **Physics Issues**: Check RigidBody2D collision layers match normal eggs
4. **Audio Missing**: Verify AudioStreamPlayer2D nodes exist (sounds may be placeholder files)
5. **PowerManager Errors**: Ensure PowerManager is loaded before PowerEgg instantiation

## Success Criteria

All tests should pass with:
- ✅ No error messages in console
- ✅ Expected visual and audio feedback
- ✅ Proper integration with existing systems
- ✅ Stable performance
- ✅ Graceful error handling