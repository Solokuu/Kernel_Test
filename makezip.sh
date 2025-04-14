#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error
set -o pipefail  # Fail pipeline if any command fails

# Debug: Show current directory and files
echo "Current directory: $(pwd)"
ls -la

# Get ZIP names from environment variables
zip_no_ksu="${ZIP_NO_KSU}"
zip_ksu="${ZIP_KSU}"

# Function to handle the packaging process
package_kernel() {
    local source_dir="$1"
    local zip_name="$2"
    
    echo "Packaging kernel from ${source_dir} to ${zip_name}"
    
    # Check if source directory exists and is not empty
    if [ ! -d "${source_dir}" ]; then
        echo "Error: Source directory ${source_dir} does not exist"
        exit 1
    fi
    
    if [ -z "$(ls -A "${source_dir}" 2>/dev/null)" ]; then
        echo "Error: Source directory ${source_dir} is empty"
        exit 1
    fi
    
    # Clean AnyKernel3 directory
    echo "Cleaning AnyKernel3 directory"
    if [ -d "AnyKernel3" ]; then
        rm -rf AnyKernel3/*
    else
        mkdir -p AnyKernel3
    fi
    
    # Copy files
    echo "Copying files from ${source_dir} to AnyKernel3"
    cp -v "${source_dir}"/* AnyKernel3/ || {
        echo "Error: Failed to copy files from ${source_dir}"
        exit 1
    }
    
    # Create zip
    echo "Creating zip archive ${zip_name}"
    (
        cd AnyKernel3 || exit 1
        zip -r9 "../${zip_name}" ./* || {
            echo "Error: Failed to create zip archive"
            exit 1
        }
    )
    
    # Move zip to workspace
    echo "Moving ${zip_name} to ${GITHUB_WORKSPACE}"
    if [ -f "${zip_name}" ]; then
        mv -v "${zip_name}" "${GITHUB_WORKSPACE}/" || {
            echo "Error: Failed to move zip file"
            exit 1
        }
    else
        echo "Error: Zip file ${zip_name} was not created"
        exit 1
    fi
    
    echo "Successfully created ${zip_name}"
}

# Package non-KernelSU version
package_kernel "outw/false" "${zip_no_ksu}"

# Package KernelSU version
package_kernel "outw/true" "${zip_ksu}"

echo "All packaging operations completed successfully"
