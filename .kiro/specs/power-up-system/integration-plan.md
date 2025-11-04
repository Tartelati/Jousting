# Power-Up System Integration Plan

## Overview

This document outlines how to integrate the Power-Up System into the existing Joust remake codebase. The integration will modify existing systems while maintaining backward compatibility and following the established architecture patterns.

## Current Codebase Analysis

### Key Components Identified:
1. **Enemy System**: `scripts/entities/enemy_base.gd` - Handles enemy defeat and egg spawning
2. **Player System**: `scripts/entities/player.gd` - Manages player state and interactions
3. **Score System**: `scripts/managers/score_manager.gd` - Handles scoring and game events
4. **Game Manager**: `scripts/managers/game_manager.gd` - Overall game state management
5. **Sound Manager**: `scripts/managers/sound_manager.gd` - Audio management

### Current Egg Mechanics:
- Enemies spawn as eggs when defeated via `defeat()` method
- Eggs are collected via `collect_egg(player_index)` method
- Collection triggers score addition and bonus calculations
- Eggs have physics (bouncing, falling) and timeout behavior

## Integration Strategy

### Phase 1: Core Power System Infrastructure

#### 1.1 Create PowerManager (New Component)
**Location**: `scripts/managers/power_manager.gd`

**Responsibilities**:
- Manage power-up types and configurations
- Track active powers per player
- Handle power activation/deactivation
- Coordinate with other systems

**Key Methods**:
```gdscript
class_name PowerManager
extends Node

# Power type definitions
enum PowerType { INVINCIBILITY }

# Configuration
var power_configs = {
    PowerType.INVINCIBILITY: {
        "duration": 10.0,
        "spawn_chance": 0.15  # 15% chance
    }
}

# Active powers tracking
var active_powers: Dictionary = {}  # player_index -> PowerData

func should_spawn_power_egg(enemy_type: String) -> bool
func activate_power(player_index: int, power_type: PowerType)
func deactivate_power(player_index: int)
func is_power_active(player_index: int, power_type: PowerType) -> bool
func get_remaining_duration(player_index: int) -> float
```

#### 1.2 Create PowerEgg Scene (New Component)
**Location**: `scenes/entities/power_egg.tscn`

**Structure**:
- Inherits from existing egg structure
- Different visual appearance (color/glow effect)
- Same physics properties as normal eggs
- Special collection behavior

#### 1.3 Create PowerEgg Script (New Component)
**Location**: `scripts/entities/power_egg.gd`

**Extends**: `enemy_base.gd` or create separate egg base class

**Key Features**:
- Visual distinction from normal eggs
- Power type identification
- Collection triggers power activation

### Phase 2: Modify Existing Systems

#### 2.1 Modify Enemy Base Class
**File**: `scripts/entities/enemy_base.gd`

**Changes**:
```gdscript
# Add power egg spawning logic to defeat() method
func defeat(player_velocity: Vector2 = Vector2.ZERO, player_index: int = 1, award_score: bool = true):
    # ... existing defeat logic ...
    
    # NEW: Check if should spawn power egg instead of normal egg
    var power_manager = get_node("/root/PowerManager")
    if power_manager and power_manager.should_spawn_power_egg(get_script().get_path()):
        _spawn_power_egg()
    else:
        # Continue with normal egg behavior
        _spawn_normal_egg()

func _spawn_power_egg():
    # Replace current egg with power egg
    # Maintain same physics and position
    pass

func _spawn_normal_egg():
    # Existing egg spawning logic (extracted from defeat method)
    pass
```

#### 2.2 Modify Player Class
**File**: `scripts/entities/player.gd`

**Changes**:
```gdscript
# Add power state tracking
var active_power_type: PowerManager.PowerType = -1
var power_end_time: float = 0.0
var is_power_active: bool = false

# Add power visual effects
@onready var power_effect_sprite: AnimatedSprite2D = $PowerEffectSprite

# Modify collision detection for invincibility
func _on_combat_area_area_entered(area):
    if is_power_active and active_power_type == PowerManager.PowerType.INVINCIBILITY:
        # Handle invincibility collision (defeat enemies on contact)
        _handle_invincibility_collision(area)
    else:
        # Existing collision logic
        _handle_normal_collision(area)

# Add power activation method
func activate_power(power_type: PowerManager.PowerType, duration: float):
    active_power_type = power_type
    power_end_time = Time.get_time_dict_from_system().unix + duration
    is_power_active = true
    _apply_power_effects(power_type)

# Add power deactivation method
func deactivate_power():
    if is_power_active:
        _remove_power_effects(active_power_type)
        is_power_active = false
        active_power_type = -1
```

#### 2.3 Modify Score Manager
**File**: `scripts/managers/score_manager.gd`

**Changes**:
```gdscript
# Add power-related signals
signal power_collected(player_index: int, power_type: int)
signal power_activated(player_index: int, power_type: int)
signal power_expired(player_index: int, power_type: int)

# Add power collection scoring
func add_power_collection_score(player_index: int, power_type: int):
    var base_score = 200  # Power eggs worth more than normal eggs
    add_score(player_index, base_score)
    emit_signal("power_collected", player_index, power_type)
```

#### 2.4 Modify Game Manager
**File**: `scripts/managers/game_manager.gd`

**Changes**:
```gdscript
# Add PowerManager as autoload or child
func _ready():
    # ... existing code ...
    
    # Initialize power system
    var power_manager = PowerManager.new()
    power_manager.name = "PowerManager"
    add_child(power_manager)
```

### Phase 3: Audio and Visual Integration

#### 3.1 Sound Manager Integration
**File**: `scripts/managers/sound_manager.gd`

**New Audio Events**:
- Power egg spawn sound
- Power egg collection sound
- Power activation sound
- Power expiration warning sound
- Invincibility ambient sound (looping)

#### 3.2 Visual Effects System
**New Components**:
- Power egg glow/particle effects
- Player invincibility visual overlay
- Power duration UI indicator
- Power expiration warning effects

### Phase 4: UI Integration

#### 4.1 HUD Modifications
**File**: `scripts/ui/hud.gd`

**New Elements**:
- Power status indicators per player
- Power duration timers
- Power type icons

#### 4.2 Notification System Integration
**File**: `scripts/ui/notification_system.gd`

**New Notifications**:
- "Power-Up Collected!" messages
- "Invincibility Active!" status
- "Power Expiring Soon!" warnings

## Implementation Order

### Step 1: Core Infrastructure
1. Create `PowerManager` class
2. Create `PowerEgg` scene and script
3. Add power system to `GameManager`

### Step 2: Basic Integration
1. Modify `enemy_base.gd` for power egg spawning
2. Modify `player.gd` for power collection
3. Test basic spawn and collection mechanics

### Step 3: Invincibility Power
1. Implement invincibility collision logic
2. Add visual effects for invincibility
3. Add audio feedback
4. Test invincibility mechanics

### Step 4: UI and Polish
1. Add HUD power indicators
2. Integrate notification system
3. Add particle effects and polish
4. Comprehensive testing

### Step 5: Configuration and Balancing
1. Add configuration options
2. Balance spawn rates and durations
3. Add debug tools for testing
4. Performance optimization

## File Structure Changes

### New Files:
```
scripts/managers/power_manager.gd
scripts/entities/power_egg.gd
scenes/entities/power_egg.tscn
scenes/effects/power_activation_effect.tscn
scenes/effects/invincibility_overlay.tscn
```

### Modified Files:
```
scripts/entities/enemy_base.gd
scripts/entities/player.gd
scripts/managers/score_manager.gd
scripts/managers/game_manager.gd
scripts/managers/sound_manager.gd
scripts/ui/hud.gd
scripts/ui/notification_system.gd
```

## Configuration System

### Power Configuration Structure:
```gdscript
var power_configs = {
    PowerType.INVINCIBILITY: {
        "duration": 10.0,
        "spawn_chance": 0.15,
        "enemy_spawn_rates": {
            "enemy_base": 0.15,
            "enemy_hunter": 0.20,
            "shadow_lord": 0.25
        },
        "visual_effects": {
            "player_overlay": "invincibility_glow",
            "collection_effect": "power_burst"
        },
        "audio": {
            "collection": "power_collect",
            "activation": "invincibility_start",
            "ambient": "invincibility_loop",
            "expiration": "power_expire"
        }
    }
}
```

## Testing Strategy

### Unit Tests:
- PowerManager power activation/deactivation
- Power egg spawning probability
- Player invincibility collision detection
- Power duration timing

### Integration Tests:
- Enemy defeat → power egg spawn → collection → activation flow
- Multi-player power independence
- Power effect stacking prevention
- Audio/visual feedback coordination

### Manual Tests:
- Gameplay feel and balance
- Visual effect quality
- Audio mixing and timing
- UI responsiveness and clarity

## Backward Compatibility

### Ensuring Compatibility:
1. All existing egg mechanics remain unchanged when power eggs don't spawn
2. Player collision detection falls back to normal behavior when no power active
3. Score system continues to work normally for regular eggs
4. No changes to save/load systems initially

### Migration Path:
1. Power system can be disabled via configuration
2. Gradual rollout possible by setting spawn rates to 0
3. Easy to add new power types without breaking existing ones

## Performance Considerations

### Optimization Points:
1. Power effect updates only when powers are active
2. Visual effects pooling for power eggs and effects
3. Efficient collision detection for invincibility
4. Minimal overhead when no powers are active

### Memory Management:
1. Power eggs use same physics as normal eggs
2. Visual effects cleaned up on power expiration
3. Audio streams properly managed
4. No memory leaks in power state tracking

This integration plan provides a comprehensive roadmap for implementing the power-up system while maintaining the existing codebase's integrity and performance.