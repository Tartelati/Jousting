extends CharacterBody2D

# Pterodactyl specific properties
var target_player = null
var pursuit_speed = 150
var is_invulnerable = true
var points_value = 1000
var screech_cooldown = 3.0
var screech_timer = 0.0
var weak_point_hit = false
var weak_point_visible = false
var weak_point_toggle_time = 0.0
var weak_point_toggle_interval = 1.5  # Time between showing/hiding weak point

# References
@onready var sprite = $Sprite2D
@onready var weak_point_sprite = $WeakPointSprite
@onready var screech_sound = $ScreechSound
@onready var collision_shape = $CollisionShape2D
@onready var weak_point_area = $WeakPointArea
@onready var animation_player = $AnimationPlayer

func _ready():
	add_to_group("enemies")
	add_to_group("pterodactyls")
	
	# Find player to target
	target_player = get_tree().get_nodes_in_group("player")[0]
	
	# Initial setup
	weak_point_sprite.visible = false
	weak_point_area.monitoring = false
	
	# Play entrance screech
	screech_sound.play()
	
	# Connect weak point area
	weak_point_area.connect("body_entered", _on_weak_point_hit)

func _physics_process(delta):
	if weak_point_hit:
		# Handle defeat state
		velocity = Vector2(0, 200)  # Fall down when defeated
		move_and_slide()
		return
	
	# Update screech timer
	screech_timer -= delta
	if screech_timer <= 0:
		screech_sound.play()
		screech_timer = screech_cooldown
	
	# Toggle weak point visibility
	weak_point_toggle_time -= delta
	if weak_point_toggle_time <= 0:
		weak_point_toggle_time = weak_point_toggle_interval
		weak_point_visible = !weak_point_visible
		weak_point_sprite.visible = weak_point_visible
		weak_point_area.monitoring = weak_point_visible
	
	# Target player if available
	if target_player and is_instance_valid(target_player):
		var direction = (target_player.global_position - global_position).normalized()
		
		# Move toward player
		velocity = direction * pursuit_speed
		
		# Flip sprite based on movement direction
		if direction.x < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
		
		# Animate based on movement
		if animation_player.has_animation("fly"):
			animation_player.play("fly")
	else:
		# If player not found, try to find again
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
	
	# Screen wrapping
	var viewport_size = get_viewport_rect().size
	if position.x < 0:
		position.x = viewport_size.x
	elif position.x > viewport_size.x:
		position.x = 0
	
	# Prevent going off top or bottom of screen
	if position.y < 20:
		position.y = 20
		velocity.y = 0
	elif position.y > viewport_size.y - 20:
		position.y = viewport_size.y - 20
		velocity.y = 0
	
	move_and_slide()

func _on_weak_point_hit(body):
	if body.is_in_group("player") and weak_point_visible:
		defeat()

func defeat():
	weak_point_hit = true
	weak_point_sprite.visible = false
	weak_point_area.monitoring = false
	
	# Play defeat animation
	if animation_player.has_animation("defeat"):
		animation_player.play("defeat")
	
	# Signal to score manager to add points
	get_node("/root/ScoreManager").add_score(points_value)
	
	# Schedule for removal
	await get_tree().create_timer(2.0).timeout
	queue_free()

func on_player_collision(player):
	# If player hits the pterodactyl (not the weak point), player loses a life
	if !weak_point_hit:
		player.lose_life()
