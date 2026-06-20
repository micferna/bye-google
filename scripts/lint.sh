#!/usr/bin/env bash
# Lint complet du projet (bonnes pratiques Ansible / YAML / Caddy).
set -euo pipefail
cd "$(dirname "$0")/.."

run() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

run "yamllint"
yamllint .

run "ansible-lint (profil production)"
ansible-lint

run "ansible syntax-check"
ansible-playbook -i inventory.ini site.yml --syntax-check

run "Validation du Caddyfile généré"
ENGINE="$(grep -oP '(?<=^container_engine: ")[^"]+' group_vars/all.yml 2>/dev/null || echo docker)"
CADDY_VER="$(grep -oP '(?<=^caddy_version: ")[^"]+' group_vars/all.yml 2>/dev/null || echo 2.8)"
tmp="$(mktemp)"
python3 - "$tmp" <<'PY'
import jinja2, sys
env = jinja2.Environment(loader=jinja2.FileSystemLoader('roles'))
out = env.get_template('core/templates/Caddyfile.j2').render(
    domain="example.lab", tls_internal=True, acme_email="",
    enable_nextcloud=True, enable_immich=True, enable_minio=True)
open(sys.argv[1], 'w').write(out)
PY
mkdir -p /tmp/_bg_apps
$ENGINE run --rm -v "$tmp":/etc/caddy/Caddyfile:ro -v /tmp/_bg_apps:/etc/caddy/apps:ro \
  "caddy:$CADDY_VER" caddy validate --config /etc/caddy/Caddyfile
rm -f "$tmp"

printf '\n\033[32m✓ Lint OK\033[0m\n'
