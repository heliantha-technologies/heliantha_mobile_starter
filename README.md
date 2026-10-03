# Heliantha Mobile Starter

Architecture retenue :

```text
Flutter Android
      ↓ HTTPS / JSON
FastAPI
      ↓
PrestaShop Webservice
      ↓
PrestaShop + sa base de données
```

## Objectif

L'application est un reflet mobile de la boutique PrestaShop existante.

- PrestaShop reste la source de vérité.
- FastAPI ne duplique pas le catalogue, les stocks, les clients ou les commandes.
- Le catalogue est public : aucune connexion obligatoire pour voir les produits.
- Le compte client est optionnel et sert notamment à retrouver le profil et les commandes.
- Le même compte doit être utilisable sur le site et dans l'application.
- La création de commande doit finir dans le même back-office PrestaShop.
- Pas de paiement bancaire intégré dans cette base. Les modes prévus sont hors-ligne : espèces / versement sur numéro de compte.

## Ce qui fonctionne dans ce starter

### Backend FastAPI
- `GET /health`
- `GET /v1/home`
- `GET /v1/categories`
- `GET /v1/products`
- `GET /v1/products/{id}`
- `GET /v1/products/{id}/image`
- `POST /v1/auth/login` via un petit pont PrestaShop optionnel
- `GET /v1/me`
- `GET /v1/orders`
- `GET /v1/orders/{id}`
- `POST /v1/orders` via pont PrestaShop optionnel
- Swagger automatique sur `/docs`

### Flutter
- Accueil
- Catalogue
- Recherche
- Fiche produit
- Panier local
- Favoris locaux
- Connexion facultative
- Compte
- Historique des commandes
- Navigation Android
- Gestion d'erreurs et chargements
- Configuration de l'URL FastAPI par `--dart-define`

## Important

Deux fonctions dépendent de la configuration réelle de votre PrestaShop et de ses modules :

1. validation du mot de passe d'un compte PrestaShop existant ;
2. création complète d'une commande avec les règles exactes de livraison et de règlement.

Elles sont isolées derrière `MOBILE_BRIDGE_URL` afin de ne pas mettre la clé PrestaShop dans l'application Flutter et de ne pas supposer une structure que nous n'avons pas encore auditée.

Un exemple de module/pont PrestaShop minimal est fourni dans `prestashop_bridge_example/`.

---

# 1. Démarrer FastAPI

Sous Windows PowerShell :

```powershell
cd C:\Users\hp\Desktop\heliantha_mobile_starter\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

Modifier `.env` :

```env
PRESTASHOP_BASE_URL=https://heliantha.ma
PRESTASHOP_WEBSERVICE_KEY=VOTRE_CLE_WEBSERVICE
JWT_SECRET=CHANGE_ME_WITH_A_LONG_RANDOM_SECRET
```

Puis :

```powershell
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8011
```

Ouvrir :

```text
http://127.0.0.1:8011/docs
```

Pour le module Devis, le moteur Flask doit aussi tourner en local sur :

```text
http://127.0.0.1:8012
```

---

# 2. Démarrer Flutter

Flutter doit être installé sur le PC.

```powershell
cd C:\Users\hp\Desktop\heliantha_mobile_starter\mobile
C:\Users\hp\Desktop\flutter\bin\flutter.bat pub get
C:\Users\hp\Desktop\flutter\bin\flutter.bat run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://127.0.0.1:8011
```

Pour un émulateur Android, `10.0.2.2` correspond au PC hôte :

```powershell
C:\Users\hp\Desktop\flutter\bin\flutter.bat run --dart-define=API_BASE_URL=http://10.0.2.2:8011
```

Sur un vrai téléphone Android connecté au même Wi-Fi, utiliser l'IP locale du PC :

```powershell
C:\Users\hp\Desktop\flutter\bin\flutter.bat run --dart-define=API_BASE_URL=http://192.168.X.X:8011
```

et lancer FastAPI sur toutes les interfaces :

```powershell
python -m uvicorn app.main:app --host 0.0.0.0 --port 8011 --reload
```

---

# 3. Activer le Webservice PrestaShop

Dans le back-office :

```text
Paramètres avancés
→ Webservice
→ Activer
→ Créer une clé dédiée
```

Pour démarrer, donner uniquement les droits GET nécessaires sur :

- products
- categories
- stock_availables
- orders
- order_details
- order_states
- customers si nécessaire côté serveur

Ne jamais mettre la clé Webservice dans Flutter.

---

# 4. Connexion client

Le Webservice historique de PrestaShop n'est pas conçu comme un endpoint de login mobile.

Le starter prévoit donc :

```text
Flutter
  ↓
FastAPI /v1/auth/login
  ↓
Pont privé PrestaShop /module/helianthamobilebridge/auth
  ↓
PrestaShop valide email + mot de passe
```

Configurer dans `backend/.env` :

```env
MOBILE_BRIDGE_URL=https://heliantha.ma/module/helianthamobilebridge
MOBILE_BRIDGE_SECRET=UNE_LONGUE_CLE_SECRETE
```

Le secret reste uniquement sur les serveurs.

---

# 5. Structure

```text
heliantha_mobile_starter/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── clients/
│   │   ├── core/
│   │   ├── schemas/
│   │   └── services/
│   ├── tests/
│   ├── .env.example
│   └── requirements.txt
│
├── mobile/
│   ├── lib/
│   │   ├── core/
│   │   ├── features/
│   │   └── shared/
│   └── pubspec.yaml
│
└── prestashop_bridge_example/
```

## Prochaine étape

Brancher le vrai PrestaShop dans `.env`, tester `/v1/products`, puis adapter la normalisation des caractéristiques produit si la boutique utilise des champs/modules spécifiques.











Pour Android, on ne “héberge” pas l’application sur le Play Store comme un site web. En pratique, tu **publies une version signée de ton application Android dans Google Play Console**. Le Play Store devient ensuite le canal officiel pour installer et mettre à jour l’app.

Pour ton projet Heliantha, le chemin sera grosso modo :

```text
Flutter
  ↓
build Android signé
  ↓
fichier .aab
  ↓
Google Play Console
  ↓
test interne / fermé
  ↓
validation Google
  ↓
publication Play Store
```

Google Play utilise aujourd’hui principalement le format **Android App Bundle `.aab`**, à partir duquel Google génère les APK adaptés aux appareils. ([Google Help][1])

### Ce qu’il faudra préparer

Tu auras besoin d’un **compte développeur Google Play Console**. L’inscription coûte actuellement **25 USD une seule fois**. Google propose un compte **personnel** ou **organisation**. Pour une application d’entreprise comme Heliantha, je privilégierais clairement le compte **organisation de l’entreprise**, pas ton compte personnel, pour que l’application appartienne officiellement à Heliantha. ([Google Help][2])

Ensuite, dans Flutter, on donnera à l’application une identité définitive, par exemple :

```text
Nom :
Heliantha

Package Android :
ma.heliantha.app
```

Le package est très important. Une fois l’app publiée avec ce nom, il devient son identité permanente sur Android. Il faut donc le choisir proprement dès le départ.

Puis on créera la version Android de production :

```powershell
flutter build appbundle --release
```

Ça produit normalement un fichier du genre :

```text
mobile\build\app\outputs\bundle\release\app-release.aab
```

Mais avant ça, on configurera la **signature Android** avec une clé de signature/keystore. C’est une partie importante, parce que les futures mises à jour doivent être reconnues comme venant de la même application.

### Dans Play Console

Une fois le `.aab` prêt, on crée l’application et on renseigne la fiche Play Store :

```text
Nom : Heliantha

Description courte
Description complète

Icône

Captures d’écran

Catégorie :
Shopping / Commerce, probablement

Pays de distribution :
Maroc

Politique de confidentialité

Adresse e-mail de support

Site web :
heliantha.ma
```

Google demande aussi plusieurs déclarations sur le contenu de l’app, les données collectées, la confidentialité, la publicité, l’accès au compte, etc.

Ensuite on envoie le `.aab`.

### On ne publiera pas directement au public

Je te conseille très fortement de commencer par :

```text
Test interne
```

Tu peux installer l’application via Google Play sur quelques téléphones, exactement comme une vraie application, mais sans la rendre publique.

Puis :

```text
Test fermé
```

avec ton boss, toi et quelques collègues.

Et seulement après :

```text
Production
```

Il y a une nuance importante : pour les **nouveaux comptes développeur personnels** créés après le 13 novembre 2023, Google exige actuellement un test fermé avec **au moins 12 testeurs inscrits pendant 14 jours consécutifs** avant de pouvoir demander l’accès à la production. ([Google Help][3])

C’est une autre raison pour laquelle, si Heliantha est une entreprise, je préférerais publier avec **le compte organisation officiel de l’entreprise**.

### Et ton FastAPI ?

Très important : publier Flutter sur Play Store **ne publie pas ton backend FastAPI**.

Aujourd’hui tu utilises :

```text
http://127.0.0.1:8011
```

Ça fonctionne uniquement sur ton PC.

Pour l’application réelle :

```text
Application Android
      ↓ Internet
https://api.heliantha.ma
      ↓
FastAPI
      ↓
PrestaShop
```

Il faudra donc héberger FastAPI sur un serveur accessible en HTTPS, probablement via l’infrastructure Hostinger ou un VPS.

Et ton application release sera compilée avec quelque chose comme :

```text
API_BASE_URL=https://api.heliantha.ma
```

pas `127.0.0.1`.

### Dans ton cas, je ne publierais pas maintenant

Tu as raison d’avoir dit précédemment que l’app n’est pas finie. Pour l’instant, continue sur Chrome et ensuite éventuellement un vrai téléphone Android.

Quand on sera proche de la fin, l’ordre idéal sera :

```text
1. terminer fonctions principales
2. tester sur vrai Android
3. héberger FastAPI en HTTPS
4. choisir package Android définitif
5. configurer signature
6. créer compte Play Console Heliantha
7. générer .aab
8. test interne
9. test fermé
10. production
```

Donc tu n’as **rien besoin de payer ou publier maintenant**. On peut continuer tranquillement à construire l’application, et préparer le Play Store seulement quand elle aura atteint un vrai niveau préproduction.

[1]: https://support.google.com/googleplay/android-developer/answer/9859152?rd=1&utm_source=chatgpt.com "Create and set up your app - Play Console Help"
[2]: https://support.google.com/googleplay/android-developer/answer/6112435?hl=fr&utm_source=chatgpt.com "Premiers pas avec la Play Console - Aide Console Play"
[3]: https://support.google.com/googleplay/android-developer/answer/14151465?hl=FR&utm_source=chatgpt.com "Exigences de test d'applications pour les nouveaux comptes de développeur personnels - Aide Console Play"

## Commandes rapides - systeme actuel Windows

### 1. Analyser Flutter

```powershell
cd C:\Users\hp\Desktop\heliantha_mobile_starter
C:\Users\hp\Desktop\flutter\bin\flutter.bat analyze
```

### 2. Demarrer le backend FastAPI mobile

```powershell
cd C:\Users\hp\Desktop\heliantha_mobile_starter\backend
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8011

Swagger :

```text
http://127.0.0.1:8011/docs
```

Important pour les devis : le moteur Flask doit tourner separement sur `http://127.0.0.1:8012`.

### 3. Demarrer Flutter sur Chrome

Ouvrir un deuxieme terminal PowerShell :

```powershell
cd C:\Users\hp\Desktop\heliantha_mobile_starter\mobile
C:\Users\hp\Desktop\flutter\bin\flutter.bat run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://127.0.0.1:8011


URL Chrome :

```text
http://localhost:3000
```

### 4. Refaire le ZIP du pont PrestaShop si besoin

```powershell
cd C:\Users\hp\Desktop\heliantha_mobile_starter\prestashop_bridge_example
if (Test-Path helianthamobilebridge.zip) { Remove-Item helianthamobilebridge.zip }
tar -a -c -f helianthamobilebridge.zip helianthamobilebridge
tar -tf helianthamobilebridge.zip
```
