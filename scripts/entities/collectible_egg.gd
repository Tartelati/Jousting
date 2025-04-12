extends Area2D

# Points awarded for collecting the egg
const COLLECT_POINTS = 50 # Or reference ScoreManager.points.egg_collect if defined there

# Preload enemy scenes for hatching
var enemy_basic_scene = preload("res://scenes/entities/enemy_base.tscn")
var enemy_hunter_scene = preload("res://scenes/entities/enemy_hunter.tscn")
var enemy_bounder_scene = preload("res://scenes/entities/enemy_bounder.tscn")
# Add other enemy types if needed

@onready var hatch_timer: Timer = $Timer
@onready var sprite: Sprite2D = $Sprite2D # Optional: for visual feedback

var _collected: bool = false # Prevent double collection/hatch

const EGG_GROUP = "collectible_eggs"

func _ready():
	print("[DEBUG Egg %s] _ready() called." % name) # DEBUG
	# Add to group for tracking
	add_to_group(EGG_GROUP)
	
	# Connect signals
	if not is_connected("area_entered", _on_area_entered):
		connect("area_entered", _on_area_entered)
		print("[DEBUG Egg %s] Connected area_entered signal." % name) # DEBUG
	else:
		print("[DEBUG Egg %s] area_entered signal ALREADY connected." % name) # DEBUG
		
	if not hatch_timer.is_connected("timeout", _on_hatch_timer_timeout):
		hatch_timer.connect("timeout", _on_hatch_timer_timeout)
		print("[DEBUG Egg %s] Connected hatch_timer timeout signal." % name) # DEBUG
	else:
		print("[DEBUG Egg %s] hatch_timer timeout signal ALREADY connected." % name) # DEBUG
	connect("area_entered", _on_area_entered)
	hatch_timer.connect("timeout", _on_hatch_timer_timeout)
	
	# Start the timer immediately
	hatch_timer.start()
	print("[DEBUG Egg %s] Hatch timer started (%.1f sec)." % [name, hatch_timer.wait_time]) # DEBUG
	
	# Optional: Add slight animation or visual cue that it's collectible/timed
	# var tween = create_tween().set_loops()
	# tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
	# tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)


func _on_area_entered(area: Area2D):
	print("[DEBUG Egg %s] _on_area_entered triggered by: %s (Parent: %s)" % [name, area.name, area.get_parent().name if area.get_parent() else "None"]) # DEBUG
	# Check if already collected or hatched
	if _collected:
		print("[DEBUG Egg %s] Area entered, but already collected/hatched. Ignoring." % name) # DEBUG
		return
		
	# Check if the entering area is the player's collection area
	var parent = area.get_parent()
	if parent and parent.is_in_group("players") and area.is_in_group("player_collectors"):
		print("[DEBUG Egg %s] Player collector area detected! Calling _collect()." % name) # DEBUG
		_collect()
	else:
		var group_check = area.is_in_group("player_collectors") if is_instance_valid(area) else "invalid area"
		var parent_group_check = parent.is_in_group("players") if is_instance_valid(parent) else "invalid parent"
		print("[DEBUG Egg %s] Area %s did not match collection criteria. Is Collector Group: %s, Parent Is Player Group: %s" % [name, area.name, group_check, parent_group_check]) # DEBUG

func _collect():
	print("[DEBUG Egg %s] _collect() called. Current _collected: %s" % [name, _collected]) # DEBUG
	if _collected: return
	_collected = true
	
	print("[DEBUG Egg %s] Egg collected by player!" % name) # DEBUG
	ScoreManager.add_score(COLLECT_POINTS)
	
	# Optional: Play collection sound via SoundManager if desired
	# SoundManager.play_sfx("egg_collect") 
	
	# Stop the hatch timer
	hatch_timer.stop()
	
	# Remove the egg
	print("[DEBUG Egg %s] Queueing free from _collect()." % name) # DEBUG
	queue_free()

func _on_hatch_timer_timeout():
	print("[DEBUG Hatch %s] Timer timeout. Collected: %s" % [name, _collected]) # DEBUG 1
	if _collected:
		print("[DEBUG Hatch %s] Already collected. Exiting." % name) # DEBUG 1a
		return
		
	_collected = true # Mark as hatched to prevent collection
	print("[DEBUG Hatch %s] Marked as collected (hatched)." % name) # DEBUG 2

	# Choose random enemy type
	var enemy_type_index = randi() % 3 # 0=base, 1=hunter, 2=bounder
	var enemy_scene = null
	print("[DEBUG Hatch %s] Random index: %d" % [name, enemy_type_index]) # DEBUG 3
	
	match enemy_type_index:
		0: 
			enemy_scene = enemy_basic_scene
			print("[DEBUG Hatch %s] Matched type 0 (Base)" % name) # DEBUG 4a
		1: 
			enemy_scene = enemy_hunter_scene
			print("[DEBUG Hatch %s] Matched type 1 (Hunter)" % name) # DEBUG 4b
		2: 
			enemy_scene = enemy_bounder_scene
			print("[DEBUG Hatch %s] Matched type 2 (Bounder)" % name) # DEBUG 4c
		_: 
			printerr("[DEBUG Hatch %s] Invalid random enemy type index!" % name) # DEBUG Error
			print("[DEBUG Hatch %s] Queueing free due to invalid type." % name) # DEBUG Error
			queue_free() # Remove egg if something went wrong
			return

	if enemy_scene:
		print("[DEBUG Hatch %s] Enemy scene selected: %s" % [name, enemy_scene.resource_path]) # DEBUG 5
		var enemy_instance = enemy_scene.instantiate()
		if not enemy_instance:
			printerr("[DEBUG Hatch %s] Failed to instantiate enemy scene!" % name) # DEBUG Error
			print("[DEBUG Hatch %s] Queueing free due to instantiation failure." % name) # DEBUG Error
			queue_free()
			return
			
		print("[DEBUG Hatch %s] Enemy instantiated: %s" % [name, enemy_instance.name]) # DEBUG 6
		enemy_instance.global_position = self.global_position
		
		var parent_node = get_parent()
		if parent_node:
			print("[DEBUG Hatch %s] Adding enemy %s to parent: %s" % [name, enemy_instance.name, parent_node.name]) # DEBUG 7
			parent_node.add_child(enemy_instance)
		else:
			printerr("[DEBUG Hatch %s] Could not get parent to add enemy instance! Queueing free." % name) # DEBUG Error
			queue_free() # Remove egg if parent is invalid
			return
		
		# Optional: Play hatch sound
		# SoundManager.play_sfx("egg_hatch")
	else:
		printerr("[DEBUG Hatch %s] enemy_scene is null after match statement!" % name) # DEBUG Error
		print("[DEBUG Hatch %s] Queueing free due to null enemy_scene." % name) # DEBUG Error
		queue_free()
		return

	# Remove the egg
	print("[DEBUG Hatch %s] Reached end of function. Queueing free." % name) # DEBUG 8
	queue_free()
