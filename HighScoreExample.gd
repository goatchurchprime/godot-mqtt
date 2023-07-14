extends Control

var brokerurl = "wss://test.mosquitto.org:8081"
var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", 
						"John", "Kevin", "Larry", "Martin", "Oliver", "Peter", "Quentin", "Robert", 
						"Samuel", "Thomas", "Ulrik", "Victor", "Wayne", "Xavier", "Youngs", "Zephir"]

var fetchingscores = true
var highscores = [ ]
var regexscores = RegEx.new()

func _ready():
	randomize()
	$VBox/HBoxPlayername/LineEdit.text = possibleusernames[randi()%len(possibleusernames)]
	$VBox/HBoxHighScore/LineEdit.text = "%d" % (randi()%1000)
	regexscores.compile("^\\w+/(\\w+)/score")
	#$MQTT.verbose_level = 0
	_on_fetch_scores_pressed()

func _on_mqtt_broker_connected():
	# this quality of service means we get an acknowledgement message back from the broker
	# which we can use to disconnect from the broker when the work is done
	var qos = 1   

	if fetchingscores:
		$MQTT.subscribe("%s/+/score" % $VBox/HBoxGamename/LineEdit.text)

		# this follow-on message is acknowledged after all subscribed retained messages have arrived
		$MQTT.publish("%s" % $VBox/HBoxGamename/LineEdit.text, "acknowledgemessage", false, qos)

	else:
		var topic = "%s/%s/score" % [$VBox/HBoxGamename/LineEdit.text, $VBox/HBoxPlayername/LineEdit.text]
		$MQTT.publish(topic, $VBox/HBoxHighScore/LineEdit.text, true, qos)

func _on_mqtt_broker_connection_failed():
	print("Connection failed")

func _on_send_score_pressed():
	fetchingscores = false
	$MQTT.connect_to_broker(brokerurl)

func _on_fetch_scores_pressed():
	fetchingscores = true
	highscores = [ ]
	$MQTT.connect_to_broker(brokerurl)

func _on_mqtt_broker_disconnected():
	print("disconnected")

func _on_mqtt_publish_acknowledge(pid):
	print("Publish message acknowledged ", pid)
	$MQTT.disconnect_from_server()
	if fetchingscores:
		highscores.sort()
		highscores.reverse()
		$VBox/HBoxTopscores/RichTextLabel.clear()
		$VBox/HBoxTopscores/RichTextLabel.append_text("[u]Top ten scores[/u]\n")
		while len(highscores) < 10:
			highscores.append([0, " --- "])
		for i in range(10):
			$VBox/HBoxTopscores/RichTextLabel.append_text("%d. [b]%s:[/b] %d\n" % [i+1, highscores[i][1], highscores[i][0]])
		print(highscores)
	
func _on_mqtt_received_message(topic, message):
	var rem = regexscores.search(topic)
	if rem:
		var playername = rem.get_string(1)
		highscores.append([int(message), playername])
