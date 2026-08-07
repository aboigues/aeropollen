#!/usr/bin/env bash
#
# Génère les packages .iq prêts à soumettre au Connect IQ Store (un par application, un par
# appareil déclaré dans le manifeste bundlé dans le même fichier — équivalent CLI du "Export
# Project" de l'extension VS Code Monkey C). Contrairement à scripts/run-tests-wsl.sh, aucun
# Docker/Xvfb n'est nécessaire : c'est de la compilation pure, qui fonctionne nativement sur
# l'hôte (voir README.md § Compilation).
#
# Usage :
#   scripts/build-store-package.sh                          # toutes les applications
#   scripts/build-store-package.sh aeropollen-pollen-field   # une seule application
#   AEROPOLLEN_STORE_OUTPUT_DIR=/tmp/out scripts/build-store-package.sh
#
# Prérequis : SDK Connect IQ Linux installé sous ~/.Garmin/ConnectIQ/Sdks/, developer_key.der
# généré à la racine du dépôt (voir README.md § Prérequis). Pour publier réellement le résultat,
# voir https://apps.garmin.com/en-US/developer/upload (un compte Garmin Developer est requis) —
# ce script ne fait que produire le fichier .iq, il ne soumet rien.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${AEROPOLLEN_STORE_OUTPUT_DIR:-$REPO_ROOT/dist}"

# Noms de fichiers plus lisibles que les noms de dossiers ; simple filet de sécurité pour toute
# future application non listée ici (utilise alors le nom du dossier tel quel).
declare -A friendly_names=(
    [aeropollen-air-quality-field]="AeroPollenAir"
    [aeropollen-pollen-field]="AeroPollenPollens"
)

apps=("$@")
if [ ${#apps[@]} -eq 0 ]; then
    apps=(aeropollen-air-quality-field aeropollen-pollen-field)
fi

if [ ! -f "$REPO_ROOT/developer_key.der" ]; then
    echo "ERREUR : $REPO_ROOT/developer_key.der introuvable." >&2
    echo "Voir README.md § Prérequis pour générer une clé de signature locale." >&2
    exit 1
fi

sdk_dir=$(find "$HOME/.Garmin/ConnectIQ/Sdks" -maxdepth 1 -name 'connectiq-sdk-lin-*' 2>/dev/null | sort -V | tail -1)
if [ -z "$sdk_dir" ]; then
    echo "ERREUR : aucun SDK Connect IQ Linux trouvé sous ~/.Garmin/ConnectIQ/Sdks/." >&2
    echo "Voir TROUBLESHOOTING.md pour la procédure d'installation." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "SDK utilisé  : $(basename "$sdk_dir")"
echo "Applications : ${apps[*]}"
echo "Sortie       : $OUTPUT_DIR"
echo

overall_status=0
declare -a summary=()

for app in "${apps[@]}"; do
    jungle="$REPO_ROOT/$app/monkey.jungle"
    if [ ! -f "$jungle" ]; then
        echo "ERREUR : $jungle introuvable — application inconnue ?" >&2
        summary+=("$app : ÉCHEC (application introuvable)")
        overall_status=1
        continue
    fi

    name="${friendly_names[$app]:-$app}"
    output="$OUTPUT_DIR/$name.iq"

    echo "=== $app -> $(basename "$output") ==="
    if "$sdk_dir/bin/monkeyc" -e -f "$jungle" -o "$output" -y "$REPO_ROOT/developer_key.der" -w -r; then
        summary+=("$app : OK -> dist/$(basename "$output")")
    else
        summary+=("$app : ÉCHEC de la compilation")
        overall_status=1
    fi
    echo
done

echo "=============================================================================="
echo "RÉSUMÉ"
for line in "${summary[@]}"; do
    echo "$line"
done
echo "=============================================================================="

exit $overall_status
