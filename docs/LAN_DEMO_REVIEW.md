# LAN demo review

Open `lan_broker_example.tscn` and keep `lan_broker_example.gd` beside it while
running the scene. The whole application-side binding is visible in `_ready()`
and `_on_broker_available()`:

1. connect to `broker_available`;
2. call `$LANBroker.start()`;
3. pass the emitted URL to `$MQTT.connect_to_broker(url)`; and
4. use the MQTT client normally after `broker_connected`.

There are two useful one-line experiments:

- `start()` searches the LAN and elects a simulated broker only when needed;
- `start_hosting()` skips discovery and always tries to host one locally.

The latter is useful when changing the broker itself. The former is the intended
no-setup path. Run the scene on two LAN computers; the status line says which
computer is hosting and which discovered it. Messages published by either should
appear in both logs.

## Code to review

- `addons/mqtt/simulated_broker.gd` is the limited MQTT packet loop.
- `addons/mqtt/lan_broker.gd` is only discovery, election and endpoint choice.
- `lan_broker_example.gd` is application glue and is expected to be rewritten.
- `tests/simulated_broker_acceptance.gd` and `tests/lan_broker_acceptance.gd`
  show the same interfaces without editor UI.

The LAN packet format is deliberately readable JSON. Search for
`_encode_message()` and `_decode_message()` to alter or inspect it.

## Current boundaries

- This assumes a friendly LAN. There is no authentication or encryption.
- Each computer needs UDP port 1884; running two discovery instances on one
  computer may fail because both try to bind it.
- The simulated broker listens on TCP 1883 by default and keeps retained values
  only in memory.
- Browser exports cannot use raw UDP or TCP. They need an explicit WebSocket
  broker and do not participate in LAN election.
- Election is intentionally modest: brief packet loss is covered by repeated
  candidate messages, but network partitions can temporarily produce two
  brokers. This is a development convenience, not a consensus service.
