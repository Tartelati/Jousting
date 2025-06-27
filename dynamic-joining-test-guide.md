# Dynamic Player Joining Test Guide

## Testing the Dynamic Joining System

### Setup
1. Connect multiple controllers to your computer
2. Launch the Joust game
3. Start a new game (this will spawn Player 1 with the best available device)

### Testing Controller-Based Joining

#### Expected Behavior
- Player 1 is spawned automatically at game start
- Players 2-4 can join by pressing START on an unused controller
- Each player gets a unique device assignment
- No device conflicts should occur

#### Test Steps
1. **Initial State**: Game starts with Player 1 using the best available device
   - If no controllers: Player 1 uses keyboard (device -1)
   - If controllers available: Player 1 uses controller 0

2. **Dynamic Joining**: Press START on unused controllers
   - Controller 0: Should join as Player 2 (if Player 1 is on keyboard)
   - Controller 1: Should join as Player 3
   - Controller 2: Should join as Player 4
   - Maximum 4 players supported

3. **Conflict Prevention**: Try pressing START on already-assigned controllers
   - Should see debug message: "Controller X already assigned to a player"
   - No new player should spawn

### Debug Output to Watch For

When testing, look for these debug messages in the Godot console:

#### System Initialization
```
[DEBUG] === MultiplayerInput System Test ===
[DEBUG] MultiplayerInput available: true
[DEBUG] Core actions: [start_game, move_left, move_right, flap, ...]
[DEBUG] Connected joypads: [0, 1, 2]
[DEBUG] Controller 0 device actions:
  - start_game -> 0start_game
  - move_left -> 0move_left
  ...
```

#### Player Spawning
```
[DEBUG] GameManager: Spawned Player1 at (200, 467) with device 0
```

#### Dynamic Joining
```
[DEBUG] GameManager: Active players: 1, Connected joypads: [0, 1, 2]
[DEBUG] GameManager: Controller 1 pressed START. Currently assigned devices: [0]
[DEBUG] GameManager: Adding new player 2 with controller 1
[DEBUG] GameManager: Spawned Player2 at (600, 467) with device 1 (controller-initiated)
```

#### Conflict Prevention
```
[DEBUG] GameManager: Controller 0 pressed START. Currently assigned devices: [0, 1]
[DEBUG] GameManager: Controller 0 already assigned to a player
```

### Troubleshooting

If dynamic joining isn't working:

1. **Check Controller Connection**: Ensure controllers are properly connected and recognized by Godot
2. **Input Map**: Verify "start_game" action includes joypad button events
3. **MultiplayerInput Plugin**: Ensure the plugin is enabled and autoloaded
4. **Debug Output**: Check console for debug messages to identify the issue

### Controller Button Mapping

The START button is typically:
- **Xbox Controllers**: Menu button (button_index 6)
- **PlayStation Controllers**: Options button (button_index 6)
- **Generic Controllers**: May vary, check button_index in debug output

### Known Limitations

- Maximum 4 players supported
- Only controllers can trigger dynamic joining (keyboard cannot join additional players)
- Controllers must be connected before the joining action
- Each device can only be assigned to one player at a time
