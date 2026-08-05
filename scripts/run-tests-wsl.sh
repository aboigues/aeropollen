#!/usr/bin/env bash
#
# Exécute les tests d'intégration Toybox.Test réels (monkeydo -t) sous Linux/WSL, via Docker +
# Xvfb (framebuffer virtuel logiciel, sans GPU). Voir TROUBLESHOOTING.md §9 pour le contexte :
# le display réel WSLg (DISPLAY=:0) nécessite une accélération GPU absente de cet environnement,
# Xvfb n'en a pas besoin.
#
# Usage :
#   scripts/run-tests-wsl.sh [app1 [app2 ...]]
#   scripts/run-tests-wsl.sh                         # toutes les applications par défaut
#   AEROPOLLEN_TEST_DEVICE=fenix7 scripts/run-tests-wsl.sh aeropollen-pollen-field
#
# Prérequis : Docker fonctionnel, SDK Connect IQ Linux installé sous
# ~/.Garmin/ConnectIQ/Sdks/, appareil de test installé sous ~/.Garmin/ConnectIQ/Devices/,
# developer_key.der généré à la racine du dépôt (voir README.md § Prérequis).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${AEROPOLLEN_TEST_DEVICE:-edge530}"
IMAGE_TAG="aeropollen-test-runner"
CONTAINER_NAME="aeropollen-test-runner-$$"

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
sdk_name=$(basename "$sdk_dir")
sdk_path_in_container="/root/.Garmin/ConnectIQ/Sdks/$sdk_name"

if [ ! -d "$HOME/.Garmin/ConnectIQ/Devices/$DEVICE" ]; then
    echo "ERREUR : appareil '$DEVICE' introuvable sous ~/.Garmin/ConnectIQ/Devices/." >&2
    exit 1
fi

echo "SDK utilisé  : $sdk_name"
echo "Appareil     : $DEVICE"
echo "Applications : ${apps[*]}"
echo

echo "Construction de l'image Docker (mise en cache après le premier run)..."
docker build -q -t "$IMAGE_TAG" -f "$REPO_ROOT/docker/test-runner.Dockerfile" "$REPO_ROOT/docker" >/dev/null

cleanup() {
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Ni /workspace ni ~/.Garmin ne peuvent être montés en lecture seule : monkeyc écrit un
# default.jungle dans le dossier du projet même quand -f est fourni, et génère aussi un
# bin/default.jungle dans le dossier du SDK à sa toute première utilisation s'il est absent
# (présent seulement une fois qu'un premier run l'a déjà généré, ce qui n'est jamais le cas
# pour un SDK fraîchement téléchargé, comme en CI).
docker run -d --name "$CONTAINER_NAME" \
    -v "$HOME/.Garmin:/root/.Garmin" \
    -v "$REPO_ROOT:/workspace" \
    "$IMAGE_TAG" sleep infinity >/dev/null

overall_status=0
declare -a summary=()
display_counter=99

for app in "${apps[@]}"; do
    echo "=== $app ==="

    if ! docker exec -w "/workspace/$app" "$CONTAINER_NAME" bash -c "
        export PATH=\"$sdk_path_in_container/bin:\$PATH\"
        mkdir -p /tmp/build/$app
        monkeyc -f monkey.jungle -d $DEVICE -o /tmp/build/$app/app.prg -y /workspace/developer_key.der -t -l 3 -w
    "; then
        echo "$app : COMPILATION ÉCHOUÉE"
        summary+=("$app : COMPILATION ÉCHOUÉE")
        overall_status=1
        echo
        continue
    fi

    # Xvfb + simulateur relancés à neuf pour chaque tentative, sur un numéro de display jamais
    # réutilisé (display_counter incrémenté à chaque essai, y compris entre applications) — évite
    # toute collision avec un socket/verrou X11 périmé.
    #
    # ATTENTION (régression déjà commise une fois, cf. TROUBLESHOOTING.md §10) : le binaire
    # `simulator` écoute TOUJOURS sur le même port TCP fixe (1234), quel que soit le DISPLAY sur
    # lequel il rend l'écran. Changer de display ne suffit donc PAS : le simulateur de la
    # tentative précédente (ou de l'application précédente) doit être explicitement tué avant
    # d'en lancer un nouveau, sinon le suivant ne peut jamais se lier au port 1234 — il démarre
    # et log normalement ("Debug: SetLayout") mais son port n'est jamais joignable, sans aucune
    # erreur explicite.
    max_attempts=3
    attempt=1
    last_line=""
    got_result=false

    while [ "$attempt" -le "$max_attempts" ]; do
        display_counter=$((display_counter + 1))
        display=":$display_counter"
        if [ "$attempt" -gt 1 ]; then
            echo "--- tentative $attempt/$max_attempts (display $display) ---"
        fi

        # Tue tout simulateur/Xvfb précédent (port 1234 fixe, cf. avertissement ci-dessus) avant
        # d'en relancer un nouveau, et attend que le port soit effectivement libéré.
        #
        # Deux pièges cumulés ici (cf. TROUBLESHOOTING.md §10) :
        # 1. `pkill -f bin/simulator` ne correspond JAMAIS au process réel : invoqué via
        #    résolution de PATH, son argv[0]/cmdline est simplement "simulator", sans aucun
        #    chemin — confirmé via /proc/<pid>/cmdline. `pkill -f` ne l'a donc jamais tué, quel
        #    que soit le nombre de fois où cette ligne s'exécutait. `-x` (correspondance exacte
        #    sur le nom du process, pas sur la ligne de commande) fonctionne.
        # 2. Même une fois correctement tué, le simulateur laisse un fichier verrou mono-instance
        #    (/root/Sim-root) qui n'est nettoyé que lors d'un arrêt propre — jamais après un
        #    signal. Sans le supprimer explicitement, toute nouvelle instance de `simulator`
        #    refuse de démarrer, silencieusement (aucune ligne de log, aucune erreur).
        docker exec "$CONTAINER_NAME" bash -c "pkill -9 -x simulator; pkill -9 -x Xvfb; rm -f /root/Sim-root; exit 0" >/dev/null 2>&1
        docker exec "$CONTAINER_NAME" bash -c '
            for i in $(seq 1 20); do
                (exec 3<>/dev/tcp/127.0.0.1/1234) 2>/dev/null || exit 0
                exec 3<&- 3>&- 2>/dev/null
                sleep 0.5
            done
            exit 1
        ' || echo "Port 1234 toujours occupé après arrêt du simulateur précédent (inattendu)"

        docker exec -d "$CONTAINER_NAME" bash -c "Xvfb $display -screen 0 1280x1024x24 >/tmp/xvfb-$display_counter.log 2>&1"

        if ! docker exec "$CONTAINER_NAME" bash -c "
            for i in \$(seq 1 30); do
                [ -S /tmp/.X11-unix/X$display_counter ] && exit 0
                sleep 0.5
            done
            exit 1
        "; then
            echo "Xvfb non prêt après 15s"
            attempt=$((attempt + 1))
            continue
        fi

        docker exec -d "$CONTAINER_NAME" bash -c "
            export PATH=\"$sdk_path_in_container/bin:\$PATH\"
            export DISPLAY=$display
            simulator >/tmp/simulator-$display_counter.log 2>&1
        "

        if ! docker exec "$CONTAINER_NAME" bash -c '
            for i in $(seq 1 40); do
                if (exec 3<>/dev/tcp/127.0.0.1/1234) 2>/dev/null; then
                    exec 3<&- 3>&-
                    exit 0
                fi
                sleep 0.5
            done
            exit 1
        '; then
            echo "Simulateur non joignable sur 127.0.0.1:1234 après 20s"
            docker exec "$CONTAINER_NAME" bash -c "
                echo '--- ps aux (simulator/Xvfb) ---'
                ps aux | grep -E 'simulator|Xvfb' | grep -v grep
                echo '--- /root/Sim-root (verrou mono-instance) ---'
                ls -la /root/Sim-root 2>&1
                echo '--- xvfb-$display_counter.log ---'
                cat /tmp/xvfb-$display_counter.log
                echo '--- simulator-$display_counter.log ---'
                cat /tmp/simulator-$display_counter.log
            " || true
            attempt=$((attempt + 1))
            continue
        fi

        log_file="/tmp/aeropollen-test-$app.log"
        # monkeydo retourne toujours le code de sortie 1, même quand tous les tests passent — le
        # résultat réel s'obtient en lisant la dernière ligne de la sortie standard
        # (PASSED/FAILED), pas via son code de sortie.
        docker exec "$CONTAINER_NAME" bash -c "
            export PATH=\"$sdk_path_in_container/bin:\$PATH\"
            export DISPLAY=$display
            monkeydo /tmp/build/$app/app.prg $DEVICE -t
        " | tee "$log_file"

        last_line=$(tail -1 "$log_file")
        if [[ "$last_line" == PASSED* || "$last_line" == FAILED* ]]; then
            got_result=true
            break
        fi

        # Sortie vide ou inattendue de monkeydo lui-même (distinct du cas "simulateur non
        # joignable" ci-dessus, déjà diagnostiqué) : le simulateur était joignable au moment du
        # check, mais quelque chose s'est mal passé pendant l'exécution des tests.
        echo "monkeydo n'a produit aucun résultat PASSED/FAILED exploitable"
        echo "--- contenu de $log_file ($(wc -l < "$log_file") lignes) ---"
        cat "$log_file"
        docker exec "$CONTAINER_NAME" bash -c '
            echo "--- ps aux (simulator/Xvfb) au moment de cet echec ---"
            ps aux | grep -E "simulator|Xvfb" | grep -v grep
        ' || true
        attempt=$((attempt + 1))
    done

    if [ "$got_result" = true ] && [[ "$last_line" == PASSED* ]]; then
        summary+=("$app : $last_line")
    elif [ "$got_result" = true ]; then
        summary+=("$app : $last_line")
        overall_status=1
    else
        summary+=("$app : ÉCHEC après $max_attempts tentatives (simulateur instable, voir TROUBLESHOOTING.md §10)")
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
