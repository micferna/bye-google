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
```

Voir `vaultwarden/` pour un exemple complet et fonctionnel.
