class_name PublicBrokerCheck
extends Node

const MQTT = preload("res://addons/mqtt/mqtt.gd")

signal log_line(text: String)

var timeout_seconds := 10.0
var _client: Node
var _topic := ""
var _message := ""
var _outcome := ""


func check(broker_url: String) -> Dictionary:
	_outcome = ""
	var host := _host_from_url(broker_url)
	var addresses := IP.resolve_hostname_addresses(host, IP.TYPE_ANY)
	log_line.emit("DNS  %s -> %s" % [host, ", ".join(addresses)])
	if addresses.is_empty():
		return _result(broker_url, false, "DNS returned no addresses")

	_client = MQTT.new()
	_client.verbose_level = 0
	_client.client_id = "godot-mqtt-test-%d" % Time.get_ticks_usec()
	_topic = "godot-mqtt/test/%s/roundtrip" % _client.client_id
	_message = "hello-%d" % Time.get_ticks_usec()
	add_child(_client)
	_client.broker_connected.connect(_on_connected)
	_client.broker_connection_failed.connect(_finish.bind("MQTT connection failed"))
	_client.broker_disconnected.connect(_finish.bind("broker disconnected before round trip"))
	_client.received_message.connect(_on_message)

	log_line.emit("OPEN %s" % broker_url)
	if not _client.connect_to_broker(broker_url):
		_finish("client rejected the broker URL")

	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while _outcome.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if _outcome.is_empty():
		_finish("timeout while in client state %d" % _client.brokerconnectmode)

	var passed := _outcome == "round trip received"
	var result := _result(broker_url, passed, _outcome)
	if is_instance_valid(_client):
		_client.disconnect_from_server()
		_client.queue_free()
		await get_tree().process_frame
	return result


func _on_connected() -> void:
	log_line.emit("MQTT connected; subscribing to %s" % _topic)
	_client.subscribe(_topic)
	# The current client has no SUBACK signal, so allow the subscription to settle.
	await get_tree().create_timer(0.25).timeout
	if not _outcome.is_empty() or not is_instance_valid(_client):
		return
	log_line.emit("SEND %s" % _message)
	_client.publish(_topic, _message)


func _on_message(topic: String, message: Variant) -> void:
	if topic == _topic and message == _message:
		_finish("round trip received")


func _finish(outcome: String) -> void:
	if _outcome.is_empty():
		_outcome = outcome


func _result(broker_url: String, passed: bool, detail: String) -> Dictionary:
	return {"broker_url": broker_url, "passed": passed, "detail": detail}


func _host_from_url(broker_url: String) -> String:
	var without_scheme := broker_url.split("://")[-1]
	return without_scheme.split(":")[0].split("/")[0]
