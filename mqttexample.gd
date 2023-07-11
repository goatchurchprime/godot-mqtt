extends Control

func _ready():
	connectedactionsactive(false)

func _on_button_connect_toggled(button_pressed):
	if button_pressed:
		randomize()
		$MQTT.client_id = "s%d" % randi()

		if $VBox/HBoxLastwill/lastwilltopic.text:
			$MQTT.set_last_will($VBox/HBoxLastwill/lastwilltopic.text, 
								$VBox/HBoxLastwill/lastwillmessage.text, 
								$VBox/HBoxLastwill/lastwillretain.button_pressed)
		$VBox/HBoxBrokerControl/status.text = "connecting..."
		var brokerurl = $VBox/HBoxBroker/brokeraddress.text
		$MQTT.connect_to_broker(brokerurl)

	else:
		$MQTT.disconnect_from_server()
		$VBox/HBoxBrokerControl/status.text = "disconnecting..."

func brokersettingsactive(active):
	$VBox/HBoxBroker/brokeraddress.editable = active
	$VBox/HBoxBroker/brokerport.editable = active
	$VBox/HBoxBroker/brokerprotocol.disabled = not active
	$VBox/HBoxLastwill/lastwilltopic.editable = active
	$VBox/HBoxLastwill/lastwillmessage.editable = active
	$VBox/HBoxLastwill/lastwillretain.disabled = not active

func connectedactionsactive(active):
	$VBox/HBoxSubscriptions/subscribetopic.editable = active
	$VBox/HBoxSubscriptions/subscribe.disabled = not active
	$VBox/HBoxPublish/publishtopic.editable = active
	$VBox/HBoxPublish/publishmessage.editable = active
	$VBox/HBoxPublish/publishretain.disabled = not active
	$VBox/HBoxPublish/publish.disabled = not active
	if not active:
		$VBox/HBoxSubscriptions/subscriptions.clear()
	$VBox/HBoxSubscriptions/subscriptions.disabled = true
	$VBox/HBoxSubscriptions/unsubscribe.disabled = true

func _on_mqtt_broker_connected():
	$VBox/HBoxBrokerControl/status.text = "connected."
	brokersettingsactive(false)
	connectedactionsactive(true)
	
func _on_mqtt_broker_disconnected():
	$VBox/HBoxBrokerControl/status.text = "disconnected."
	brokersettingsactive(true)
	connectedactionsactive(false)

func _on_mqtt_received_message(topic, message):
	print("received topic %s message %s" % [topic, message])
	$VBox/subscribedmessages.append_text("[b]%s[/b] %s\n" % [topic, message])

func _on_publish_pressed():
	var qos = 0
	$MQTT.publish($VBox/HBoxPublish/publishtopic.text, 
				$VBox/HBoxPublish/publishmessage.text, 
				$VBox/HBoxPublish/publishretain.button_pressed, 
				qos)

func _on_subscribe_pressed():
	var qos = 0
	var topic = $VBox/HBoxSubscriptions/subscribetopic.text.strip_edges()
	$MQTT.subscribe(topic, qos)
	for i in range($VBox/HBoxSubscriptions/subscriptions.item_count):
		if topic == $VBox/HBoxSubscriptions/subscriptions.get_item_text(i):
			return
	$VBox/HBoxSubscriptions/subscriptions.add_item(topic)
	$VBox/HBoxSubscriptions/subscriptions.select($VBox/HBoxSubscriptions/subscriptions.item_count - 1)
	$VBox/HBoxSubscriptions/subscriptions.disabled = false
	$VBox/HBoxSubscriptions/unsubscribe.disabled = false

func _on_unsubscribe_pressed():
	var seloptbutt = $VBox/HBoxSubscriptions/subscriptions
	var sel = seloptbutt.selected
	var topic = seloptbutt.get_item_text(sel)
	$MQTT.unsubscribe(topic)
	seloptbutt.remove_item(seloptbutt.selected)
	$VBox/HBoxSubscriptions/subscriptions.disabled = (seloptbutt.item_count == 0)
	$VBox/HBoxSubscriptions/unsubscribe.disabled = (seloptbutt.item_count == 0)
	if seloptbutt.item_count != 0:
		seloptbutt.select(min(sel, seloptbutt.item_count - 1))
