# Simulated broker scope

The simulated broker removes the need to install a broker for private LAN
development. It is not intended to replace Mosquitto or another managed broker.

The first version implements the MQTT 3.1.1 behaviour used by this repository:

- TCP clients and clean sessions;
- CONNECT, SUBSCRIBE, UNSUBSCRIBE, PUBLISH, PING and DISCONNECT;
- QoS 0 messages and acknowledgement of incoming QoS 1 messages;
- `+` and `#` subscription wildcards;
- retained messages;
- last-will messages, including on keepalive timeout; and
- duplicate client-ID replacement.

It deliberately omits TLS, WebSockets, authentication, access control,
persistent sessions, disk persistence, QoS 2, bridging and public deployment.
Applications needing those features should supply a conventional MQTT broker.

UDP discovery is a separate convenience layered around this broker. It only
advertises and discovers an MQTT TCP endpoint; it does not define a second
lobby or game-signalling protocol.
