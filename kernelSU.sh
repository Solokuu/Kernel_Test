#!/bin/bash

# Define colors
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

# Get version from environment
version=${VERSION:-"LineageOS-20"}
kernelsu_version=${KERNELSU_VERSION:-"v1.0.6"}

echo -e "${GREEN}[+] Preparing KernelSU-Next ${kernelsu_version} for ${version}${NC}"

# Clone KernelSU-Next using raw Git URL
if [ ! -d "KernelSU-next" ]; then
    echo -e "${YELLOW}[!] Cloning KernelSU-Next...${NC}"
    git clone https://git.kernel.org/pub/scm/linux/kernel/git/tiann/KernelSU-next.git -b "${kernelsu_version}" KernelSU-next || {
        echo -e "${YELLOW}[!] Fallback to GitHub mirror...${NC}"
        git clone https://github.com/tiann/KernelSU-next.git -b "${kernelsu_version}" KernelSU-next || {
            echo -e "${RED}[-] Failed to clone KernelSU-Next from all sources!${NC}"
            exit 1
        }
    }
fi

# Ensure kernel directory exists
mkdir -p kernel
cd kernel || {
    echo -e "${RED}[-] Kernel directory not found!${NC}"
    exit 1
}

# Apply KernelSU patches
echo -e "${GREEN}[+] Applying KernelSU patches...${NC}"
../KernelSU-next/scripts/setup.sh . || {
    echo -e "${RED}[-] Failed to apply KernelSU patches!${NC}"
    exit 1
}

# 4.14-specific fixes
echo -e "${YELLOW}[!] Applying 4.14 compatibility patches...${NC}"

# 1. Disable unsupported features
[ -f "KernelSU/.config" ] && {
    sed -i 's/CONFIG_KSU_FSVERITY=y/CONFIG_KSU_FSVERITY=n/' KernelSU/.config
    sed -i 's/CONFIG_KSU_MEMFD_SECRET=y/CONFIG_KSU_MEMFD_SECRET=n/' KernelSU/.config
}

# 2. Fix kallsyms lookup if missing
if [ -f "KernelSU/kernel/ksu.c" ] && ! grep -q "kallsyms_lookup_name" KernelSU/kernel/ksu.c; then
    echo -e "${YELLOW}[!] Patching kallsyms_lookup_name...${NC}"
    echo -e "\n#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 7, 0)\nvoid *kallsyms_lookup_name(const char *name) {\n    return (void *)0x$(grep ' kallsyms_lookup_name$' /proc/kallsyms | cut -d' ' -f1 2>/dev/null || echo 'FFFFFF12345678');\n}\n#endif\n" >> KernelSU/kernel/ksu.c
fi

# 3. Ensure drivers directory exists
mkdir -p drivers/KernelSU 2>/dev/null

echo -e "${GREEN}[+] KernelSU-Next ${kernelsu_version} successfully configured!${NC}"
