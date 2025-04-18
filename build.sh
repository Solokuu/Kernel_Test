#!/bin/bash

# Get version from GitHub environment variable
version=${VERSION}

# Check if version is provided
if [ -z "$version" ]
then
    echo "No version specified. No config or build will be executed. Exiting..."
    exit 1
fi

# Function to add drivers from drivers.cfg
add_drivers() {
    echo -e "\033[34mAdding drivers from drivers.cfg...\033[0m"
    
    if [ ! -f "$DRIVERS_CONFIG" ]; then
        echo "No drivers.cfg found, skipping driver additions."
        return 0
    fi
    
    if [ ! -f "kernel/out/.config" ]; then
        echo "Config file doesn't exist, please run config commands first."
        return 1
    fi
    
    # Read driver configurations from file
    while IFS= read -r driver_config || [ -n "$driver_config" ]; do
        # Skip empty lines and comments
        if [[ -z "$driver_config" || "$driver_config" == \#* ]]; then
            continue
        fi
        
        echo "Adding: $driver_config"
        config_key=$(echo "$driver_config" | cut -d'=' -f1)
        
        # First undefine existing config (if any)
        ./scripts/config --file "out/.config" --undefine "$config_key" 2>/dev/null
        
        # Then add new config
        ./scripts/config --file "out/.config" --set-val "$config_key" "$(echo "$driver_config" | cut -d'=' -f2)"
    done < "$DRIVERS_CONFIG"
    
    # Update configuration
    make O="out" ARCH="$ARCH" olddefconfig || {
        echo "Failed to update configuration with new drivers"
        return 1
    }
    
    echo -e "\033[34mDriver configuration updated successfully.\033[0m"
}

# Convert the YAML file to JSON
json=$(python -c "import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)" < sources.yaml)

# Check if json is empty
if [ -z "$json" ]
then
    echo "Failed to convert YAML to JSON. Exiting..."
    exit 1
fi

# Parse the JSON file
config_commands=$(echo $json | jq -r --arg version "$version" '.[$version].config[]')
build_commands=$(echo $json | jq -r --arg version "$version" '.[$version].build[]')

# Check if config_commands and build_commands are empty
if [ -z "$config_commands" ] || [ -z "$build_commands" ]
then
    echo "Failed to parse JSON. Exiting..."
    exit 1
fi

# Print the commands that will be executed
echo -e "\033[31mBuild.sh will execute following commands corresponding to ${version}:\033[0m"
echo "$config_commands" | while read -r command; do
    echo -e "\033[32m$command\033[0m"
done
echo "$build_commands" | while read -r command; do
    echo -e "\033[32m$command\033[0m"
done

# Enter the kernel directory
cd kernel || exit 1

# Execute the config commands
echo "$config_commands" | while read -r command; do
    eval "$command"
done

# Add driver configurations
add_drivers

# Execute the build commands
echo "$build_commands" | while read -r command; do
    eval "$command"
done
