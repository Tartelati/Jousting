class_name PowerVisualization
extends Control

# Visualization settings
var show_spawn_locations: bool = false
var show_collection_heatmap: bool = false
var show_power_timers: bool = false
var show_performance_overlay: bool = false

# Visual components
var spawn_markers: Array[Control] = []
var collection_markers: Array[Control] = []
var timer_displays: Array[Control] = []
var performance_overlay: Control

# References
var power_analytics: Node  # PowerAnalytics
var power_manager: Node

# Colors for different power types
var power_colors: Dictionary = {
	0: Color.GOLD,  # Invincibility
	-1: Color.WHITE  # Unknown/Default
}

# Marker scenes
var spawn_marker_scene: PackedScene
var collection_marker_scene: PackedScene

func _ready():
	_setup_visualization()
	_find_references()
	_create_marker_scenes()

func _setup_visualization():
	"""Setup visualization canvas"""
	# Make this control cover the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	
	# Create performance overlay
	_create_performance_overlay()

func _find_references():
	"""Find analytics and power manager references"""
	power_analytics = get_node_or_null("/root/PowerAnalytics")
	power_manager = get_node_or_null("/root/PowerManager")
	
	if power_analytics:
		# Connect to analytics signals for real-time updates
		power_analytics.analytics_updated.connect(_on_analytics_updated)
		power_analytics.performance_warning.connect(_on_performance_warning)

func _create_marker_scenes():
	"""Create marker scenes programmatically"""
	# Create spawn marker scene
	spawn_marker_scene = PackedScene.new()
	var spawn_marker = Control.new()
	spawn_marker.set_script(preload("res://scripts/debug/spawn_marker.gd"))
	spawn_marker_scene.pack(spawn_marker)
	
	# Create collection marker scene
	collection_marker_scene = PackedScene.new()
	var collection_marker = Control.new()
	collection_marker.set_script(preload("res://scripts/debug/collection_marker.gd"))
	collection_marker_scene.pack(collection_marker)

func _create_performance_overlay():
	"""Create performance monitoring overlay"""
	performance_overlay = Control.new()
	performance_overlay.name = "PerformanceOverlay"
	performance_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	performance_overlay.size = Vector2(300, 200)
	performance_overlay.visible = false
	
	# Add background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	performance_overlay.add_child(bg)
	
	# Add performance label
	var perf_label = RichTextLabel.new()
	perf_label.name = "PerformanceLabel"
	perf_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	perf_label.fit_content = true
	perf_label.bbcode_enabled = true
	performance_overlay.add_child(perf_label)
	
	add_child(performance_overlay)

# Public Interface

func enable_spawn_visualization(enabled: bool):
	"""Enable/disable spawn location visualization"""
	show_spawn_locations = enabled
	if enabled:
		_update_spawn_visualization()
	else:
		_clear_spawn_markers()

func enable_collection_heatmap(enabled: bool):
	"""Enable/disable collection heatmap visualization"""
	show_collection_heatmap = enabled
	if enabled:
		_update_collection_heatmap()
	else:
		_clear_collection_markers()

func enable_timer_display(enabled: bool):
	"""Enable/disable power timer display"""
	show_power_timers = enabled
	if enabled:
		_update_timer_displays()
	else:
		_clear_timer_displays()

func enable_performance_overlay(enabled: bool):
	"""Enable/disable performance monitoring overlay"""
	show_performance_overlay = enabled
	if performance_overlay:
		performance_overlay.visible = enabled
		if enabled:
			_update_performance_overlay()

func toggle_all_visualizations():
	"""Toggle all visualizations on/off"""
	var new_state = not (show_spawn_locations or show_collection_heatmap or show_power_timers or show_performance_overlay)
	enable_spawn_visualization(new_state)
	enable_collection_heatmap(new_state)
	enable_timer_display(new_state)
	enable_performance_overlay(new_state)

# Visualization Updates

func _update_spawn_visualization():
	"""Update spawn location markers"""
	if not power_analytics or not show_spawn_locations:
		return
	
	_clear_spawn_markers()
	
	var spawn_data = power_analytics.get_spawn_visualization_data()
	var current_time = Time.get_time_dict_from_system().unix
	
	# Only show recent spawns (last 30 seconds)
	for spawn_info in spawn_data:
		if current_time - spawn_info.timestamp > 30:
			continue
		
		var marker = _create_spawn_marker(spawn_info)
		if marker:
			spawn_markers.append(marker)
			add_child(marker)

func _create_spawn_marker(spawn_info: Dictionary) -> Control:
	"""Create a spawn location marker"""
	var marker = Control.new()
	marker.size = Vector2(20, 20)
	marker.position = Vector2(spawn_info.position.x - 10, spawn_info.position.y - 10)
	
	# Create visual indicator
	var circle = ColorRect.new()
	circle.size = Vector2(20, 20)
	circle.color = Color.YELLOW if spawn_info.successful else Color.RED
	circle.color.a = 0.7
	marker.add_child(circle)
	
	# Add border for successful spawns
	if spawn_info.successful:
		var border = ColorRect.new()
		border.size = Vector2(22, 22)
		border.position = Vector2(-1, -1)
		border.color = power_colors.get(spawn_info.get("power_type", -1), Color.WHITE)
		border.color.a = 0.8
		marker.add_child(border)
		marker.move_child(border, 0)  # Move to back
	
	# Add fade-out animation
	var tween = create_tween()
	tween.tween_property(marker, "modulate:a", 0.0, 5.0)
	tween.tween_callback(marker.queue_free)
	
	return marker

func _update_collection_heatmap():
	"""Update collection heatmap visualization"""
	if not power_analytics or not show_collection_heatmap:
		return
	
	_clear_collection_markers()
	
	var heatmap_data = power_analytics.get_collection_heatmap_data()
	
	for player_index in heatmap_data:
		var player_collections = heatmap_data[player_index]
		var player_color = _get_player_color(player_index)
		
		for collection_info in player_collections:
			var marker = _create_collection_marker(collection_info, player_color)
			if marker:
				collection_markers.append(marker)
				add_child(marker)

func _create_collection_marker(collection_info: Dictionary, player_color: Color) -> Control:
	"""Create a collection heatmap marker"""
	var marker = Control.new()
	marker.size = Vector2(16, 16)
	marker.position = Vector2(collection_info.position.x - 8, collection_info.position.y - 8)
	
	# Create heat indicator
	var heat_circle = ColorRect.new()
	heat_circle.size = Vector2(16, 16)
	heat_circle.color = player_color
	heat_circle.color.a = 0.5
	marker.add_child(heat_circle)
	
	# Add power type indicator
	var power_indicator = ColorRect.new()
	power_indicator.size = Vector2(6, 6)
	power_indicator.position = Vector2(5, 5)
	power_indicator.color = power_colors.get(collection_info.get("power_type", -1), Color.WHITE)
	marker.add_child(power_indicator)
	
	return marker

func _update_timer_displays():
	"""Update power timer displays"""
	if not power_manager or not show_power_timers:
		return
	
	_clear_timer_displays()
	
	if not power_manager.has_method("get_all_active_powers"):
		return
	
	var active_powers = power_manager.get_all_active_powers()
	
	for player_index in active_powers:
		var power_data = active_powers[player_index]
		var timer_display = _create_timer_display(player_index, power_data)
		if timer_display:
			timer_displays.append(timer_display)
			add_child(timer_display)

func _create_timer_display(player_index: int, power_data: Dictionary) -> Control:
	"""Create a power timer display"""
	var timer_display = Control.new()
	timer_display.size = Vector2(120, 30)
	
	# Position based on player index
	var base_pos = Vector2(10, 50 + (player_index - 1) * 35)
	timer_display.position = base_pos
	
	# Background
	var bg = ColorRect.new()
	bg.size = Vector2(120, 30)
	bg.color = Color(0, 0, 0, 0.6)
	timer_display.add_child(bg)
	
	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.size = Vector2(100, 20)
	progress_bar.position = Vector2(10, 5)
	progress_bar.max_value = power_data.duration
	progress_bar.value = power_data.remaining_time
	
	# Color based on power type
	var power_color = power_colors.get(power_data.type, Color.WHITE)
	progress_bar.modulate = power_color
	
	timer_display.add_child(progress_bar)
	
	# Timer label
	var timer_label = Label.new()
	timer_label.text = "P%d: %.1fs" % [player_index, power_data.remaining_time]
	timer_label.size = Vector2(120, 30)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_display.add_child(timer_label)
	
	return timer_display

func _update_performance_overlay():
	"""Update performance monitoring overlay"""
	if not power_analytics or not performance_overlay or not show_performance_overlay:
		return
	
	var perf_label = performance_overlay.get_node("PerformanceLabel")
	if not perf_label:
		return
	
	var perf_report = power_analytics.get_performance_report()
	
	var overlay_text = "[b]Power System Performance[/b]\n\n"
	overlay_text += "FPS: %.1f\n" % perf_report.average_fps
	overlay_text += "Frame Time: %.2fms\n" % (perf_report.average_frame_time * 1000)
	overlay_text += "Frame Drops: %d\n" % perf_report.frame_drops
	overlay_text += "Audio Issues: %d\n" % perf_report.audio_stutters
	overlay_text += "Memory Spikes: %d\n" % perf_report.memory_spikes
	overlay_text += "\n[b]Performance Score: %.1f/100[/b]" % perf_report.performance_score
	
	# Color code the performance score
	if perf_report.performance_score >= 80:
		overlay_text += " [color=green](Good)[/color]"
	elif perf_report.performance_score >= 60:
		overlay_text += " [color=yellow](Fair)[/color]"
	else:
		overlay_text += " [color=red](Poor)[/color]"
	
	perf_label.text = overlay_text

# Helper Methods

func _get_player_color(player_index: int) -> Color:
	"""Get color for player visualization"""
	match player_index:
		1:
			return Color.BLUE
		2:
			return Color.RED
		3:
			return Color.GREEN
		4:
			return Color.PURPLE
		_:
			return Color.WHITE

func _clear_spawn_markers():
	"""Clear all spawn markers"""
	for marker in spawn_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	spawn_markers.clear()

func _clear_collection_markers():
	"""Clear all collection markers"""
	for marker in collection_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	collection_markers.clear()

func _clear_timer_displays():
	"""Clear all timer displays"""
	for display in timer_displays:
		if is_instance_valid(display):
			display.queue_free()
	timer_displays.clear()

# Signal Handlers

func _on_analytics_updated(metric_type: String, _data: Dictionary):
	"""Handle analytics updates for real-time visualization"""
	match metric_type:
		"spawn_attempt", "successful_spawn":
			if show_spawn_locations:
				_update_spawn_visualization()
		"power_collection":
			if show_collection_heatmap:
				_update_collection_heatmap()

func _on_performance_warning(_warning_type: String, _details: Dictionary):
	"""Handle performance warnings"""
	if show_performance_overlay:
		# Flash the performance overlay to indicate warning
		if performance_overlay:
			var original_color = performance_overlay.modulate
			performance_overlay.modulate = Color.RED
			
			var tween = create_tween()
			tween.tween_property(performance_overlay, "modulate", original_color, 0.5)

# Update Loop

func _process(_delta):
	"""Update visualizations that need real-time updates"""
	if show_power_timers:
		_update_timer_displays()
	
	if show_performance_overlay:
		_update_performance_overlay()

# Input Handling

func _input(event):
	"""Handle debug input for visualization toggles"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F11:
				enable_spawn_visualization(not show_spawn_locations)
			KEY_F12:
				enable_collection_heatmap(not show_collection_heatmap)
			KEY_INSERT:
				enable_timer_display(not show_power_timers)
			KEY_HOME:
				enable_performance_overlay(not show_performance_overlay)
			KEY_END:
				toggle_all_visualizations()