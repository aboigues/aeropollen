# Image pour exécuter les tests Toybox.Test réels (monkeydo -t) sous Linux/WSL.
# Voir TROUBLESHOOTING.md §1, §6 et §9 pour le contexte de chaque dépendance.
#
# Le SDK Connect IQ et les fichiers d'appareil ne sont PAS embarqués dans l'image (montés au
# runtime depuis ~/.Garmin par scripts/run-tests-wsl.sh) : ce sont des ressources propriétaires
# Garmin, on ne les redistribue pas.
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    # libwebkit2gtk-4.0-37/libgtk-3-0/libsecret-1-0/libusb-1.0-0 : requis par le simulateur
    # (absents des dépôts Ubuntu 24.04, d'où l'usage d'ubuntu:20.04 — TROUBLESHOOTING.md §1)
    libwebkit2gtk-4.0-37 \
    libgtk-3-0 \
    libsecret-1-0 \
    libusb-1.0-0 \
    # openjdk-11-jre NON-headless : monkeyc rastérise les icônes SVG via Java AWT/Batik, le
    # paquet headless ne fournit pas libawt_xawt.so (TROUBLESHOOTING.md §6)
    openjdk-11-jre \
    # xvfb : framebuffer virtuel logiciel pour le simulateur, sans GPU (TROUBLESHOOTING.md §9)
    xvfb \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
