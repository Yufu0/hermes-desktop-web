# Déploiement de Hermes Desktop en conteneur (hermes-desktop-web)

Guide complet, dans l'ordre, pour déployer la vraie app desktop Electron de
Hermes Agent en conteneur Docker avec accès web (noVNC), connectée à un
gateway Hermes déjà existant.

## 0. Prérequis

- Docker + Docker Compose installés.
- L'URL et, si besoin, le token de session de ton gateway Hermes existant
  et joignable (déjà démarré, pas géré par ce projet).

## 1. Cloner ton repo

```bash
git clone https://github.com/Yufu0/hermes-desktop-web.git
cd hermes-desktop-web
```

Tu dois avoir :
```
hermes-desktop-web/
├── docker-compose.yml
├── README.md
└── hermes-desktop-electron/
    ├── Dockerfile
    └── docker/
        ├── start-electron.sh
        └── supervisord.conf
```

## 2. Cloner le monorepo source de l'app, À CÔTÉ (au même niveau)

Le `docker-compose.yml` utilise la racine du repo comme contexte de build et
s'attend à trouver le code source ici :

```bash
git clone https://github.com/NousResearch/hermes-agent.git
```

Structure finale attendue (les deux dossiers au même niveau) :
```
hermes-desktop-web/
├── docker-compose.yml
├── hermes-desktop-electron/
│   ├── Dockerfile
│   └── docker/...
└── hermes-agent/          <- vient d'être cloné
    ├── package.json
    ├── apps/desktop/
    └── ...
```

## 3. Appliquer le correctif noVNC (version épinglée)

Une version `main` de noVNC a provoqué une erreur JS (`Cannot read
properties of null (reading 'addEventListener')`) due à un décalage de
cache. Ouvre `hermes-desktop-electron/Dockerfile` et remplace la ligne :

```dockerfile
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/noVNC \
    && git clone --depth 1 https://github.com/novnc/websockify /opt/noVNC/utils/websockify
```

par :

```dockerfile
RUN git clone --depth 1 --branch v1.5.0 https://github.com/novnc/noVNC.git /opt/noVNC \
    && git clone --depth 1 --branch v0.12.0 https://github.com/novnc/websockify /opt/noVNC/utils/websockify
```

(Commite ce changement dans ton repo pour ne pas avoir à le refaire.)

## 4. Rendre le script de lancement exécutable

```bash
chmod +x hermes-desktop-electron/docker/start-electron.sh
```

## 5. Définir la connexion au gateway existant

**Le point le plus fréquent d'échec : l'URL doit avoir un schéma explicite
`http://` ou `https://`.** `192.168.1.50:9119` seul est rejeté par l'app
(`Remote gateway URL is not valid`) ; il faut `http://192.168.1.50:9119`.

```bash
export HERMES_GATEWAY_URL="http://<host-ou-ip-de-ton-gateway>:<port>"
# Optionnel — uniquement si ton gateway utilise l'auth par token
# (laisse vide s'il utilise l'auth OAuth hébergée) :
export HERMES_GATEWAY_TOKEN="<ton-token>"
```

## 6. Build et lancement

```bash
docker compose up --build
```

Le build fait, dans l'ordre : installation Node (`npm ci` sur le monorepo),
build de l'app desktop (`vite build` + bundle Electron + staging de
node-pty), puis l'image finale installe Xvfb/noVNC/fluxbox/supervisor et
copie le build. Ça prend plusieurs minutes la première fois.

Un volume Docker nommé `hermes-desktop-data` est monté sur
`/data/hermes-desktop` et branché sur `HERMES_DESKTOP_USER_DATA_DIR` — tout
le dossier userData d'Electron (config de connexion, cookies/session OAuth,
local storage, préférences fenêtre) y est stocké et survit à un
`docker compose down` / rebuild / redémarrage machine. Pour repartir de
zéro : `docker volume rm hermes-desktop-web_hermes-desktop-data` (le nom
exact du volume dépend du nom du dossier projet ; `docker volume ls` pour
vérifier).

## 7. Ouvrir l'interface

Pour la meilleure qualité visuelle, utilise ces paramètres dans l'URL
(qualité JPEG maximale, pas de compression zlib superflue en local) :

```
http://localhost:6080/vnc.html?autoconnect=true&quality=9&compression=0&resize=scale
```

- `quality=9` : qualité JPEG maximale de l'encodage Tight (0 = très
  compressé/flou, 9 = quasi sans perte).
- `compression=0` : pas de compression zlib supplémentaire — inutile en
  local, ça ne fait que consommer du CPU pour rien.
- `resize=scale` : redimensionne l'écran virtuel (1920×1080 par défaut
  maintenant) pour tenir dans ta fenêtre de navigateur. Si ton écran est
  assez grand, tu peux mettre `resize=off` à la place pour un rendu pixel
  pour pixel sans aucun lissage de redimensionnement (plus net, mais avec
  scrollbars si ta fenêtre est plus petite que 1920×1080).

Si tu obtiens une erreur JS noVNC (`addEventListener` sur `null`) malgré le
correctif de l'étape 3 : fais un rechargement forcé (`Ctrl+Shift+R`) ou
ouvre un onglet de navigation privée — c'est un souci de cache navigateur,
pas serveur.

## 8. Vérifier que la connexion au gateway est bien passée

Dans un autre terminal, pendant que le conteneur tourne :

```bash
docker exec hermes-desktop env | grep HERMES_DESKTOP_REMOTE
```

Tu dois voir :
```
HERMES_DESKTOP_REMOTE_URL=http://<ton-host>:<port>
HERMES_DESKTOP_REMOTE_TOKEN=<vide ou ton token>
```

Si `HERMES_DESKTOP_REMOTE_URL` est vide ici, la variable n'a pas été
exportée avant le `docker compose up` (retourne à l'étape 5, puis relance
`docker compose up --build` — pas besoin de tout rebuild, Compose recréera
juste le conteneur avec le nouvel environnement).

## 9. Lire les logs si quelque chose cloche

```bash
docker compose logs -f desktop
```

Erreurs à ignorer (inoffensives, attendues en conteneur sans session
desktop complète) :
- `Failed to connect to the bus` (dbus)
- `Failed to read: session.screen0.titlebar.*` (fluxbox, thème par défaut)
- `install-stamp.json ... ENOENT` (vérif auto-updater, non pertinente ici)
- `404 ... /api/audio/voice-live/status` (probe de fonctionnalité optionnelle
  que ton gateway n'expose pas forcément)

Erreur à traiter : `Remote gateway URL is not valid: Invalid URL` → revoir
l'étape 5 (schéma `http://`/`https://` manquant, ou variable non exportée).

## Limites connues de ce setup

- OAuth natif, trousseau de secrets (libsecret), et mise à jour automatique
  de l'app ne sont pas garantis de fonctionner à l'identique d'un vrai
  poste de bureau — voir le `README.md` du repo pour le détail.
- Ce n'est pas le dashboard web officiel de Hermes (`hermes dashboard`) :
  c'est la vraie app Electron, capturée en VNC. Plus riche, mais plus lourd
  et plus fragile en environnement conteneurisé sans session desktop réelle.