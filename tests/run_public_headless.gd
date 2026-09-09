extends SceneTree

const PublicBrokerCheck = preload("res://tests/public_broker_check.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for broker_url in ["tcp://broker.hivemq.com:1883", "tcp://test.mosquitto.org:1883"]:
		var check := PublicBrokerCheck.new()
		root.add_child(check)
		check.log_line.connect(func(line): print("  %s" % line))
		var result: Dictionary = await check.check(broker_url)
		print("%s %s — %s" % ["PASS" if result.passed else "UNAVAILABLE", result.broker_url, result.detail])
		check.queue_free()
	quit()
