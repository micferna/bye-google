# Changelog

Toutes les évolutions notables de ce projet sont documentées ici.
Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

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
