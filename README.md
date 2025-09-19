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
- High score system with persistent storage
- Dynamic player joining and controller support

## Game Systems

### Score Management
The game features a comprehensive scoring system that tracks player performance across multiple sessions:

- **Real-time Scoring**: Points awarded for defeating enemies, collecting eggs, and completing waves
- **High Score Persistence**: Scores are automatically saved to local storage and persist across game sessions
- **Multi-player Support**: Independent score tracking for up to 4 players simultaneously
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

### High Score Save System
A comprehensive high score persistence system has been implemented with robust features. See `.kiro/specs/high-score-save-system/` for detailed requirements, design, and implementation plans including:

- **✅ Data Validation**: Complete HighScoreValidator class with comprehensive score and name validation
- **✅ Robust Data Persistence**: Complete HighScoreStorage class with automatic saving, backup and recovery mechanisms
- **✅ Enhanced ScoreManager**: Fully integrated enhanced ScoreManager with new persistence features and backward compatibility
- **✅ ScoreManager Integration**: Complete integration with HighScoreStorage and HighScoreValidator, including enhanced submission methods, automatic saving, error handling, and comprehensive testing
- **✅ Data Migration System**: Migration system with version tracking, backward compatibility, and save file recovery
- **✅ Enhanced Name Entry UI**: Complete enhanced name entry and validation UI with real-time feedback, character filtering, and comprehensive testing
- **✅ Player Name Entry**: Validation and sanitization of player names for high scores
- **✅ Error Handling**: Graceful degradation when storage is unavailable, with comprehensive error recovery
- **✅ Session Tracking**: Unique session IDs and current session score marking
- **✅ Multi-player Integration**: Support for multiple players achieving high scores in single sessions
- **Configuration Management**: Customizable settings for score limits and storage locations (in progress)

## Getting Started

To run the game, follow these steps:
1. Clone the repository: `git clone https://github.com/Tartelati/Jousting.git`
2. Open the project in Godot 4.4
3. Ensure the multiplayer_input addon is enabled in Project Settings
4. Run the main scene to start the game

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
2. Update documentation for any new features
3. Test multiplayer functionality thoroughly
4. Consider the impact on the high score system

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
