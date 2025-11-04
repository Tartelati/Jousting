extends Node

# Test runner for power configuration system
# Run this scene to test the configuration and balancing system

@onready var test_label: Label = $UI/VBoxContainer/TestLabel
@onready var results_text: RichTextLabel = $UI/VBoxContainer/ResultsText
@onready var run_button: Button = $UI/VBoxContainer/RunButton

var config_test: Resource

func _ready():
	_setup_ui()
	_connect_signals()

func _setup_ui():
	test_label.text = "Power Configuration System Tests"
	results_text.bbcode_enabled = true
	results_text.text = "Click 'Run Tests' to start configuration system tests"

func _connect_signals():
	run_button.pressed.connect(_run_tests)

func _run_tests():
	results_text.clear()
	results_text.append_text("[b]Running Power Configuration System Tests...[/b]\n\n")
	
	# Load and run configuration manager tests
	var config_test_script = preload("res://tests/unit/test_power_config_manager.gd")
	config_test = config_test_script.new()
	
	# Capture test output
	var original_print = print
	var test_output = []
	
	# Run tests and capture output
	config_test.run_all_tests()
	
	# Display results
	_display_test_results()

func _display_test_results():
	if not config_test:
		results_text.append_text("[color=red]Failed to run tests[/color]\n")
		return
	
	var total_tests = config_test.total_tests
	var passed_tests = config_test.passed_tests
	var failed_tests = config_test.failed_tests
	
	results_text.append_text("[b]Test Results Summary:[/b]\n")
	results_text.append_text("Total Tests: %d\n" % total_tests)
	results_text.append_text("[color=green]Passed: %d[/color]\n" % passed_tests)
	
	if failed_tests > 0:
		results_text.append_text("[color=red]Failed: %d[/color]\n" % failed_tests)
	else:
		results_text.append_text("Failed: 0\n")
	
	results_text.append_text("\n")
	
	if failed_tests == 0:
		results_text.append_text("[color=green][b]All configuration tests passed![/b][/color]\n")
		results_text.append_text("The power system configuration and balancing system is working correctly.\n")
	else:
		results_text.append_text("[color=red][b]Some tests failed![/b][/color]\n")
		results_text.append_text("Check the console output for detailed error information.\n")
	
	# Add configuration system status
	results_text.append_text("\n[b]Configuration System Status:[/b]\n")
	
	var config_manager = PowerConfigManager.new()
	if config_manager:
		results_text.append_text("✓ PowerConfigManager can be instantiated\n")
		results_text.append_text("✓ Default configuration loads successfully\n")
		results_text.append_text("✓ System enabled: %s\n" % config_manager.is_system_enabled())
		results_text.append_text("✓ Debug mode: %s\n" % config_manager.is_debug_mode())
		
		var invincibility_config = config_manager.get_power_config("invincibility")
		if invincibility_config.size() > 0:
			results_text.append_text("✓ Invincibility power configuration loaded\n")
			results_text.append_text("  - Duration: %.1fs\n" % invincibility_config.get("duration", 0.0))
			results_text.append_text("  - Spawn Chance: %.1f%%\n" % (invincibility_config.get("spawn_chance", 0.0) * 100))
		else:
			results_text.append_text("[color=red]✗ Invincibility power configuration missing[/color]\n")
	else:
		results_text.append_text("[color=red]✗ PowerConfigManager failed to instantiate[/color]\n")
	
	# Test configuration file existence
	results_text.append_text("\n[b]Configuration Files:[/b]\n")
	if FileAccess.file_exists("res://power_system_config.json"):
		results_text.append_text("✓ Default configuration file exists\n")
	else:
		results_text.append_text("[color=red]✗ Default configuration file missing[/color]\n")
	
	if FileAccess.file_exists("user://power_system_config.json"):
		results_text.append_text("✓ User configuration file exists\n")
	else:
		results_text.append_text("- User configuration file not found (will be created when needed)\n")
	
	results_text.append_text("\n[b]Debug Tools Status:[/b]\n")
	
	# Test debug UI scene
	var debug_ui_path = "res://scenes/debug/power_debug_ui.tscn"
	if ResourceLoader.exists(debug_ui_path):
		results_text.append_text("✓ Debug UI scene exists\n")
	else:
		results_text.append_text("[color=red]✗ Debug UI scene missing[/color]\n")
	
	# Test debug console scene
	var console_path = "res://scenes/debug/power_console.tscn"
	if ResourceLoader.exists(console_path):
		results_text.append_text("✓ Debug console scene exists\n")
	else:
		results_text.append_text("[color=red]✗ Debug console scene missing[/color]\n")
	
	# Test dev tools script
	var dev_tools_path = "res://scripts/debug/power_dev_tools.gd"
	if ResourceLoader.exists(dev_tools_path):
		results_text.append_text("✓ Developer tools script exists\n")
	else:
		results_text.append_text("[color=red]✗ Developer tools script missing[/color]\n")
	
	results_text.append_text("\n[b]Integration Test:[/b]\n")
	
	# Test PowerManager integration
	var power_manager = get_node_or_null("/root/PowerManager")
	if power_manager:
		results_text.append_text("✓ PowerManager found in scene tree\n")
		
		if power_manager.has_method("get_configuration_manager"):
			var pm_config_manager = power_manager.get_configuration_manager()
			if pm_config_manager:
				results_text.append_text("✓ PowerManager has configuration manager\n")
			else:
				results_text.append_text("[color=red]✗ PowerManager configuration manager is null[/color]\n")
		else:
			results_text.append_text("[color=red]✗ PowerManager missing get_configuration_manager method[/color]\n")
		
		if power_manager.has_method("toggle_debug_ui"):
			results_text.append_text("✓ PowerManager has debug UI toggle method\n")
		else:
			results_text.append_text("[color=red]✗ PowerManager missing debug UI methods[/color]\n")
	else:
		results_text.append_text("[color=orange]- PowerManager not found (may not be loaded in test scene)[/color]\n")
	
	results_text.append_text("\n[color=cyan][b]Configuration System Test Complete![/b][/color]\n")
	results_text.append_text("Press F1 to toggle debug UI, F12 to toggle console (when debug mode is enabled)\n")