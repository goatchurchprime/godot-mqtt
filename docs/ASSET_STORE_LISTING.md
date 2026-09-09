# Godot Asset Store listing draft

This file records the factual release metadata. The maintainer should edit the
public wording in their own voice before submitting it for review.

## Identity

- Asset name: **Godot MQTT Client — TCP, TLS and WebSocket**
- Asset URL slug: `godot-mqtt-client`
- Publisher: Julian Todd (or the maintainer's existing publisher identity)
- Type: Addon
- License: MIT
- Version: 1.4
- Minimum Godot version: 4.1
- Maximum Godot version: leave unset
- Source: https://github.com/goatchurchprime/godot-mqtt

## Summary

A small MQTT 3.1.1 client written entirely in GDScript, with TCP, TLS,
WebSocket and secure WebSocket transports.

## Description facts

- Supports Godot 4.1 and later.
- Supports MQTT 3.1.1 publish and subscribe using QoS 0 and QoS 1.
- Supports retained messages and last-will messages.
- Supports text and binary payloads.
- Web exports must use WebSocket or secure WebSocket transport.
- QoS 2, persistent sessions and automatic reconnect are not implemented.
- The source repository includes demonstrations and editor/headless tests.

## Version 1.4 changelog

- Correct PUBACK parsing and acknowledgement signalling.
- Wrap packet identifiers through the valid 1–65535 range.
- Reject unsupported QoS 2 explicitly.
- Validate network-derived packet lengths in release builds.
- Bound packet processing per frame and improve socket failure reporting.
- Add deterministic tests and opt-in public-broker diagnostics.

## AI usage disclosure

OpenAI Codex assisted with the V1.4 client-hardening patch, test suite, release
documentation and packaging script under the maintainer's direction. The
repository includes the exact GDScript diff produced during this work. The
maintainer reviews, tests and takes responsibility for the released code.

## Upload

Upload `dist/godot-mqtt.zip`. It contains only `addons/mqtt` and unpacks to
the correct project-relative location.
