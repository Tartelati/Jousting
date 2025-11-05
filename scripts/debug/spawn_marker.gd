extends Control

# Simple spawn marker for visualization
# This script provides basic functionality for spawn location markers

func _ready():
	# Set up basic appearance
	custom_minimum_size = Vector2(20, 20)
	
	# Create visual representation
	var circle = ColorRect.new()
	circle.size = Vector2(20, 20)
	circle.color = Color.YELLOW
	circle.color.a = 0.7
	add_child(circle)
	
	# Auto-fade after 5 seconds
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 5.0)
	tween.tween_callback(queue_free)

func set_spawn_info(spawn_info: Dictionary):
	"""Set spawn information for this marker"""
	if spawn_info.has("successful") and spawn_info.successful:
		# Change color for successful spawns
		var circle = get_child(0)
		if circle:
			circle.color = Color.GREEN
			circle.color.a = 0.8