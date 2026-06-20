ANSIBLE := ansible-playbook -i inventory.ini site.yml
# -K demande le mot de passe sudo (become). Retire-le si sudo NOPASSWD.
ASK := -K
# Moteur de conteneurs pour les cibles utilitaires (mets ENGINE=podman si besoin).
ENGINE  ?= docker
COMPOSE := $(ENGINE) compose

.PHONY: help deploy core nextcloud immich minio apps backup hardening status logs down restart lint scan

help:
	@echo "bye-google — cibles disponibles :"
	@echo "  make deploy      Déployer toute la plateforme"
	@echo "  make core        Reverse-proxy + SSO + dashboard"
	@echo "  make nextcloud   (Re)déployer Nextcloud"
	@echo "  make immich      (Re)déployer Immich"
	@echo "  make minio       (Re)déployer MinIO"
	@echo "  make apps        Déployer les apps perso (apps/)"
	@echo "  make hardening   (Re)appliquer le durcissement de l'hôte"
	@echo "  make backup      Lancer une sauvegarde maintenant"
	@echo "  make status      État des conteneurs"
	@echo "  make logs S=core Logs d'une stack (core|nextcloud|immich|minio)"
	@echo "  make down        Arrêter toutes les stacks"
	@echo "  make lint        Lint complet (yamllint + ansible-lint + Caddy)"
	@echo "  make scan        Scan sécurité (secrets + vulnérabilités images)"

deploy:    ; $(ANSIBLE) $(ASK)
core:      ; $(ANSIBLE) $(ASK) --tags core
nextcloud: ; $(ANSIBLE) $(ASK) --tags nextcloud
immich:    ; $(ANSIBLE) $(ASK) --tags immich
minio:     ; $(ANSIBLE) $(ASK) --tags minio
apps:      ; $(ANSIBLE) $(ASK) --tags apps
hardening: ; $(ANSIBLE) $(ASK) --tags hardening
backup:    ; $(ANSIBLE) $(ASK) --tags backup -e backup_run_now=true

status:
	@$(ENGINE) ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

logs:
	@$(COMPOSE) --project-directory /srv/byegoogle/$(S) logs -f --tail=100

down:
	@for d in core nextcloud immich minio; do \
	  [ -f /srv/byegoogle/$$d/docker-compose.yml ] && \
	  $(COMPOSE) --project-directory /srv/byegoogle/$$d down || true ; \
	done

restart: down deploy

lint:
	@./scripts/lint.sh

scan:
	@./scripts/scan.sh
