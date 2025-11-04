extends TestBase

# Integration test for enemy defeat mechanics with power egg spawning
class_name IntegrationEnemyPowerEggTest

var test_name = "Enemy Power Egg Integration Test"

func _ready():
	print("\n" + "=".repeat(50))
	print("STARTING: " + test_name)
	print("=".repeat(50))

func run_tests():
	print("\n--- Enemy Power Egg Integration Tests ---")
	
	test_enemy_class_name_mapping()
	test_power_egg_spawn_decision()
	test_normal_egg_spawn_fallback()
	test_power_manager_integration()
	
	print_results()

func test_enemy_class_name_mapping():
	print("\n🧪 Testing enemy class name mapping...")
	
	# Test enemy_base
	var enemy_base_scene = preload("res://scenes/entities/enemy_base.tscn")
	var enemy_base = enemy_base_scene.instantiate()
	add_child(enemy_base)
	
	await get_tree().process_frame
	
	var enemy_class_name = enemy_base._get_enemy_class_name()
	assert_eq(enemy_class_name, "EnemyBase", "enemy_base should map to EnemyBase")
	
	enemy_base.queue_free()
	
	# Test enemy_hunter
	var enemy_hunter_scene = preload("res://scenes/entities/enemy_hunter.tscn")
	var enemy_hunter = enemy_hunter_scene.instantiate()
	add_child(enemy_hunter)
	
	await get_tree().process_frame
	
	enemy_class_name = enemy_hunter._get_enemy_class_name()
	assert_eq(enemy_class_name, "EnemyHunter", "enemy_hunter should map to EnemyHunter")
	
	enemy_hunter.queue_free()
	
	# Test shadowlord
	var shadow_lord_scene = preload("res://scenes/entities/shadowlord.tscn")
	var shadow_lord = shadow_lord_scene.instantiate()
	add_child(shadow_lord)
	
	await get_tree().process_frame
	
	enemy_class_name = shadow_lord._get_enemy_class_name()
	assert_eq(enemy_class_name, "ShadowLord", "shadowlord should map to ShadowLord")
	
	shadow_lord.queue_free()
	
	print("✅ Enemy class name mapping test passed")

func test_power_egg_spawn_decision():
	print("\n🧪 Testing power egg spawn decision logic...")
	
	# Ensure PowerManager is available
	var power_manager = get_node_or_null("/root/PowerManager")
	if not power_manager:
		print("⚠️  PowerManager not available, skipping spawn decision test")
		return
	
	var enemy_base_scene = preload("res://scenes/entities/enemy_base.tscn")
	var enemy = enemy_base_scene.instantiate()
	add_child(enemy)
	
	await get_tree().process_frame
	
	# Test that the method exists and returns a boolean
	var enemy_class_name = enemy._get_enemy_class_name()
	var should_spawn_power = power_manager.should_spawn_power_egg(enemy_class_name)
	
	assert_true(typeof(should_spawn_power) == TYPE_BOOL, "should_spawn_power_egg should return boolean")
	
	enemy.queue_free()
	
	print("✅ Power egg spawn decision test passed")

func test_normal_egg_spawn_fallback():
	print("\n🧪 Testing normal egg spawn fallback...")
	
	var enemy_base_scene = preload("res://scenes/entities/enemy_base.tscn")
	var enemy = enemy_base_scene.instantiate()
	add_child(enemy)
	
	await get_tree().process_frame
	
	# Force enemy to flying state for defeat
	enemy.current_state = enemy.State.FLYING
	
	# Test that _spawn_normal_egg method exists and can be called
	enemy._spawn_normal_egg(Vector2.ZERO, 1, true)
	
	# Should transition to EGG state
	assert_eq(enemy.current_state, enemy.State.EGG, "Enemy should transition to EGG state after normal egg spawn")
	
	enemy.queue_free()
	
	print("✅ Normal egg spawn fallback test passed")

func test_power_manager_integration():
	print("\n🧪 Testing PowerManager integration...")
	
	var power_manager = get_node_or_null("/root/PowerManager")
	if not power_manager:
		print("⚠️  PowerManager not available, skipping integration test")
		return
	
	# Test that PowerManager has required methods
	assert_true(power_manager.has_method("should_spawn_power_egg"), "PowerManager should have should_spawn_power_egg method")
	assert_true(power_manager.has_method("get_power_egg_scene"), "PowerManager should have get_power_egg_scene method")
	
	# Test power egg scene loading
	var power_egg_scene = power_manager.get_power_egg_scene()
	assert_not_null(power_egg_scene, "PowerManager should return valid power egg scene")
	
	# Test spawn rate configuration
	var spawn_rates = power_manager.power_configs[power_manager.PowerType.INVINCIBILITY].enemy_spawn_rates
	assert_true(spawn_rates.has("EnemyBase"), "PowerManager should have EnemyBase spawn rate")
	assert_true(spawn_rates.has("EnemyHunter"), "PowerManager should have EnemyHunter spawn rate")
	assert_true(spawn_rates.has("ShadowLord"), "PowerManager should have ShadowLord spawn rate")
	
	assert_eq(spawn_rates["EnemyBase"], 0.15, "EnemyBase spawn rate should be 15%")
	assert_eq(spawn_rates["EnemyHunter"], 0.20, "EnemyHunter spawn rate should be 20%")
	assert_eq(spawn_rates["ShadowLord"], 0.25, "ShadowLord spawn rate should be 25%")
	
	print("✅ PowerManager integration test passed")