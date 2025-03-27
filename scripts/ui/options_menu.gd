extends Control

signal closed

@onready var master_slider = $Panel/VBoxContainer/MasterVolumeSlider
@onready var music_slider = $Panel/VBoxContainer/MusicVolumeSlider
@onready var sfx_slider = $Panel/VBoxContainer/SFXVolumeSlider

func _ready():
	# Set initial slider values
	var sound_manager = get_node("/root/SoundManager")
	master_slider.value = sound_manager.master_volume
	music_slider.value = sound_manager.music_volume
	sfx_slider.value = sound_manager.sfx_volume
	
	# Connect slider signals
	master_slider.connect("value_changed", _on_master_volume_changed)
	music_slider.connect("value_changed", _on_music_volume_changed)
	sfx_slider.connect("value_changed", _on_sfx_volume_changed)
	
	# Connect back button
	$Panel/VBoxContainer/BackButton.connect("pressed", _on_back_pressed)

func _on_master_volume_changed(value):
	get_node("/root/SoundManager").set_master_volume(value)

func _on_music_volume_changed(value):
	get_node("/root/SoundManager").set_music_volume(value)

func _on_sfx_volume_changed(value):
	get_node("/root/SoundManager").set_sfx_volume(value)

func _on_back_pressed():
	emit_signal("closed")
