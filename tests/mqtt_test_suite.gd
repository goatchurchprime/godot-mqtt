class_name MQTTTestSuite
extends RefCounted

const MQTT = preload("res://addons/mqtt/mqtt.gd")

signal test_started(test_name: String)
signal test_finished(result: Dictionary)

var break_on_failure := false
var _current_failures: Array[String] = []


func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var tests := [
		["remaining length encoding", _test_remaining_length_encoding],
		["short integer encoding", _test_short_integer_encoding],
		["variable string encoding", _test_variable_string_encoding],
		["CONNECT packet structure", _test_connect_packet_structure],
		["fragmented packet waits", _test_fragmented_packet_waits],
		["coalesced packets are separated", _test_coalesced_packets],
		["CONNACK changes connection state", _test_connack],
		["incoming PUBLISH emits message", _test_incoming_publish],
		["PUBACK emits its declared signal", _test_puback_signal],
		["PUBACK and PUBREC opcodes", _test_puback_opcodes],
		["packet identifiers wrap", _test_packet_identifier_wrap],
	]

	for test_case in tests:
		results.append(_run_test(test_case[0], test_case[1]))
	return results


func _run_test(test_name: String, test_callable: Callable) -> Dictionary:
	_current_failures.clear()
	test_started.emit(test_name)
	var started_usec := Time.get_ticks_usec()
	test_callable.call()
	var result := {
		"name": test_name,
		"passed": _current_failures.is_empty(),
		"failures": _current_failures.duplicate(),
		"elapsed_usec": Time.get_ticks_usec() - started_usec,
	}
	test_finished.emit(result)
	return result


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_current_failures.append(message)
	if break_on_failure:
		assert(false, message)


func _check_equal(actual: Variant, expected: Variant, context: String) -> void:
	_check(actual == expected, "%s\n  expected: %s\n  actual:   %s" % [context, expected, actual])


func _encoded_remaining_length(size: int) -> PackedByteArray:
	var packet := PackedByteArray([0x00, 0x00])
	MQTT.encoderemaininglength(packet, size)
	return packet.slice(1)


func _test_remaining_length_encoding() -> void:
	_check_equal(_encoded_remaining_length(0), PackedByteArray([0x00]), "zero")
	_check_equal(_encoded_remaining_length(127), PackedByteArray([0x7f]), "one-byte maximum")
	_check_equal(_encoded_remaining_length(128), PackedByteArray([0x80, 0x01]), "two-byte minimum")
	_check_equal(_encoded_remaining_length(16383), PackedByteArray([0xff, 0x7f]), "two-byte maximum")
	_check_equal(_encoded_remaining_length(16384), PackedByteArray([0x80, 0x80, 0x01]), "three-byte minimum")


func _test_short_integer_encoding() -> void:
	var packet := PackedByteArray()
	MQTT.encodeshortint(packet, 0x1234)
	_check_equal(packet, PackedByteArray([0x12, 0x34]), "short integers use network byte order")


func _test_variable_string_encoding() -> void:
	var packet := PackedByteArray()
	MQTT.encodevarstr(packet, "MQTT".to_ascii_buffer())
	_check_equal(packet, PackedByteArray([0x00, 0x04, 0x4d, 0x51, 0x54, 0x54]), "variable string has a two-byte length")


func _new_client() -> Node:
	var client := MQTT.new()
	client.verbose_level = 0
	client.client_id = "test-client"
	return client


func _test_connect_packet_structure() -> void:
	var client := _new_client()
	var packet: PackedByteArray = client.firstmessagetoserver()
	_check_equal(packet[0], MQTT.CP_CONNECT, "CONNECT control byte")
	_check_equal(packet.slice(2, 8), PackedByteArray([0x00, 0x04, 0x4d, 0x51, 0x54, 0x54]), "CONNECT protocol name")
	_check_equal(packet[8], 0x04, "MQTT protocol level is 3.1.1")
	_check((packet[9] & 0x02) != 0, "CONNECT requests a clean session")
	client.free()


func _test_fragmented_packet_waits() -> void:
	var client := _new_client()
	client.receivedbuffer = PackedByteArray([MQTT.CP_PINGRESP])
	_check_equal(client.wait_msg(), false, "an incomplete fixed header must wait")
	_check_equal(client.receivedbuffer.size(), 1, "waiting must retain partial bytes")
	client.receivedbuffer.append(0x00)
	_check_equal(client.wait_msg(), true, "the completed packet is consumed")
	_check_equal(client.receivedbuffer.size(), 0, "the completed packet leaves no bytes")
	client.free()


func _test_coalesced_packets() -> void:
	var client := _new_client()
	client.receivedbuffer = PackedByteArray([MQTT.CP_PINGRESP, 0x00, MQTT.CP_PINGRESP, 0x00])
	_check_equal(client.wait_msg(), true, "first packet is available")
	_check_equal(client.receivedbuffer, PackedByteArray([MQTT.CP_PINGRESP, 0x00]), "second packet remains buffered")
	_check_equal(client.wait_msg(), true, "second packet is available")
	_check_equal(client.receivedbuffer.size(), 0, "both packets are consumed independently")
	client.free()


func _test_connack() -> void:
	var client := _new_client()
	var connected_count := [0]
	client.broker_connected.connect(func(): connected_count[0] += 1)
	client.brokerconnectmode = MQTT.BCM_WAITING_CONNACK
	client.receivedbuffer = PackedByteArray([MQTT.CP_CONNACK, 0x02, 0x00, 0x00])
	_check_equal(client.wait_msg(), true, "CONNACK is consumed")
	_check_equal(client.brokerconnectmode, MQTT.BCM_CONNECTED, "successful CONNACK marks the client connected")
	_check_equal(connected_count[0], 1, "successful CONNACK emits broker_connected once")
	client.free()


func _test_incoming_publish() -> void:
	var client := _new_client()
	var messages: Array[Array] = []
	client.received_message.connect(func(topic, message): messages.append([topic, message]))
	var topic := "test/topic".to_ascii_buffer()
	var payload := "hello".to_ascii_buffer()
	var remaining := 2 + topic.size() + payload.size()
	client.receivedbuffer = PackedByteArray([MQTT.CP_PUBLISH, remaining])
	MQTT.encodevarstr(client.receivedbuffer, topic)
	client.receivedbuffer.append_array(payload)
	_check_equal(client.wait_msg(), true, "PUBLISH is consumed")
	_check_equal(messages, [["test/topic", "hello"]], "PUBLISH emits its topic and payload")
	client.free()


func _test_puback_signal() -> void:
	var client := _new_client()
	var acknowledgements: Array[int] = []
	client.publish_acknowledge.connect(func(packet_id): acknowledgements.append(packet_id))
	client.receivedbuffer = PackedByteArray([MQTT.CP_PUBACK, 0x02, 0x12, 0x34])
	_check_equal(client.wait_msg(), true, "PUBACK is consumed")
	_check_equal(acknowledgements, [0x1234], "PUBACK emits publish_acknowledge")
	client.free()


func _test_puback_opcodes() -> void:
	_check_equal(MQTT.CP_PUBACK, 0x40, "PUBACK opcode")
	_check_equal(MQTT.CP_PUBREC, 0x50, "PUBREC opcode")


func _test_packet_identifier_wrap() -> void:
	var client := _new_client()
	client.pid = 65534
	_check_equal(client.subscribe("test/one"), 65535, "last packet identifier")
	_check_equal(client.unsubscribe("test/one"), 1, "packet identifier wraps to one")
	client.free()
