#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_directory="${1:-${repository_root}/dist}"
package_path="${output_directory}/godot-mqtt.zip"

mkdir -p "${output_directory}"
rm -f "${package_path}"
cd "${repository_root}"
zip -q "${package_path}" \
	addons/mqtt/LICENSE.md \
	addons/mqtt/README.md \
	addons/mqtt/mqtt.gd \
	addons/mqtt/mqtt.gd.uid \
	addons/mqtt/mqtt.tscn \
	addons/mqtt/simulated_broker.gd \
	addons/mqtt/simulated_broker.gd.uid \
	addons/mqtt/simulated_broker.tscn \
	addons/mqtt/lan_broker.gd \
	addons/mqtt/lan_broker.gd.uid \
	addons/mqtt/lan_broker.tscn

echo "Created ${package_path}"
