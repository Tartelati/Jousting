# Jousting

This repository is a remake of the classic Atari Joust game. The project is created as a hobby to learn the Godot 4.4 engine.

## Overview

Jousting is a 2D platformer game developed using GDScript, the scripting language for Godot. The aim of this project is to recreate the gameplay and mechanics of the original Atari Joust game while exploring the features and capabilities of the Godot 4.4 engine.

## Features

- Classic Joust gameplay mechanics
- 2D platforming with physics-based movement
- Enemy AI and challenging levels
- Retro-inspired graphics and sound effects

## Getting Started

To run the game, follow these steps:
1. Clone the repository: `git clone https://github.com/Tartelati/Jousting.git`
2. Open the project in Godot 4.4
3. Run the main scene to start the game

## Testing

Unit tests run with the [GUT](https://github.com/bitwes/Gut) framework (v9.4.0, for Godot 4.4).

Run the suite headlessly:

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```

- Tests live in `test/unit/`, configuration in `.gutconfig.json`.
- CI runs the suite on every push/PR (see `.github/workflows/tests.yml`).
- First run (local or CI) needs an asset import: `godot --headless --import --path .`

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests to improve the game.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
