extends Control

signal quit

func _ready():
	# Connect button signals
	$AnimationPlayer/QuitButton.connect("pressed", _on_quit_pressed)

func _on_quit_pressed():
	emit_signal("quit")


func _on_quit_button_pressed() -> void:
	pass # Replace with function body.
