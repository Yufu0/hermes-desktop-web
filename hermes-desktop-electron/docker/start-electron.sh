#!/bin/bash
set -e

cd /repo/apps/desktop

# --no-sandbox : obligatoire en conteneur (le sandbox Chromium a besoin de
#   privilèges que Docker n'accorde pas par défaut)
# --disable-gpu : pas de GPU dans le conteneur
#
# Au premier lancement, l'app affichera son écran de configuration
# ("first-run"). C'est LÀ, dans la fenêtre visible via noVNC, qu'il faut
# choisir une connexion distante ("remote") et entrer l'adresse du gateway
# Hermes (le service `gateway` du docker-compose.yml), plutôt que de laisser
# l'app essayer de lancer/bootstrapper son propre backend Python local
# (ce qui ne fonctionnerait pas proprement dans ce conteneur).
exec npx electron . \
    --no-sandbox \
    --disable-gpu \
    --disable-software-rasterizer \
    --disable-dev-shm-usage
