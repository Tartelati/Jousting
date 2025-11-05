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
- Power-up system with collectible power eggs and temporary special abilities (Tasks 1-8 complete - ready for gameplay testing and balancing)
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
- Dynamic player joining during gameplay
- Controller and keyboard support
- Independent player state management
- Collision and interaction systems between players

## Development Specifications

The project includes detailed specifications for ongoing development:

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

### Power-Up System 🔄 IN DEVELOPMENT - Core Mechanics Complete
A comprehensive power-up system with core mechanics now functional. This system adds temporary special abilities through collectible power eggs. See `.kiro/specs/power-up-system/` for detailed requirements, design, and implementation documentation:

**Implemented Features:**
- **✅ Power Egg Spawning**: 15% chance for power eggs to spawn instead of normal eggs when enemies are defeated
- **✅ Invincibility Power**: Temporary invulnerability with enemy-defeating contact ability (10-second duration)
- **✅ Collection System**: Physics-based power egg collection with immediate activation
- **✅ PowerManager Infrastructure**: Complete power system with multi-player support and timer management
- **✅ Player Integration**: Full invincibility mechanics with collision detection and bonus scoring
- **✅ Enemy Integration**: Enemy defeat mechanics enhanced with power egg spawning logic
- **✅ Configuration System**: Adjustable spawn rates, durations, and effects for gameplay balancing
- **✅ Timer Management**: Power duration tracking with expiration warnings and automatic cleanup

**Recently Completed:**
- **✅ Visual Effects**: Enhanced power egg appearance, player power indicators, and activation effects
- **✅ Audio Feedback**: Complete audio system for spawning, collection, activation, and expiration
- **✅ Multi-Player UI**: Per-player power status indicators with duration timers and visual feedback
- **✅ Configuration System**: External configuration file, runtime parameter adjustment, and developer tools

**Implementation Status:**
- **✅ Requirements**: Complete user stories and acceptance criteria defined
- **✅ Design Document**: Comprehensive architecture and component design completed
- **✅ Integration Plan**: Detailed plan for integrating with existing codebase
- **✅ Implementation Tasks**: 14-phase development roadmap with clear milestones
- **✅ Tasks 1-8 Complete**: Core infrastructure, PowerEgg entity, enemy integration, player mechanics, visual effects, audio system, multi-player UI, and configuration system
- **✅ Task 2 - PowerEgg Entity**: PowerEgg entity and collection system complete
- **✅ Task 3 - Enemy Integration**: Enemy defeat mechanics integration complete
- **✅ Task 4 - Player Mechanics**: Player invincibility power implementation complete
- **✅ Task 5 - Visual Effects**: Visual effects system complete
- **✅ Task 6 - Audio System**: Comprehensive audio feedback system complete
- **🔄 Task 7 - Multi-Player UI**: Multi-player UI integration **IN PROGRESS**

## Getting Started

To run the game, follow these steps:
1. Clone the repository: `git clone https://github.com/Tartelati/Jousting.git`
2. Open the project in Godot 4.4
3. Ensure the required addons are enabled in Project Settings > Plugins:
   - `multiplayer_input` (for controller support)
4. Run the main scene to start the game

**Note**: The project uses a built-in testing framework and does not require the GUT (Godot Unit Test) addon.

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

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
