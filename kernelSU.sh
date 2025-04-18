#!/bin/bash

# Kolory
GREEN='\033[32m'
RED='\033[31m'
NC='\033[0m'

# Wersja KernelSU (1.0.3)
KERNELSU_VERSION="v1.0.3"

# Przejdź do katalogu kernela (jeśli nie istnieje, utwórz)
cd kernel || { mkdir -p kernel && cd kernel; }

# Pobierz KernelSU (z ręcznym sprawdzeniem struktury)
echo -e "${GREEN}[+] Applying KernelSU ${KERNELSU_VERSION}...${NC}"
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s "$KERNELSU_VERSION" || {
    # Ręczna naprawa brakującego katalogu drivers/
    if [ ! -d "drivers" ]; then
        echo -e "${YELLOW}[!] Creating missing 'drivers/' directory...${NC}"
        mkdir -p drivers
        curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s "$KERNELSU_VERSION"
    fi
}

# Kontynuuj tylko jeśli KernelSU został zastosowany
if [ -d "KernelSU" ]; then
    echo -e "${GREEN}[+] KernelSU applied successfully!${NC}"
else
    echo -e "${RED}[-] Failed to apply KernelSU!${NC}"
    exit 1
fi
