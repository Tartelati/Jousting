class_name PowerDebugUI
extends Control

# UI Components
@onready var main_panel: Panel = $MainPanel
@onready var tab_container: TabContainer = $MainPanel/VBoxContainer/TabContainer

# Configuration Tab
@onready var config_tab: VBoxContainer = $MainPanel/VBoxContainer/TabContainer/Configuration
@onready var system_enabled_check: CheckBox = $MainPanel/VBoxContainer/TabContainer/Configuration/SystemSettings/SystemEnabledCheck
@onready var debug_mode_check: CheckBox = $MainPanel/VBoxContainer/TabContainer/Configuration/SystemSettings/DebugModeCheck
@onready var duration_slider: HSlider = $MainPanel/VBoxContainer/TabContainer/Configuration/PowerSettings/DurationSlider
@onready var duration_label: Label = $MainPanel/VBoxContainer/TabContainer/Configuration/PowerSettings/DurationLabel
@onready var spawn_chance_slider: HSlider = $MainPanel/VBoxContainer/TabContainer/Configuration/PowerSettings/SpawnChanceSlider
@onready var spawn_chance_label: Label = $MainPanel/VBoxContainer/TabContainer/Configuration/PowerSettings/SpawnChanceLabel

# Testing Tab
@onready var testing_tab: VBoxContainer = $MainPanel/VBoxContainer/TabContainer/Testing
@onready var force_spawn_button: Button = $MainPanel/VBoxContainer/TabContainer/Testing/TestControls/ForceSpawnButton
@onready var activate_power_button: Button = $MainPanel/VBoxContainer/TabContainer/Testing/TestControls/ActivatePowerButton
@onready var deactivate_all_button: Button = $MainPanel/VBoxContainer/TabContainer/Testing/TestControls/DeactivateAllButton
@onready var test_player_spin: SpinBox = $MainPanel/VBoxContainer/TabContainer/Testing/TestControls/PlayerSpinBox

# Visualization Tab
@onready var visualization_tab: VBoxContainer = $MainPanel/VBoxContainer/TabContainer/Visualization
@onready var spawn_visualization_check: CheckBox = $MainPanel/VBoxContainer/TabContainer/Visualization/VisualizationSettings/SpawnVisualizationCheck
@onready var timer_display_check: CheckBox = $MainPanel/VBoxContainer/TabContainer/Visualization/VisualizationSettings/TimerDisplayCheck
@onready var active_powers_list: ItemList = $MainPanel/VBoxContainer/TabContainer/Visualization/ActivePowersList

# Statistics Tab
@onready var statistics_tab: VBoxContainer = $MainPanel/VBoxContainer/TabContainer/Statistics
@onready var stats_label: RichTextLabel = $MainPanel/VBoxContainer/TabContainer/Statistics/StatsLabel
@onready var reset_stats_button: Button = $MainPanel/VBoxContainer/TabContainer/Statistics/ResetStatsButton

# Control buttons
@onready var close_button: Button = $MainPanel/VBoxContainer/ControlButtons/CloseButton
@onready var save_config_button: Button = $MainPanel/VBoxContainer/ControlButtons/SaveConfigButton
@onready var reload_config_button: Button = $MainPanel/VBoxContainer/ControlButtons/ReloadConfigButton

# References
var power_manager: Node
var config_manager
var update_timer: Timer

# Statistics tracking
var spawn_attempts: int = 0
var successful_spawns: int = 0
var power_activations: Dictionary = {}
var power_collections: Dictionary = {}

# Visualization
var spawn_visualization_enabled: bool = false
var timer_display_enabled: bool = false

func _ready():
	_setup_ui()
	_connect_signals()
	_find_managers()
	_setup_update_timer()
	_load_current_config()

func _setup_ui():
	"""Initialize UI components"""
	# Set up sliders
	duration_slider.min_value = 1.0
	duration_slider.max_value = 30.0
	duration_slider.step = 0.5
	duration_slider.value = 10.0
	
	spawn_chance_slider.min_value = 0.0
	spawn_chance_slider.max_value = 1.0
	spawn_chance_slider.step = 0.01
	spawn_chance_slider.value = 0.15
	
	# Set up player selection
	test_player_spin.min_value = 1
	test_player_spin.max_value = 4
	test_player_spin.value = 1
	
	# Initially hide the debug UI
	visible = false

func _connect_signals():
	"""Connect UI signals"""
	# Configuration controls
	system_enabled_check.toggled.connect(_on_system_enabled_toggled)
	debug_mode_check.toggled.connect(_on_debug_mode_toggled)
	duration_slider.value_changed.connect(_on_duration_changed)
	spawn_chance_slider.value_changed.connect(_on_spawn_chance_changed)
	
	# Testing controls
	force_spawn_button.pressed.connect(_on_force_spawn_pressed)
	activate_power_button.pressed.connect(_on_activate_power_pressed)
	deactivate_all_button.pressed.connect(_on_deactivate_all_pressed)
	
	# Visualization controls
	spawn_visualization_check.toggled.connect(_on_spawn_visualization_toggled)
	timer_display_check.toggled.connect(_on_timer_display_toggled)
	
	# Control buttons
	close_button.pressed.connect(_on_close_pressed)
	save_config_button.pressed.connect(_on_save_config_pressed)
	reload_config_button.pressed.connect(_on_reload_config_pressed)
	reset_stats_button.pressed.connect(_on_reset_stats_pressed)

func _find_managers():
	"""Find power manager and config manager references"""
	power_manager = get_node_or_null("/root/PowerManager")
	if not power_manager:
		print("[PowerDebugUI] PowerManager not found")
	
	# Create config manager if it doesn't exist
	if not config_manager:
		var PowerConfigManager = preload("res://scripts/managers/power_config_manager.gd")
		config_manager = PowerConfigManager.new()

func _setup_update_timer():
	"""Setup timer for regular UI updates"""
	update_timer = Timer.new()
	update_timer.wait_time = 0.5  # Update every 500ms
	update_timer.timeout.connect(_update_display)
	add_child(update_timer)
	update_timer.start()

func _load_current_config():
	"""Load current configuration into UI"""
	if not config_manager:
		return
	
	# System settings
	system_enabled_check.button_pressed = config_manager.is_system_enabled()
	debug_mode_check.button_pressed = config_manager.is_debug_mode()
	
	# Power settings (using invincibility as example)
	var invincibility_config = config_manager.get_power_config("invincibility")
	if invincibility_config.size() > 0:
		duration_slider.value = invincibility_config.get("duration", 10.0)
		spawn_chance_slider.value = invincibility_config.get("spawn_chance", 0.15)
	
	# Visualization settings
	spawn_visualization_check.button_pressed = config_manager.get_debug_setting("show_spawn_visualization", false)
	timer_display_check.button_pressed = config_manager.get_debug_setting("show_power_timers", false)
	
	_update_labels()

func _update_labels():
	"""Update slider labels with current values"""
	duration_label.text = "Duration: %.1fs" % duration_slider.value
	spawn_chance_label.text = "Spawn Chance: %.1f%%" % (spawn_chance_slider.value * 100)

func _update_display():
	"""Update display with current power system state"""
	if not visible:
		return
	
	_update_active_powers_list()
	_update_statistics()

func _update_active_powers_list():
	"""Update the active powers list"""
	if not power_manager:
		return
	
	active_powers_list.clear()
	
	var active_powers = power_manager.get_all_active_powers()
	for player_index in active_powers.keys():
		var power_data = active_powers[player_index]
		var power_name = _get_power_name(power_data.type)
		var remaining_time = power_data.remaining_time
		
		var item_text = "Player %d: %s (%.1fs)" % [player_index, power_name, remaining_time]
		active_powers_list.add_item(item_text)

func _update_statistics():
	"""Update statistics display"""
	var stats_text = "[b]Power System Statistics[/b]\n\n"
	
	# Spawn statistics
	var spawn_rate = 0.0
	if spawn_attempts > 0:
		spawn_rate = float(successful_spawns) / float(spawn_attempts) * 100.0
	
	stats_text += "[b]Spawn Statistics:[/b]\n"
	stats_text += "• Spawn Attempts: %d\n" % spawn_attempts
	stats_text += "• Successful Spawns: %d\n" % successful_spawns
	stats_text += "• Actual Spawn Rate: %.1f%%\n\n" % spawn_rate
	
	# Power activation statistics
	stats_text += "[b]Power Activations:[/b]\n"
	for power_type in power_activations.keys():
		var power_name = _get_power_name(power_type)
		stats_text += "• %s: %d times\n" % [power_name, power_activations[power_type]]
	
	if power_activations.size() == 0:
		stats_text += "• No powers activated yet\n"
	
	stats_text += "\n[b]Power Collections:[/b]\n"
	for power_type in power_collections.keys():
		var power_name = _get_power_name(power_type)
		stats_text += "• %s: %d times\n" % [power_name, power_collections[power_type]]
	
	if power_collections.size() == 0:
		stats_text += "• No powers collected yet\n"
	
	# System status
	stats_text += "\n[b]System Status:[/b]\n"
	stats_text += "• System Enabled: %s\n" % ("Yes" if config_manager.is_system_enabled() else "No")
	stats_text += "• Debug Mode: %s\n" % ("Yes" if config_manager.is_debug_mode() else "No")
	
	if power_manager:
		var active_count = power_manager.get_all_active_powers().size()
		stats_text += "• Active Powers: %d\n" % active_count
	
	stats_label.text = stats_text

func _get_power_name(power_type) -> String:
	"""Get human-readable power name"""
	# Assuming PowerManager.PowerType enum values
	match power_type:
		0:  # INVINCIBILITY
			return "Invincibility"
		_:
			return "Unknown Power"

# Signal handlers

func _on_system_enabled_toggled(enabled: bool):
	"""Handle system enabled toggle"""
	if config_manager:
		config_manager.set_system_enabled(enabled)

func _on_debug_mode_toggled(enabled: bool):
	"""Handle debug mode toggle"""
	if config_manager:
		config_manager.set_debug_mode(enabled)

func _on_duration_changed(value: float):
	"""Handle duration slider change"""
	duration_label.text = "Duration: %.1fs" % value
	if config_manager:
		config_manager.set_power_duration("invincibility", value)

func _on_spawn_chance_changed(value: float):
	"""Handle spawn chance slider change"""
	spawn_chance_label.text = "Spawn Chance: %.1f%%" % (value * 100)
	if config_manager:
		config_manager.set_spawn_chance("invincibility", value)

func _on_force_spawn_pressed():
	"""Handle force spawn button"""
	if not power_manager:
		print("[PowerDebugUI] PowerManager not available")
		return
	
	# Create a power egg at a test position
	var power_egg_scene = power_manager.get_power_egg_scene()
	if power_egg_scene:
		var power_egg = power_egg_scene.instantiate()
		var current_scene = get_tree().current_scene
		if current_scene:
			power_egg.global_position = Vector2(400, 300)  # Center-ish position
			current_scene.add_child(power_egg)
			print("[PowerDebugUI] Force spawned power egg")
			
			# Track statistics
			successful_spawns += 1

func _on_activate_power_pressed():
	"""Handle activate power button"""
	if not power_manager:
		print("[PowerDebugUI] PowerManager not available")
		return
	
	var player_index = int(test_player_spin.value)
	var success = power_manager.activate_power(player_index, 0)  # INVINCIBILITY = 0
	
	if success:
		print("[PowerDebugUI] Activated invincibility for player %d" % player_index)
		# Track statistics
		if not power_activations.has(0):
			power_activations[0] = 0
		power_activations[0] += 1
	else:
		print("[PowerDebugUI] Failed to activate power for player %d" % player_index)

func _on_deactivate_all_pressed():
	"""Handle deactivate all button"""
	if not power_manager:
		print("[PowerDebugUI] PowerManager not available")
		return
	
	power_manager.reset_all_powers()
	print("[PowerDebugUI] Deactivated all powers")

func _on_spawn_visualization_toggled(enabled: bool):
	"""Handle spawn visualization toggle"""
	spawn_visualization_enabled = enabled
	print("[PowerDebugUI] Spawn visualization %s" % ("enabled" if enabled else "disabled"))

func _on_timer_display_toggled(enabled: bool):
	"""Handle timer display toggle"""
	timer_display_enabled = enabled
	print("[PowerDebugUI] Timer display %s" % ("enabled" if enabled else "disabled"))

func _on_close_pressed():
	"""Handle close button"""
	visible = false

func _on_save_config_pressed():
	"""Handle save config button"""
	if config_manager:
		var success = config_manager.save_configuration()
		if success:
			print("[PowerDebugUI] Configuration saved successfully")
		else:
			print("[PowerDebugUI] Failed to save configuration")

func _on_reload_config_pressed():
	"""Handle reload config button"""
	if config_manager:
		var success = config_manager.load_configuration()
		if success:
			_load_current_config()
			print("[PowerDebugUI] Configuration reloaded successfully")
		else:
			print("[PowerDebugUI] Failed to reload configuration")

func _on_reset_stats_pressed():
	"""Handle reset statistics button"""
	spawn_attempts = 0
	successful_spawns = 0
	power_activations.clear()
	power_collections.clear()
	print("[PowerDebugUI] Statistics reset")

# Public methods

func show_debug_ui():
	"""Show the debug UI"""
	visible = true
	_load_current_config()

func hide_debug_ui():
	"""Hide the debug UI"""
	visible = false

func toggle_debug_ui():
	"""Toggle debug UI visibility"""
	if visible:
		hide_debug_ui()
	else:
		show_debug_ui()

func track_spawn_attempt():
	"""Track a spawn attempt for statistics"""
	spawn_attempts += 1

func track_successful_spawn():
	"""Track a successful spawn for statistics"""
	successful_spawns += 1

func track_power_collection(power_type):
	"""Track a power collection for statistics"""
	if not power_collections.has(power_type):
		power_collections[power_type] = 0
	power_collections[power_type] += 1

func track_power_activation(power_type):
	"""Track a power activation for statistics"""
	if not power_activations.has(power_type):
		power_activations[power_type] = 0
	power_activations[power_type] += 1

# Input handling for debug hotkeys
func _input(event):
	"""Handle debug hotkeys"""
	if not config_manager or not config_manager.is_debug_mode():
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				toggle_debug_ui()
			KEY_F2:
				_on_force_spawn_pressed()
			KEY_F3:
				_on_activate_power_pressed()
			KEY_F4:
				_on_deactivate_all_pressed()