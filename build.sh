#!/bin/bash

# Get version from GitHub environment variable
version=${VERSION}

# Check if version is provided
if [ -z "$version" ]
then
    echo "No version specified. No config or build will be executed. Exiting..."
    exit 1
fi

# Apply drivers configuration if drivers.cfg exists
if [ -f "../drivers.cfg" ]; then
    echo "Applying drivers configuration..."
    CONFIG_FILE="arch/arm64/configs/lineage-nashc_defconfig"
    
    # Create backup
    cp $CONFIG_FILE ${CONFIG_FILE}.bak
    
    # Process each line in drivers.cfg
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        config_key=$(echo "$line" | cut -d'=' -f1 | xargs)
        config_value=$(echo "$line" | cut -d'=' -f2 | xargs)
        
        echo "Processing: $config_key=$config_value"
        
        # Remove existing setting if exists
        sed -i "/^$config_key[ =]/d" $CONFIG_FILE
        sed -i "/^# $config_key is not set/d" $CONFIG_FILE
        
        # Add new setting
        echo "$config_key=$config_value" >> $CONFIG_FILE
    done < "../drivers.cfg"
    
    echo "Config changes applied"
fi

# Convert the YAML file to JSON
json=$(python3 -c "import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)" < sources.yaml)

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

# Execute the config commands
echo "$config_commands" | while read -r command; do
    eval "$command"
    if [ $? -ne 0 ]; then
        echo "Config command failed: $command"
        exit 1
    fi
done

# Execute the build commands
echo "$build_commands" | while read -r command; do
    eval "$command"
    if [ $? -ne 0 ]; then
        echo "Build command failed: $command"
        exit 1
    fi
done
