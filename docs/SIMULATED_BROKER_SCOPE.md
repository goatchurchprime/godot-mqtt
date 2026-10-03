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

Discovery packets are UTF-8 JSON with four intentionally visible fields:
`protocol`, `version`, `kind` and `node_id`; broker offers also contain `port`.
The packet kinds are `probe`, `candidate` and `offer`. When no offer appears,
nodes exchange candidates for a short interval and the lowest node identifier
starts the broker. Its periodic offers cause later instances to join it.

The default UDP discovery port is 1884 and the broker's TCP port is 1883. Both
are exported settings. Discovery accepts the packet source address rather than
an address claimed inside the payload.

## Deterministic network faults

`configure_faults(profile)` installs one deliberately small fault profile at
the broker-to-subscriber boundary. It affects only outbound `PUBLISH` packets
whose topics match `topic_filters`; an empty list matches every topic. MQTT
connection, subscription, ping and acknowledgement packets remain reliable, as
do the broker's retained-state updates. This lets tests fuzz audio topics while
leaving status and control topics untouched.

The accepted profile fields are:

- `enabled`: opt in to fault injection;
- `seed`: deterministic random seed;
- `topic_filters`: MQTT `+`/`#` filters selecting application traffic;
- `latency_ms`: fixed one-way delivery latency;
- `jitter_ms`: uniformly selected positive or negative latency variation;
- `loss_rate` and `duplicate_rate`: probabilities from `0.0` to `1.0`;
- `reorder_ms`: a uniformly selected extra delay, bounded by this value, which
  can move later packets ahead of earlier ones; and
- `disconnect_after`: unexpectedly close the subscriber receiving the Nth
  matching delivery. Zero disables interruption.

`hold_deliveries(milliseconds)` temporarily holds all matching deliveries
already passing through the enabled profile. When the timer expires, every due
packet is written in the same frame to model a burst after a network pause.
`get_fault_counters()` returns `matched`, `queued`, `delivered`, `dropped`,
`duplicated`, `reordered` (nonzero reorder delays injected) and `interrupted`.
Calling `configure_faults()` again
resets the RNG, counters, hold and queued deliveries, making a seed/profile and
the same publish sequence replayable. `clear_faults()` restores direct delivery.

The LAN wrapper forwards these calls only when it is the hosting instance.
`hold_deliveries()` returns `ERR_UNAVAILABLE`, and counters are empty, when that
instance joined a broker hosted elsewhere.
