class_name TestBase
extends Node

# Simple test base class to replace GUT functionality
# Provides basic assertion methods for testing

var _test_results = []
var _tests_passed = 0
var _tests_failed = 0

# Test assertion methods
func assert_eq(actual, expected, message: String = ""):
	var test_name = message if message != "" else "Equality check"
	if actual == expected:
		_tests_passed += 1
		_test_results.append("✓ PASS: " + test_name)
		return true
	else:
		_tests_failed += 1
		_test_results.append("✗ FAIL: " + test_name + " (expected: " + str(expected) + ", got: " + str(actual) + ")")
		return false

func assert_true(condition: bool, message: String = ""):
	var test_name = message if message != "" else "True condition check"
	if condition:
		_tests_passed += 1
		_test_results.append("✓ PASS: " + test_name)
		return true
	else:
		_tests_failed += 1
		_test_results.append("✗ FAIL: " + test_name + " (expected true, got false)")
		return false

func assert_false(condition: bool, message: String = ""):
	var test_name = message if message != "" else "False condition check"
	if not condition:
		_tests_passed += 1
		_test_results.append("✓ PASS: " + test_name)
		return true
	else:
		_tests_failed += 1
		_test_results.append("✗ FAIL: " + test_name + " (expected false, got true)")
		return false

func assert_not_null(value, message: String = ""):
	var test_name = message if message != "" else "Not null check"
	if value != null:
		_tests_passed += 1
		_test_results.append("✓ PASS: " + test_name)
		return true
	else:
		_tests_failed += 1
		_test_results.append("✗ FAIL: " + test_name + " (expected not null, got null)")
		return false

func assert_null(value, message: String = ""):
	var test_name = message if message != "" else "Null check"
	if value == null:
		_tests_passed += 1
		_test_results.append("✓ PASS: " + test_name)
		return true
	else:
		_tests_failed += 1
		_test_results.append("✗ FAIL: " + test_name + " (expected null, got " + str(value) + ")")
		return false

func assert_gt(actual, expected, message: String = ""):
	var test_name = message if message != "" else "Greater than check"
	if actual > expected:
		_tests_passed += 1
		_test_results.append("✓ PASS: " + test_name)
		return true
	else:
		_tests_failed += 1
		_test_results.append("✗ FAIL: " + test_name + " (expected " + str(actual) + " > " + str(expected) + ")")
		return false

func assert_lt(actual, expected, message: String = ""):
	var test_name = message if message != "" else "Less than check"
	if actual < expected:
		_tests_passed += 1
		_test_results.append("✓ PASS: " + test_name)
		return true
	else:
		_tests_failed += 1
		_test_results.append("✗ FAIL: " + test_name + " (expected " + str(actual) + " < " + str(expected) + ")")
		return false

func assert_ge(actual, expected, message: String = ""):
	var test_name = message if message != "" else "Greater than or equal check"
	if actual >= expected:
		_tests_passed += 1
		_test_results.append("✓ PASS: " + test_name)
		return true
	else:
		_tests_failed += 1
		_test_results.append("✗ FAIL: " + test_name + " (expected " + str(actual) + " >= " + str(expected) + ")")
		return false

func assert_ne(actual, expected, message: String = ""):
	var test_name = message if message != "" else "Not equal check"
	if actual != expected:
		_tests_passed += 1
		_test_results.append("✓ PASS: " + test_name)
		return true
	else:
		_tests_failed += 1
		_test_results.append("✗ FAIL: " + test_name + " (expected " + str(actual) + " != " + str(expected) + ")")
		return false

# Helper methods
func add_child_autofree(node: Node):
	"""Add a child node that will be automatically freed"""
	add_child(node)
	# Store reference for cleanup
	if not has_meta("_autofree_children"):
		set_meta("_autofree_children", [])
	var children = get_meta("_autofree_children")
	children.append(node)
	set_meta("_autofree_children", children)

func wait_frames(frame_count: int = 1):
	"""Wait for specified number of frames"""
	for i in frame_count:
		await get_tree().process_frame

# Test lifecycle methods
func before_each():
	"""Override this method to set up before each test"""
	pass

func after_each():
	"""Override this method to clean up after each test"""
	# Clean up autofree children
	if has_meta("_autofree_children"):
		var children = get_meta("_autofree_children")
		for child in children:
			if is_instance_valid(child) and child.get_parent() == self:
				child.queue_free()
		set_meta("_autofree_children", [])

func before_all():
	"""Override this method to set up before all tests"""
	pass

func after_all():
	"""Override this method to clean up after all tests"""
	pass

# Test execution
func run_tests():
	"""Run all test methods in this class"""
	_test_results.clear()
	_tests_passed = 0
	_tests_failed = 0
	
	before_all()
	
	# Get all methods that start with "test_"
	var methods = []
	for method in get_method_list():
		if method.name.begins_with("test_"):
			methods.append(method.name)
	
	# Run each test method
	for method_name in methods:
		before_each()
		print("Running: " + method_name)
		call(method_name)
		after_each()
		await get_tree().process_frame
	
	after_all()
	
	# Print results
	print_results()

func print_results():
	"""Print test results"""
	print("\n" + "=".repeat(50))
	print("TEST RESULTS")
	print("=".repeat(50))
	
	for result in _test_results:
		print(result)
	
	print("\n" + "=".repeat(50))
	print("SUMMARY:")
	print("Tests Passed: %d" % _tests_passed)
	print("Tests Failed: %d" % _tests_failed)
	print("Total Tests: %d" % (_tests_passed + _tests_failed))
	
	if _tests_failed == 0:
		print("🎉 ALL TESTS PASSED!")
	else:
		print("❌ %d TESTS FAILED" % _tests_failed)
	
	print("=".repeat(50))

func get_test_summary():
	"""Get test summary as dictionary"""
	return {
		"passed": _tests_passed,
		"failed": _tests_failed,
		"total": _tests_passed + _tests_failed,
		"results": _test_results
	}