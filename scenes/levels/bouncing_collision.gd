extends Area2D

# How much to multiply the player's horizontal velocity when bouncing
@export var bounce_factor: float = 1.0
# Add a small force to ensure the bounce happens
@export var minimum_bounce_speed: float = 100.0


func _ready():
	connect("body_entered", _on_body_entered)



func _on_body_entered(body):
	# Check if the colliding body is the player
	if body.is_in_group("players"):  # Note: using "players" instead of "player"
		# Get current horizontal velocity
		var velocity = body.velocity
		
		# Debugging
		print("Before bounce - velocity: ", velocity)
		
		# Reverse horizontal direction and maintain speed
		velocity.x = -velocity.x * bounce_factor
		
		# Ensure minimum bounce speed
		if abs(velocity.x) < minimum_bounce_speed:
			velocity.x = minimum_bounce_speed * sign(velocity.x)
		
		# Force an immediate player state change in addition to velocity change
		# This is critical because the player state machine will otherwise override our velocity
		if body.has_method("bounce_from_wall"):
			body.bounce_from_wall(velocity)
		else:
			# Directly modify player state variables as a fallback
			body.velocity = velocity
			if "current_direction" in body:
				body.current_direction = sign(velocity.x)
			if "move_state" in body and body.has_method("_state_moving"):
				body.move_state = body.MoveState.MOVING
		
		# Flip the player sprite
		if body.has_method("flip_sprite"):
			body.flip_sprite()
		else:
			var sprite = body.get_node_or_null("Sprite2D")
			if sprite:
				sprite.flip_h = !sprite.flip_h
				
		print("After bounce - applied velocity: ", velocity)
