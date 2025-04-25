extends Control

# Path to the main menu scene - adjust if your path is different
const MAIN_MENU_SCENE_PATH = "res://scenes/ui/main_menu.tscn"
const INTRO_DELAY: float = 5.0 # Seconds to wait after sound starts

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var spray_sound: AudioStreamPlayer = %SpraySound
@onready var black_background: ColorRect = %BlackBackground # Ensure this line remains commented out if unused

var _is_skipping: bool = false # Flag to prevent double transition
var _is_waiting_for_input: bool = false

func _ready():
	# Play the sound immediately
	if spray_sound:
		spray_sound.play()
	else:
		printerr("OpeningCinematic: SpraySound node not found!")

	# Wait for the specified delay
	await get_tree().create_timer(INTRO_DELAY).timeout
	
	# Check if we skipped during the delay
	if _is_skipping:
		return

	# Now start the animation
	if animation_player:
		# Connect the signal for when the animation finishes (can be done here or earlier)
		if not animation_player.is_connected("animation_finished", _on_animation_finished):
			animation_player.connect("animation_finished", _on_animation_finished)
		
		# Play the animation named "intro"
		animation_player.play("intro")
	else:
		printerr("OpeningCinematic: AnimationPlayer node not found after delay!")
		# Fallback: Go directly to main menu if animation player is missing
		_go_to_main_menu()
		
# This function is called by the Call Method Track keyframe you created
func _pause_for_input() -> void:
	if animation_player and animation_player.is_playing():
		animation_player.pause()
		_is_waiting_for_input = true
		print("Intro animation paused, waiting for input.")
		# Optional: Show the prompt label
		# if continue_prompt: continue_prompt.show()

func _unhandled_input(event):
	# Ensure the node is ready and in the tree before processing input
	if not is_inside_tree():
		return
		
	# Check for the skip action (default: Escape key)
	if event.is_action_pressed("ui_cancel") and not _is_skipping:
		print("Skipping cinematic...")
		_skip_cinematic()
		# Removed set_input_as_handled() as it seems to cause errors during transition


func _skip_cinematic():
	if _is_skipping: # Prevent multiple calls
		return
	_is_skipping = true
	
	# Stop sound and animation
	if spray_sound:
		spray_sound.stop()
	if animation_player:
		animation_player.stop() # Stop playback
		# Optional: Reset animation if needed animation_player.seek(0, true) 
		
	# Go to main menu immediately
	_go_to_main_menu()

func _on_animation_finished(anim_name: StringName):
	# Check if the correct animation finished and we haven't already skipped
	if anim_name == "intro" and not _is_skipping:
		_go_to_main_menu()

func _go_to_main_menu():
	# Ensure we only transition once
	if get_tree().current_scene.scene_file_path == scene_file_path: 
		print("Transitioning to Main Menu...")
	# Change the scene to the main menu
	var error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if error != OK:
		printerr("Failed to change scene to Main Menu: ", error)
