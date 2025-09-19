extends Node

# Test runner for migration system tests
class_name TestMigrationRunner

var test_migration: TestMigrationSystem

func _ready():
	print("=== Migration System Test Runner ===")
	
	# Create and run migration tests
	test_migration = TestMigrationSystem.new()
	add_child(test_migration)
	
	# Wait a frame for initialization
	await get_tree().process_frame
	
	# Run the tests
	test_migration.run_tests()
	
	# Print summary
	print("\n=== Migration Test Summary ===")
	print("Total Tests: %d" % test_migration.tests_total)
	print("Passed: %d" % test_migration.tests_passed)
	print("Failed: %d" % test_migration.tests_failed)
	
	if test_migration.tests_failed == 0:
		print("✅ All migration tests passed!")
	else:
		print("❌ Some migration tests failed!")
	
	print("=== Migration Test Runner Complete ===")