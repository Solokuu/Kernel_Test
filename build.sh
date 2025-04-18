#!/bin/bash

# Kolory
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'

# Sprawdź wersję
if [ -z "$VERSION" ]; then
    echo -e "${RED}[-] VERSION not set! Exiting...${NC}"
    exit 1
fi

# Konwertuj YAML → JSON
json=$(python3 -c "import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin)))" < sources.yaml 2>/dev/null)
if [ -z "$json" ]; then
    echo -e "${RED}[-] Failed to parse YAML!${NC}"
    exit 1
fi

# Pobierz komendy buildowe i zmodyfikuj dla 4.14
build_commands=$(echo "$json" | jq -r --arg version "$VERSION" '.[$version].build[]' | \
    sed 's/LLVM=1/LLVM=0/g' | \
    sed 's/LD=ld.lld/LD=bfd/g')

# Kompilacja
cd kernel || exit 1
echo -e "${GREEN}[+] Building kernel with KernelSU 1.0.3...${NC}"
eval "$build_commands" || {
    echo -e "${RED}[-] Build failed! Check logs.${NC}"
    exit 1
}

echo -e "${GREEN}[+] Kernel compiled successfully!${NC}"
