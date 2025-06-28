# SpawnManager.gd
# Godot 4.x - Handles all entity and player spawning, spawn point management, and spawn queue
extends Node

signal all_spawns_completed
signal entity_spawned(entity)

# Queue of spawn requests: {type, scene, data, callback, is_player}
var spawn_queue: Array = []
# List of busy spawn points (by Node reference)
var busy_spawn_points: Array = []
# All available spawn points (populated at _ready or via refresh)
var spawn_points: Array = []

# Debug state variables for reduced print spam
var _last_free_points_count: int = -1
var _waiting_for_spawn_points: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	refresh_spawn_points()

func refresh_spawn_points():
	spawn_points.clear()
	var parent = get_parent()
	if parent:
		_find_spawn_points_recursive(parent)

func _find_spawn_points_recursive(node):
	for child in node.get_children():
		if child.is_in_group("SpawnPoints"):
			spawn_points.append(child)
		_find_spawn_points_recursive(child)

# Add a spawn request to the queue
func queue_spawn(scene: PackedScene, data: Dictionary = {}, is_player: bool = false, callback: Callable = Callable()):
	print("[SpawnManager] queue_spawn called. Scene:", scene, "is_player:", is_player, "data:", data)
	spawn_queue.append({
		"scene": scene,
		"data": data,
		"is_player": is_player,
		"callback": callback
	})
	print("[SpawnManager] Current queue size:", spawn_queue.size())
	# If this is the only item, start processing
	if spawn_queue.size() == 1:
		print("[SpawnManager] Starting process_next_spawn() from queue_spawn")
		process_next_spawn()

# For wave manager: queue a batch of enemies
func queue_spawn_batch(spawn_list: Array):
	print("[SpawnManager] queue_spawn_batch called. List size:", spawn_list.size())
	for entry in spawn_list:
		print("[SpawnManager] queue_spawn_batch entry:", entry)
		queue_spawn(entry.scene, entry.data, false, entry.callback if "callback" in entry else Callable())

# For player respawn
func queue_player_spawn(scene: PackedScene, data: Dictionary = {}, callback: Callable = Callable()):
	queue_spawn(scene, data, true, callback)

# Main spawn loop
func process_next_spawn():
	# Only print when queue is not empty and we are about to try spawning
	if spawn_queue.is_empty():
		print("[SpawnManager] All spawns completed. Emitting signal.")
		emit_signal("all_spawns_completed")
		return
	# Only print when we actually have a change in free spawn points
	var free_points = spawn_points.filter(func(p): return not busy_spawn_points.has(p))
	if _last_free_points_count != free_points.size():
		print("[SpawnManager] Free spawn points:", free_points.size())
		_last_free_points_count = free_points.size()
	if free_points.is_empty():
		# Only print once per block of waiting
		if not _waiting_for_spawn_points:
			print("[SpawnManager] No free spawn points. Waiting...")
			_waiting_for_spawn_points = true
		await get_tree().process_frame
		process_next_spawn()
		return
	_waiting_for_spawn_points = false
	# Find a free spawn point
	var spawn_data = spawn_queue[0]
	var spawn_point = free_points.pick_random()
	print("[SpawnManager] Spawning entity at point:", spawn_point)
	busy_spawn_points.append(spawn_point)
	# Instance the entity
	var entity = spawn_data.scene.instantiate()
	entity.global_position = spawn_point.global_position
	print("[SpawnManager] Instantiated entity:", entity)
	# Pass custom data (e.g. player_index) if needed
	for k in spawn_data.data:
		entity.set(k, spawn_data.data[k])
	# Add to scene
	get_parent().add_child(entity)
	print("[SpawnManager] Entity added to scene.")
	emit_signal("entity_spawned", entity)
	# Connect to animation finished (assume entity has 'spawn_animation_finished' signal or similar)
	if entity.has_signal("spawn_animation_finished"):
		entity.connect("spawn_animation_finished", Callable(self, "_on_spawn_animation_finished").bind(spawn_point, entity, spawn_data.callback))
	else:
		# Fallback: use a timer if no signal
		print("[SpawnManager] No spawn_animation_finished signal. Using fallback timer.")
		await get_tree().create_timer(1.0).timeout
		_on_spawn_animation_finished(spawn_point, entity, spawn_data.callback)

func _on_spawn_animation_finished(spawn_point, entity, callback):
	if busy_spawn_points.has(spawn_point):
		busy_spawn_points.erase(spawn_point)
	# Remove from queue
	if not spawn_queue.is_empty():
		spawn_queue.pop_front()
	# Call callback if provided
	if callback:
		callback.call(entity)
	# Spawn next in queue
	process_next_spawn()
