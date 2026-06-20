#!/usr/bin/env bash
# Scan de sécurité : secrets committés + vulnérabilités des images de conteneurs.
set -euo pipefail
cd "$(dirname "$0")/.."

SEV="${SEV:-HIGH,CRITICAL}"
ENGINE="$(grep -oP '(?<=^container_engine: ")[^"]+' group_vars/all.yml 2>/dev/null || echo docker)"
run() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# ── 1) Secrets ──────────────────────────────────────────────────────────
run "Recherche de secrets (gitleaks)"
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks dir . --no-banner --redact -v || true
else
  echo "gitleaks non installé — contrôle minimal :"
  if find . -name vault.yml -not -name 'vault.example.yml' -path '*/group_vars/*' | grep -q .; then
    echo "  ⚠ group_vars/vault.yml présent : vérifie qu'il n'est PAS committé (cf .gitignore)."
  fi
  echo "  (installe gitleaks pour une analyse complète)"
fi

# ── 2) Misconfigurations IaC (Trivy) ────────────────────────────────────
run "Misconfigurations (trivy config)"
trivy config --quiet --severity "$SEV" . || true

# ── 3) Vulnérabilités des images ────────────────────────────────────────
run "Vulnérabilités des images de conteneurs (trivy image)"
imgs="$($ENGINE ps --format '{{.Image}}' 2>/dev/null | sort -u || true)"
if [[ -z "$imgs" ]]; then
  echo "Aucun conteneur en cours — scan de la liste par défaut."
  imgs="caddy:2.8 docker.io/authelia/authelia:4.38 nextcloud:30-apache
        postgres:16-alpine redis:7-alpine minio/minio:latest
        ghcr.io/gethomepage/homepage:latest vaultwarden/server:latest"
fi
for img in $imgs; do
  printf '\n\033[36m→ %s\033[0m\n' "$img"
  trivy image --quiet --severity "$SEV" --ignore-unfixed "$img" || true
done

printf '\n\033[32m✓ Scan terminé\033[0m (corrige en priorité CRITICAL/HIGH corrigeables)\n'
