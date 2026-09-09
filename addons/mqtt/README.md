# Godot MQTT client

This folder is the installable addon. Copy `addons/mqtt` into a Godot 4
project, then instantiate `mqtt.tscn` or preload `mqtt.gd`.

The client implements the small MQTT 3.1.1 subset used by the included demos:

- TCP, TLS, WebSocket and secure WebSocket connections;
- publish and subscribe with QoS 0 or QoS 1;
- retained messages;
- last-will messages; and
- binary or text payloads.

QoS 2 is not implemented. Web exports must use `ws://` or `wss://`, because
browsers do not provide applications with raw TCP sockets.

The full source repository contains demonstrations, editor-friendly tests and
public-broker diagnostics:

https://github.com/goatchurchprime/godot-mqtt

This addon is distributed under the MIT license in `LICENSE.md`.
