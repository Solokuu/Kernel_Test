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
json=$(python3 -c "
import sys, yaml, json, traceback
try:
    print(json.dumps(yaml.safe_load(sys.stdin)))
except Exception as e:
    traceback.print_exc()
    sys.exit(1)
" < sources.yaml) || exit 1

# Get commands
kernel_commands=$(echo "$json" | jq -r --arg v "$VERSION" '.[$v].kernel[]? // empty') || exit 1
config_commands=$(echo "$json" | jq -r --arg v "$VERSION" '.[$v].config[]? // empty') || exit 1
ksu_config_commands=$(echo "$json" | jq -r --arg v "$VERSION" '.[$v].kernelSU_config[]? // empty') || exit 1
build_commands=$(echo "$json" | jq -r --arg v "$VERSION" '.[$v].buildSU[]? // empty') || exit 1
ksu_version=$(echo "$json" | jq -r --arg v "$VERSION" '.[$v].kernelSU[]? // empty') || exit 1
ksu_commands=$(echo "$json" | jq -r --arg v "$ksu_version" '.KernelSU.version[$v][]? // empty') || exit 1

# Execute commands with error handling
execute_commands() {
  local commands=$1
  local desc=$2
  echo -e "\n\033[32m=== $desc ===\033[0m"
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    cmd=${cmd//kernelsu-version/$KERNELSU_VERSION}
    echo -e "\033[33mExecuting: $cmd\033[0m"

    # Special handling for config commands
    if [[ "$desc" == *"Configuring"* ]]; then
      (set -x; eval "$cmd" || {
        echo -e "\033[31mError: Command failed, trying to recover...\033[0m"
        make ARCH=arm64 O=out olddefconfig
      })
    else
      (set -x; eval "$cmd") || {
        echo -e "\033[31mError: Command failed\033[0m"
        exit 1
      }
    fi
  done <<< "$commands"
}

# Clone kernel and toolchain
execute_commands "$kernel_commands" "Cloning kernel"
execute_commands "$(echo "$json" | jq -r --arg v "$VERSION" '.[$v].clang[]? // empty')" "Setting up toolchain"

# Configure and build
cd kernel || { echo -e "\033[31mError: kernel directory not found\033[0m"; exit 1; }

# Clean build directory
if [ -d "out" ]; then
  echo -e "\n\033[35m=== Cleaning previous build ===\033[0m"
  rm -rf out
fi

# Apply configuration step by step
execute_commands "$config_commands" "Initial kernel configuration"
execute_commands "make ARCH=arm64 O=out olddefconfig" "Applying default config"
execute_commands "$ksu_config_commands" "Applying KernelSU config"
execute_commands "make ARCH=arm64 O=out olddefconfig" "Finalizing config"

# Setup KernelSU
execute_commands "$ksu_commands" "Setting up KernelSU"

# Build kernel
execute_commands "$build_commands" "Building kernel"

echo -e "\n\033[32m=== KernelSU build completed successfully ===\033[0m"
