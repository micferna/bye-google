# Modèle de sécurité — bye-google

Philosophie : **fermé par défaut**, surface d'attaque minimale, tout reproductible.

## 1. Surface réseau

- **Une seule porte d'entrée** : Caddy (ports 80/443). Aucun autre service n'est publié
  sur l'hôte — bases de données, Authelia, MinIO, etc. vivent sur le réseau Docker privé `edge`.
- **Pare-feu nftables** (`roles/hardening`) : **`policy drop` par défaut en INPUT, OUTPUT _et_
  FORWARD** (egress filtré), **dual-stack IPv4/IPv6**. Seuls sont autorisés en sortie :
  DNS, NTP, HTTP/HTTPS (apt, pull d'images, ACME), DHCP, ICMP, et les bridges de conteneurs.
  SSH entrant uniquement depuis `ssh_allowed_cidrs` / `ssh_allowed_cidrs6`. Paquets jetés
  journalisés (rate-limité) avec le préfixe `byeg-drop-*`.
  - Table dédiée `inet byegoogle` : on ne touche jamais aux chaînes Docker (pas de `flush ruleset`).
  - **NAT (PREROUTING/POSTROUTING)** délibérément non filtré : ces hooks gèrent le SNAT/masquerade
    des conteneurs (moteur). Y mettre un DROP couperait tout le réseau des conteneurs.
  - Ports de sortie en plus : `firewall_extra_egress_tcp` / `firewall_extra_egress_udp`.
    Désactiver l'egress strict : `firewall_strict: false`.
- **CrowdSec** (`roles/crowdsec`) : détection comportementale (SSH/HTTP/scans) + bouncer pare-feu
  nftables qui bannit les IP malveillantes — en complément de **fail2ban**.
- **Moteur** : Docker (durci via `daemon.json`) **ou** Podman sans démon / rootless
  (`container_engine: podman`) pour réduire la surface d'attaque.
- **fail2ban** bannit les tentatives SSH en force brute.

> ⚠️ Si tu administres la machine à distance, ajoute ton IP/CIDR à `ssh_allowed_cidrs`
> dans `group_vars/all.yml` **avant** d'appliquer le durcissement, sous peine de te bloquer.

## 2. Authentification

- **Authelia** (SSO) protège le dashboard et toute app marquée `protect: true`.
  Mots de passe stockés en **argon2id**, limitation de débit (`regulation`) intégrée.
- Nextcloud / Immich / Vaultwarden gardent leur propre authentification forte (pas de double login).
- **Active la 2FA (TOTP)** dans Authelia après le premier login, et passe les règles sensibles
  en `two_factor` dans `roles/core/templates/authelia/configuration.yml.j2`.

## 3. Secrets

- Tous les secrets sont dans `group_vars/vault.yml` (généré aléatoirement, `chmod 600`, git-ignoré).
- Pour les chiffrer au repos : `ansible-vault encrypt group_vars/vault.yml`
  (puis lance avec `--ask-vault-pass`).
- **Sauvegarde ce fichier** hors-ligne : il contient le mot de passe restic et les clés Authelia.

## 4. Durcissement de l'hôte

- **SSH** : pas de login root par mot de passe, `MaxAuthTries 3`, X11/agent-forwarding off.
  Passe `ssh_disable_password: true` une fois ta clé en place (clé obligatoire).
- **sysctl** : anti-spoofing (`rp_filter`), pas de redirections ICMP, `kptr_restrict`, etc.
- **Docker** : `no-new-privileges`, `userland-proxy: false`, logs plafonnés, `live-restore`.
- **Conteneurs** : `cap_drop: ALL` + `no-new-privileges` là où c'est possible.
- **Mises à jour de sécurité automatiques** (`unattended-upgrades`).
- Le socket Docker n'est **jamais** exposé brut : Homepage passe par un proxy en lecture seule.

## 5. TLS

- Par défaut **CA interne Caddy** : rien n'est exposé sur Internet. Installe le certificat racine
  sur tes appareils pour éviter les avertissements :
  ```bash
  # récupère le root CA généré par Caddy
  docker compose -f /srv/byegoogle/core/docker-compose.yml cp \
    caddy:/data/caddy/pki/authorities/local/root.crt ./byegoogle-root.crt
  # puis importe byegoogle-root.crt dans le magasin de confiance de tes appareils
  ```
- Pour un vrai domaine public : `tls_internal: false` + `acme_email` → Let's Encrypt automatique.

## 6. Résolution des noms (`*.<domaine>`)

Les sous-domaines doivent pointer vers l'IP du serveur. Options :
- DNS local (Pi-hole / AdGuard / Unbound) : wildcard `*.home.lab → 192.168.x.x` ;
- ou `/etc/hosts` sur chaque appareil ;
- ou un domaine en `sslip.io` (ex. `cloud.192-168-1-10.sslip.io`) sans config DNS.

## 7. Sauvegardes

- `restic` chiffré, quotidien (timer systemd), rétention 7j/4s/6m, dump PostgreSQL inclus.
- **Teste la restauration** régulièrement : `restic -r /srv/byegoogle/backup/restic restore latest --target /tmp/test`.
- Pour le hors-site (règle 3-2-1), pointe restic vers ton MinIO ou un S3 distant (voir le script).

## Limites connues / pistes d'amélioration

- Brancher le **bouncer CrowdSec dans Caddy** (en plus du bouncer pare-feu) pour bloquer au niveau HTTP.
- Activer **Authelia 2FA obligatoire** sur les interfaces d'admin.
- Isoler davantage avec des conteneurs **rootless (Podman)** si ton modèle de menace l'exige.
- Brancher des **alertes** (Uptime-Kuma → notif) et l'envoi des sauvegardes **hors-site**.
