extends Control

signal quit

@onready var animation_player: AnimationPlayer = %AnimationPlayer


func _ready():
	$AnimationPlayer.play()
	
	# Connect button signals
	$AnimationPlayer/QuitButton.connect("pressed", _on_quit_pressed)
	
	# Play the animation. Replace "your_animation_name" with the actual
	# name of the animation you created in the AnimationPlayer.
	if animation_player:
		animation_player.play("DemoShowcase")
	else:
		printerr("Demo Showcase: AnimationPlayer node not found!")

func _on_quit_pressed():
	emit_signal("quit")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
