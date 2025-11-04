extends Node

func _ready():
	print("Starting Enemy Power Egg Integration Test Runner...")
	
	# Ensure PowerManager is available
	if not get_node_or_null("/root/PowerManager"):
		print("PowerManager not found, adding it...")
		var power_manager_script = preload("res://scripts/managers/power_manager.gd")
		var power_manager = power_manager_script.new()
		power_manager.name = "PowerManager"
		get_tree().root.add_child(power_manager)
	
	# Ensure ScoreManager is available
	if not get_node_or_null("/root/ScoreManager"):
		print("ScoreManager not found - tests may have limited functionality")
	
	# Run the test
	var test = preload("res://tests/integration_enemy_power_egg_test.gd").new()
	add_child(test)
	test.run_tests()
	
	# Exit after a short delay
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()