#!/bin/bash

# Pobierz wersję ze zmiennej środowiskowej GitHub
version=${VERSION}

# Sprawdź czy wersja jest podana
if [ -z "$version" ]
then
    echo -e "\033[31mNie podano wersji. Konfiguracja i kompilacja nie zostaną wykonane. Wyjście...\033[0m"
    exit 1
fi

# Funkcja do dodawania sterowników z drivers.cfg
dodaj_sterowniki() {
    echo -e "\033[34m[KROK 1/3] Dodawanie sterowników z pliku konfiguracyjnego...\033[0m"
    
    # Sprawdź czy plik drivers.cfg istnieje
    if [ ! -f "../drivers.cfg" ]; then
        echo -e "\033[33mNie znaleziono pliku drivers.cfg, pomijam dodawanie sterowników.\033[0m"
        return 0
    fi
    
    # Sprawdź czy plik .config istnieje
    if [ ! -f "out/.config" ]; then
        echo -e "\033[31mBłąd: Nie znaleziono pliku konfiguracyjnego out/.config\033[0m"
        return 1
    fi
    
    # Dodaj każdy sterownik z listy
    while IFS= read -r sterownik || [ -n "$sterownik" ]; do
        # Pomijaj puste linie i komentarze
        if [[ -z "$sterownik" || "$sterownik" == \#* ]]; then
            continue
        fi
        
        echo -e "\033[32mDodaję: $sterownik\033[0m"
        konfig_klucz=$(echo "$sterownik" | cut -d'=' -f1)
        
        # Najpierw usuń istniejącą konfigurację (jeśli istnieje)
        ./scripts/config --file "out/.config" --undefine "$konfig_klucz" 2>/dev/null
        
        # Następnie dodaj nową konfigurację
        ./scripts/config --file "out/.config" --set-val "$konfig_klucz" "$(echo "$sterownik" | cut -d'=' -f2)"
    done < "../drivers.cfg"
    
    # Zaktualizuj konfigurację
    make O="out" ARCH="$ARCH" olddefconfig || {
        echo -e "\033[31mBłąd podczas aktualizacji konfiguracji ze sterownikami\033[0m"
        return 1
    }
    
    echo -e "\033[34m[SUKCES] Konfiguracja sterowników zaktualizowana pomyślnie.\033[0m"
}

# Konwertuj plik YAML do JSON
json=$(python -c "import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)" < sources.yaml)

# Sprawdź czy konwersja się udała
if [ -z "$json" ]
then
    echo -e "\033[31mBłąd: Nie udało się przekonwertować YAML do JSON. Wyjście...\033[0m"
    exit 1
fi

# Parsuj plik JSON
config_commands=$(echo $json | jq -r --arg version "$version" '.[$version].config[]')
build_commands=$(echo $json | jq -r --arg version "$version" '.[$version].build[]')

# Sprawdź czy komendy istnieją
if [ -z "$config_commands" ] || [ -z "$build_commands" ]
then
    echo -e "\033[31mBłąd: Nie udało się parsować JSON. Wyjście...\033[0m"
    exit 1
fi

# Wyświetl komendy które zostaną wykonane
echo -e "\033[35m\n[INFO] Skrypt wykona następujące komendy dla wersji ${version}:\033[0m"
echo "$config_commands" | while read -r command; do
    echo -e "\033[36m● $command\033[0m"
done
echo "$build_commands" | while read -r command; do
    echo -e "\033[36m● $command\033[0m"
done

# Wejdź do katalogu kernela
cd kernel || {
    echo -e "\033[31mBłąd: Nie można wejść do katalogu kernel. Wyjście...\033[0m"
    exit 1
}

# Wykonaj komendy konfiguracyjne
echo -e "\033[34m\n[KROK 2/3] Wykonywanie konfiguracji kernela...\033[0m"
echo "$config_commands" | while read -r command; do
    eval "$command" || {
        echo -e "\033[31mBłąd podczas wykonywania komendy: $command\033[0m"
        exit 1
    }
done

# Sprawdź czy plik .config został utworzony
if [ ! -f "out/.config" ]; then
    echo -e "\033[31mBłąd: Plik out/.config nie istnieje po wykonaniu komend konfiguracyjnych\033[0m"
    exit 1
fi

# Dodaj konfigurację sterowników
dodaj_sterowniki || exit 1

# Wykonaj komendy budowania
echo -e "\033[34m\n[KROK 3/3] Kompilacja kernela...\033[0m"
echo "$build_commands" | while read -r command; do
    eval "$command" || {
        echo -e "\033[31mBłąd podczas wykonywania komendy: $command\033[0m"
        exit 1
    }
done

echo -e "\033[32m\n[SUKCES] Kompilacja zakończona pomyślnie!\033[0m"
