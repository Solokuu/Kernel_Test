#!/bin/bash
set -euo pipefail

# Debug info
echo -e "\n\033[34m=== Starting build.sh ===\033[0m"
echo "VERSION: ${VERSION:-not set}"
echo "KERNELSU: ${KERNELSU:-false}"
echo "Current directory: $(pwd)"
ls -la

# Validate version
if [ -z "${VERSION:-}" ]; then
    echo -e "\033[31mError: No version specified. Exiting...\033[0m"
    exit 1
fi

# Check for required files
if [ ! -f "sources.yaml" ]; then
    echo -e "\033[31mError: sources.yaml not found\033[0m"
    exit 1
fi

# Convert YAML to JSON
json=$(python3 -c "
import sys, yaml, json, traceback
try:
    json.dump(yaml.safe_load(sys.stdin), sys.stdout)
except Exception:
    traceback.print_exc()
    sys.exit(1)
" < sources.yaml) || {
    echo -e "\033[31mError: Failed to convert YAML to JSON\033[0m"
    exit 1
}

# Parse JSON with error handling
config_commands=$(echo "$json" | jq -r --arg version "$VERSION" '.[$version].config[]? // empty') || {
    echo -e "\033[31mError: Failed to parse config commands\033[0m"
    exit 1
}

build_commands=$(echo "$json" | jq -r --arg version "$VERSION" '.[$version].build[]? // empty') || {
    echo -e "\033[31mError: Failed to parse build commands\033[0m"
    exit 1
}

# KernelSU specific commands
if [ "${KERNELSU:-false}" = "true" ]; then
    echo -e "\n\033[33m=== Applying KernelSU modifications ===\033[0m"
    ksu_config_commands=$(echo "$json" | jq -r --arg version "$VERSION" '.[$version].kernelSU_config[]? // empty') || {
        echo -e "\033[31mError: Failed to parse KernelSU config commands\033[0m"
        exit 1
    }
    
    ksu_build_commands=$(echo "$json" | jq -r --arg version "$VERSION" '.[$version].kernelSU_build[]? // empty') || {
        echo -e "\033[31mError: Failed to parse KernelSU build commands\033[0m"
        exit 1
    }
    
    config_commands=$(echo -e "$config_commands\n$ksu_config_commands")
    build_commands=$(echo -e "$build_commands\n$ksu_build_commands")
fi

# Validate commands
if [ -z "$config_commands" ] || [ -z "$build_commands" ]; then
    echo -e "\033[31mError: No commands found for version $VERSION\033[0m"
    exit 1
fi

# Print commands
echo -e "\n\033[35m=== Config Commands ===\033[0m"
echo "$config_commands" | while read -r cmd; do
    [ -n "$cmd" ] && echo -e "\033[36m$cmd\033[0m"
done

echo -e "\n\033[35m=== Build Commands ===\033[0m"
echo "$build_commands" | while read -r cmd; do
    [ -n "$cmd" ] && echo -e "\033[36m$cmd\033[0m"
done

# Enter kernel directory
echo -e "\n\033[34m=== Executing in kernel directory ===\033[0m"
cd kernel || {
    echo -e "\033[31mError: Failed to enter kernel directory\033[0m"
    exit 1
}

# Execute config commands
echo -e "\n\033[32m=== Running config commands ===\033[0m"
while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    echo -e "\033[33mExecuting: $cmd\033[0m"
    eval "$cmd" || {
        echo -e "\033[31mError: Command failed: $cmd\033[0m"
        exit 1
    }
done <<< "$config_commands"

# Execute build commands
echo -e "\n\033[32m=== Running build commands ===\033[0m"
while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    echo -e "\033[33mExecuting: $cmd\033[0m"
    eval "$cmd" || {
        echo -e "\033[31mError: Command failed: $cmd\033[0m"
        exit 1
    }
done <<< "$build_commands"

echo -e "\n\033[32m=== Build completed successfully ===\033[0m"
