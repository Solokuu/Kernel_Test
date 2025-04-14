#!/bin/bash

# Check for required commands
for cmd in python jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is not installed." >&2
        exit 1
    fi
done

# Get version from GitHub environment variable
version="${VERSION}"

# Check if version is provided
if [ -z "$version" ]; then
    echo "No version specified. Exiting..." >&2
    exit 1
fi

# Check if sources.yaml exists
if [ ! -f "sources.yaml" ]; then
    echo "Error: sources.yaml not found." >&2
    exit 1
fi

# Convert the YAML file to JSON
json=$(python -c "import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)" < "sources.yaml") || {
    echo "Failed to convert YAML to JSON. Exiting..." >&2
    exit 1
}

# Check if json is empty
if [ -z "$json" ]; then
    echo "Error: Empty JSON output. Exiting..." >&2
    exit 1
fi

# Parse the JSON file for anykernel
anykernel=$(echo "$json" | jq -r --arg version "$version" '.[$version].anykernel[]') || {
    echo "Failed to parse JSON for anykernel. Exiting..." >&2
    exit 1
}

# Check if anykernel is empty
if [ -z "$anykernel" ]; then
    echo "Error: No anykernel found for version $version. Exiting..." >&2
    exit 1
fi

# Parse the JSON file for AnyKernel3 version corresponding to anykernel
anykernel3=$(echo "$json" | jq -r --arg anykernel "$anykernel" '.AnyKernel3.version[$anykernel][]') || {
    echo "Failed to parse JSON for AnyKernel3. Exiting..." >&2
    exit 1
}

# Check if anykernel3 is empty
if [ -z "$anykernel3" ]; then
    echo "Error: No AnyKernel3 version found for $anykernel. Exiting..." >&2
    exit 1
fi

# Append "AnyKernel3" to the anykernel3 command
anykernel3_cmd="${anykernel3} AnyKernel3"

# Print the commands that will be executed
echo -e "\033[31mScript will execute following commands corresponding to ${version}:\033[0m" >&2
echo -e "\033[32m${anykernel3_cmd}\033[0m" >&2

# Ask for confirmation
read -p "Are you sure you want to execute this command? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Execute the command
eval "$anykernel3_cmd"
