# Hermes Agent Desktop (Electron) en conteneur → connecté à ton gateway existant

## Architecture (simplifiée)

Un seul conteneur, puisque ton gateway Hermes tourne déjà ailleurs :

```
navigateur ──(noVNC/HTTP :6080)──> [conteneur: Xvfb + vraie app Electron]
                                              │
                                              │ HERMES_DESKTOP_REMOTE_URL
                                              ▼
                                    [ton gateway Hermes existant]
```

C'est toujours la vraie app `apps/desktop` (pas le dashboard web), affichée
via noVNC. Elle est préconfigurée par variables d'environnement pour se
connecter directement à ton gateway, sans passer par l'écran "first-run" de
connexion.

Ces variables sont lues nativement par le code de l'app
(`apps/desktop/electron/main.ts`) :

- `HERMES_DESKTOP_REMOTE_URL` : bascule automatiquement l'app en mode remote
  et pointe vers cette URL, pour tous les profils.
- `HERMES_DESKTOP_REMOTE_TOKEN` : le jeton de session si ton gateway utilise
  l'auth par token (`X-Hermes-Session-Token`). Laisse-la vide si ton gateway
  utilise l'auth OAuth hébergée — l'app affichera alors l'écran de login
  habituel dans la fenêtre (visible via noVNC).

## Mise en place

1. Clone le monorepo à côté de ces fichiers :
   ```bash
   git clone https://github.com/NousResearch/hermes-agent.git
   ```
   Structure attendue :
   ```
   ./hermes-agent/              <- le monorepo cloné (sert de contexte de build)
   ./hermes-desktop-electron/   <- Dockerfile, docker/, ce README
   ./docker-compose.yml
   ```

2. Renseigne l'adresse de ton gateway (obligatoire — sans ça la variable
   passée au conteneur sera vide et l'app restera en mode local) :
   ```bash
   export HERMES_GATEWAY_URL="http://<host-ou-ip-de-ton-gateway>:<port>"
   export HERMES_GATEWAY_TOKEN="ton-token-si-auth-par-token"   # optionnel
   ```
   Si le gateway tourne sur ta machine hôte (hors Docker), utilise
   `http://host.docker.internal:<port>` sous Docker Desktop (Mac/Windows) ;
   sous Linux natif, ajoute `extra_hosts: ["host.docker.internal:host-gateway"]`
   au service `desktop` dans le `docker-compose.yml`, ou utilise directement
   l'IP de la machine hôte.

3. Lance :
   ```bash
   docker compose up --build
   ```

4. Ouvre `http://localhost:6080/vnc.html?autoconnect=true&resize=scale`.
   L'app devrait démarrer déjà connectée à ton gateway (mode remote global).

## Limites connues (honnêtes) — à vérifier/adapter

Cette app est **beaucoup** plus intégrée à l'OS qu'une Electron classique :
OAuth natif via fenêtres système, trousseau de clés (libsecret), terminal
intégré (node-pty, compilé nativement), détection WSL. Dans un conteneur
Linux sans session desktop réelle :

- **OAuth hébergé** (si ton gateway l'utilise) : le flux ouvre une fenêtre
  système captée par le navigateur par défaut — à tester via noVNC.
- **Trousseau de secrets (libsecret)** : sans GNOME Keyring/KWallet actif,
  le stockage de secrets peut tomber en fallback ; sans impact si tu passes
  déjà le token par variable d'env.
- **Mise à jour automatique** (`updater-process.ts`) : une image Docker se
  met à jour en rebuild, pas via l'auto-updater intégré — ignore/désactive
  cette fonctionnalité si elle se manifeste dans l'UI.

Je n'ai pas de démon Docker disponible dans cet environnement pour valider
un build de bout en bout — ce Dockerfile est construit à partir de la
lecture réelle du code source du repo (`package.json`, scripts de build,
les vraies variables d'env `HERMES_DESKTOP_REMOTE_*` dans `main.ts`), mais
attends-toi à ajuster un détail ou deux au premier `docker compose up --build`
(chemins de workspace manquants dans les `COPY` du Dockerfile, par exemple,
si l'app dépend d'un autre workspace que `apps/shared`). Colle-moi les
erreurs si ça bloque.