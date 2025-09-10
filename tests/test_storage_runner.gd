extends Node

# Test runner specifically for HighScoreStorage tests
# This can be run from the Godot editor or command line

var tests_passed = 0
var tests_failed = 0
var tests_total = 0
var test_name = "HighScoreStorage Tests"

func _ready():
	print("Starting %s..." % test_name)
	run_tests()
	print_final_results()

func run_tests():
	"""Override this method in test classes"""
	pass

func print_final_results():
	print("\n" + "="*60)
	print("FINAL TEST RESULTS - %s" % test_name)
	print("="*60)
	print("Tests Passed: %d" % tests_passed)
	print("Tests Failed: %d" % tests_failed)
	print("Total Tests: %d" % tests_total)
	
	var pass_rate = 0.0
	if tests_total > 0:
		pass_rate = float(tests_passed) / float(tests_total) * 100.0
	
	print("Pass Rate: %.1f%%" % pass_rate)
	
	if tests_failed == 0:
		print("🎉 ALL TESTS PASSED!")
	else:
		print("❌ %d TESTS FAILED" % tests_failed)
	
	print("="*60)