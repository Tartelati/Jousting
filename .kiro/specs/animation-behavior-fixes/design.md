# Design Document

## Overview

This design addresses two specific animation and behavior issues in the game:

1. **Player Defeated Animation Fix**: The current defeated animation uses unpredictable movement patterns. We need to constrain it to horizontal-only movement using cosine/sine mathematical functions for smooth oscillation.

2. **Egg-to-Bird Collection Behavior**: Currently, when a player collects an egg after a rescue bird has spawned, the bird disappears immediately. We need to modify this so the bird speeds up and completes its screen traversal instead.

## Architecture

### Current System Analysis

**Player Defeated State:**
- Located in `scripts/entities/player.gd`
- Uses `defeated_fly_time` and `defeated_fly_direction` variables
- Current physics applies sine wave to Y velocity: `velocity.y += sine_offset * delta`
- Problem: This creates unpredictable vertical movement patterns

**Egg-to-Bird System:**
- Enemy defeat creates egg state in `enemy_base.gd`
- Hatch timer triggers `spawn_rescue_bird()` after egg settles
- Rescue bird moves toward egg position and rescues it
- Problem: Bird disappears when egg is collected, regardless of bird position

## Components and Interfaces

### 1. Player Defeated Animation Component

**Location**: `scripts/entities/player.gd` - `_physics_process()` method

**Current Implementation**:
```gdscript
if current_state == State.DEFEATED:
    defeated_fly_time += delta
    defeated_time += delta
    # Sine wave: amplitude 30px, period 1.5s
    var sine_offset = 30.0 * sin(defeated_fly_time * 4.0)
    velocity.y += sine_offset * delta
    move_and_slide()
```

**Required Changes**:
- Remove vertical sine wave application to velocity.y
- Apply horizontal cosine/sine movement to position.x directly
- Maintain defeated_fly_direction for consistent horizontal movement
- Keep existing screen boundary and respawn logic

### 2. Rescue Bird Behavior Component

**Location**: `scripts/entities/rescue_bird.gd`

**Current Implementation**:
- Bird moves toward target_x at constant speed
- Bird disappears when reaching target enemy
- No communication with egg collection system

**Required Changes**:
- Add speed_multiplier property for acceleration
- Add reference tracking between bird and egg
- Modify bird behavior when egg is collected
- Implement screen traversal completion logic

### 3. Egg Collection Integration

**Location**: `scripts/entities/enemy_base.gd` - `collect_egg()` method

**Current Implementation**:
- Egg collection immediately destroys enemy
- No communication with associated rescue bird

**Required Changes**:
- Check for associated rescue bird before destruction
- Signal bird to speed up instead of disappearing
- Allow bird to complete traversal independently

## Data Models

### Enhanced Player State
```gdscript
# Existing variables
var defeated_fly_time: float = 0.0
var defeated_fly_direction: int = 1
var defeated_time: float = 0.0

# New variables for horizontal movement
var defeated_base_x: float = 0.0  # Starting X position for oscillation
var defeated_oscillation_amplitude: float = 60.0  # Horizontal movement range
```

### Enhanced Rescue Bird State
```gdscript
# Existing variables
var move_speed: float = 100.0
var direction: int = 1
var target_enemy: Node = null

# New variables for speed control
var base_speed: float = 100.0
var speed_multiplier: float = 1.0
var is_speeding_up: bool = false
var egg_was_collected: bool = false
```

### Egg-Bird Association
```gdscript
# In enemy_base.gd
var associated_rescue_bird: Node = null  # Reference to spawned bird
```

## Error Handling

### Player Animation Safeguards
- Validate defeated_fly_direction is not zero
- Clamp horizontal movement within screen boundaries
- Fallback to simple horizontal movement if cosine/sine calculations fail

### Bird-Egg Communication
- Handle cases where bird reference becomes invalid
- Graceful degradation if egg is collected before bird spawns
- Prevent memory leaks from circular references

### Screen Boundary Management
- Ensure birds complete traversal even with speed changes
- Handle edge cases where birds might get stuck at screen edges
- Validate viewport dimensions before calculating traversal paths

## Testing Strategy

### Unit Tests
- Test horizontal cosine/sine movement calculations
- Verify speed multiplier effects on bird movement
- Test egg-bird reference management

### Integration Tests
- Test complete defeated animation cycle with horizontal-only movement
- Test egg collection with active rescue bird
- Test bird speed-up and traversal completion
- Test edge cases (bird at screen edge when egg collected)

### Manual Testing Scenarios
1. **Defeated Animation**: Defeat player and observe horizontal-only movement pattern
2. **Normal Egg Collection**: Collect egg before bird spawns (existing behavior)
3. **Bird Speed-up**: Let egg hatch, spawn bird, then collect egg while bird is mid-traversal
4. **Edge Cases**: Test bird behavior when egg collected at various bird positions

## Implementation Phases

### Phase 1: Player Defeated Animation Fix
1. Modify defeated state physics in `player.gd`
2. Replace vertical sine wave with horizontal cosine movement
3. Set defeated_base_x when entering defeated state
4. Test horizontal-only movement patterns

### Phase 2: Bird-Egg Communication System
1. Add bird reference tracking in `enemy_base.gd`
2. Modify `spawn_rescue_bird()` to store bird reference
3. Update `collect_egg()` to check for active bird
4. Add speed-up mechanism to `rescue_bird.gd`

### Phase 3: Screen Traversal Completion
1. Implement speed multiplier in bird movement
2. Add traversal completion logic
3. Handle bird cleanup after screen exit
4. Test various collection timing scenarios

## Technical Considerations

### Performance Impact
- Minimal performance impact expected
- Cosine/sine calculations are lightweight
- Bird reference tracking adds negligible memory overhead

### Backward Compatibility
- Changes maintain existing game mechanics
- No breaking changes to save data or player progress
- Existing egg collection scoring remains unchanged

### Animation Timing
- Defeated animation maintains same duration (3 seconds)
- Bird speed-up should be noticeable but not jarring
- Smooth transitions between normal and accelerated bird movement