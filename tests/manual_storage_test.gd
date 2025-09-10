extends Node

# Manual test for HighScoreStorage - can be attached to any node and run
# This provides a simple way to verify the storage functionality works

func _ready():
	print("=== Manual HighScoreStorage Test ===")
	test_storage_functionality()

func test_storage_functionality():
	"""Simple test to verify storage works correctly"""
	
	# Create storage instance
	var storage = HighScoreStorage.new({
		"save_location": "user://manual_test.save",
		"backup_enabled": true,
		"debug_logging": true
	})
	
	# Clean up any existing test file
	if FileAccess.file_exists("user://manual_test.save"):
		DirAccess.remove_absolute("user://manual_test.save")
	if FileAccess.file_exists("user://manual_test.backup"):
		DirAccess.remove_absolute("user://manual_test.backup")
	
	print("\n1. Testing save operation...")
	
	# Create test data
	var test_scores: Array[Dictionary] = [
		{
			"name": "ManualTest1",
			"score": 10000,
			"date": "2024-01-01",
			"timestamp": 1704067200,
			"player_index": 1,
			"session_id": "manual_test_1",
			"version": "1.0.0"
		},
		{
			"name": "ManualTest2",
			"score": 8000,
			"date": "2024-01-02", 
			"timestamp": 1704153600,
			"player_index": 2,
			"session_id": "manual_test_2",
			"version": "1.0.0"
		}
	]
	
	# Save scores
	var save_result = storage.save_high_scores(test_scores)
	if save_result == HighScoreStorage.StorageError.SUCCESS:
		print("✓ Save operation successful")
	else:
		print("✗ Save operation failed: ", save_result)
		return
	
	print("\n2. Testing load operation...")
	
	# Load scores
	var loaded_scores = storage.load_high_scores()
	if loaded_scores.size() == 2:
		print("✓ Load operation successful - loaded %d scores" % loaded_scores.size())
		print("  - Score 1: %s with %d points" % [loaded_scores[0].name, loaded_scores[0].score])
		print("  - Score 2: %s with %d points" % [loaded_scores[1].name, loaded_scores[1].score])
	else:
		print("✗ Load operation failed - expected 2 scores, got %d" % loaded_scores.size())
		return
	
	print("\n3. Testing backup functionality...")
	
	# Create backup
	var backup_result = storage.backup_high_scores()
	if backup_result == HighScoreStorage.StorageError.SUCCESS:
		print("✓ Backup creation successful")
		if FileAccess.file_exists("user://manual_test.backup"):
			print("✓ Backup file exists")
		else:
			print("✗ Backup file not found")
	else:
		print("✗ Backup creation failed: ", backup_result)
	
	print("\n4. Testing file integrity...")
	
	# Verify file integrity
	var integrity_check = storage.verify_file_integrity("user://manual_test.save")
	if integrity_check:
		print("✓ File integrity verification passed")
	else:
		print("✗ File integrity verification failed")
	
	print("\n5. Testing corruption recovery...")
	
	# Corrupt the main file
	var file = FileAccess.open("user://manual_test.save", FileAccess.WRITE)
	file.store_string("corrupted data")
	file.close()
	
	# Try to load - should recover from backup
	var recovered_scores = storage.load_high_scores()
	if recovered_scores.size() == 2:
		print("✓ Recovery from backup successful")
		print("  - Recovered %d scores from backup" % recovered_scores.size())
	else:
		print("✗ Recovery from backup failed")
	
	print("\n6. Cleaning up test files...")
	
	# Clean up
	if FileAccess.file_exists("user://manual_test.save"):
		DirAccess.remove_absolute("user://manual_test.save")
		print("✓ Cleaned up main test file")
	
	if FileAccess.file_exists("user://manual_test.backup"):
		DirAccess.remove_absolute("user://manual_test.backup")
		print("✓ Cleaned up backup test file")
	
	print("\n=== Manual Test Complete ===")
	print("If all steps show ✓, the HighScoreStorage is working correctly!")