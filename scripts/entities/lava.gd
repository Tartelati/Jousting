extends Area2D

func _ready():
	# Add to hazards group for easy access
	add_to_group("hazards")
	
	connect("body_entered", _on_body_entered)
	

func _on_body_entered(body):
	if body.is_in_group("players"):
		body.die()
	elif body.is_in_group("enemies") and body.has_method("defeat"):
		body.defeat()
