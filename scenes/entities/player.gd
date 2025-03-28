extends CharacterBody2D

#movement parameters
var gravity = 800
var flap_force = -300
var move_speed = 150
var max_fall_speed = 400

#state tracking
var is_flapping = false
var is_alive = true

#references
@onready var sprite = $Sprite2D
@onready var flap_sound = $FlapSound
@onready var collision_sound = $CollisionSound
@onready var death_sound = $DeathSound
@onready var combat_area = $CombatArea
@onready var collection_area = $CollectionArea


func _ready():
	# Add to player group for easy access
	add_to_group("players")
	
	# Connect combat area signal
	combat_area.connect("area_entered", _on_combat_area_area_entered)
	# Connect collection_area signal
	
	collection_area.connect("area_entered", _on_collection_area_area_entered)

func _physics_process(delta):
	if not is_alive:
		return
		
	# Apply gravity only when not on floor
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	
	# Handle flapping
	if Input.is_action_just_pressed("Flap"):
		velocity.y = flap_force
		is_flapping = true
		flap_sound.play()
	else:
		is_flapping = false
	
	# Handle horizontal movement
	var direction = 0
	if Input.is_action_pressed("move_left"):
		direction = -1
		sprite.flip_h = true
	elif Input.is_action_pressed("move_right"):
		direction = 1
		sprite.flip_h = false
	
	velocity.x = direction * move_speed
	
	# Handle screen wrapping
	screen_wrapping()
	
	# Update animation based on movement
	update_animation()
	
	# Move the character
	move_and_slide()

func screen_wrapping():
	var viewport_rect = get_viewport_rect().size
	
	# Create a larger buffer for wrapping
	var buffer = 10  # Increased buffer size
	
	# Check if player is about to go off the left edge
	if global_position.x < buffer:
		# Immediately teleport to right side with same velocity
		global_position.x = viewport_rect.x - buffer
		# No need to change velocity, keep momentum
	
	# Check if player is about to go off the right edge
	elif global_position.x > viewport_rect.x - buffer:
	# Immediately teleport to left side with same velocity
		global_position.x = buffer
	# No need to change velocity, keep momentum

func update_animation():
	# This would be replaced with proper animation states
	# when using AnimatedSprite2D
	if is_flapping:
		sprite.modulate = Color(1, 1, 0.8)  # Slight yellow tint when flapping
	else:
		sprite.modulate = Color(1, 1, 1)  # Normal color otherwise

func _on_combat_area_area_entered(area):
	if not is_alive or not area.get_parent().is_in_group("enemies"):
		return
		
	var enemy = area.get_parent()
	
	# Skip if enemy is in egg or hatching state
	if "current_state" in enemy and (enemy.current_state == enemy.State.EGG or enemy.current_state == enemy.State.HATCHING):
		return
			
	# Get the collision shapes for more precise position comparison
	var player_bottom = global_position.y + $CollisionShape2D.shape.height/2
	var enemy_top = 0
	var collision_shape = enemy.get_node("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CircleShape2D:
			enemy_top = enemy.global_position.y - enemy.get_node("CollisionShape2D").shape.radius
		elif collision_shape.shape is CapsuleShape2D or collision_shape.shape is RectangleShape2D:
			enemy_top = enemy.global_position.y - enemy.get_node("CollisionShape2D").shape.height/2
		#failsafe with default value
		else:
			enemy_top = enemy.global_position.y - 10
		
	var enemy_bottom = 0
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CircleShape2D:
			enemy_bottom = enemy.global_position.y + enemy.get_node("CollisionShape2D").shape.radius
		elif collision_shape.shape is CapsuleShape2D or collision_shape.shape is RectangleShape2D:
			enemy_bottom = enemy.global_position.y + enemy.get_node("CollisionShape2D").shape.height/2
		#failsafe with default value
		else:
			enemy_bottom = enemy.global_position.y + 10

	# Compare Y positions to determine winner
	if player_bottom < enemy_top + 10: # Add a small threshold for better gameplay feel
		# Player wins - jousted from above
		enemy.defeat()
		
		# Add a small upward bounce
		velocity.y = -150
		
		# Play victory sound
		if has_node("VictorySound"):
			$VictorySound.play()
		
	else :
		# Enemy wins or bounce
		if global_position.y > enemy_bottom - 10: # Add a small threshold
			die()
		else:
			# Side collision - bounce off each other
			var direction = sign(global_position.x - enemy.global_position.x)
			velocity.x = direction * 200
			velocity.y = -100
			
			if "velocity" in enemy:
				enemy.velocity.x = -direction * 200
				enemy.velocity.y = -100
			
			collision_sound.play()

func die():
	is_alive = false
	death_sound.play()
	sprite.modulate = Color(1, 0.5, 0.5)  # Red tint
	
	# Notify game manager
	get_node("/root/ScoreManager").lose_life()
	
	# Wait and respawn
	await get_tree().create_timer(2.0).timeout
	respawn()

func respawn():
	is_alive = true
	position = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y / 2)
	velocity = Vector2.ZERO
	sprite.modulate = Color(1, 1, 1)  # Reset color

func _on_collection_area_area_entered(area):
	#Debug print to check if this function is being called
	print("Collection area detected: ", area.name)
	
	# Check if the area is an EggArea from an enemy
	if area.name == "EggArea" and area.get_parent().is_in_group("enemies"):
		var enemy = area.get_parent()
		
		#Print more debug info to understand the state
		print("Enemy current_state: ", enemy.current_state if "current_state" in enemy else "unknown")
		print("Enemy State.EGG value: ", enemy.State.EGG if "State" in enemy else "unknown")
		
		# Check if enemy is in EGG state
		if "current_state" in enemy and (enemy.current_state == enemy.State.EGG or enemy.current_state == enemy.State.HATCHING):
			print("Egg Collected by player via collection area!")
			enemy.collect_egg()
