extends StaticBody2D

@export var bounce_factor: float = 1.0

func _ready():
	connect("body_entered", _on_body_entered)



func _on_body_entered(body):
	if body.is_in_group("players"):
		# Get current horizontal velocity
		var velocity = body.velocity
		# Reverse horizontal direction and maintain speed
		velocity.x = -velocity.x * bounce_factor
		# Apply the new velocity
		body.velocity = velocity
		
		# Flip the player sprite horizontally
		if body.has_method("flip_sprite"):
			body.flip_sprite()
		else:
			# Alternative way to flip the sprite if no specific method exists
			var sprite = body.get_node_or_null("Sprite2D")
			if sprite:
				sprite.flip_h = !sprite.flip_h
