# Tes apps (mini-PaaS)

Dépose un dossier par application. Chaque dossier doit contenir :

- `app.yml` — la fiche de l'app (nom, sous-domaine, port, SSO ou non)
- `docker-compose.yml` — la définition du/des conteneur(s)

Puis : `make apps`. Caddy crée automatiquement `https://<subdomain>.<domaine>`.

## Règles à respecter dans le compose

1. Le **service principal doit porter le même nom** que `name:` dans `app.yml`
   (Caddy route vers `<name>:<port>`).
2. Le service doit rejoindre le réseau externe **`edge`** :

   ```yaml
   networks: [edge]
   # ...
   networks:
     edge:
       external: true
   ```

3. **Ne publie pas de port** sur l'hôte (`ports:`) — l'accès passe par Caddy en HTTPS.
4. Variables injectées automatiquement (fichier `.env` généré) : `DOMAIN`, `SUBDOMAIN`,
   `FQDN`, `URL`. Utilise-les dans ton compose, ex. `DOMAIN: "https://${FQDN}"`.

## Exemple : `app.yml`

```yaml
name: monapp
subdomain: monapp     # https://monapp.<domaine>
port: 8080            # port écouté DANS le conteneur
protect: true         # true => derrière le SSO Authelia
host_port: 8202       # requis seulement si caddy_mode: native (voir ci-dessous)
```

Voir `vaultwarden/` pour un exemple complet et fonctionnel.

## Si Caddy est en mode natif (`caddy_mode: native`)

Caddy tourne alors sur l'hôte et ne peut pas joindre tes conteneurs par leur nom DNS.
Ton app doit donc :

1. déclarer un `host_port` unique dans `app.yml` ;
2. publier ce port **sur loopback** dans son compose :

   ```yaml
   ports:
     - "127.0.0.1:8202:8080"   # 127.0.0.1:<host_port>:<port>
   ```

C'est inoffensif en mode conteneur (Caddy utilise le DNS), et indispensable en mode natif.
