# Player Movement System Documentation

## Overview
This document outlines the redesigned movement system for our Godot 4.4 game, replacing the previous "idle, moving, decelerating" states with a more nuanced "idle, walking, flying" system. The new system introduces variable speeds, directional control mechanics, and collision handling.

## 1. Walking State

### Speed Levels
- **Speed 0 (Idle)**: 0 - Player is stationary
- **Speed 1**: 100
- **Speed 2**: 200
- **Speed 3**: 300 (Maximum)

### Walking Mechanics
- **Starting Movement**: From idle, pressing a directional input transitions the player to walking at Speed 1
- **Acceleration**: Pressing the same directional input while already walking increases speed by one level (up to Speed 3)
- **Deceleration**: Pressing the opposite directional input reduces speed by one level and triggers deceleration animation
- **Continued Deceleration**: Further opposite directional inputs continue to reduce speed until reaching idle (Speed 0)

### Collision Handling While Walking
- **Standard Collision**: If collision doesn't occur on StompArea or VulnerableArea:
  - Player changes direction (flips to face opposite way)
  - Speed decreases by one level (e.g., Speed 3 → Speed 2)
- **Collision Scenarios**:
  - Player vs Enemy
  - Enemy vs Enemy
  - Player or Enemy vs Platform
- **Enemy Collision Behavior**: Enemies change direction upon collision but maintain their preset speed (no speed reduction)

## 2. Flying State

### Speed Levels (Horizontal Movement)
- **Speed 0**: 0 - Vertical movement only (affected by gravity)
- **Speed 1**: 100
- **Speed 2**: 200
- **Speed 3**: 300 (Maximum)

### Flying Mechanics
- **Directional Control**: Directional input alone only flips the sprite to face that direction without affecting movement
- **Movement Initiation**: Requires both directional input AND flap input to move horizontally
- **Vertical Movement**: Flap input without directional input maintains current horizontal speed while elevating the player upward
- **Acceleration**: Pressing same directional input + flap while already moving increases speed by one level (up to Speed 3)
- **Changing Direction**: 
  - Opposite directional input alone only flips the sprite
  - Opposite directional input + flap decreases current speed by one level
  - Continued opposite direction + flap inputs reduce speed to 0 before beginning movement in the new direction

## State Transitions

### Idle to Flying
- **Trigger**: Pressing the flap input while in idle state (Speed 0)
- **Initial Speed**: Player begins flying at Speed 0 (no horizontal movement)
- **Movement**: Player must input flap + direction to begin horizontal movement

### Walking to Flying
- **Trigger**: Pressing the flap input while in walking state
- **Speed Preservation**: Current walking speed level is transferred to flying state
  - Example: Walking at Speed 3 → Flap input → Flying at Speed 3
- **Direction**: Maintains the same movement direction when transitioning

### Flying to Walking
- **Trigger**: Player contacts a platform while falling/flying
- **Automatic Transition**: When gravity pulls the player down to a platform
- **Speed Preservation**: Current flying horizontal speed level transfers to walking speed

### Gravity Effect
- Gravity constantly affects the player while in flying state
- If flap input stops, player begins falling until reaching a platform
- When platform contact occurs, state automatically transitions to walking

## Audio Feedback

### Walking State
- **Idle (Speed 0)**: No audio
- **Walking**: Play walking_audio
- **Speed Variations**: Audio playback speed increases with movement speed
  - Speed 1: Normal audio speed
  - Speed 2: Increased audio speed
  - Speed 3: Maximum audio speed

### Flying State
- Specific audio cues for flying state to be implemented
- Audio feedback for speed changes while flying

## Animation Integration
- Deceleration is now represented through animation rather than as a separate state
- Direction changes should trigger appropriate sprite flipping
- Speed levels may have corresponding animation variations
