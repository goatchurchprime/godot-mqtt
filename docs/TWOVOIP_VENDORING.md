# TwoVoIP vendoring guide

Vendor the V1.5 addon files into TwoVoIP's existing `addons/mqtt` directory:

- `LICENSE.md`
- `README.md`
- `mqtt.gd`, `mqtt.gd.uid` and `mqtt.tscn`
- `simulated_broker.gd`, `simulated_broker.gd.uid` and
  `simulated_broker.tscn`
- `lan_broker.gd`, `lan_broker.gd.uid` and `lan_broker.tscn`

During review, pin the source to the exact V1.5 commit or tag rather than the
moving branch. The broker is optional: existing projects can continue to use
only the MQTT client.

## Symmetric application startup

Each native application may instantiate `lan_broker.tscn`, connect its
`broker_available(url, hosted_here)` signal, optionally configure faults, and
call `start()`. The instances discover or elect one host and all MQTT clients
connect to the emitted URL.

```gdscript
func _ready() -> void:
	$LANBroker.broker_available.connect(_on_broker_available)
	$LANBroker.configure_faults({
		"enabled": fuzz_enabled,
		"seed": fuzz_seed,
		"topic_filters": ["twovoip/audio/#"],
		"latency_ms": latency_ms,
		"jitter_ms": jitter_ms,
		"loss_rate": loss_rate,
		"duplicate_rate": duplicate_rate,
		"reorder_ms": reorder_ms,
	})
	$LANBroker.start()


func _on_broker_available(url: String, hosted_here: bool) -> void:
	print("LAN MQTT endpoint %s; hosted here=%s" % [url, hosted_here])
	$MQTT.connect_to_broker(url)
```

For deterministic automation, designate one process and call
`start_hosting()` there; other processes call `start()`. For interactive smoke
tests, every process can call `start()` and allow election to select the host.

Configure every contender before `start()` so whichever instance wins applies
the same profile. Only the hosting instance can subsequently call
`hold_deliveries(milliseconds)` or return non-empty `get_fault_counters()`.
Calling `configure_faults()` again resets its seeded run; an empty profile turns
faults off. Scope audio topics separately from signalling/status topics so MQTT
control semantics and application liveness remain observable during a fault.
