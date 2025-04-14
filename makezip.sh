#!/bin/bash
set -euo pipefail

# Load environment
source_env() {
    if [ -f ".env" ]; then
        set -o allexport
        source .env
        set +o allexport
    fi
}
source_env

# Set defaults
OUTPUT_DIR="${OUTPUT_DIR:-output}"
ZIP_NO_KSU="${ZIP_NO_KSU:-LineageOS-20-NoKernelSU.zip}"
ZIP_KSU="${ZIP_KSU:-LineageOS-20-KernelSU.zip}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

package_kernel() {
    local source_dir="$1"
    local zip_name="$2"
    local temp_zip="temp_${zip_name}"

    echo "🔧 Packaging ${zip_name} from ${source_dir}"

    # Verify source
    if [ ! -d "${source_dir}" ]; then
        echo "❌ Error: Source directory ${source_dir} not found" >&2
        return 1
    fi

    if [ -z "$(ls -A "${source_dir}")" ]; then
        echo "❌ Error: No kernel image in ${source_dir}" >&2
        return 1
    fi

    # Prepare AnyKernel3
    echo "🛠 Preparing AnyKernel3 directory"
    rm -rf AnyKernel3/*
    cp -v "${source_dir}"/* AnyKernel3/ || {
        echo "❌ Error: Failed to copy kernel image" >&2
        return 1
    }

    # Create zip
    echo "📦 Creating zip archive"
    (
        cd AnyKernel3 || return 1
        zip -r9 "../${temp_zip}" ./* || {
            echo "❌ Error: Zip creation failed" >&2
            return 1
        }
    )

    # Move final zip
    mv -v "${temp_zip}" "${OUTPUT_DIR}/${zip_name}" || {
        echo "❌ Error: Failed to move final zip" >&2
        return 1
    }

    echo "✅ Successfully created ${OUTPUT_DIR}/${zip_name}"
    return 0
}

# Main execution
echo "🚀 Starting kernel packaging"
package_kernel "outw/false" "${ZIP_NO_KSU}"
package_kernel "outw/true" "${ZIP_KSU}"

echo "🎉 All packages created successfully"
ls -lh "${OUTPUT_DIR}"
