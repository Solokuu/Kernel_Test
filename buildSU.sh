#!/bin/bash
set -euo pipefail

# Debug info
echo -e "\n\033[34m=== Starting buildSU.sh (KernelSU version) ===\033[0m"
echo "VERSION: ${VERSION:-not set}"
echo "KERNELSU_VERSION: ${KERNELSU_VERSION:-not set}"
echo "Current directory: $(pwd)"
ls -la

# Validate inputs
if [ -z "${VERSION:-}" ]; then
    echo -e "\033[31mError: VERSION not specified. Exiting...\033[0m"
    exit 1
fi

if [ -z "${KERNELSU_VERSION:-}" ]; then
    echo -e "\033[31mError: KERNELSU_VERSION not specified. Exiting...\033[0m"
    exit 1
fi

# Check for required files
if [ ! -f "sources.yaml" ]; then
    echo -e "\033[31mError: sources.yaml not found\033[0m"
    exit 1
fi

# Convert YAML to JSON with error handling
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

# Parse build commands
build_commands=$(echo "$json" | jq -r --arg version "$VERSION" '.[$version].buildSU[]? // empty') || {
    echo -e "\033[31mError: Failed to parse build commands\033[0m"
    exit 1
}

if [ -z "$build_commands" ]; then
    echo -e "\033[31mError: No build commands found for version $VERSION\033[0m"
    exit 1
fi

# Print commands
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

# Execute build commands
echo -e "\n\033[32m=== Running build commands ===\033[0m"
while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    cmd=${cmd//kernelsu-version/$KERNELSU_VERSION}
    echo -e "\033[33mExecuting: $cmd\033[0m"
    eval "$cmd" || {
        echo -e "\033[31mError: Command failed: $cmd\033[0m"
        exit 1
    }
done <<< "$build_commands"

echo -e "\n\033[32m=== KernelSU build completed successfully ===\033[0m"
