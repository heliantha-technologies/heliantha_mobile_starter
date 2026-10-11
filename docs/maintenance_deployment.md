# Maintenance commune : Flask, API mobile et Flutter

Le bouton de l’administration pilote un seul état enregistré dans la base Flask.
Il couvre les visiteurs anonymes **et les comptes clients connectés**. PrestaShop,
son module et sa base ne sont pas modifiés. Les webhooks de notification conservent
leur authentification existante et continuent à recevoir les événements.

## Déployer les trois parties

1. Déployer les modifications du projet **HELIANTHA SOLAIRE** et redémarrer Flask.
2. Déployer **heliantha_mobile_starter/backend** et redémarrer FastAPI.
   Dans son `.env`, définir l’URL **interne réelle** du serveur Flask :

   ```env
   # Production actuelle si le moteur écoute bien sur ce port :
   FLASK_INTERNAL_URL=http://127.0.0.1:8012
   ```

   En local avec `run.py`, utiliser `http://127.0.0.1:5000`.
   Dans des conteneurs séparés, utiliser le nom DNS du service Flask.
   Sans valeur : port 8012 si `APP_ENV=production`, sinon port 5000.
   Cette URL est aussi utilisée par le proxy de calcul des devis.

3. Reconstruire Flutter :

   ```powershell
   cd mobile
   C:\Users\hp\Desktop\flutter\bin\flutter.bat build web --release
   ```

   Publier le **contenu complet** de `mobile/build/web` sur l’hébergement Flutter.
   Pour Android/iOS, distribuer aussi une version mise à jour. Les anciens clients
   seront déjà bloqués par l’API, mais n’ont pas le nouvel écran intégré.

## Routage Nginx

Conserver `/admin/` et `/api/` vers Flask, et `/v1/` vers FastAPI.
`/v1/maintenance/status` doit atteindre FastAPI sans cache CDN/proxy. Il s’agit
d’une requête HTTP JSON longue, pas d’un WebSocket : aucun Upgrade nécessaire.
Prévoir un délai de lecture d’au moins 35 s (60 s convient). Si des règles de cache
personnalisées existent, exclure ces deux statuts de maintenance.
Ne pas mettre une règle Nginx 503 globale devant `/admin`.
Le shell Flutter reste servi : il affiche lui-même la page de maintenance.

Pour l’exemption administrateur dans le site Flutter, `/admin`, `/api` et `/v1`
doivent partager l’hôte de l’application (configuration normale sur
`app.heliantha.ma`). Le cookie de session admin est vérifié par Flask ; un JWT
client, un paramètre d’URL ou un en-tête `X-Admin` ne donnent aucune exemption.
L’application native n’a pas de connexion administrateur et reste donc bloquée.

## Vérification sur le serveur

```bash
curl -i http://127.0.0.1:8012/api/maintenance/status
curl -i http://127.0.0.1:8011/v1/maintenance/status
```

Les deux doivent répondre HTTP 200, JSON `maintenance: false` (ou `true` pendant
la maintenance) et `Cache-Control: ... no-store`. Un 404 indique un déploiement
manquant ou un mauvais routage. Un 503 `maintenance_status_unavailable` indique
que FastAPI ne joint pas le statut Flask : vérifier `FLASK_INTERNAL_URL`.

Ouvrir le site dans une fenêtre privée, puis activer le mode depuis une autre
fenêtre admin. La page déjà ouverte bascule normalement en environ une seconde
plus le réseau. Les contrôles métier utilisent un cache public de 15 secondes
par processus FastAPI ; sans lecteur du canal de statut, une bascule peut donc
prendre jusqu’à 15 secondes avant de bloquer une nouvelle opération. Le canal
de suivi rafraîchit ce même état au plus toutes les secondes. Une exemption
administrateur est toujours vérifiée auprès de Flask et n’est jamais mise en cache.
Une requête déjà en cours avant activation n’est pas interrompue ni rejouée.
À la désactivation, le site se réouvre automatiquement sans perdre les données
locales. En cas de panne Flask, FastAPI conserve le dernier état public vérifié,
actif ou inactif ; sans état initial connu, il répond HTTP 503. Une ancienne
exemption administrateur ne peut jamais servir de valeur de secours.

## Hôtes autorisés

FastAPI rejette les en-têtes Host absents, multiples, malformés et les hôtes
inconnus avec HTTP 400, avant le contrôle de maintenance. Les valeurs par défaut
sont `localhost`, `127.0.0.1`, `::1`, `heliantha.ma`, `www.heliantha.ma`,
`app.heliantha.ma` et `api.heliantha.ma`. `testserver` est ajouté uniquement
en environnement `development`.

Pour un autre domaine ou une adresse IP du réseau local, définir `TRUSTED_HOSTS`
dans l’environnement du processus qui lance FastAPI. Cette liste remplace les
valeurs par défaut ; les jokers sont refusés. Aucun nouveau champ n’a été ajouté
à la configuration JWT ni aux fichiers `.env`.

```powershell
$env:TRUSTED_HOSTS = 'localhost,127.0.0.1,app.heliantha.ma,api.heliantha.ma'
```

Le reverse proxy doit transmettre un Host présent dans cette liste. Le filtre
de maintenance lit le chemin ASGI et gère aussi les applications montées sous
un `root_path`, indépendamment de cet en-tête.

Les fichiers locaux ne mettent pas à jour le serveur à eux seuls. Le déploiement
des trois services est nécessaire ; aucune modification distante n’est réalisée
par les tests locaux.
