extends Node

# Integration test for migration system
class_name IntegrationMigrationTest

var score_manager: Node
var test_results: Dictionary = {
	"tests_run": 0,
	"tests_passed": 0,
	"tests_failed": 0
}

func _ready():
	print("=== Integration Migration Test ===")
	
	# Get the ScoreManager
	score_manager = get_node("/root/ScoreManager")
	if not score_manager:
		print("❌ ScoreManager not found - cannot run integration tests")
		return
	
	# Run integration tests
	await run_integration_tests()
	
	# Print results
	print_test_results()

func run_integration_tests():
	"""Run comprehensive integration tests for migration system"""
	
	# Test 1: Legacy file migration through ScoreManager
	await test_legacy_file_migration_integration()
	
	# Test 2: Version upgrade simulation
	await test_version_upgrade_simulation()
	
	# Test 3: Save file recovery integration
	await test_save_file_recovery_integration()
	
	# Test 4: Migration with existing game data
	await test_migration_with_existing_data()

func test_legacy_file_migration_integration():
	"""Test complete legacy file migration through ScoreManager"""
	print("\n--- Testing Legacy File Migration Integration ---")
	
	# Create a legacy save file
	var legacy_scores = [
		{"name": "LegacyPlayer1", "score": 25000},
		{"name": "LegacyPlayer2", "score": 18000},
		{"name": "David Lacassagne", "score": 999999999}  # Ensure David is preserved
	]
	
	var save_path = "user://high_scores.save"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_var(legacy_scores)
	file.close()
	
	# Reinitialize ScoreManager to trigger migration
	score_manager.load_high_scores()
	
	# Wait for processing
	await get_tree().process_frame
	
	# Verify migration occurred
	var high_scores = score_manager.high_scores
	
	if high_scores.size() >= 3:
		# Check that David is still at the top
		if high_scores[0].name == "David Lacassagne":
			record_test_result(true, "David Lacassagne preserved at top after migration")
		else:
			record_test_result(false, "David Lacassagne not preserved at top after migration")
		
		# Check that legacy players were migrated with enhanced fields
		var legacy_player_found = false
		for entry in high_scores:
			if entry.name == "LegacyPlayer1":
				legacy_player_found = true
				if entry.has("date") and entry.has("timestamp") and entry.has("version"):
					record_test_result(true, "Legacy player migrated with enhanced fields")
				else:
					record_test_result(false, "Legacy player missing enhanced fields after migration")
				break
		
		if not legacy_player_found:
			record_test_result(false, "Legacy player not found after migration")
	else:
		record_test_result(false, "Insufficient scores after migration")
	
	# Verify file was updated to new format
	file = FileAccess.open(save_path, FileAccess.READ)
	var saved_data = file.get_var()
	file.close()
	
	if saved_data is Dictionary and saved_data.has("version") and saved_data.has("magic"):
		record_test_result(true, "Save file updated to new format after migration")
	else:
		record_test_result(false, "Save file not updated to new format after migration")

func test_version_upgrade_simulation():
	"""Test simulation of version upgrade scenario"""
	print("\n--- Testing Version Upgrade Simulation ---")
	
	# Create a v1.0 format file
	var v1_0_data = {
		"magic": "HSCORE",
		"timestamp": Time.get_unix_time_from_system(),
		"scores": [
			{"name": "V1Player", "score": 12000, "date": "2024-01-01"},
			{"name": "AnotherV1Player", "score": 8000, "date": "2024-01-02"}
		],
		"checksum": "test_checksum"
	}
	
	var save_path = "user://high_scores.save"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_var(v1_0_data)
	file.close()
	
	# Load through ScoreManager
	score_manager.load_high_scores()
	await get_tree().process_frame
	
	# Check migration backup was created
	var backup_path = save_path.get_basename() + "_pre_migration_1.0.backup"
	if FileAccess.file_exists(backup_path):
		record_test_result(true, "Migration backup created for v1.0 upgrade")
		
		# Verify backup contains original data
		var backup_file = FileAccess.open(backup_path, FileAccess.READ)
		var backup_data = backup_file.get_var()
		backup_file.close()
		
		if backup_data.has("original_data") and backup_data.has("detected_version"):
			record_test_result(true, "Migration backup contains proper metadata")
		else:
			record_test_result(false, "Migration backup missing metadata")
		
		# Cleanup backup
		DirAccess.remove_absolute(backup_path)
	else:
		record_test_result(false, "Migration backup not created for v1.0 upgrade")
	
	# Verify scores were migrated with version tracking
	var migrated_scores = score_manager.high_scores
	var v1_player_found = false
	
	for entry in migrated_scores:
		if entry.name == "V1Player":
			v1_player_found = true
			if entry.has("version") and entry.version.begins_with("migrated_from_"):
				record_test_result(true, "V1.0 player migrated with version tracking")
			else:
				record_test_result(false, "V1.0 player missing version tracking")
			break
	
	if not v1_player_found:
		record_test_result(false, "V1.0 player not found after migration")

func test_save_file_recovery_integration():
	"""Test save file recovery from alternate locations"""
	print("\n--- Testing Save File Recovery Integration ---")
	
	# Remove main save file
	var main_save_path = "user://high_scores.save"
	if FileAccess.file_exists(main_save_path):
		DirAccess.remove_absolute(main_save_path)
	
	# Create save file in alternate location
	var alt_path = "user://scores.save"
	var recovery_scores = [
		{"name": "RecoveredPlayer", "score": 15000},
		{"name": "David Lacassagne", "score": 999999999}
	]
	
	var file = FileAccess.open(alt_path, FileAccess.WRITE)
	file.store_var(recovery_scores)
	file.close()
	
	# Load through ScoreManager - should trigger recovery
	score_manager.load_high_scores()
	await get_tree().process_frame
	
	# Verify recovery occurred
	var recovered_scores = score_manager.high_scores
	var recovered_player_found = false
	
	for entry in recovered_scores:
		if entry.name == "RecoveredPlayer":
			recovered_player_found = true
			record_test_result(true, "Player recovered from alternate location")
			break
	
	if not recovered_player_found:
		record_test_result(false, "Player not recovered from alternate location")
	
	# Verify main save file was recreated
	if FileAccess.file_exists(main_save_path):
		record_test_result(true, "Main save file recreated after recovery")
	else:
		record_test_result(false, "Main save file not recreated after recovery")
	
	# Cleanup alternate file
	if FileAccess.file_exists(alt_path):
		DirAccess.remove_absolute(alt_path)

func test_migration_with_existing_data():
	"""Test migration when there's existing game data"""
	print("\n--- Testing Migration with Existing Data ---")
	
	# Set up some current game scores
	score_manager.reset_all_players()
	score_manager.add_score(1, 5000)
	score_manager.add_score(2, 3000)
	
	# Create legacy save file
	var legacy_data = [
		{"name": "OldChampion", "score": 50000},
		{"name": "LegacyHero", "score": 30000}
	]
	
	var save_path = "user://high_scores.save"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_var(legacy_data)
	file.close()
	
	# Load high scores - should migrate legacy data
	score_manager.load_high_scores()
	await get_tree().process_frame
	
	# Verify both legacy and current data coexist properly
	var final_scores = score_manager.high_scores
	var old_champion_found = false
	var david_found = false
	
	for entry in final_scores:
		if entry.name == "OldChampion":
			old_champion_found = true
		elif entry.name == "David Lacassagne":
			david_found = true
	
	if old_champion_found and david_found:
		record_test_result(true, "Legacy and default data coexist after migration")
	else:
		record_test_result(false, "Legacy and default data not properly merged")
	
	# Test submitting new high score after migration
	var submission_result = score_manager.submit_high_score(1, "NewPlayer")
	
	if submission_result.success:
		record_test_result(true, "New high score submission works after migration")
	else:
		record_test_result(false, "New high score submission failed after migration")

func record_test_result(passed: bool, test_name: String):
	"""Record the result of a test"""
	test_results.tests_run += 1
	
	if passed:
		test_results.tests_passed += 1
		print("✓ PASS: %s" % test_name)
	else:
		test_results.tests_failed += 1
		print("✗ FAIL: %s" % test_name)

func print_test_results():
	"""Print final test results"""
	print("\n=== Integration Migration Test Results ===")
	print("Total Tests: %d" % test_results.tests_run)
	print("Passed: %d" % test_results.tests_passed)
	print("Failed: %d" % test_results.tests_failed)
	
	if test_results.tests_failed == 0:
		print("✅ All integration migration tests passed!")
	else:
		print("❌ Some integration migration tests failed!")
	
	print("=== Integration Migration Test Complete ===")