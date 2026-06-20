#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
#  bye-google — installeur "facile"
#  Génère les secrets puis déploie toute la plateforme via Ansible.
# ════════════════════════════════════════════════════════════════════════
set -euo pipefail
cd "$(dirname "$0")"

VAULT="group_vars/vault.yml"
AUTHELIA_IMG="docker.io/authelia/authelia:4.38"
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
die()  { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# Moteur de conteneurs choisi dans group_vars/all.yml (docker | podman)
ENGINE="$(grep -oP '(?<=^container_engine: ")[^"]+' group_vars/all.yml 2>/dev/null || echo docker)"

bold "==> Vérification des pré-requis (moteur : $ENGINE)"
for bin in ansible-playbook "$ENGINE" openssl; do
  command -v "$bin" >/dev/null 2>&1 || die "'$bin' est introuvable. Installe-le puis relance."
done
$ENGINE compose version >/dev/null 2>&1 || die "'$ENGINE compose' est requis."
ok "ansible, $ENGINE, $ENGINE compose, openssl présents"

bold "==> Collections Ansible requises"
ansible-galaxy collection install -r requirements.yml >/dev/null
ok "community.general + ansible.posix"

# ── Génération des secrets ──────────────────────────────────────────────
if [[ -f "$VAULT" ]]; then
  bold "==> $VAULT existe déjà — secrets conservés."
else
  bold "==> Génération des secrets dans $VAULT"
  read -rp "Mot de passe ADMIN du SSO (compte '$(grep -oP '(?<=^admin_user: ").*(?=")' group_vars/all.yml || echo admin)') : " -s ADMIN_PW; echo
  [[ -n "${ADMIN_PW:-}" ]] || die "Mot de passe vide."

  echo "    Calcul du hash argon2id (via $AUTHELIA_IMG)…"
  HASH="$($ENGINE run --rm "$AUTHELIA_IMG" \
            authelia crypto hash generate argon2 --password "$ADMIN_PW" \
          | sed -n 's/^Digest: //p')"
  [[ "$HASH" == \$argon2id\$* ]] || die "Échec du calcul du hash argon2."

  rnd() { openssl rand -hex 32; }
  pw()  { openssl rand -base64 30 | tr -d '/+=' | cut -c1-32; }

  umask 077
  cat > "$VAULT" <<EOF
---
# Généré par bootstrap.sh — NE PAS committer.
vault_nextcloud_db_password: "$(pw)"
vault_nextcloud_admin_password: "$(pw)"
vault_immich_db_password: "$(pw)"
vault_minio_root_password: "$(pw)"
vault_authelia_jwt_secret: "$(rnd)"
vault_authelia_session_secret: "$(rnd)"
vault_authelia_storage_key: "$(rnd)"
vault_authelia_admin_password_hash: '$HASH'
vault_restic_password: "$(pw)"
EOF
  ok "Secrets générés (chmod 600). Sauvegarde ce fichier en lieu sûr !"
fi

# ── Déploiement ─────────────────────────────────────────────────────────
bold "==> Déploiement Ansible (sudo requis)"
echo "    (mot de passe sudo de cette machine demandé ci-dessous)"
exec ansible-playbook -i inventory.ini site.yml -K "$@"
