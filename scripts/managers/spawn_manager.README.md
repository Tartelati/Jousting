# Godot 4.x - Register this as an autoload singleton in project settings for global access
# Usage: SpawnManager.queue_spawn(...), SpawnManager.queue_player_spawn(...)
#
# To use:
# - WaveManager: call queue_spawn_batch([...]) with enemy scenes and data
# - Player: call queue_player_spawn(player_scene, {"player_index": 1}, callback)
#
# The manager will emit 'all_spawns_completed' when all queued spawns are done.
#
# You may want to add this to autoloads:
# [autoload]
# SpawnManager="*res://scripts/managers/spawn_manager.gd"
