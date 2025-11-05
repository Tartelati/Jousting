extends Control

# Simple collection marker for heatmap visualization
# This script provides basic functionality for collection heatmap markers

func _ready():
	# Set up basic appearance
	custom_minimum_size = Vector2(16, 16)
	
	# Create visual representation
	var circle = ColorRect.new()
	circle.size = Vector2(16, 16)
	circle.color = Color.BLUE
	circle.color.a = 0.5
	add_child(circle)

func set_collection_info(collection_info: Dictionary, player_color: Color):
	"""Set collection information for this marker"""
	var circle = get_child(0)
	if circle:
		circle.color = player_color
		circle.color.a = 0.5
	
	# Add power type indicator if available
	if collection_info.has("power_type"):
		var indicator = ColorRect.new()
		indicator.size = Vector2(6, 6)
		indicator.position = Vector2(5, 5)
		
		# Color based on power type
		match collection_info.power_type:
			0:  # Invincibility
				indicator.color = Color.GOLD
			_:
				indicator.color = Color.WHITE
		
		add_child(indicator)