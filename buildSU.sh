#!/bin/bash
set -euo pipefail

# Debug info
echo -e "\n\033[34m=== Starting buildSU.sh (KernelSU version) ===\033[0m"
echo "VERSION: ${VERSION:-not set}"
echo "KERNELSU_VERSION: ${KERNELSU_VERSION:-not set}"
echo "Current directory: $(pwd)"
ls -la

# Validate inputs
[ -z "${VERSION:-}" ] && { echo -e "\033[31mError: VERSION not specified\033[0m"; exit 1; }
[ -z "${KERNELSU_VERSION:-}" ] && { echo -e "\033[31mError: KERNELSU_VERSION not specified\033[0m"; exit 1; }
[ ! -f "sources.yaml" ] && { echo -e "\033[31mError: sources.yaml not found\033[0m"; exit 1; }

# Convert YAML to JSON
json=$(python3 -c "import sys,yaml,json,traceback; try: json.dump(yaml.safe_load(sys.stdin), sys.stdout) except: traceback.print_exc(); sys.exit(1)" < sources.yaml) || exit 1

# Get commands
kernel_commands=$(echo "$json" | jq -r --arg v "$VERSION" '.[$v].kernel[]? // empty') || exit 1
config_commands=$(echo "$json" | jq -r --arg v "$VERSION" '.[$v].config[]? // empty') || exit 1
ksu_config_commands=$(echo "$json" | jq -r --arg v "$VERSION" '.[$v].kernelSU_config[]? // empty') || exit 1
build_commands=$(echo "$json" | jq -r --arg v "$VERSION" '.[$v].buildSU[]? // empty') || exit 1
ksu_commands=$(echo "$json" | jq -r --arg v "$(echo "$json" | jq -r --arg v "$VERSION" '.[$v].kernelSU[]? // empty')" '.KernelSU.version[$v][]? // empty') || exit 1

# Execute commands
execute_commands() {
  local commands=$1
  local desc=$2
  echo -e "\n\033[32m=== $desc ===\033[0m"
  while I
