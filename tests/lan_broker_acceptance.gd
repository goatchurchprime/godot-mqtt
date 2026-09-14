extends SceneTree

const MQTT = preload("res://addons/mqtt/mqtt.gd")
const LANBroker = preload("res://addons/mqtt/lan_broker.gd")

var failures: Array[String] = []
var service: Node
var joining_service: Node
var client: Node
var race_services: Array[Node] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	service = LANBroker.new()
	service.verbose = false
	service.discovery_port = 19884
	service.broker_port = 19883
	service.discovery_seconds = 0.1
	service.election_seconds = 0.2
	service.announce_seconds = 0.05
	root.add_child(service)
	_check(service.start() == OK, "LAN broker search starts")
	await _wait_for(func(): return service.is_hosting(), 2.0, "no offer falls back to a simulated broker")
	_check(service.is_hosting(), "LAN service reports that it is hosting")

	var offer := await _request_offer()
	_check(offer.get("kind") == "offer", "UDP probe receives an offer")
	_check(offer.get("port") == 19883, "UDP offer contains the MQTT port")

	joining_service = LANBroker.new()
	joining_service.verbose = false
	joining_service.discovery_port = service.discovery_port
	joining_service.broker_port = service.broker_port
	joining_service.discovery_seconds = 0.1
	root.add_child(joining_service)
	_check(joining_service.start() == OK, "second same-machine service starts")
	await _wait_for(func(): return joining_service.state == LANBroker.State.USING_REMOTE, 2.0, "same-machine service discovers the first broker")
	_check(not joining_service.is_hosting(), "second same-machine service does not start another broker")

	client = MQTT.new()
	client.client_id = "lan-acceptance"
	client.verbose_level = 0
	root.add_child(client)
	var messages: Array[Array] = []
	client.received_message.connect(func(topic, message): messages.append([topic, message]))
	client.connect_to_broker(joining_service.broker_url)
	await _wait_for(func(): return client.brokerconnectmode == MQTT.BCM_CONNECTED, 2.0, "client connects to offered broker")
	client.subscribe("lan/acceptance")
	await create_timer(0.05).timeout
	client.publish("lan/acceptance", "hello")
	await _wait_for(func(): return ["lan/acceptance", "hello"] in messages, 2.0, "offered broker carries MQTT traffic")

	for index in range(2):
		var contender := LANBroker.new()
		contender.verbose = false
		contender.discovery_port = 19885
		contender.broker_port = 19886
		contender.discovery_seconds = 0.1
		contender.election_seconds = 0.2
		contender.announce_seconds = 0.05
		root.add_child(contender)
		race_services.append(contender)
		_check(contender.start() == OK, "simultaneous contender %d starts" % (index + 1))
	await _wait_for(
		func(): return _count_state(race_services, LANBroker.State.HOSTING) == 1 and _count_state(race_services, LANBroker.State.USING_REMOTE) == 1,
		3.0,
		"simultaneous same-machine instances converge on one broker"
	)
	_finish()


func _request_offer() -> Dictionary:
	var probe := PacketPeerUDP.new()
	var error := probe.bind(0, "127.0.0.1")
	if error != OK:
		_fail("could not bind probe socket (error %d)" % error)
		return {}
	probe.set_dest_address("127.0.0.1", service.discovery_port)
	var packet := {
		"protocol": service.PROTOCOL_NAME,
		"version": service.PROTOCOL_VERSION,
		"kind": "probe",
		"node_id": "acceptance-probe",
	}
	probe.put_packet(JSON.stringify(packet).to_utf8_buffer())
	var deadline := Time.get_ticks_msec() + 2000
	while probe.get_available_packet_count() == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if probe.get_available_packet_count() == 0:
		_fail("timeout: UDP broker offer")
		return {}
	var value = JSON.parse_string(probe.get_packet().get_string_from_utf8())
	return value if value is Dictionary else {}


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


func _count_state(services: Array[Node], wanted_state: int) -> int:
	var count := 0
	for item in services:
		if item.state == wanted_state:
			count += 1
	return count


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL ", message)


func _finish() -> void:
	if is_instance_valid(client):
		client.disconnect_from_server()
		client.queue_free()
	if is_instance_valid(service):
		service.stop()
		service.queue_free()
	if is_instance_valid(joining_service):
		joining_service.stop()
		joining_service.queue_free()
	for contender in race_services:
		if is_instance_valid(contender):
			contender.stop()
			contender.queue_free()
	if failures.is_empty():
		print("PASS LAN broker acceptance")
	else:
		printerr("%d LAN broker acceptance failure(s)" % failures.size())
	quit(failures.size())
