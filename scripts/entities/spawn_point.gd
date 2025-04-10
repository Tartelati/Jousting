# scripts/entities/spawn_point.gd
extends Marker2D

# Flag to indicate if the player is currently inside the detection zone.
var is_player_nearby: bool = false

# Reference to the detection zone Area2D. 
# Assumes the Area2D is the FIRST child of this Marker2D.
@onready var detection_zone: Area2D = get_child(0) if get_child_count() > 0 and get_child(0) is Area2D else null

func _ready():
	if not detection_zone:
		printerr("SpawnPoint %s: No Area2D found as the first child!" % name)
		return
		
	# Connect signals from the Area2D to detect the player's CharacterBody2D
	detection_zone.connect("body_entered", _on_detection_zone_body_entered)
	detection_zone.connect("body_exited", _on_detection_zone_body_exited)
	
	# Initial check in case player starts inside the zone
	# Use call_deferred to wait for physics state to be available
	call_deferred("_check_initial_overlap")

func _check_initial_overlap():
	if not detection_zone: return 
	
	var overlapping_bodies = detection_zone.get_overlapping_bodies()
	for body in overlapping_bodies:
		# Check if the overlapping body is the player (assuming player is in "players" group)
		if body.is_in_group("players"):
			is_player_nearby = true
			# print("SpawnPoint %s initially blocked by player body." % name) # Optional debug
			return # Found player

func _on_detection_zone_body_entered(body: Node2D):
	# Check if the body entering is the player
	if body.is_in_group("players"):
		is_player_nearby = true
		# print("SpawnPoint %s blocked by player body entering." % name) # Optional debug

func _on_detection_zone_body_exited(body: Node2D):
	# Check if the body exiting is the player
	if body.is_in_group("players"):
		# Check if *any other* player bodies are still inside before unblocking
		# Use call_deferred to wait for physics state update after exit signal
		call_deferred("_check_remaining_overlap", body)

func _check_remaining_overlap(exited_body: Node2D):
	if not detection_zone: return

	var still_overlapping = false
	for other_body in detection_zone.get_overlapping_bodies():
		# Check if it's a player and not the one that just exited (though exited body shouldn't be in list)
		if other_body.is_in_group("players"): 
			still_overlapping = true
			break
			
	if not still_overlapping:
		is_player_nearby = false
		# print("SpawnPoint %s unblocked by player body exiting." % name) # Optional debug

# Helper function for the WaveManager
func can_spawn() -> bool:
	return not is_player_nearby
