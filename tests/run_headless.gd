extends SceneTree

const MQTTTestSuite = preload("res://tests/mqtt_test_suite.gd")


func _init() -> void:
	var suite := MQTTTestSuite.new()
	var results := suite.run_all()
	var failure_count := 0
	for result in results:
		if result.passed:
			print("PASS %s" % result.name)
		else:
			failure_count += 1
			printerr("FAIL %s" % result.name)
			for failure in result.failures:
				printerr("  %s" % failure)
	print("%d passed, %d failed" % [results.size() - failure_count, failure_count])
	quit(failure_count)
