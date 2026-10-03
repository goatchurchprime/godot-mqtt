# MQTT

Godot 4 addon - to implement MQTT

## Installation

Clone the repo and copy the `addons/mqtt` folder into your project's `addons` folder 
(or install it from the Godot Asset Library).

## Applications

**MQTT** is probably the simplest known networking protocol you can use 
to communicate between systems, which is why it is often used by 
low power IoT (Internet of Things) devices.

In spite of its simplicity, MQTT is extremely flexible and has the 
advantage of being standardized enough that you don't need to write 
your own server-side software.  You can often get by with "borrowing " the use of a public server on the internet (see [test.mosquitto.org](https://test.mosquitto.org/)).

Uses for MQTT in Godot are chat rooms, receiving and sending messages to physical devices, high score tables, remote monitoring of runtime metrics (eg framerate) of an alpha release for quality control, and as a 
[signalling server](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html#id1)
for the powerful WebRTC peer-to-peer networking protocol.  

Here is a [talk](https://www.youtube.com/watch?v=en9fMP4g9y8) from 
GodotCon 2021 that included demo of controlling a wheeled robot from 
the Dodge the Creeps game.

[![image](https://github.com/goatchurchprime/godot-mqtt/assets/677254/593b8a53-801e-480f-9812-cfc4e9ae360b)](https://www.youtube.com/watch?v=en9fMP4g9y8)



The **mqttexample** project in this repo is good for 
experimenting and exploring the features. 

![image](https://github.com/goatchurchprime/godot-mqtt/assets/677254/264473c6-6ad1-4a87-8bb5-49fd28789bed)

There's also an even simpler **HighScoreExample** scene that demonstrates how to implement a list of 
global high scores in a game.

The **lan_broker_example** scene needs no internet connection and no separately
installed broker. Each native instance looks for a broker advertised on the LAN.
If it finds none, the instances elect one of themselves to run the deliberately
limited GDScript broker. Open the scene on two computers and publish a message to
see both clients using the same broker.

## The protocol

The easiest way to understand this protocol (without using Godot or this plugin) is to [install mosquitto](https://mosquitto.org/download/), 
and open two command line consoles on your computer.

Run the following command in the first console:

* `mosquitto_sub -v -h test.mosquitto.org -t "godot/#"`

and then run this other command in the second console:

* `mosquitto_pub -h test.mosquitto.org -t "godot/abcd" -m "Bingo!"`

The first console should have now printed:
   
* `godot/abcd Bingo!`

*What's going on here?*  

The first command connected to the broker `test.mosquitto.org` 
and subscribed to the topic `"godot/#"` where the `'#'` is a wild-card 
that matches the remained of the topic string.

The second command publishes the message `"Bingo!"` to the topic `"godot/abcd"` 
on the broker at the address `test.mosquitto.org`, which is picked up by the first 
command since it matches the pattern.  

Now you understand the basics, you can do the same thing on a webpage 
version of the mqtt client at [hivemq.com](https://www.hivemq.com/demos/websocket-client/).
(The ClientID is a unique identifier for the client, often randomly generated.)

### Advanced features

To make this protocol insanely useful, there are two further features:

When the **`retain`** flag is set to true, the broker not only sends the message to 
all the subscribers, it also keeps a copy and sends it to any new subscriber that matches the topic.
This allows for persistent data (eg high scores) to be recorded and updated on the 
broker.  To delete a retained message, publish an empty message to its topic.  

When a new connection is made to the broker, a **`lastwill`** topic and message can optionally be included.
This message will be published automatically on disconnect.  The lastwill message 
can also have its `retain` flag set.

These two features can be combined to provide a connection status feature for a player instance 
by first executing: 
* `set_last_will( topic="playerstates/myplayerid", msg="disconnected", retain=true )`

before connecting to the broker.  

Then the first message you send after successfully connecting to the broker is:
* `publish( topic="playerstates/myplayerid", msg="readytoplay", retain=true )`

This persistent message will be automatically over-written at disconnect.

At any time when a player elsewhere connects to this broker and subscribes 
to the topic `"playerstates/+"` the the messages returned will 
correctly give their online statuses.

There is final setting in the publish fuction, **`qos`** for "Quality of Service".  
This tells the broker whether you want an acknowledgement that the message 
has gotten through to it (`qos=1`). QoS 2 is not implemented and is rejected
explicitly rather than being encoded incorrectly.
  

## Usage

* `$MQTT.set_last_will(topic, msg, retain=false, qos=0)`

Must be set before connection is made.

* `$MQTT.connect_to_broker(brokerurl)`   

This URL should contain protocol and port, eg 
`"tcp://test.mosquitto.org:1883/"` for the basic default setting
or for secure websocket `"wss://test.mosquitto.org:8081/"`.

Some MQTT brokers do not have the WebSocket interface enabled
since the primary interface is TCP.  WebSockets are, however,  
necessary to get round restrictions in HTML5 not having direct access 
to TCP sockets.

* `$MQTT.subscribe(topic, qos=0)`

This subscribes to a topic.  All subscribed messages go to the 
same `received_message`.  

* `$MQTT.unsubscribe(topic)`
 
Little used since all topics are unsubscribed on disconnect.
The topic has to match exactly to one that was subscribed.  
(You cannot use this for include/exclude rules.)

* `$MQTT.publish(topic, msg, retain=false, qos=0)`

Publish a message to the broker.

### @export parameters

* @export var client_id = ""
* @export var verbose_level = 2  # 0 quiet, 1 connections and subscriptions, 2 all messages
* @export var binarymessages = false
* @export var pinginterval = 30
                                
### Signals

* received_message(topic, message)
* signal broker_connected()
* signal broker_disconnected()
* signal broker_connection_failed()
* signal publish_acknowledge(id)

## Tests

Open `tests/mqtt_test_runner.tscn` in Godot to run the deterministic tests and
inspect failures in the editor. The public-broker checks are opt-in because
they require internet access and public brokers can be unavailable.

The same deterministic suite can be run headlessly with:

* `godot --headless --path . --script res://tests/run_headless.gd`

The simulated broker and LAN discovery have real-socket acceptance tests:

* `godot --headless --path . --script res://tests/simulated_broker_acceptance.gd`
* `godot --headless --path . --script res://tests/simulated_broker_faults.gd`
* `godot --headless --path . --script res://tests/lan_broker_acceptance.gd`

## LAN broker convenience

Add `addons/mqtt/lan_broker.tscn` beside your MQTT client and call `start()`.
Its `broker_available(url, hosted_here)` signal supplies the TCP URL to pass to
`connect_to_broker()`. UDP carries only small, versioned discovery and election
messages; all application signalling still uses MQTT.

LAN discovery and the simulated broker are for trusted native LAN development.
They have no authentication, TLS, persistence or WebSocket listener. Web exports
cannot host or discover them and should use an explicitly configured `ws://` or
`wss://` broker. See `docs/SIMULATED_BROKER_SCOPE.md` for the supported subset.

The simulated broker can also inject deterministic faults into selected
broker-to-subscriber `PUBLISH` traffic. This is intended for local real-time
network tests; MQTT connection, subscription, ping and acknowledgement control
packets bypass the fault queue. For example:

```gdscript
$MQTTLANBroker.configure_faults({
	"enabled": true,
	"seed": 1234,
	"topic_filters": ["voip/audio/#"],
	"latency_ms": 40,
	"jitter_ms": 15,
	"loss_rate": 0.02,
	"duplicate_rate": 0.01,
	"reorder_ms": 20,
})
```

Call `hold_deliveries(milliseconds)` on a hosting LAN broker to queue matching
traffic and release it as a burst, and `get_fault_counters()` to record the
run. See `docs/SIMULATED_BROKER_SCOPE.md` for the complete profile.

For downstream vendoring and the symmetric TwoVoIP smoke-test startup pattern,
see `docs/TWOVOIP_VENDORING.md`. These broker additions are the V1.5 feature
set; the existing MQTT client API remains V1.4-compatible.

## Development disclosure

The V1.4 test suite and client-hardening changes were prepared with OpenAI
Codex under the maintainer's direction. They are kept as one reviewable commit,
and `docs/V1.4_MQTT_GDSCRIPT.diff` contains only the change to the addon
GDScript. Release decisions and human review remain with the maintainer.

The subsequent simulated-broker and LAN-discovery implementation was also
prepared with Codex under the maintainer's direction. It is split into small
local commits and accompanied by `docs/LAN_DEMO_REVIEW.md` so its interface and
limitations can be exercised and revised before release.
