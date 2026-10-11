extends GutTest

const HUNTER_SCENE := preload("res://scenes/entities/enemy_hunter.tscn")


func test_hunter_sprite_faces_travel_direction_on_both_sides() -> void:
	var hunter = HUNTER_SCENE.instantiate()
	var target := Node2D.new()
	add_child_autofree(hunter)
	add_child_autofree(target)

	hunter.position = Vector2(400, 200)
	hunter.target = target

	target.position = Vector2(500, 200)
	hunter.process_flying(0.0)
	assert_eq(hunter.direction, 1)
	assert_false(hunter.enemy_animation.flip_h, "rightward hunter faces right")

	target.position = Vector2(300, 200)
	hunter.process_flying(0.0)
	assert_eq(hunter.direction, -1)
	assert_true(hunter.enemy_animation.flip_h, "leftward hunter faces left")
