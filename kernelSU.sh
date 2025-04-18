#!/bin/bash

# Kolory dla logów
GREEN='\033[32m'
RED='\033[31m'
NC='\033[0m'

# Wersja KernelSU (1.0.3)
KERNELSU_VERSION="v1.0.3"

# Pobierz i zastosuj KernelSU
echo -e "${GREEN}[+] Applying KernelSU ${KERNELSU_VERSION}...${NC}"
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s "$KERNELSU_VERSION" || {
    echo -e "${RED}[-] Failed to apply KernelSU!${NC}"
    exit 1
}

# Ręczne poprawki dla kernela 4.14
cd kernel || exit 1

# 1. Wyłącz fsverity (jeśli powoduje błędy)
if [ -f "KernelSU/.config" ]; then
    sed -i 's/CONFIG_KSU_FSVERITY=y/CONFIG_KSU_FSVERITY=n/' KernelSU/.config
    echo -e "${GREEN}[+] Disabled CONFIG_KSU_FSVERITY${NC}"
fi

# 2. Napraw brakujące symbole (np. kallsyms_lookup_name)
if [ -f "KernelSU/kernel/ksu.c" ]; then
    if ! grep -q "kallsyms_lookup_name" KernelSU/kernel/ksu.c; then
        echo -e "${GREEN}[+] Patching kallsyms_lookup_name...${NC}"
        echo -e "\n#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 7, 0)\nvoid *kallsyms_lookup_name(const char *name) {\n    return (void *)0xFFFFFF12345678; // Replace with actual address from /proc/kallsyms\n}\n#endif" >> KernelSU/kernel/ksu.c
    fi
fi

echo -e "${GREEN}[+] KernelSU 1.0.3 patched for kernel 4.14!${NC}"
