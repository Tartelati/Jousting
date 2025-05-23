extends Node2D

# This script is attached to the main gameplay scene (main_game.tscn).
# It primarily acts as a container for the current level and UI elements during gameplay.
# The GameManager will add the level and HUD as children of the nodes within this scene.

func _ready():
	# Tell the GameManager that this scene is loaded and ready for setup.
	# Check if GameManager exists to avoid errors if run standalone
	if GameManager: 
		GameManager.setup_new_gameplay_scene(1, self)
	else:
		printerr("MainGame Scene: GameManager not found!")

# Example: If you needed to access the HUD or Level from here later:
# @onready var current_scene_node = %CurrentScene
# @onready var ui_node = %UI
