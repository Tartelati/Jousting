extends Control

@onready var test_script = preload("res://tests/integration_multi_player_power_test.gd")
@onready var start_button = $VBoxContainer/StartButton
@onready var results_label = $VBoxContainer/ScrollContainer/ResultsLabel

var test_instance

func _ready():
	start_button.pressed.connect(_on_start_button_pressed)
	results_label.text = "Multi-Player Power Independence Test\nClick 'Start Test' to begin..."

func _on_start_button_pressed():
	start_button.disabled = true
	results_label.text = "Running multi-player power independence tests...\n"
	
	# Create test instance
	test_instance = test_script.new()
	add_child(test_instance)
	
	# Connect to test completion
	if test_instance.has_signal("test_completed"):
		test_instance.connect("test_completed", _on_test_completed)
	
	# Run tests
	test_instance.run_all_tests()

func _on_test_completed():
	start_button.disabled = false
	if test_instance:
		results_label.text += "\nTest completed! Check console for detailed results."
		test_instance.queue_free()