extends TestBase

# Integration test for PowerEgg entity and collection system
class_name IntegrationPowerEggTest

func _ready():
	test_name = "PowerEgg Integration Test"
	print("\n" + "=".repeat(50))
	print("STARTING: " + test_name)
	print("=".repeat(50))

func run_tests():
	print("\n--- PowerEgg Integration Tests ---")
	
	test_power_egg_instantiation()
	test_power_egg_physics_setup()
	test_power_egg_collection_area()
	test_power_egg_visual_appearance()
	test_power_egg_timeout_system()
	
	print_results()

func test_power_egg_instantiation():
	print("\n🧪 Testing PowerEgg instantiation...")
	
	var power_egg_scene = preload("res://scenes/entities/power_egg.tscn")
	assert_not_null(power_egg_scene, "PowerEgg scene should load")
	
	var power_egg = power_egg_scene.instantiate()
	assert_not_null(power_egg, "PowerEgg should instantiate")
	assert_true(power_egg.is_in_group("power_eggs"), "PowerEgg should be in power_eggs group")
	
	# Test default properties
	assert_eq(power_egg.power_type, 0, "Default power type should be INVINCIBILITY (0)")
	assert_eq(power_egg.collection_points, 200, "Default collection points should be 200")
	assert_eq(power_egg.timeout_duration, 15.0, "Default timeout should be 15 seconds")
	assert_false(power_egg.is_collected, "PowerEgg should not be collected initially")
	
	power_egg.queue_free()
	print("✅ PowerEgg instantiation test passed")

func test_power_egg_physics_setup():
	print("\n🧪 Testing PowerEgg physics setup...")
	
	var power_egg_scene = preload("res://scenes/entities/power_egg.tscn")
	var power_egg = power_egg_scene.instantiate()
	add_child(power_egg)
	
	# Wait a frame for _ready to be called
	await get_tree().process_frame
	
	# Test physics properties
	assert_eq(power_egg.collision_layer, 16, "PowerEgg should be on egg layer (16)")
	assert_eq(power_egg.collision_mask, 6, "PowerEgg should collide with environment and player (6)")
	assert_eq(power_egg.mass, 1.0, "PowerEgg mass should be 1.0")
	assert_eq(power_egg.gravity_scale, 1.0, "PowerEgg gravity scale should be 1.0")
	assert_true(power_egg.contact_monitor, "PowerEgg should have contact monitoring enabled")
	
	power_egg.queue_free()
	print("✅ PowerEgg physics setup test passed")

func test_power_egg_collection_area():
	print("\n🧪 Testing PowerEgg collection area...")
	
	var power_egg_scene = preload("res://scenes/entities/power_egg.tscn")
	var power_egg = power_egg_scene.instantiate()
	add_child(power_egg)
	
	# Wait a frame for _ready to be called
	await get_tree().process_frame
	
	var collection_area = power_egg.get_node("CollectionArea")
	assert_not_null(collection_area, "PowerEgg should have CollectionArea")
	assert_true(collection_area.is_in_group("power_egg_collection_zones"), "CollectionArea should be in power_egg_collection_zones group")
	assert_eq(collection_area.collision_layer, 32, "CollectionArea should be on pickup layer (32)")
	assert_eq(collection_area.collision_mask, 32, "CollectionArea should detect pickup layer (32)")
	assert_true(collection_area.monitoring, "CollectionArea should be monitoring")
	assert_true(collection_area.monitorable, "CollectionArea should be monitorable")
	
	power_egg.queue_free()
	print("✅ PowerEgg collection area test passed")

func test_power_egg_visual_appearance():
	print("\n🧪 Testing PowerEgg advanced visual appearance...")
	
	var power_egg_scene = preload("res://scenes/entities/power_egg.tscn")
	var power_egg = power_egg_scene.instantiate()
	add_child(power_egg)
	
	# Wait a frame for _ready to be called
	await get_tree().process_frame
	
	var sprite = power_egg.get_node("AnimatedSprite2D")
	var glow_effect = power_egg.get_node("GlowEffect")
	var trail_effect = power_egg.get_node_or_null("TrailEffect")
	var aura_effect = power_egg.get_node_or_null("AuraEffect")
	var spawn_effect = power_egg.get_node("SpawnEffect")
	
	assert_not_null(sprite, "PowerEgg should have AnimatedSprite2D")
	assert_not_null(glow_effect, "PowerEgg should have GlowEffect")
	assert_not_null(trail_effect, "PowerEgg should have TrailEffect for advanced visuals")
	assert_not_null(aura_effect, "PowerEgg should have AuraEffect for advanced visuals")
	assert_not_null(spawn_effect, "PowerEgg should have enhanced SpawnEffect")
	
	# Test golden color for invincibility power
	var expected_color = Color(1.0, 0.8, 0.3)
	assert_true(sprite.modulate.is_equal_approx(expected_color), "Sprite should have golden color for invincibility")
	
	var expected_glow = Color(1.0, 0.9, 0.4, 0.8)
	assert_true(glow_effect.modulate.is_equal_approx(expected_glow), "Glow effect should have golden glow color")
	
	# Test advanced particle effects
	if trail_effect:
		assert_true(trail_effect.emitting, "Trail effect should be emitting during power egg lifetime")
		assert_eq(trail_effect.amount, 15, "Trail effect should have correct particle count")
	
	if aura_effect:
		assert_true(aura_effect.emitting, "Aura effect should be emitting during power egg lifetime")
		assert_eq(aura_effect.amount, 8, "Aura effect should have correct particle count")
	
	# Test enhanced spawn effect properties
	assert_eq(spawn_effect.amount, 50, "Enhanced spawn effect should have more particles")
	assert_eq(spawn_effect.lifetime, 3.0, "Enhanced spawn effect should have longer lifetime")
	assert_true(spawn_effect.explosiveness > 0.5, "Enhanced spawn effect should be explosive")
	
	power_egg.queue_free()
	print("✅ PowerEgg advanced visual appearance test passed")

func test_power_egg_timeout_system():
	print("\n🧪 Testing PowerEgg timeout system...")
	
	var power_egg_scene = preload("res://scenes/entities/power_egg.tscn")
	var power_egg = power_egg_scene.instantiate()
	add_child(power_egg)
	
	# Wait a frame for _ready to be called
	await get_tree().process_frame
	
	var timeout_timer = power_egg.get_node("TimeoutTimer")
	assert_not_null(timeout_timer, "PowerEgg should have TimeoutTimer")
	assert_eq(timeout_timer.wait_time, 15.0, "TimeoutTimer should be set to 15 seconds")
	assert_true(timeout_timer.one_shot, "TimeoutTimer should be one-shot")
	assert_false(timeout_timer.is_stopped(), "TimeoutTimer should be running after _ready")
	
	power_egg.queue_free()
	print("✅ PowerEgg timeout system test passed")

func test_power_egg_collection():
	print("\n🧪 Testing PowerEgg collection...")
	
	# This test requires PowerManager to be available
	var power_manager = get_node_or_null("/root/PowerManager")
	if not power_manager:
		print("⚠️  PowerManager not available, skipping collection test")
		return
	
	var power_egg_scene = preload("res://scenes/entities/power_egg.tscn")
	var power_egg = power_egg_scene.instantiate()
	add_child(power_egg)
	
	# Wait a frame for _ready to be called
	await get_tree().process_frame
	
	# Test collection
	var initial_score = ScoreManager.get_score(1) if ScoreManager else 0
	power_egg.collect(1)
	
	assert_true(power_egg.is_collected, "PowerEgg should be marked as collected")
	
	if ScoreManager:
		var final_score = ScoreManager.get_score(1)
		assert_gt(final_score, initial_score, "Score should increase after collection")
	
	print("✅ PowerEgg collection test passed")