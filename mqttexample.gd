extends Control



func _on_button_connect_toggled(button_pressed):
	if button_pressed:
#		StartMQTTstatuslabel.text = "on"
		randomize()
		$MQTT.client_id = "s%d" % randi()
		$MQTT.set_last_will("godot/myname", "Connection is dead", true)
		#StartMQTTstatuslabel.text = "connecting"
		var brokerurl = $brokeraddress.text
		$MQTT.connect_to_broker(brokerurl)
	else:
		$MQTT.disconnect_from_server()
		#StartMQTTstatuslabel.text = "off"


func _on_mqtt_broker_connected():
	print("broker connected")


func _on_mqtt_broker_disconnected():
	print("broker disconnected")


func _on_mqtt_received_message(topic, message):
	print("received topic %s message %s" % [topic, message])


func _on_publish_pressed():
	var retain = false
	var qos = 0
	$MQTT.publish($publishtopic.text, $publishmessage.text, retain, qos)
