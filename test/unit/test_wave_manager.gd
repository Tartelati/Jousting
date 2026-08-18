extends GutTest
# ============================================================
# Unit tests for WaveManager.
# Lock in the CURRENT behavior of wave progression, platform
# state management and enemy spawning.
#
# NOTE: SpawnManager (autoload) is stubbed for the normal-wave
# path so tests don't trigger the spawn queue (see issue #9/#10).
# ============================================================

const WaveManager = preload("res://scripts/managers/wave_manager.gd")
const SpawnManagerScript = preload("res://scripts/managers/spawn_manager.gd")

var level: Node
var wave_mgr: Node


class MockSpawnPoint:
	extends Marker2D
	var available := true

	func can_spawn() -> bool:
		return available


# Neutral subclass of the SpawnManager autoload. start_wave() feeds the
# real autoload's queue, which recurses forever with no spawn points
# available in a test tree (issue #10) — so we swap the autoload's script
# with this inert version for the duration of the test.
class NeutralSpawner:
	extends SpawnManagerScript

	func queue_spawn_batch(_spawn_list: Array) -> void:
		pass

	func queue_spawn(_scene: PackedScene, _data: Dictionary = {}, _is_player: bool = false, _callback: Callable = Callable()) -> void:
		pass


func before_each():
	SpawnManager.set_script(NeutralSpawner)

	level = Node.new()
	level.name = "Level"
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child_autofree(level)
	_build_platforms(level)

	wave_mgr = WaveManager.new()
	level.add_child(wave_mgr)


func after_each():
	# Restore the real autoload script.
	SpawnManager.set_script(SpawnManagerScript)


func _build_platforms(parent: Node) -> void:
	var platforms := Node2D.new()
	platforms.name = "Platforms"
	parent.add_child(platforms)
	platforms.add_child(_make_platform("platform1", "SpawnPoint4"))
	platforms.add_child(_make_platform("platform2", ""))
	platforms.add_child(_make_platform("platform3", "SpawnPoint1"))
	platforms.add_child(_make_platform("platform4", "SpawnPoint3"))


func _make_platform(pname: String, spawn_name: String) -> StaticBody2D:
	var p := StaticBody2D.new()
	p.name = pname
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	p.add_child(sprite)
	var col := CollisionShape2D.new()
	col.name = "Collision"
	p.add_child(col)
	if spawn_name != "":
		var marker := Marker2D.new()
		marker.name = spawn_name
		p.add_child(marker)
	return p


# ---------------- Wave progression ----------------

func test_start_wave_sets_wave_number_and_base_enemy_count():
	wave_mgr.start_wave(1)

	assert_eq(wave_mgr.current_wave, 1)
	assert_eq(wave_mgr.enemies_remaining, 3, "wave 1 = base of 3 enemies")


func test_start_wave_enemy_count_scales_with_increment():
	wave_mgr.start_wave(3)

	assert_eq(wave_mgr.enemies_remaining, 3 + (3 - 1) * 2, "wave 3 = base + 2 increments")


func test_start_wave_increments_when_no_number_given():
	wave_mgr.current_wave = 2
	wave_mgr.start_wave()

	assert_eq(wave_mgr.current_wave, 3)


func test_start_wave_sets_progress_and_emits_wave_started():
	var emitted: Array = []
	wave_mgr.wave_started.connect(func(n): emitted.append(n))

	wave_mgr.start_wave(2)

	assert_true(wave_mgr.wave_in_progress)
	assert_eq(emitted, [2])


func test_wave_5_is_an_egg_wave():
	wave_mgr.start_wave(5)

	assert_true(wave_mgr.is_egg_wave, "wave % 5 == 0 triggers the egg wave")
	assert_eq(wave_mgr.enemies_remaining, 0, "egg waves spawn no direct enemies")


# ---------------- Platform state management ----------------

func test_platform1_disabled_from_wave3():
	wave_mgr.start_wave(3)

	var p1 := level.get_node("Platforms/platform1") as StaticBody2D
	assert_false(p1.visible, "platform1 hidden at wave 3")
	assert_true((p1.get_node("Collision") as CollisionShape2D).disabled, "platform1 collision off at wave 3")


func test_platform2_disabled_from_wave4():
	wave_mgr.start_wave(4)

	var p2 := level.get_node("Platforms/platform2") as StaticBody2D
	assert_true((p2.get_node("Collision") as CollisionShape2D).disabled, "platform2 collision off at wave 4")


func test_reset_wave_reenables_platforms():
	wave_mgr.start_wave(3)  # disables platform1
	wave_mgr.start_wave(5)  # wave % 5 == 0 resets all platforms

	var p1 := level.get_node("Platforms/platform1") as StaticBody2D
	assert_true(p1.visible, "reset wave restores platform1 visibility")
	assert_false((p1.get_node("Collision") as CollisionShape2D).disabled, "reset wave restores platform1 collision")


# ---------------- Enemy spawning ----------------

func test_spawn_enemy_spawns_and_decrements():
	var point := MockSpawnPoint.new()
	level.add_child(point)
	wave_mgr.spawn_points = [point]
	wave_mgr.current_wave = 1
	wave_mgr.enemies_remaining = 3

	var children_before := level.get_child_count()
	wave_mgr.spawn_enemy()

	assert_eq(wave_mgr.enemies_remaining, 2, "spawn_enemy decrements the counter")
	assert_eq(level.get_child_count(), children_before + 1, "one enemy added to the level")
	assert_true(level.get_child(level.get_child_count() - 1).is_in_group("enemies"))

	# clean up the spawned enemy immediately
	level.get_child(level.get_child_count() - 1).free()


func test_spawn_enemy_skips_disabled_spawn_point():
	var point := MockSpawnPoint.new()
	point.available = false
	level.add_child(point)
	wave_mgr.spawn_points = [point]
	wave_mgr.current_wave = 1
	wave_mgr.enemies_remaining = 3

	var children_before := level.get_child_count()
	wave_mgr.spawn_enemy()

	assert_eq(wave_mgr.enemies_remaining, 3, "no spawn when the only point is unavailable")
	assert_eq(level.get_child_count(), children_before, "no enemy added")


func test_spawn_enemy_noop_with_no_spawn_points():
	wave_mgr.spawn_points = []
	wave_mgr.current_wave = 1
	wave_mgr.enemies_remaining = 2

	var children_before := level.get_child_count()
	wave_mgr.spawn_enemy()

	assert_eq(wave_mgr.enemies_remaining, 2)
	assert_eq(level.get_child_count(), children_before)
