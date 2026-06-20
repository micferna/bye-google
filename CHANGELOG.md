# Changelog

Toutes les évolutions notables de ce projet sont documentées ici.
Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [Non publié]

### Ajouté
- **Pré-seeding des sondes Uptime-Kuma** (best-effort, via `uptime-kuma-api` dans un venv) :
  crée automatiquement des moniteurs HTTP (Nextcloud, Immich, MinIO, Vaultwarden, Dashboard)
  au déploiement. Gated par `uptimekuma_seed` + `vault_uptimekuma_password` ; n'échoue jamais le déploiement.
- **Mode natif (sans conteneur) pour Caddy et MinIO** (`caddy_mode` / `minio_mode: native`) :
  Caddy installé via apt + systemd, MinIO en binaire + systemd. En Caddy natif, les backends
  conteneurisés sont publiés sur `127.0.0.1` (`native_ports`) ; les apps du mini-PaaS utilisent
  un `host_port`. Compatible avec les 4 combinaisons (Caddy/MinIO × conteneur/natif).
- **CrowdSec parse les logs d'accès Caddy** (collection `crowdsecurity/caddy`) : les attaques
  HTTP sont détectées puis bannies au niveau du pare-feu nftables, sans build Caddy custom.
  Caddy écrit un journal JSON dans `core/logs/access.log` (toggle `crowdsec_caddy_logs`).

### Corrigé
- CI : job sécurité (gitleaks `GITHUB_TOKEN` requis + `trivy-action` épinglé sur un tag valide).

## [0.1.0] - 2026-06-21

### Ajouté
- Déploiement **Ansible** complet d'un cloud maison auto-hébergé pour homelab.
- **Dé-Google** : Nextcloud (fichiers/agenda/contacts), Immich (photos).
- **Stockage objet S3** : MinIO.
- **Mini-PaaS** : déploie tes apps via `apps/<nom>/` (route Caddy + HTTPS auto).
  Apps fournies activées : **Vaultwarden** (mots de passe), **Uptime-Kuma** (supervision).
- **Reverse-proxy** Caddy (TLS auto : CA interne ou Let's Encrypt) + **SSO Authelia** +
  **dashboard Homepage**.
- **Moteur de conteneurs interchangeable** : `docker` ou `podman` (sans démon / rootless).
- **Réseau dual-stack IPv4/IPv6** (nftables + `ip6tables` + réseau `edge` ULA).
- **Sécurité de l'hôte** :
  - Pare-feu nftables **default-drop INPUT/OUTPUT/FORWARD** (egress filtré, dual-stack).
  - **fail2ban** + **CrowdSec** (agent + bouncer pare-feu nftables).
  - SSH durci, sysctl réseau, mises à jour de sécurité automatiques (reboot optionnel).
  - Conteneurs durcis (`no-new-privileges`, `cap_drop`), socket Docker non exposé (proxy RO).
- **Sauvegardes** restic chiffrées (timer systemd, dump PostgreSQL, rétention).
- **Outillage qualité/sécu** : `make lint` (yamllint + ansible-lint), `make scan`
  (gitleaks + Trivy), pre-commit, CI GitHub Actions.

[0.1.0]: https://github.com/micferna/bye-google/releases/tag/v0.1.0
