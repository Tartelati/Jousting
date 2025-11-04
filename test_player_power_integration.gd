extends Node

# Simple test to verify player power integration

func _ready():
	print("Testing Player Power Integration...")
	
	# Test PowerManager availability
	var power_manager = get_node_or_null("/root/PowerManager")
	if power_manager:
		print("✓ PowerManager found")
		
		# Test power activation
		var result = power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
		if result:
			print("✓ Power activation successful")
			
			# Check if power is active
			if power_manager.is_power_active(1):
				print("✓ Power is active for player 1")
			else:
				print("❌ Power should be active")
			
			# Test deactivation
			power_manager.deactivate_power(1)
			if not power_manager.is_power_active(1):
				print("✓ Power deactivation successful")
			else:
				print("❌ Power should be deactivated")
		else:
			print("❌ Power activation failed")
	else:
		print("❌ PowerManager not found")
	
	print("Player Power Integration Test Complete!")
	get_tree().quit()