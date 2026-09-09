extends Control

@onready var lan_broker = $LANBroker
@onready var mqtt = $MQTT
@onready var status = $Margin/VBox/Status
@onready var log_output = $Margin/VBox/Log
@onready var message = $Margin/VBox/SendRow/Message
@onready var send_button = $Margin/VBox/SendRow/Send


func _ready() -> void:
	lan_broker.broker_available.connect(_on_broker_available)
	lan_broker.failed.connect(_on_lan_failed)
	mqtt.broker_connected.connect(_on_mqtt_connected)
	mqtt.broker_connection_failed.connect(_on_mqtt_failed)
	mqtt.received_message.connect(_on_message)
	mqtt.client_id = "lan-demo-%08x" % randi()
	send_button.disabled = true
	var error: int = lan_broker.start()
	if error != OK:
		status.text = "LAN setup failed (error %d)" % error


func _on_broker_available(url: String, hosted_here: bool) -> void:
	status.text = ("Hosting " if hosted_here else "Discovered ") + url
	_append("Connecting MQTT client...")
	mqtt.connect_to_broker(url)


func _on_mqtt_connected() -> void:
	mqtt.subscribe("godot-mqtt/lan-demo/chat")
	status.text += " — connected"
	send_button.disabled = false
	_append("Ready. Start this scene on another LAN computer to join the same broker.")


func _on_mqtt_failed() -> void:
	status.text += " — MQTT connection failed"
	send_button.disabled = true


func _on_lan_failed(reason: String) -> void:
	status.text = reason
	_append("LAN mode requires a native build with TCP and UDP support.")


func _on_message(topic: String, payload) -> void:
	_append("%s: %s" % [topic, payload])


func _on_send_pressed() -> void:
	var text: String = message.text.strip_edges()
	if text.is_empty():
		return
	mqtt.publish("godot-mqtt/lan-demo/chat", "%s: %s" % [mqtt.client_id, text])
	message.clear()


func _on_message_submitted(_text: String) -> void:
	_on_send_pressed()


func _append(text: String) -> void:
	log_output.append_text(text + "\n")
