extends Node2D

@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer

# the 2 textures
var small_j = preload("res://assets/sprites/test_j_small.png")
var big_j = preload("res://assets/sprites/test_J_big.png")

func _ready() -> void:
	# set initial texture
	sprite.texture = small_j
	
func transform_j():
	animation_player.play("j_to_J")
