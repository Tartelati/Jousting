extends Node

# Sound effect players
var sfx_players = []
var num_sfx_players = 8
var current_sfx_player = 0

# Music player
var music_player = null
var current_music = ""

# Volume settings
var master_volume = 0.1
var music_volume = 0.1
var sfx_volume = 1.0

# Sound effect paths
var sfx_paths = {
	"flap": "res://assets/sounds/sfx/flap.wav",
	"collision": "res://assets/sounds/sfx/collision.wav",
	"defeat": "res://assets/sounds/sfx/defeat.wav",
	"egg_collect": "res://assets/sounds/sfx/egg_collect.wav",
	"player_death": "res://assets/sounds/sfx/player_death.wav",
	"wave_complete": "res://assets/sounds/sfx/wave_complete.wav",
	"game_over": "res://assets/sounds/sfx/game_over.wav",
	"pterodactyl": "res://assets/sounds/sfx/pterodactyl.wav"
}

# Music paths
var music_paths = {
	"menu": "res://assets/sounds/music/mainmenumusic_placeholder.ogg",
	#"gameplay": "res://assets/sounds/music/gameplay_music.ogg",
	#"game_over": "res://assets/sounds/music/game_over_music.ogg"
}

func _ready():
	# Create sound effect players
	for i in range(num_sfx_players):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	
	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	# Load settings
	load_settings()
	
	# Apply volume settings
	apply_volume_settings()

func play_sfx(sfx_name):
	if not sfx_paths.has(sfx_name):
		push_error("Sound effect not found: " + sfx_name)
		return
	
	# Load sound effect
	var stream = load(sfx_paths[sfx_name])
	if stream == null:
		push_error("Failed to load sound effect: " + sfx_paths[sfx_name])
		return
	
	# Find an available player
	var player = sfx_players[current_sfx_player]
	current_sfx_player = (current_sfx_player + 1) % num_sfx_players
	
	# Play the sound effect
	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume * master_volume)
	player.play()

func play_music(music_name):
	if current_music == music_name:
		return
	
	if not music_paths.has(music_name):
		push_error("Music not found: " + music_name)
		return
	
	# Load music
	var stream = load(music_paths[music_name])
	if stream == null:
		push_error("Failed to load music: " + music_paths[music_name])
		return
	
	# Fade out current music if playing
	if music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, 1.0)
		tween.tween_callback(func():
			music_player.stop()
			music_player.stream = stream
			music_player.volume_db = linear_to_db(music_volume * master_volume)
			music_player.play()
		)
	else:
		# Play new music
		music_player.stream = stream
		music_player.volume_db = linear_to_db(music_volume * master_volume)
		music_player.play()
	
	current_music = music_name

func stop_music():
	if music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, 1.0)
		tween.tween_callback(func():
			music_player.stop()
		)
	
	current_music = ""

func set_master_volume(volume):
	master_volume = clamp(volume, 0.0, 1.0)
	apply_volume_settings()
	save_settings()

func set_music_volume(volume):
	music_volume = clamp(volume, 0.0, 1.0)
	apply_volume_settings()
	save_settings()

func set_sfx_volume(volume):
	sfx_volume = clamp(volume, 0.0, 1.0)
	apply_volume_settings()
	save_settings()

func apply_volume_settings():
	# Apply to music player
	if music_player.playing:
		music_player.volume_db = linear_to_db(music_volume * master_volume)
	
	# SFX players will get the new volume next time they play

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save("user://audio_settings.cfg")

func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://audio_settings.cfg")
	
	if err == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 0.8)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
