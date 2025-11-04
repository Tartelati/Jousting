class_name PowerConsole
extends Control

# Simple console for power system runtime commands
# Accessible via F12 key when debug mode is enabled

@onready var console_panel: Panel = $ConsolePanel
@onready var output_text: RichTextLabel = $ConsolePanel/VBoxContainer/OutputText
@onready var input_line: LineEdit = $ConsolePanel/VBoxContainer/InputContainer/InputLine
@onready var execute_button: Button = $ConsolePanel/VBoxContainer/InputContainer/ExecuteButton
@onready var clear_button: Button = $ConsolePanel/VBoxContainer/InputContainer/ClearButton

var power_manager: Node
var config_manager
var dev_tools
var command_history: Array[String] = []
var history_index: int = -1

func _ready():
	_setup_ui()
	_connect_signals()
	_find_managers()
	_setup_dev_tools()
	_print_welcome_message()

func _setup_ui():
	"""Setup console UI"""
	# Initially hide console
	visible = false
	
	# Setup console panel
	console_panel.size = Vector2(800, 400)
	console_panel.position = Vector2(100, 100)
	
	# Setup output text
	output_text.bbcode_enabled = true
	output_text.scroll_following = true

func _connect_signals():
	"""Connect UI signals"""
	input_line.text_submitted.connect(_on_command_submitted)
	execute_button.pressed.connect(_execute_current_command)
	clear_button.pressed.connect(_clear_output)

func _find_managers():
	"""Find power system managers"""
	power_manager = get_node_or_null("/root/PowerManager")
	if power_manager and power_manager.has_method("get_configuration_manager"):
		config_manager = power_manager.get_configuration_manager()

func _setup_dev_tools():
	"""Setup developer tools"""
	if power_manager:
		var PowerDevTools = preload("res://scripts/debug/power_dev_tools.gd")
		dev_tools = PowerDevTools.new(power_manager)

func _print_welcome_message():
	"""Print welcome message to console"""
	_print_line("[color=cyan][b]Power System Console[/b][/color]")
	_print_line("Type 'help' for available commands")
	_print_line("Press F12 to toggle console, Up/Down arrows for command history")
	_print_line("")

func _input(event):
	"""Handle console input events"""
	if not power_manager or not config_manager or not config_manager.is_debug_mode():
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F12:
				toggle_console()
			KEY_UP:
				if visible and input_line.has_focus():
					_navigate_history(-1)
			KEY_DOWN:
				if visible and input_line.has_focus():
					_navigate_history(1)

func toggle_console():
	"""Toggle console visibility"""
	visible = not visible
	if visible:
		input_line.grab_focus()

func _navigate_history(direction: int):
	"""Navigate command history"""
	if command_history.size() == 0:
		return
	
	history_index += direction
	history_index = clamp(history_index, -1, command_history.size() - 1)
	
	if history_index >= 0:
		input_line.text = command_history[history_index]
		input_line.caret_column = input_line.text.length()
	else:
		input_line.text = ""

func _on_command_submitted(command: String):
	"""Handle command submission"""
	_execute_command(command)

func _execute_current_command():
	"""Execute command from input line"""
	var command = input_line.text.strip_edges()
	if command != "":
		_execute_command(command)

func _execute_command(command: String):
	"""Execute a console command"""
	if command.strip_edges() == "":
		return
	
	# Add to history
	if command_history.size() == 0 or command_history[-1] != command:
		command_history.append(command)
		if command_history.size() > 50:  # Limit history size
			command_history.pop_front()
	history_index = -1
	
	# Print command
	_print_line("[color=yellow]> %s[/color]" % command)
	
	# Parse and execute command
	var parts = command.split(" ", false)
	if parts.size() == 0:
		return
	
	var cmd = parts[0].to_lower()
	var args = parts.slice(1)
	
	match cmd:
		"help":
			_cmd_help(args)
		"status":
			_cmd_status(args)
		"enable":
			_cmd_enable(args)
		"disable":
			_cmd_disable(args)
		"set":
			_cmd_set(args)
		"get":
			_cmd_get(args)
		"preset":
			_cmd_preset(args)
		"test":
			_cmd_test(args)
		"spawn":
			_cmd_spawn(args)
		"activate":
			_cmd_activate(args)
		"deactivate":
			_cmd_deactivate(args)
		"reset":
			_cmd_reset(args)
		"save":
			_cmd_save(args)
		"load":
			_cmd_load(args)
		"export":
			_cmd_export(args)
		"clear":
			_clear_output()
		_:
			_print_line("[color=red]Unknown command: %s[/color]" % cmd)
			_print_line("Type 'help' for available commands")
	
	# Clear input
	input_line.text = ""

# Command implementations

func _cmd_help(args: Array):
	"""Show help information"""
	if args.size() > 0:
		var topic = args[0].to_lower()
		match topic:
			"set":
				_print_line("[b]SET command usage:[/b]")
				_print_line("  set duration <seconds>     - Set power duration")
				_print_line("  set spawn_chance <0-1>     - Set spawn chance")
				_print_line("  set enemy_rate <enemy> <0-1> - Set enemy spawn rate")
			"test":
				_print_line("[b]TEST command usage:[/b]")
				_print_line("  test spawn_rate [iterations] - Test spawn rate accuracy")
				_print_line("  test duration [player]       - Test power duration")
			"preset":
				_print_line("[b]PRESET command usage:[/b]")
				_print_line("  preset testing    - Apply testing configuration")
				_print_line("  preset balanced   - Apply balanced configuration")
				_print_line("  preset rare       - Apply rare spawn configuration")
				_print_line("  preset frequent   - Apply frequent spawn configuration")
			_:
				_print_line("[color=red]No help available for: %s[/color]" % topic)
	else:
		_print_line("[b]Available commands:[/b]")
		_print_line("  [color=cyan]help [topic][/color]        - Show help (topics: set, test, preset)")
		_print_line("  [color=cyan]status[/color]              - Show system status")
		_print_line("  [color=cyan]enable/disable[/color]      - Enable/disable power system")
		_print_line("  [color=cyan]set <param> <value>[/color] - Set configuration parameter")
		_print_line("  [color=cyan]get <param>[/color]         - Get configuration parameter")
		_print_line("  [color=cyan]preset <name>[/color]       - Apply configuration preset")
		_print_line("  [color=cyan]test <type> [args][/color]  - Run tests")
		_print_line("  [color=cyan]spawn <count>[/color]       - Force spawn power eggs")
		_print_line("  [color=cyan]activate <player>[/color]   - Activate power for player")
		_print_line("  [color=cyan]deactivate [player][/color] - Deactivate power(s)")
		_print_line("  [color=cyan]reset[/color]               - Reset all powers")
		_print_line("  [color=cyan]save/load[/color]           - Save/load configuration")
		_print_line("  [color=cyan]export[/color]              - Export configuration report")
		_print_line("  [color=cyan]clear[/color]               - Clear console output")

func _cmd_status(_args: Array):
	"""Show system status"""
	_print_line("[b]Power System Status:[/b]")
	_print_line("  System Enabled: %s" % config_manager.is_system_enabled())
	_print_line("  Debug Mode: %s" % config_manager.is_debug_mode())
	
	if power_manager:
		var active_powers = power_manager.get_all_active_powers()
		_print_line("  Active Powers: %d" % active_powers.size())
		
		for player_index in active_powers.keys():
			var power_data = active_powers[player_index]
			_print_line("    Player %d: %s (%.1fs remaining)" % [
				player_index,
				_get_power_name(power_data.type),
				power_data.remaining_time
			])
	
	_print_line("  Invincibility Duration: %.1fs" % config_manager.get_power_duration("invincibility"))
	_print_line("  Invincibility Spawn Chance: %.1f%%" % (config_manager.get_spawn_chance("invincibility") * 100))

func _cmd_enable(_args: Array):
	"""Enable power system"""
	config_manager.set_system_enabled(true)
	_print_line("[color=green]Power system enabled[/color]")

func _cmd_disable(_args: Array):
	"""Disable power system"""
	config_manager.set_system_enabled(false)
	_print_line("[color=orange]Power system disabled[/color]")

func _cmd_set(args: Array):
	"""Set configuration parameter"""
	if args.size() < 2:
		_print_line("[color=red]Usage: set <parameter> <value>[/color]")
		return
	
	var param = args[0].to_lower()
	var value_str = args[1]
	
	match param:
		"duration":
			var value = value_str.to_float()
			if value > 0:
				config_manager.set_power_duration("invincibility", value)
				_print_line("[color=green]Set duration to %.1fs[/color]" % value)
			else:
				_print_line("[color=red]Invalid duration: %s[/color]" % value_str)
		
		"spawn_chance":
			var value = value_str.to_float()
			if value >= 0 and value <= 1:
				config_manager.set_spawn_chance("invincibility", value)
				_print_line("[color=green]Set spawn chance to %.1f%%[/color]" % (value * 100))
			else:
				_print_line("[color=red]Invalid spawn chance (must be 0-1): %s[/color]" % value_str)
		
		"enemy_rate":
			if args.size() < 3:
				_print_line("[color=red]Usage: set enemy_rate <enemy_type> <rate>[/color]")
				return
			var enemy_type = args[1]
			var rate = args[2].to_float()
			if rate >= 0 and rate <= 1:
				config_manager.set_enemy_spawn_rate("invincibility", enemy_type, rate)
				_print_line("[color=green]Set %s spawn rate to %.1f%%[/color]" % [enemy_type, rate * 100])
			else:
				_print_line("[color=red]Invalid rate (must be 0-1): %s[/color]" % args[2])
		
		_:
			_print_line("[color=red]Unknown parameter: %s[/color]" % param)

func _cmd_get(args: Array):
	"""Get configuration parameter"""
	if args.size() < 1:
		_print_line("[color=red]Usage: get <parameter>[/color]")
		return
	
	var param = args[0].to_lower()
	
	match param:
		"duration":
			var value = config_manager.get_power_duration("invincibility")
			_print_line("Duration: %.1fs" % value)
		
		"spawn_chance":
			var value = config_manager.get_spawn_chance("invincibility")
			_print_line("Spawn Chance: %.1f%%" % (value * 100))
		
		"enemy_rates":
			var invincibility_config = config_manager.get_power_config("invincibility")
			var enemy_rates = invincibility_config.get("enemy_spawn_rates", {})
			_print_line("Enemy Spawn Rates:")
			for enemy_type in enemy_rates.keys():
				_print_line("  %s: %.1f%%" % [enemy_type, enemy_rates[enemy_type] * 100])
		
		_:
			_print_line("[color=red]Unknown parameter: %s[/color]" % param)

func _cmd_preset(args: Array):
	"""Apply configuration preset"""
	if args.size() < 1:
		_print_line("[color=red]Usage: preset <name>[/color]")
		_print_line("Available presets: testing, balanced, rare, frequent")
		return
	
	var preset_name = args[0].to_lower()
	var success = false
	
	match preset_name:
		"testing":
			success = dev_tools.apply_testing_preset()
		"balanced":
			success = dev_tools.apply_balanced_preset()
		"rare":
			success = dev_tools.apply_rare_preset()
		"frequent":
			success = dev_tools.apply_frequent_preset()
		_:
			_print_line("[color=red]Unknown preset: %s[/color]" % preset_name)
			return
	
	if success:
		_print_line("[color=green]Applied %s preset[/color]" % preset_name)
	else:
		_print_line("[color=red]Failed to apply preset[/color]")

func _cmd_test(args: Array):
	"""Run tests"""
	if args.size() < 1:
		_print_line("[color=red]Usage: test <type> [args][/color]")
		_print_line("Available tests: spawn_rate, duration")
		return
	
	var test_type = args[0].to_lower()
	
	match test_type:
		"spawn_rate":
			var iterations = 1000
			if args.size() > 1:
				iterations = args[1].to_int()
			
			_print_line("Running spawn rate test with %d iterations..." % iterations)
			var results = dev_tools.run_spawn_rate_test(iterations)
			
			_print_line("[b]Spawn Rate Test Results:[/b]")
			_print_line("  Overall Rate: %.2f%%" % (results.get("overall_rate", 0.0) * 100))
			
			var enemy_results = results.get("enemy_results", {})
			for enemy_type in enemy_results.keys():
				var enemy_data = enemy_results[enemy_type]
				_print_line("  %s: %.2f%% (%d/%d)" % [
					enemy_type,
					enemy_data.rate * 100,
					enemy_data.spawns,
					enemy_data.attempts
				])
		
		"duration":
			var player_index = 1
			if args.size() > 1:
				player_index = args[1].to_int()
			
			var result = dev_tools.test_power_duration_accuracy(player_index)
			if result.has("error"):
				_print_line("[color=red]%s[/color]" % result.error)
			else:
				_print_line("Started duration test for player %d (expected: %.1fs)" % [
					player_index,
					result.expected_duration
				])
		
		_:
			_print_line("[color=red]Unknown test type: %s[/color]" % test_type)

func _cmd_spawn(args: Array):
	"""Force spawn power eggs"""
	var count = 1
	if args.size() > 0:
		count = args[0].to_int()
	
	dev_tools.force_spawn_power_eggs(count)
	_print_line("[color=green]Spawned %d power eggs[/color]" % count)

func _cmd_activate(args: Array):
	"""Activate power for player"""
	if args.size() < 1:
		_print_line("[color=red]Usage: activate <player_index>[/color]")
		return
	
	var player_index = args[0].to_int()
	if player_index < 1 or player_index > 4:
		_print_line("[color=red]Invalid player index (must be 1-4): %d[/color]" % player_index)
		return
	
	var success = power_manager.activate_power(player_index, 0)  # INVINCIBILITY = 0
	if success:
		_print_line("[color=green]Activated invincibility for player %d[/color]" % player_index)
	else:
		_print_line("[color=red]Failed to activate power for player %d[/color]" % player_index)

func _cmd_deactivate(args: Array):
	"""Deactivate power(s)"""
	if args.size() == 0:
		# Deactivate all
		power_manager.reset_all_powers()
		_print_line("[color=green]Deactivated all powers[/color]")
	else:
		var player_index = args[0].to_int()
		if player_index < 1 or player_index > 4:
			_print_line("[color=red]Invalid player index (must be 1-4): %d[/color]" % player_index)
			return
		
		power_manager.deactivate_power(player_index)
		_print_line("[color=green]Deactivated power for player %d[/color]" % player_index)

func _cmd_reset(_args: Array):
	"""Reset system"""
	power_manager.reset_all_powers()
	_print_line("[color=green]Reset all powers[/color]")

func _cmd_save(_args: Array):
	"""Save configuration"""
	var success = config_manager.save_configuration()
	if success:
		_print_line("[color=green]Configuration saved[/color]")
	else:
		_print_line("[color=red]Failed to save configuration[/color]")

func _cmd_load(_args: Array):
	"""Load configuration"""
	var success = config_manager.load_configuration()
	if success:
		_print_line("[color=green]Configuration loaded[/color]")
	else:
		_print_line("[color=red]Failed to load configuration[/color]")

func _cmd_export(_args: Array):
	"""Export configuration report"""
	var report = dev_tools.export_configuration_report()
	_print_line("[b]Configuration Report:[/b]")
	_print_line(report)

# Utility methods

func _print_line(text: String):
	"""Print line to console output"""
	output_text.append_text(text + "\n")

func _clear_output():
	"""Clear console output"""
	output_text.clear()
	_print_welcome_message()

func _get_power_name(power_type) -> String:
	"""Get human-readable power name"""
	match power_type:
		0:  # INVINCIBILITY
			return "Invincibility"
		_:
			return "Unknown Power"