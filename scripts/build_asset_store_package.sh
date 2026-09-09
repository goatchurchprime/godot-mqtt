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
	addons/mqtt/mqtt.tscn

echo "Created ${package_path}"
