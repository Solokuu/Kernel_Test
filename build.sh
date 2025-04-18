#!/bin/bash

# Get version from GitHub environment variable
version=${VERSION}

# Check if version is provided
if [ -z "$version" ]
then
    echo "No version specified. No config or build will be executed. Exiting..."
    exit 1
fi

# Store the root directory
ROOT_DIR=$(pwd)

# Check if we're in kernel directory
if [ ! -f "Makefile" ]; then
    echo "Not in kernel source directory! Changing to kernel directory..."
    cd kernel || exit 1
    KERNEL_DIR=$(pwd)
else
    KERNEL_DIR=$(pwd)
fi

# Apply drivers configuration if drivers.cfg exists
if [ -f "${ROOT_DIR}/drivers.cfg" ]; then
    echo "Applying drivers configuration..."
    CONFIG_FILE="${KERNEL_DIR}/arch/arm64/configs/lineage-nashc_defconfig"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file $CONFIG_FILE not found!"
        echo "Available config files:"
        find "${KERNEL_DIR}/arch/arm64/configs/" -type f | sed 's/^/  /'
        exit 1
    fi
    
    # Create backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # Process each line in drivers.cfg
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        config_key=$(echo "$line" | cut -d'=' -f1 | xargs)
        config_value=$(echo "$line" | cut -d'=' -f2 | xargs)
        
        echo "Processing: $config_key=$config_value"
        
        # Remove existing setting if exists
        sed -i "/^$config_key[ =]/d" "$CONFIG_FILE"
        sed -i "/^# $config_key is not set/d" "$CONFIG_FILE"
        
        # Add new setting
        echo "$config_key=$config_value" >> "$CONFIG_FILE"
    done < "${ROOT_DIR}/drivers.cfg"
    
    echo "Config changes applied"
fi

# Convert the YAML file to JSON
if [ -f "${ROOT_DIR}/sources.yaml" ]; then
    json=$(python3 -c "import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin)))" < "${ROOT_DIR}/sources.yaml" 2>/dev/null)
else
    echo "Error: sources.yaml not found in ${ROOT_DIR}"
    exit 1
fi

# Check if json is empty
if [ -z "$json" ]
then
    echo "Failed to parse YAML. Exiting..."
    exit 1
fi

# Parse the JSON file
config_commands=$(echo "$json" | jq -r --arg version "$version" '.[$version].config[]?')
build_commands=$(echo "$json" | jq -r --arg version "$version" '.[$version].build[]?')

# Check if config_commands and build_commands are empty
if [ -z "$config_commands" ] || [ -z "$build_commands" ]
then
    echo "Failed to parse JSON. Using default commands..."
    config_commands="make O=out ARCH=arm64 lineage-nashc_defconfig"
    build_commands="ARCH=arm64 CROSS_COMPILE=\"${ROOT_DIR}/clang/bin/aarch64-linux-gnu-\" CROSS_COMPILE_COMPAT=\"${ROOT_DIR}/clang/bin/arm-linux-gnueabi\" CROSS_COMPILE_ARM32=\"${ROOT_DIR}/clang/bin/arm-linux-gnueabi-\" CLANG_TRIPLE=aarch64-linux-gnu- make -j$(nproc --all) LLVM=1 LLVM_IAS=1 LD=ld.lld AR=llvm-ar NM=llvm-nm AS=llvm-as OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip O=out"
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
