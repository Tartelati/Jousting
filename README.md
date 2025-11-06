# Jousting

This repository is a remake of the classic Atari Joust game. The project is created as a hobby to learn the Godot 4.4 engine.

## Overview

Jousting is a 2D platformer game developed using GDScript, the scripting language for Godot. The aim of this project is to recreate the gameplay and mechanics of the original Atari Joust game while exploring the features and capabilities of the Godot 4.4 engine.

## Features

- Classic Joust gameplay mechanics
- 2D platforming with physics-based movement
- Enemy AI and challenging levels
- Retro-inspired graphics and sound effects
- Multiplayer support (up to 4 players)
- Enhanced high score system with robust persistence, validation, and user feedback
- Power-up system with collectible power eggs and temporary special abilities (✅ COMPLETE - All 14 tasks finished, fully integrated and production-ready)
- Dynamic player joining and controller support
- Type-safe code with explicit type annotations for better Godot 4 compatibility

## Game Systems

### Score Management
The game features a comprehensive scoring system that tracks player performance across multiple sessions:

- **Real-time Scoring**: Points awarded for defeating enemies, collecting eggs, and completing waves
- **Enhanced High Score System**: Robust persistence with data validation, backup/recovery, and migration support
- **User Feedback**: Animated notifications for achievements, personal bests, and save confirmations
- **Multi-player Support**: Independent score tracking for up to 4 players simultaneously
- **Name Entry**: Real-time validation with character filtering and user-friendly error messages
- **High Score Display**: Formatted display with current session highlighting and responsive UI
- **Bonus System**: Special bonuses for air catches and other skilled maneuvers

### Player Movement System
Advanced physics-based movement with multiple states:

- **Walking**: Ground-based movement with speed acceleration (3 speed levels)
- **Flying**: Aerial movement with flapping mechanics and momentum conservation
- **Braking**: Deceleration system when changing directions
- **State Transitions**: Smooth transitions between movement states

### Multiplayer Features
- Dynamic player joining during gameplay (up to 4 players)
- Controller and keyboard support with automatic device assignment
- Independent player state management
- Collision and interaction systems between players
- **Complete Player Scene Support**: All 4 player scenes (player1-4.tscn) properly configured and loading without errors
- **Resource Loading Stability**: Resolved all preload issues for reliable debug mode launching

## Development Specifications

The project includes detailed specifications for ongoing development:

### Godot Resource Loading Fix ✅ COMPLETE
A systematic resolution of resource loading issues that prevented debug mode from launching. See `.kiro/specs/godot-resource-loading-fix/` for detailed requirements, design, and implementation documentation:

**Resolution Summary:**
- **✅ Problem Diagnosis**: Systematic testing identified player3.tscn as the corrupted file causing preload errors
- **✅ Safe File Replacement**: Recreated player3.tscn with minimal working structure to eliminate resource conflicts
- **✅ GameManager Integration**: Restored all player scene preloads for full 4-player multiplayer support
- **✅ Verification Testing**: Confirmed stable debug mode launching and preserved all existing functionality

**Technical Achievement**: Resolved resource loading conflicts through targeted file replacement without affecting other working components, enabling reliable development environment and full multiplayer capability.

### High Score Save System ✅ COMPLETE
A comprehensive high score persistence system has been fully implemented with all 9 major tasks complete. See `.kiro/specs/high-score-save-system/` for detailed requirements, design, and implementation documentation:

**Core System Components:**
- **✅ Data Validation**: Complete HighScoreValidator class with comprehensive score and name validation
- **✅ Robust Data Persistence**: Complete HighScoreStorage class with automatic saving, backup and recovery mechanisms
- **✅ Enhanced ScoreManager**: Fully integrated enhanced ScoreManager with new persistence features and backward compatibility
- **✅ Data Migration System**: Migration system with version tracking, backward compatibility, and save file recovery

**User Experience Features:**
- **✅ Enhanced Name Entry UI**: Real-time validation with character filtering and user-friendly feedback
- **✅ High Score Display System**: Formatted display with proper number formatting, date display, and current session highlighting
- **✅ User Feedback System**: Animated notifications for achievements, errors, and personal bests
- **✅ Multi-player High Score Support**: Sequential name entry for multiple qualifying players with independent validation

**Technical Features:**
- **✅ Error Handling**: Graceful degradation when storage is unavailable, with comprehensive error recovery
- **✅ Session Tracking**: Unique session IDs and current session score marking
- **✅ Comprehensive Testing**: Full test coverage including unit, integration, and manual testing suites

**Deferred Features:**
- **📋 Task 10**: Main menu integration with dedicated high score viewing screen (deferred for future development)

### Power-Up System ✅ COMPLETE - Production Ready
A comprehensive power-up system with all mechanics fully implemented, tested, and integrated. This system adds temporary special abilities through collectible power eggs. See `.kiro/specs/power-up-system/` for detailed requirements, design, and implementation documentation:

**Implemented Features:**
- **✅ Power Egg Spawning**: 15% chance for power eggs to spawn instead of normal eggs when enemies are defeated
- **✅ Invincibility Power**: Temporary invulnerability with enemy-defeating contact ability (10-second duration)
- **✅ Collection System**: Physics-based power egg collection with immediate activation
- **✅ PowerManager Infrastructure**: Complete power system with multi-player support and timer management
- **✅ Player Integration**: Full invincibility mechanics with collision detection and bonus scoring
- **✅ Enemy Integration**: Enemy defeat mechanics enhanced with power egg spawning logic
- **✅ Configuration System**: Adjustable spawn rates, durations, and effects for gameplay balancing
- **✅ Timer Management**: Power duration tracking with expiration warnings and automatic cleanup
- **✅ Error Handling**: Comprehensive error handling and graceful fallbacks for all edge cases

**Advanced Features:**
- **✅ Visual Effects**: Enhanced power egg appearance, player power indicators, and activation effects
- **✅ Audio Feedback**: Complete audio system for spawning, collection, activation, and expiration
- **✅ Multi-Player UI**: Per-player power status indicators with duration timers and visual feedback
- **✅ Configuration System**: External configuration file, runtime parameter adjustment, and developer tools
- **✅ Error Handling**: Graceful fallbacks, resource loading protection, and edge case management
- **✅ Testing Suite**: Comprehensive unit, integration, and performance tests
- **✅ Visual Polish**: Advanced particle effects and screen effects for enhanced visual appeal
- **✅ Analytics System**: Power usage tracking and balance analysis tools with debug visualization
- **✅ Final Integration**: Complete GameManager integration with comprehensive gameplay testing

**Implementation Status:**
- **✅ Requirements**: Complete user stories and acceptance criteria defined
- **✅ Design Document**: Comprehensive architecture and component design completed
- **✅ Integration Plan**: Detailed plan for integrating with existing codebase
- **✅ Implementation Tasks**: All 14 development tasks completed
- **✅ Tasks 1-14 Complete**: Entire power-up system fully implemented and production-ready

## Getting Started

To run the game, follow these steps:
1. Clone the repository: `git clone https://github.com/Tartelati/Jousting.git`
2. Open the project in Godot 4.4
3. Ensure the required addons are enabled in Project Settings > Plugins:
   - `multiplayer_input` (for controller support)
4. Run the main scene to start the game

**Note**: The project uses a built-in testing framework and does not require the GUT (Godot Unit Test) addon.

### Recent Fixes
- **✅ Resource Loading Resolution**: Systematically resolved all resource loading issues affecting debug mode
- **✅ Player 3 Scene Fix**: Recreated corrupted player3.tscn with minimal working structure using safe file replacement
- **✅ Full 4-Player Support**: All player scenes (player1-4.tscn) now load correctly with complete multiplayer functionality
- **✅ Debug Mode Stability**: Eliminated parser errors preventing debug mode from launching

### Testing
The project includes comprehensive testing with a built-in framework:
- **Simple Framework**: Built-in `TestBase` class with all necessary assertion methods and proper lifecycle management
- **Test Coverage**: All high score system components have full unit and integration test coverage
- **Test Execution**: Run `tests/simple_test_runner.tscn` to execute all test suites
- **Manual Testing**: Detailed test procedures available in the `tests/` directory
- **Test Types**: Unit tests, integration tests, and manual testing scenarios
- **Inheritance Support**: Proper `super.before_each()` and `super.after_each()` calls ensure consistent test behavior
- **Type Safety**: Enhanced with explicit type annotations for better Godot 4 compatibility
- **No Dependencies**: Works out of the box without external addons or plugins

### Controls
- **Player 1**: Arrow keys to move, Space to flap
- **Player 2-4**: Controller support with dynamic assignment
- **Menu Navigation**: Arrow keys or controller D-pad

## Project Structure

```
├── scripts/
│   ├── entities/          # Player and enemy logic
│   ├── managers/          # Game systems (Score, Game, Sound, Spawn)
│   └── ui/               # User interface components
├── scenes/
│   ├── entities/         # Player and enemy scenes
│   ├── levels/           # Game level scenes
│   └── ui/              # UI scenes
├── assets/
│   ├── sprites/         # Game artwork and animations
│   ├── sounds/          # Audio files
│   └── fonts/           # Typography assets
└── .kiro/
    └── specs/           # Development specifications and documentation
```

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests to improve the game.

When contributing:
1. Follow the existing code style and structure
2. Use explicit type annotations for better type safety (Godot 4 best practice)
3. Update documentation for any new features
4. Test multiplayer functionality thoroughly
5. Consider the impact on the high score system

### Resource Loading Best Practices
When working with scene files:
- Use systematic testing (enable scenes one by one) to isolate loading issues
- Prefer safe file replacement over cache manipulation for corrupted scenes
- Maintain backup files during scene recreation
- Verify all preload statements after scene modifications

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
