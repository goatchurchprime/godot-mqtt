# MQTT

Godot 4 addon - to implement MQTT

## Installation

Clone the repo and copy the `addons/mqtt` folder into your project's `addons` folder 
(or use the AssetLib to install when 

## Applications

**MQTT** is probably the simplest networking protocol you can use 
to communicate between systems, which is why it is often used by 
IoT devices.

In spite of its simplicity, it is extremely flexible and has the 
advantage of being standardized enough that you don't need to write 
any server-side software.  For quick experimental applications you 
can "borrow" the use of a server that is already on the public internet, 
such as [test.mosquitto.org](https://test.mosquitto.org/).

See [this talk](https://www.youtube.com/watch?v=en9fMP4g9y8) from 
GodotCon 2021 for a demo of controlling a wheeled robot from 
the Dodge the Creeps game.  You can also use it to listen to 
realtime sensor data and build up a virtual dashboard.

Other uses are for public room chats, running a simple implementation of 
a daily high score, providing runtime remote monitoring of your game when 
it is alpha release, and acting as a 
[signalling server](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html#id1)
for the powerful WebRTC peer-to-peer networking protocol that is 
built into Godot.  

Try the *mqttexample* project that comes in this repo is a good place 
to experiment and explore the features, as well as testing out if the connections
are working. 

## The protocol

The easiest way to understand this protocol is [install mosquitto](https://mosquitto.org/download/), 
open two console on your machine, and run the following command in the first console:

> mosquitto_sub -v -h test.mosquitto.org -t "godot/#"

and then type this command in the second console:

> mosquitto_pub -h test.mosquitto.org -t "godot/abcd" -m "Bingo!"

The first console should now print:
   
> godot/abcd Bingo!

What's happening?  The first command has connected to the broker "test.mosquitto.org" 
and subscribed to the topic "godot/#".  The '#' is a wild-card that means any topic that 
starts with "godot/' will be received.

The second command publishes the message "Bingo!" to the topic "godot/abcd" 
on the broker at the address "test.mosquitto.org", which is picked up by the first 
command as it matches the pattern.  Since the broker is out on the internet you could run 
these commands on different machines.  

Now that you understand the basics, you can do the same thing through an online 
version of mosquitto at [https://www.hivemq.com/demos/websocket-client/](https://www.hivemq.com/demos/websocket-client/). 
by filling in the boxes.

To make this protocol insanely useful, there are two further features:

When the **retain** flag is set to true on any message, the broker doesn't only send the message to 
all the subscribers, it also keeps a copy which will be sent to any new subscriber which matches the topic
message.  This allows for persistent data (eg high scores) to be recorded and updated on the 
broker.  To delete a retained message, publish an empty message to its topic.  

When a new connection is made to the broker, a **lastwill** topic and message can optionally be included.
This message will be published automatically when the connection is broken.  The lastwill message 
can also have 

These two features can be combined to provide a connection status feature for a player instance 
by first executing: 
* set_last_will( topic="playerstates/myplayerid", msg="disconnected", retain=true )
before connecting to the broker.  

Then the first message you send after connection is:
* publish( topic="playerstates/myplayerid", msg="readytoplay", retain=true )
This message is automatically over-written on disconnect.

At any time when a player elsewhere connects to this broker and subscribes 
to the topic "playerstates/+" the the messages returned for their ids will 
correctly give their online statuses.

A final setting with any message is **qos** for "Quality of Service".  
This tells the broker whether you want an acknowledgement that the message 
has gotten through to it (qos=1) as well as build in confirmation 
and de-dplication features (qos=2).  It's not been fully implemented in this 
library.  
  

## Usage

* $MQTT.set_last_will(topic, msg, retain=false, qos=0)
(Must be set before connection is made.)

* $MQTT.connect_to_broker(brokerurl)
This URL should contain protocol and port, eg 
"tcp://test.mosquitto.org:1883/" for the basic default setting
or for secure websocket "wss://test.mosquitto.org:8081/".

Note that MQTT brokers don't always have the websocket interface enabled
since the primary interface was tcp sockets.  Websockets needed to be 
added later due to the restrictions in HTML5 not having direct access 
to tcp sockets.

* $MQTT.subscribe(topic, qos=0)
This subscribes to a topic.  All subscribed messages go to the 
same `received_message`.  

* $MQTT.unsubscribe(topic)
Little used since all topics are unsubscribed on disconnect.
The topic has to match exactly to one that was subscribed.  
(You can't use this for include/exclude rules.)

* $MQTT.publish(topic, msg, retain=false, qos=0)
Publish a message to the broker.


### @export parameters

@export var client_id = ""
@export var verbose_level = 2  # 0 quiet, 1 connections and subscriptions, 2 all messages
@export var binarymessages = false
@export var pinginterval = 30

                                
### Signals

* received_message(topic, message)
* signal broker_connected()
* signal broker_disconnected()
* signal broker_connection_failed()



