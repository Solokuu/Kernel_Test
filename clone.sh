#!/bin/bash

# Get version from GitHub environment variable
version=${VERSION}

# Check if version is provided
if [ -z "$version" ]
then
    echo "No version specified. No kernel or clang will be cloned. Exiting..."
    exit 1
fi

# Convert the YAML file to JSON
json=$(python -c "import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)" < sources.yaml)

# Parse the JSON file
kernel_commands=$(echo $json | jq -r --arg version "$version" '.[$version].kernel[]')
clang_commands=$(echo $json | jq -r --arg version "$version" '.[$version].clang[]')

# Print the commands that will be executed
echo -e "\033[31mClone.sh will execute following commands corresponding to ${version}:\033[0m"
echo "$kernel_commands" | while read -r command; do
    echo -e "\033[32m$command\033[0m"
done
echo "$clang_commands" | while read -r command; do
    echo -e "\033[32m$command\033[0m"
done

# Clone the kernel and append clone path to the command
echo "$kernel_commands" | while read -r command; do
    eval "$command kernel"
done

# Clone the clang and append clone path to the command
echo "$clang_commands" | while read -r command; do
    eval "$command kernel/clang"
done

# =============================================
# Atheros AR9271 firmware installation section
# =============================================

echo -e "\033[34m\nInstalling Atheros AR9271 firmware...\033[0m"

# Define paths
FIRMWARE_URL="https://github.com/OpenELEC/wlan-firmware/raw/master/firmware/ath9k_htc/htc_9271-1.4.0.fw"
FIRMWARE_DIR="kernel/drivers/net/wireless/ath/ath9k/firmware"
KCONFIG_FILE="kernel/drivers/net/wireless/ath/ath9k/Kconfig"

# Create firmware directory if it doesn't exist
mkdir -p "$FIRMWARE_DIR"

# Download the firmware
echo "Downloading firmware from ${FIRMWARE_URL}..."
wget -q "$FIRMWARE_URL" -O "${FIRMWARE_DIR}/htc_9271.fw"
if [ $? -ne 0 ]; then
    echo -e "\033[31mFailed to download firmware!\033[0m"
    exit 1
fi

# Update Kconfig to include firmware path
echo "Updating Kconfig file..."
if grep -q "ATH9K_HTC_FW_PATH" "$KCONFIG_FILE"; then
    # Update existing configuration
    sed -i 's|default "ath9k_htc/htc_9271.fw"|default "firmware/htc_9271.fw"|' "$KCONFIG_FILE"
else
    # Add new configuration
    cat <<EOT >> "$KCONFIG_FILE"

config ATH9K_HTC_FW_PATH
    string "Firmware path for Atheros HTC based wireless cards"
    default "firmware/htc_9271.fw"
    help
      This sets the firmware path for Atheros HTC based wireless cards.
      Default is firmware/htc_9271.fw
EOT
fi

# Update Makefile to ensure driver is built
MAKEFILE="kernel/drivers/net/wireless/ath/ath9k/Makefile"
if ! grep -q "ath9k_htc" "$MAKEFILE"; then
    echo "obj-\$(CONFIG_ATH9K_HTC) += ath9k_htc.o" >> "$MAKEFILE"
fi

echo -e "\033[32mFirmware installation completed successfully!\033[0m"
echo -e "\033[33mDon't forget to enable CONFIG_ATH9K_HTC in your kernel config!\033[0m"
