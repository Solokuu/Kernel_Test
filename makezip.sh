#!/bin/bash
set -euo pipefail

# Debug info
echo "Current directory: $(pwd)"
ls -la

# Set default values
zip_no_ksu="${ZIP_NO_KSU:-LineageOS-20-NoKernelSU.zip}"
zip_ksu="${ZIP_KSU:-LineageOS-20-KernelSU.zip}"
output_dir="${GITHUB_WORKSPACE}/output"
mkdir -p "${output_dir}"

# Function to package kernel
package_kernel() {
    local source_dir="$1"
    local zip_name="$2"
    local temp_zip="${zip_name%.zip}-temp.zip"
    
    echo "Packaging kernel from ${source_dir} to ${zip_name}"
    
    # Verify source
    if [ ! -d "${source_dir}" ]; then
        echo "Error: Source directory ${source_dir} not found" >&2
        return 1
    fi
    
    if [ -z "$(ls -A "${source_dir}")" ]; then
        echo "Error: Source directory ${source_dir} is empty" >&2
        return 1
    fi

    # Prepare AnyKernel3
    echo "Preparing AnyKernel3 directory"
    mkdir -p AnyKernel3
    rm -rf AnyKernel3/*

    # Copy files
    echo "Copying kernel image"
    cp -v "${source_dir}"/* AnyKernel3/ || {
        echo "Error: Failed to copy kernel image" >&2
        return 1
    }

    # Create zip in current directory
    echo "Creating zip archive"
    (
        cd AnyKernel3 || return 1
        zip -r9 "../${temp_zip}" ./* || {
            echo "Error: Failed to create zip" >&2
            return 1
        }
    )

    # Move to output directory
    echo "Moving zip to output directory"
    mv -v "${temp_zip}" "${output_dir}/${zip_name}" || {
        echo "Error: Failed to move zip file" >&2
        return 1
    }

    return 0
}

# Package both versions
echo "Starting packaging process"
package_kernel "outw/false" "${zip_no_ksu}" || exit 1
package_kernel "outw/true" "${zip_ksu}" || exit 1

echo "Packaging completed successfully"
ls -lh "${output_dir}"
