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
	broker.verbose = true
	root.add_child(broker)
	var listen_port := _start_available_port()
	if listen_port == 0:
		_fail("could not find a free loopback port")
		_finish()
		return
	var broker_url := "tcp://127.0.0.1:%d" % listen_port

	var observer := _new_client("observer")
	var publisher := _new_client("publisher")
	var observer_messages: Array[Array] = []
	var acknowledgements: Array[int] = []
	observer.received_message.connect(func(topic, message): observer_messages.append([topic, message]))
	publisher.publish_acknowledge.connect(func(packet_id): acknowledgements.append(packet_id))
	observer.connect_to_broker(broker_url)
	publisher.connect_to_broker(broker_url)
	await _wait_for(func(): return _is_connected(observer) and _is_connected(publisher), 2.0, "two clients connect")

	observer.subscribe("acceptance/+/message")
	await create_timer(0.05).timeout
	var publish_id: int = publisher.publish("acceptance/first/message", "hello", true, 1)
	await _wait_for(func(): return ["acceptance/first/message", "hello"] in observer_messages, 2.0, "wildcard message arrives")
	await _wait_for(func(): return publish_id in acknowledgements, 2.0, "QoS 1 PUBACK arrives")

	var ordered_observer := _new_client("ordered-observer")
	var second_ordered_observer := _new_client("second-ordered-observer")
	var ordered_messages: Array[String] = []
	var second_ordered_messages: Array[String] = []
	ordered_observer.received_message.connect(func(topic, message):
		if topic == "acceptance/ordered":
			ordered_messages.append(message)
	)
	second_ordered_observer.received_message.connect(func(topic, message):
		if topic == "acceptance/ordered":
			second_ordered_messages.append(message)
	)
	ordered_observer.connect_to_broker(broker_url)
	second_ordered_observer.connect_to_broker(broker_url)
	await _wait_for(func(): return _is_connected(ordered_observer) and _is_connected(second_ordered_observer), 2.0, "ordering observers connect")
	ordered_observer.subscribe("acceptance/ordered")
	second_ordered_observer.subscribe("acceptance/ordered")
	await create_timer(0.05).timeout
	var expected_order: Array[String] = []
	for index in range(20):
		var message := "packet-%02d" % index
		expected_order.append(message)
		publisher.publish("acceptance/ordered", message)
	await _wait_for(func(): return ordered_messages.size() == expected_order.size() and second_ordered_messages.size() == expected_order.size(), 2.0, "unfuzzed message stream reaches both observers")
	if ordered_messages != expected_order:
		_fail("first observer's unfuzzed ordering changed: %s" % [ordered_messages])
	if second_ordered_messages != expected_order:
		_fail("second observer's unfuzzed ordering changed: %s" % [second_ordered_messages])

	var late_client := _new_client("late-client")
	var late_messages: Array[Array] = []
	late_client.received_message.connect(func(topic, message): late_messages.append([topic, message]))
	late_client.connect_to_broker(broker_url)
	await _wait_for(func(): return _is_connected(late_client), 2.0, "late client connects")
	late_client.subscribe("acceptance/first/message")
	await _wait_for(func(): return ["acceptance/first/message", "hello"] in late_messages, 2.0, "retained message reaches late client")

	observer.subscribe("acceptance/status/+")
	await create_timer(0.05).timeout
	var will_client := _new_client("will-client")
	will_client.set_last_will("acceptance/status/will-client", "lost", true)
	will_client.connect_to_broker(broker_url)
	await _wait_for(func(): return _is_connected(will_client), 2.0, "will client connects")
	will_client.socket.disconnect_from_host()
	await _wait_for(func(): return ["acceptance/status/will-client", "lost"] in observer_messages, 2.0, "last will follows abrupt disconnect")

	_finish()


func _start_available_port() -> int:
	for candidate in range(18883, 18893):
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
		print("PASS simulated broker loopback acceptance")
	else:
		printerr("%d simulated broker acceptance failure(s)" % failures.size())
	quit(failures.size())
