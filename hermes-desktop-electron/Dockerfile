# Conteneur pour la VRAIE app desktop Electron de Hermes Agent
# (apps/desktop dans le monorepo NousResearch/hermes-agent), exposée via
# noVNC. Se connecte à un gateway Hermes distant (voir docker-compose.yml)
# plutôt que d'essayer de lancer son propre backend Python en interne.
#
# IMPORTANT : le contexte de build est la racine "files/" (celle qui
# contient à la fois hermes-agent/ et hermes-desktop-electron/), pas
# hermes-agent/ tout seul — d'où les chemins "hermes-agent/..." et
# "hermes-desktop-electron/..." ci-dessous. Voir docker-compose.yml.
#
# Node/Electron versions alignées sur apps/desktop/package.json:
#   node:  ^22.22.0 || ^24.11.0 || >=26.0.0
#   electron: 40.10.2

FROM node:24-bookworm-slim AS builder

# build-essential + python3 : requis par node-gyp pour compiler node-pty
# (terminal intégré du desktop), staged ensuite par stage-native-deps.mjs
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential python3 git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /repo

# Le lockfile racine décrit TOUT le monorepo (root + web + ui-tui + apps/*),
# donc on installe depuis la racine, pas depuis apps/desktop isolément —
# c'est ce que assert-root-install.mjs vérifie avant chaque build.
COPY hermes-agent/package.json hermes-agent/package-lock.json ./
COPY hermes-agent/apps/desktop/package.json apps/desktop/package.json
COPY hermes-agent/apps/shared/package.json apps/shared/package.json
# Adapte/complète ces COPY si d'autres workspaces (web, ui-tui, tests-js)
# sont nécessaires pour que `npm ci` résolve correctement.
RUN npm ci

COPY hermes-agent/apps/desktop apps/desktop
COPY hermes-agent/apps/shared apps/shared

# vite build + bundle-electron-main + stage-native-deps (node-pty)
RUN npm run build --workspace apps/desktop


# ---------- Image d'exécution ----------
FROM node:24-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb x11vnc fluxbox supervisor git wget ca-certificates python3 \
    libnss3 libatk-bridge2.0-0 libatk1.0-0 libgtk-3-0 libgbm1 \
    libasound2 libxss1 libxtst6 libx11-xcb1 libdrm2 libsecret-1-0 \
    xdg-utils \
    fonts-liberation fonts-noto-color-emoji fonts-dejavu-core fontconfig \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch v1.5.0 https://github.com/novnc/noVNC.git /opt/noVNC \
    && git clone --depth 1 --branch v0.12.0 https://github.com/novnc/websockify /opt/noVNC/utils/websockify

WORKDIR /repo
COPY --from=builder /repo /repo

ENV DISPLAY=:99
ENV WIDTH=1920
ENV HEIGHT=1080
ENV NOVNC_PORT=6080

COPY hermes-desktop-electron/docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY hermes-desktop-electron/docker/start-electron.sh /repo/docker/start-electron.sh
RUN chmod +x /repo/docker/start-electron.sh

EXPOSE 6080
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]