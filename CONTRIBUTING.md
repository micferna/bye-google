# Contribuer à bye-google

Merci de ton intérêt ! Ce projet vise un homelab **simple, sécurisé et reproductible**.

## Mise en place

```bash
git clone https://github.com/micferna/bye-google && cd bye-google
pip install ansible ansible-lint yamllint pre-commit
ansible-galaxy collection install -r requirements.yml
pre-commit install            # lint automatique à chaque commit
```

## Avant d'ouvrir une PR

```bash
make lint    # yamllint + ansible-lint (profil "production") + validation Caddy
make scan    # gitleaks (secrets) + trivy (CVE images + misconfig IaC)
```

Tout doit passer au vert. La CI rejoue ces vérifications sur chaque PR.

## Règles

- **Jamais de secret** dans le dépôt. Les secrets vivent dans `group_vars/vault.yml`
  (git-ignoré, généré par `bootstrap.sh`). Utilise `vault.example.yml` comme modèle.
- **Sécurisé par défaut** : pas de port publié inutilement, conteneurs avec
  `no-new-privileges`/`cap_drop`, droits de fichiers restrictifs.
- Une fonctionnalité = idéalement un **rôle** (ou une **app** dans `apps/`) isolé et togglable
  via `group_vars/all.yml`.
- Messages de commit clairs (style [Conventional Commits](https://www.conventionalcommits.org/)
  apprécié : `feat:`, `fix:`, `docs:`…).
- Respecte les conventions existantes (FQCN des modules, noms de tâches explicites, idempotence).

## Ajouter une app (mini-PaaS)

Voir [`apps/README.md`](apps/README.md). En résumé : un dossier `apps/<nom>/` avec
`app.yml` + `docker-compose.yml`, puis `make apps`.

## Signaler une faille de sécurité

Ne crée pas d'issue publique : contacte le mainteneur en privé.
