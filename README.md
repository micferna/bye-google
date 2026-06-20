# bye-google 👋☁️

Ton **cloud maison** auto-hébergé pour homelab — une alternative *simple, sécurisée et performante*
à Google Cloud / Google Drive / Google Photos / Amazon S3, déployée en une commande avec **Ansible**.

> Objectif : reprendre le contrôle de tes données sans sacrifier le confort. Tout tourne chez toi,
> rien n'est exposé par défaut, tout est reproductible (Infrastructure as Code).

---

## Ce que ça remplace

| Service Google / AWS            | Brique auto-hébergée          | Sous-domaine            |
|---------------------------------|-------------------------------|-------------------------|
| Google Drive / Docs / Agenda    | **Nextcloud**                 | `cloud.<domaine>`       |
| Google Photos                   | **Immich**                    | `photos.<domaine>`      |
| Amazon S3 / Google Cloud Storage| **MinIO** (compatible S3)     | `s3.` / `minio.<domaine>`|
| Déploiement d'apps (PaaS)       | **mini-PaaS** (`apps/`)       | `<app>.<domaine>`       |
| Google Password Manager         | **Vaultwarden** (activé)      | `vault.<domaine>`       |
| Supervision / statut            | **Uptime-Kuma** (activé)      | `uptime.<domaine>`      |
| Console / portail               | **Homepage** (dashboard) + **Authelia** (SSO) | `home.` / `auth.<domaine>` |

Toutes les briques sont **optionnelles** (active/désactive dans `group_vars/all.yml`).

---

## Architecture

```
                Internet / LAN
                      │
                ┌─────▼─────┐   TLS auto (CA interne ou Let's Encrypt)
                │   Caddy   │   reverse-proxy + HTTPS
                └─────┬─────┘
          ┌───────────┼─────────────┬───────────┬──────────┐
     ┌────▼────┐ ┌────▼────┐  ┌─────▼────┐ ┌─────▼────┐ ┌───▼────┐
     │ Authelia│ │Homepage │  │Nextcloud │ │  Immich  │ │ MinIO  │
     │  (SSO)  │ │(dashbrd)│  │ +PG+Redis│ │+PG+Redis │ │  (S3)  │
     └─────────┘ └─────────┘  └──────────┘ └──────────┘ └────────┘
            réseau docker « edge » (privé) — rien n'est publié sauf 80/443
```

- **Caddy** est la seule porte d'entrée (ports 80/443). Tout le reste vit sur un réseau Docker privé.
- **Authelia** fournit le SSO et protège les interfaces d'admin (dashboard, etc.).
- L'hôte est durci : firewall **nftables en _default-drop_ INPUT/OUTPUT/FORWARD**, **SSH** clé-only,
  **fail2ban** + **CrowdSec**, **sysctl** réseau, mises à jour de sécurité automatiques.

---

## Démarrage rapide

Pré-requis : une machine **Debian/Ubuntu** avec `ansible`, `openssl`, et un **moteur de
conteneurs** — `docker` **ou** `podman` (voir [Sans Docker](#sans-docker--podman)).
(Le script `bootstrap.sh` vérifie tout et te le dira.)

```bash
git clone <ce-repo> bye-google && cd bye-google

# 1) Édite ta config (au minimum : le domaine)
$EDITOR group_vars/all.yml

# 2) Lance l'installeur : il génère tous les secrets et déploie tout
./bootstrap.sh
```

C'est tout. Le script :
1. génère un fichier de secrets (`group_vars/vault.yml`) avec des mots de passe aléatoires ;
2. te demande le mot de passe admin du SSO et en calcule le hash argon2 ;
3. lance `ansible-playbook site.yml`.

### Accès

- Dashboard : `https://home.<domaine>`
- Photos : `https://photos.<domaine>` · Fichiers : `https://cloud.<domaine>` · S3 : `https://minio.<domaine>`

> **TLS interne (défaut)** : Caddy crée sa propre autorité de certification. Installe le certificat
> racine sur tes appareils (voir `docs/SECURITY.md`) ou passe à Let's Encrypt (`tls_internal: false`).

---

## Commandes utiles (Makefile)

```bash
make deploy            # tout déployer
make core              # juste reverse-proxy + SSO + dashboard
make nextcloud         # (re)déployer une brique précise
make status            # état des conteneurs
make backup            # lancer une sauvegarde restic maintenant
make logs S=core       # suivre les logs d'une stack
make down              # tout arrêter
```

---

## Déployer tes propres apps (mini-PaaS)

Dépose un dossier dans `apps/<nom>/` avec un `docker-compose.yml` et un `app.yml` :

```yaml
# apps/monapp/app.yml
name: monapp
subdomain: monapp     # => https://monapp.<domaine>
port: 8080            # port interne du conteneur
protect: true         # true = derrière le SSO Authelia
```

Puis `make apps`. Caddy crée la route + HTTPS automatiquement. Un exemple complet (Vaultwarden)
est fourni dans `apps/vaultwarden/`.

---

## Structure

```
bye-google/
├── bootstrap.sh          # installeur "facile" (génère secrets + déploie)
├── site.yml              # playbook principal
├── group_vars/
│   ├── all.yml           # ⚙️  toute la config (domaine, toggles, versions)
│   └── vault.example.yml # modèle de secrets (le vrai vault.yml est généré)
├── roles/
│   ├── common/  hardening/  engine/        # socle + sécurité + moteur (docker|podman)
│   ├── core/                               # Caddy + Authelia + Homepage
│   ├── nextcloud/  immich/  minio/         # les services
│   ├── apps/                               # mini-PaaS
│   └── backup/                             # sauvegardes restic
├── apps/                 # tes apps perso (exemple : vaultwarden)
├── scripts/              # lint.sh, scan.sh
├── .github/workflows/    # CI (lint + scan sécurité)
└── docs/SECURITY.md      # modèle de menace + durcissement
```

## Sans Docker ? → Podman

Tu ne veux pas du démon Docker ? Mets dans `group_vars/all.yml` :

```yaml
container_engine: podman   # au lieu de "docker"
```

Tout le reste est identique (`./bootstrap.sh`). Podman tourne **sans démon central** et
peut fonctionner en **rootless**. Le projet bascule automatiquement `docker compose` →
`podman compose`, la socket et le proxy de socket.

> ⚠️ Réalité technique : un déploiement **100 % sans conteneur** n'est pas réaliste pour
> cette pile — **Immich** n'est distribué qu'en conteneur par l'éditeur, et Nextcloud + ses
> dépendances en natif deviennent ingérables. Podman répond au besoin « pas de Docker » sans
> ce coût de maintenance. Caddy et MinIO étant de simples binaires, une option d'install
> **native** pour ceux-là peut être ajoutée — demande si tu la veux.

## Réseau : IPv4 **et** IPv6 (dual-stack)

La pile est **dual-stack** par défaut (`enable_ipv6: true`) :
- pare-feu nftables avec règles IPv4 **et** IPv6 (ICMPv6/NDP autorisés, SSH filtré par
  `ssh_allowed_cidrs` + `ssh_allowed_cidrs6`) ;
- Docker/Podman avec `ip6tables` et réseau `edge` en IPv6 (ULA `fd00:b9e6::/64`).

Pour de l'IPv4 pur : `enable_ipv6: false`.

## Qualité & sécurité (outillage)

Bonnes pratiques intégrées, exécutables en local et en CI :

```bash
make lint   # yamllint + ansible-lint (profil "production") + validation du Caddyfile
make scan   # gitleaks (secrets) + trivy (misconfig IaC + CVE des images)
```

- **`.pre-commit-config.yaml`** : `pre-commit install` pour linter à chaque commit
  (yamllint, ansible-lint, gitleaks, shellcheck, clé privée).
- **`.github/workflows/ci.yml`** : lint + scan secrets/IaC à chaque push/PR.

Voir **[docs/SECURITY.md](docs/SECURITY.md)** pour le modèle de sécurité détaillé.
