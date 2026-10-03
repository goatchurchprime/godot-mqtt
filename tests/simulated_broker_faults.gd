extends SceneTree

const MQTT = preload("res://addons/mqtt/mqtt.gd")
const SimulatedBroker = preload("res://addons/mqtt/simulated_broker.gd")

var failures: Array[String] = []
var broker: Node
var clients: Array[Node] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	broker = SimulatedBroker.new()
	broker.verbose = false
	root.add_child(broker)
	var listen_port := _start_available_port()
	if listen_port == 0:
		_fail("could not find a free loopback port")
		_finish()
		return
	var broker_url := "tcp://127.0.0.1:%d" % listen_port

	var observer := _new_client("fault-observer")
	var publisher := _new_client("fault-publisher")
	var messages: Array[Array] = []
	observer.received_message.connect(func(topic, message): messages.append([topic, message]))
	observer.connect_to_broker(broker_url)
	publisher.connect_to_broker(broker_url)
	await _wait_for(func(): return _is_connected(observer) and _is_connected(publisher), 2.0, "clients connect")
	observer.subscribe("audio/#")
	observer.subscribe("status/#")
	await create_timer(0.05).timeout

	broker.configure_faults({
		"enabled": true,
		"seed": 101,
		"topic_filters": ["audio/#"],
	})
	broker.hold_deliveries(150)
	publisher.publish("audio/peer", "held-1")
	publisher.publish("audio/peer", "held-2")
	publisher.publish("status/peer", "ready")
	await _wait_for(func(): return ["status/peer", "ready"] in messages, 0.1, "unmatched status traffic bypasses hold")
	_check(not ["audio/peer", "held-1"] in messages, "matching audio traffic remains held")
	await _wait_for(func(): return ["audio/peer", "held-1"] in messages and ["audio/peer", "held-2"] in messages, 1.0, "held audio is released as a burst")

	messages.clear()
	broker.configure_faults({
		"enabled": true,
		"seed": 202,
		"topic_filters": ["audio/#"],
		"latency_ms": 20,
		"duplicate_rate": 1.0,
	})
	publisher.publish("audio/peer", "twice")
	await create_timer(0.01).timeout
	_check(messages.is_empty(), "fixed latency delays matching traffic")
	await _wait_for(func(): return messages.count(["audio/peer", "twice"]) == 2, 1.0, "duplication emits a second delivery")
	var duplicate_counters: Dictionary = broker.get_fault_counters()
	_check(duplicate_counters.duplicated == 1, "duplication counter records the injected copy")

	messages.clear()
	var replay_profile := {
		"enabled": true,
		"seed": 303,
		"topic_filters": ["audio/#"],
		"loss_rate": 0.4,
		"duplicate_rate": 0.35,
		"jitter_ms": 2,
		"reorder_ms": 8,
	}
	broker.configure_faults(replay_profile)
	for index in range(20):
		publisher.publish("audio/peer", "run-a-%02d" % index)
	await create_timer(0.2).timeout
	var first_run: Dictionary = broker.get_fault_counters()
	broker.configure_faults(replay_profile)
	for index in range(20):
		publisher.publish("audio/peer", "run-b-%02d" % index)
	await create_timer(0.2).timeout
	var second_run: Dictionary = broker.get_fault_counters()
	_check(first_run == second_run, "same seed and traffic reproduce fault counters")
	_check(first_run.dropped > 0 and first_run.delivered > 0, "replay sample includes both loss and delivery")
	_check(first_run.reordered > 0, "bounded reorder delay is injected")

	var disconnected: Array[String] = []
	broker.client_disconnected.connect(func(client_id, unexpected):
		if unexpected:
			disconnected.append(client_id)
	)
	broker.configure_faults({
		"enabled": true,
		"seed": 404,
		"topic_filters": ["audio/#"],
		"disconnect_after": 2,
	})
	publisher.publish("audio/peer", "before-interrupt")
	publisher.publish("audio/peer", "interrupt")
	await _wait_for(func(): return "fault-observer" in disconnected, 1.0, "configured delivery interrupts subscriber connection")
	_check(broker.get_fault_counters().interrupted == 1, "interruption counter records the disconnect")

	_finish()


func _start_available_port() -> int:
	for candidate in range(19903, 19913):
		if broker.start(candidate) == OK:
			return candidate
	return 0


func _new_client(client_id: String) -> Node:
	var client := MQTT.new()
	client.client_id = client_id
	client.verbose_level = 0
	root.add_child(client)
	clients.append(client)
	return client


func _is_connected(client: Node) -> bool:
	return client.brokerconnectmode == MQTT.BCM_CONNECTED


func _wait_for(predicate: Callable, timeout_seconds: float, description: String) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not predicate.call():
		_fail("timeout: " + description)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS ", description)
	else:
		_fail(description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL ", message)


func _finish() -> void:
	for client in clients:
		if is_instance_valid(client):
			client.disconnect_from_server()
			client.queue_free()
	if is_instance_valid(broker):
		broker.stop()
		broker.queue_free()
	if failures.is_empty():
		print("PASS simulated broker fault injection")
	else:
		printerr("%d simulated broker fault injection failure(s)" % failures.size())
	quit(failures.size())
