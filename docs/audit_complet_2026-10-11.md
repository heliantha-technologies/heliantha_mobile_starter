# Audit Heliantha Mobile — 11 octobre 2026

> État initial avant corrections. Le chantier S02, S04, P01 et P03 demandé ensuite
> est décrit dans [le compte rendu des corrections](securisation_pdf_maintenance.md).
> Les résultats et vulnérabilités ci-dessous restent ceux du diagnostic initial.

Le projet dispose d'une base fonctionnelle et de protections utiles, mais plusieurs points doivent être corrigés avant une exposition réseau partagée ou une publication en production. Les priorités sont la clé JWT locale, l'accès aux PDF clients, l'atomicité des commandes et le contrôle de maintenance. Pour la réactivité, les principaux coûts viennent des requêtes sérialisées et répétées, ainsi que de l'affichage artificiellement lent des réponses de l'assistant.

Audit demandé : sécurité, performances et réactivité au clic, rendu moderne, code mort. Aucun correctif applicatif ni suppression n'a été effectué. Les ajouts sont ce rapport, quatre captures locales et un script de capture dans `mobile/.dart_tool/audit/`, ignoré par Git. Les commandes de vérification ont écrit leurs caches habituels. Aucun achat, compte client, devis réel ou événement de notification n'a été créé. Aucune valeur de secret n'est reproduite.

## Périmètre et fiabilité

- Sources Flutter, configuration Android/web/desktop, API FastAPI, clients et services, schémas, tests, pont PHP PrestaShop, dépendances et documentation du starter.
- Lecture ciblée du moteur voisin `HELIANTHA SOLAIRE` pour vérifier le contrôle d'accès aux PDF. Cela ne constitue pas un audit complet de ce second projet.
- Tests et reproductions locaux avec réponses simulées. Les tests backend ont utilisé des identifiants de test et un blocage des connexions externes ; les connexions loopback nécessaires à asyncio ont été conservées.
- Rendu réel des widgets actuels avec données simulées : accueil 390 × 844, accueil 1440 × 900, accueil 320 × 740 avec texte à 150 %, sélection de projet 390 × 844. Ces captures ne proviennent pas d'une session Chrome ou d'un téléphone. Les bannières sont volontairement vides pour observer le repli. Roboto a été chargé pour les tests ; certaines familles de texte et certains emoji conservent les substitutions du runner. Les rectangles typographiques visibles dans certaines captures ne prouvent pas un défaut de production.
- Le serveur publié, le reverse proxy, TLS, les permissions Webservice effectives, les modules de paiement installés, les sauvegardes et le pont réellement déployé n'ont pas été vérifiés. Aucun benchmark de charge ou profilage sur Android réel n'a été effectué.
- Les références externes sont des avis et documentations officiels consultés. La revue des vulnérabilités de dépendances est ciblée ; ce n'est pas un scan exhaustif de toutes les dépendances transitives.

P1 = à traiter avant exposition/publication ou risque métier majeur ; P2 = défaut important ; P3 = amélioration ou nettoyage. Aucun P0 établi. « Confirmé en source » ne signifie pas « exploité sur le serveur publié ».

## Résultats des vérifications

| Vérification | Résultat | Portée |
| --- | --- | --- |
| Analyse Dart avec les règles existantes | Aucun diagnostic, code de sortie 0 | `dart --suppress-analytics analyze --format machine`, dépendances existantes |
| Suite Flutter existante | **129 réussites, 1 ignoré** | `flutter test --no-pub --reporter expanded` ; le test ignoré est réservé au web dans `favorites_images_test.dart:95` |
| Suite backend existante | **125 réussites, 1 échec**, 1 avertissement | Python 3.11.9 du backend ; pytest 8.4.2 déjà présent dans l'autre environnement local, sans installation ni mise à jour |
| Échec backend | `test_failed_scan_is_not_cached_and_retry_recovers[asyncio]` | AnyIO signale deux exceptions de Future non récupérées dans `SingleFlight` ; détail P04 ci-dessous |
| Captures de rendu isolées | **4 scénarios réussis** | Script séparé dans `.dart_tool/audit/`, hors suite applicative |
| Contrôle maintenance / Host | Requête normale **503**, Host malformé **200** | Route de sonde créée uniquement en mémoire, sans accès boutique ; S04 |
| Maintenance concurrente | **583 ms pour 10 requêtes**, source simulée à 50 ms | Reproduction du verrou global ; ce chiffre n'est pas une mesure de production |
| Annulation SingleFlight | Annuler un demandeur annule aussi un autre demandeur | Reproduction isolée ; le travail principal termine pourtant normalement |
| Cohérence Python backend | `pip check` : aucune incompatibilité déclarée | Ne vérifie pas les vulnérabilités |
| Git | Aucun fichier applicatif suivi modifié | `build/` était déjà non suivi avant audit ; seuls rapport et captures ajoutés |

Les protections financières, la recherche et la persistance ont de nombreux tests utiles. Leur réussite ne couvre pas les courses PHP, les permissions du serveur publié, les performances réelles ni tous les changements de compte.

## Sécurité : priorités avant publication

### S01 — P1 : JWT local prévisible avec les écritures réelles activées

**Preuve :** la configuration locale utilise `APP_ENV=development`, active `CHECKOUT_WRITE_ENABLED` et contient un `JWT_SECRET` de type placeholder (`backend/.env:2`, `:9`, `:10`). Le validateur n'émet qu'un avertissement en développement : [config.py](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/core/config.py:134). La documentation propose aussi une écoute sur toutes les interfaces : [README](C:/Users/hp/Desktop/heliantha_mobile_starter/README.md:135).

**Impact :** si cet environnement devient accessible, un JWT forgé avec la clé prévisible permet d'usurper un client et d'utiliser ses droits auprès de l'API. Le risque dépasse un simple exemple de développement puisque les écritures sont activées. L'exposition distante n'a pas été vérifiée.

**Correction :** clé aléatoire propre à cet environnement, refus des placeholders lorsque l'API travaille sur la boutique réelle et séparation des tests. Une rotation invalide les sessions existantes : la préparer comme un changement volontaire, sans l'effectuer pendant cet audit.

### S02 — P1 : PDF clients accessibles par identifiant séquentiel

**Preuve :** [devis.py](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/routers/devis.py:385) accepte un identifiant numérique puis récupère le PDF, sans identité ni jeton d'accès. Dans le projet Flask voisin, [routes.py](<C:/Users/hp/Desktop/HELIANTHA SOLAIRE/app/routes.py:847>) lit le devis par son identifiant sans contrôle de propriété. Le PDF contient nom, téléphone et ville : [pdf_service.py](<C:/Users/hp/Desktop/HELIANTHA SOLAIRE/app/services/pdf_service.py:435>).

**Impact :** énumération possible des devis et de leurs données personnelles si les routes locales correspondantes sont publiées. Aucun PDF client n'a été téléchargé pour l'audit.

**Correction :** contrôle de propriété pour un client connecté ; capacité de partage aléatoire/signée et limitée dans le temps pour un invité. Protéger les deux routes, FastAPI et Flask.

### S03 — P1 : idempotence PHP non atomique

**Preuve :** [checkout.php](C:/Users/hp/Desktop/heliantha_mobile_starter/prestashop_bridge_example/helianthamobilebridge/controllers/front/checkout.php:223) vérifie la clé, crée le panier et la commande, puis écrit la clé seulement après `validateOrder()` (`:268`, `:280`). Aucune réservation atomique ou contrainte unique n'encadre cette séquence.

**Impact :** deux confirmations simultanées peuvent franchir le même contrôle. Une panne entre création de commande et mémorisation de clé laisse aussi une fenêtre de double création. Les tests backend actuels vérifient une reprise sur pont simulé déjà idempotent ; ils ne prouvent pas l'atomicité du pont PHP.

**Correction :** table d'idempotence avec clé unique, réservation atomique, état en cours/terminé et référence durable vers un seul panier ; réconciliation après panne. Ne pas entourer aveuglément tous les hooks de paiement d'une transaction sans vérifier leurs effets.

### S04 — P1 dans ce projet : contrôle maintenance contournable par Host

**Preuve :** [main.py](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/main.py:64) utilise `request.url.path` pour décider quelles routes protéger. Starlette installé est **0.50.0**, concerné par [GHSA-86qp-5c8j-p5mr / CVE-2026-48710](https://github.com/Kludex/starlette/security/advisories/GHSA-86qp-5c8j-p5mr). La reproduction locale obtient 503 avec un Host normal et 200 avec un Host malformé sur la même route de sonde `/v1/`.

**Impact :** le blocage maintenance peut être évité si le proxy laisse passer cet en-tête. Cela ne supprime pas les contrôles JWT des routes privées ; c'est le contrôle de maintenance qui est contourné. L'avis de bibliothèque classe la faille Moderate ; la priorité P1 reflète l'usage de ce contrôle dans le projet.

**Correction :** décision de chemin basée sur le chemin ASGI, validation des hôtes attendus et gestion stricte des proxies de confiance. Préparer une migration compatible de FastAPI/Starlette ; ne pas imposer isolément une version de Starlette incompatible avec le FastAPI épinglé.

### S05 — P1 conditionnel : paiement et état de commande trop permissifs

**Preuve :** [checkout.php](C:/Users/hp/Desktop/heliantha_mobile_starter/prestashop_bridge_example/helianthamobilebridge/controllers/front/checkout.php:568) énumère tous les modules de paiement activés sans utiliser son argument panier. La confirmation emploie systématiquement `PS_OS_PREPARATION` avant `validateOrder()` (`:267`).

**Impact :** restrictions de pays, devise, groupe ou transporteur ignorées par cette liste. Si un module bancaire est activé, le parcours propre à ce module peut être contourné lors de la création de commande. Le statut est également à vérifier pour un versement encore attendu. Les modules et le sens exact de l'état de production sont inconnus.

**Correction :** autoriser explicitement les moyens hors ligne prévus par le périmètre, appliquer leurs restrictions et leur état d'attente. Vérifier le module réellement installé avant toute conclusion sur les commandes existantes.

## Sécurité : autres défauts et durcissements

| ID / priorité | Constat, preuve et impact | Action recommandée |
| --- | --- | --- |
| S06 / P2 | Limiteur de login basé sur le premier `X-Forwarded-For` brut : [auth.py](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/api/routes/auth.py:24). Changer cet en-tête change le compteur ; protection éventuelle au proxy inconnue. Compteurs locaux également séparés entre workers. | IP déterminée avec proxies de confiance ; quotas partagés par IP et compte. |
| S07 / P2 | Politique de mot de passe et quota d'inscription absents côté serveur : [auth.py schémas](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/schemas/auth.py:9), route inscription `api/routes/auth.py:99`, pont `auth.php:112`. Hacher avant validation du modèle client ne valide pas la solidité du mot de passe en clair. Les hooks de la boutique réelle restent à vérifier. | Même politique que la boutique, limites de longueur et quota d'inscription ; validation avant hachage. |
| S08 / P2 | L'aperçu public de commande crée un panier PrestaShop à chaque appel : `checkout.php:153` → `buildCart` → `$cart->add()` à `:338`. Cela écrit même avec la confirmation désactivée. | Panier temporaire réutilisable contrôlé, expiration/nettoyage, quota d'aperçus et nettoyage après échec. |
| S09 / P2 | Listes checkout sans taille maximale, quantité sans plafond, mode chaîne libre, clés et champs sans limites suffisantes : [checkout.py schémas](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/schemas/checkout.py:4). Calcul devis public également sans quota local. | Bornes métier, enum, invariants invité/connecté, limites de corps et quotas ; conserver les parcours invités. |
| S10 / P2 | Quantité minimale PrestaShop mal traitée : `checkout.php:365` vérifie `!$updated`, alors que `updateQty()` peut renvoyer `-1`, vrai en PHP. Une ligne refusée peut être omise sans erreur claire. Dépend d'un produit avec minimum supérieur à 1. | Traiter explicitement `-1` et vérifier toutes les lignes du panier final avant confirmation. Le comportement est documenté dans le [Cart PrestaShop 8.2](https://raw.githubusercontent.com/PrestaShop/PrestaShop/8.2.x/classes/Cart.php). |
| S11 / P2 | JWT valide pendant 720 minutes, sans révocation liée au changement de mot de passe ou à la désactivation du compte : [security.py](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/core/security.py:34), `config.py:46`. | Durée adaptée, renouvellement contrôlé et version/révocation de session ; vérification de l'état client pour opérations sensibles. |
| S12 / P2 | Historique assistant partagé entre comptes : clé globale `heliantha_chat_history`, SharedPreferences, restauration sans identité : [ai_chat_bottom_sheet.dart](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/assistant/presentation/widgets/ai_chat_bottom_sheet.dart:382). Logout `account_screen.dart:86` ne le purge pas. | Historique par identité/session, effacement explicite au logout et durée de conservation. Éviter de conserver indéfiniment les coordonnées/devis. |
| S13 / P2 | FCM déduplique uniquement le token ; échec de désinscription hors réseau conserve `_registeredToken` : [fcm_service.dart](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/notifications/services/fcm_service.dart:96), `:119`. Au compte suivant, l'inscription peut être sautée. Confidentialité conditionnelle à l'association conservée côté serveur. | Dédupliquer par utilisateur + token, remettre l'état local à zéro et réinscrire après changement de compte ; prévoir désinscription différée/rotation et filtrer les messages du compte précédent. |
| S14 / P2 | HTTP et certificats utilisateur autorisés globalement dans le manifeste/config réseau Android, y compris release : `AndroidManifest.xml:11`, `network_security_config.xml:3,6`. | Exceptions dans le debug, HTTPS et CA système en release. Cette policy concerne les connexions natives ; elle ne prouve pas une interception de Dio, car les [sockets Dart ont leurs propres règles](https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android). Utiliser les [debug-overrides Android](https://developer.android.com/privacy-and-security/security-config). |
| S15 / P2 conditionnel | URLs PDF/médias HTTP externes conservées malgré le durcissement de la base API : [app_config.dart](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/core/config/app_config.dart:63), `shared/utils/api_url.dart:22`. | Valider schéma et destination en release pour les URLs reçues ; conserver les exceptions locales uniquement dans le développement. |
| S16 / P2 | Transition d'alerte stock non atomique : lecture de l'ancien état, clé temporelle, envoi FCM, puis mise à jour : [notifications.py](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/services/notifications.py:221). Deux webhooks peuvent produire deux alertes. | Transition et notification dans une transaction, identifiant stable d'événement, push après commit. |
| S17 / P3 | Réponses du pont journalisées jusqu'à 2 000 caractères, dont login/adresses : [bridge.py](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/clients/bridge.py:130). Des routes renvoient aussi des détails upstream via `str(exc)`. | Logs structurés sans corps personnel ; erreurs publiques génériques et détails techniques filtrés dans les journaux. |
| S18 / P3 | Sauvegarde Android du stockage sécurisé non explicitement configurée. Le package installé recommande d'exclure ses préférences ; aucune règle de sauvegarde correspondante trouvée. | Vérifier les exclusions et les restaurations sur Android. Risque de session/restauration défectueuse ; aucune fuite du token chiffré démontrée. |

`flutter_secure_storage` est utilisé pour le token : ce n'est pas un JWT directement stocké en clair dans SharedPreferences. La branche web repose néanmoins sur la sécurité du navigateur et de l'origine ; un stockage dit sécurisé ne constitue pas une protection générale contre un XSS. Les [recommandations OWASP sur le stockage navigateur](https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html) justifient une revue des scripts et en-têtes du site publié, qui n'a pas été effectuée ici.

## Performances et clic instantané

Un clic peut recevoir un retour visuel rapide alors que le réseau continue. L'objectif proposé est un feedback en moins de **100 ms**, avec une action locale immédiate quand elle est sûre, puis progression et erreur visibles pour le travail distant. Il s'agit d'un objectif à mesurer, pas d'une garantie actuelle. La commande README lance Chrome en debug ; les [mesures Flutter](https://docs.flutter.dev/perf/ui-performance) doivent être faites en profile/release, avec [Chrome DevTools pour le web](https://docs.flutter.dev/perf/web-performance).

| ID / priorité | Constat et preuve | Conséquence / correction |
| --- | --- | --- |
| P01 / P1 performance | Verrou global maintenu pendant le contrôle HTTP Flask : [maintenance.py](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/services/maintenance.py:36). Chaque requête métier impose `fresh=True` via `main.py:76`, même lorsque son propre résultat est déjà en cache. | 10 lectures simultanées avec un contrôle simulé de 50 ms prennent 583 ms. Réduire le verrou au partage de l'appel/résultat et définir la cohérence du contrôle ; conserver la fermeture en cas d'indisponibilité et éviter toute fuite d'exemption admin. |
| P02 / P1 performance | Chaque aperçu checkout force d'abord N fiches produit, puis lance l'aperçu : [checkout_screen.dart](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/checkout/presentation/checkout_screen.dart:107), `cart_provider.dart:248`. Le changement transporteur recommence cette séquence. | N GET + aperçu, amplifiés par P01 ; les anciennes sélections restent dans la file de synchronisation. Séparer devise/prix et transporteur, regrouper les produits, dédupliquer/annuler les anciennes estimations. Le serveur doit garder les contrôles de prix, devise et stock. |
| P03 / P1 expérience | La réponse assistant est reçue intégralement, puis affichée par 2–3 caractères toutes les 45 ms : [ai_chat_bottom_sheet.dart](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/assistant/presentation/widgets/ai_chat_bottom_sheet.dart:691). `_isLoading` reste vrai jusqu'à la fin. | Pour une réponse longue, 1 000 caractères ajoutent environ **15 s**, 3 000 environ **45 s**, après le réseau. Afficher le texte immédiatement ou plafonner l'effet et permettre de le terminer. Le streaming serveur est une amélioration distincte. |
| P04 / P2 fiabilité | `SingleFlight` crée une Future puis y dépose l'exception même sans demandeur qui la récupère : [single_flight.py](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/core/single_flight.py:27), `:48`. Les demandeurs attendent aussi la Future sans protection d'annulation (`:40`). | Échec de test sur erreur de scan ; reproduction montrant qu'un demandeur annulé annule un autre. Revoir le partage de tâche/Future, consommation des erreurs et isolation d'annulation, par exemple avec attente protégée ; ajouter les cas erreur sans suiveur et annulation d'un suiveur. |
| P05 / P2 | Ajout panier avec message de succès immédiat alors que la conversion peut être en attente ou échouer : [product_card.dart](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/shared/widgets/product_card.dart:168), `cart_provider.dart:149`. | Retourner un résultat/Future : succès après ajout effectif, état d'attente et réessai en cas de conversion. Garder instantané l'ajout local dans la même devise. |
| P06 / P2 | Sélecteur catégories ouvert seulement après le Future réseau : [catalog_screen.dart](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/catalog/presentation/catalog_screen.dart:346). Pas de gestion d'erreur sur cette attente ; taps répétés possibles. | Ouvrir le panneau immédiatement avec chargement/erreur/données et verrou d'ouverture. |
| P07 / P2 | Favoris construits entièrement dans une Column, une fiche par favori : [favorites_screen.dart](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/favorites/presentation/favorites_screen.dart:45), `:75`. | Construction et N appels hors écran. Liste paresseuse avec clés, chargement groupé ou concurrence limitée. |
| P08 / P2 | `FutureProvider.family` fiche sans expiration automatique ; caches de fiches Flutter non bornés : [catalog_providers.dart](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/catalog/providers/catalog_providers.dart:38), `catalog_repository.dart:23,224`. Cache détail backend également non borné (`services/catalog.py:69,825`). | Le provider garde la valeur toute la session et peut court-circuiter le TTL repository. Invalidation/rafraîchissement explicites et éviction bornée ; `autoDispose` seul ne définit pas la fraîcheur. |
| P09 / P2 | Redis met produits et stocks en cache **900 s** : [prestashop_cache.py](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/core/prestashop_cache.py:16), `clients/prestashop.py:15,23,89`. | Si Redis est disponible, un TTL Flutter de deux minutes ou backend de vingt secondes ne rend pas le stock amont frais. TTL par ressource et invalidation métier ; toujours revalider au checkout. Redis actif en production non vérifié. |
| P10 / P2 | Redis synchrone appelé dans fonctions async ; timeout de 200 ms par opération : `clients/prestashop.py:65,89`, `core/prestashop_cache.py:26,51,69`. | Redis lent/absent peut bloquer la boucle serveur. Client async ou déport en thread, désactivation temporaire après échec. |
| P11 / P2 | SQLite synchrone dans les handlers async, attente de verrou jusqu'à cinq secondes : [notifications.py](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/services/notifications.py:42). Construction du service et schéma réexécutés par requête (`api/deps.py:70`, `notifications.py:38`). | Initialisation/migration au démarrage et appels bloquants hors boucle async ; mesurer la contention réelle avant changement de base. |
| P12 / P2 | Reset du chat sans annuler la requête/génération en vol : `ai_chat_bottom_sheet.dart:475` versus `:641`. Historique complet sérialisé et renvoyé à chaque message (`:424`, `:634`, `assistant_api_service.dart:77`). | Ancienne réponse peut perturber la nouvelle discussion ; coût croissant. Token d'annulation/génération contrôlé après chaque await et timer, limite en messages/octets. |
| P13 / P2 | Notification marquée lue sans attendre, puis provider invalidé immédiatement : [notifications_screen.dart](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/notifications/presentation/notifications_screen.dart:72). | GET pouvant finir avant POST et badge rester non lu. Mise à jour locale immédiate, invalidation après synchronisation ; navigation indépendante du réseau. |
| P14 / P3 à profiler | Chat reconstruit toutes les 45 ms ; flou sigma 18, cartes accueil avec flous sigma 12 ; timer carrousel actif dans onglets conservés. `ai_chat_bottom_sheet.dart:713,748`, `home_screen.dart:524,1412`, `app_router.dart:51`. | Isoler les widgets animés et tester le bénéfice des flous ; suspendre les timers hors visibilité et en pause. Aucun jank mesuré ici. |
| P15 / P3 | Cache images backend limité à 100 objets, sans budget d'octets : `api/routes/catalog.py:184,238`. Clients HTTP devis recréés par appel (`routers/devis.py:351,397`). | Miniatures adaptées et budget mémoire ; client HTTP devis partagé et fermé au shutdown. Les trois images de marque pèsent environ 1,87 Mio au total, ce qui mérite de mesurer le décodage sur appareil modeste. |
| P16 / P3 | Connexion dans le checkout attend FCM : `checkout_screen.dart:210`, contrairement au login indépendant (`login_screen.dart:65`). | Lancer inscription push après la connexion réussie, sans retarder le parcours client. |

La recherche n'est plus dans l'état défectueux décrit au début de l'audit du 5 octobre : normalisation, pagination, rejet des réponses anciennes, caches de pages bornés et préchargement intercepté sont déjà présents. Les trois défauts P01/P02/P03 sont plus prioritaires pour la réactivité actuelle qu'une refonte générale des widgets.

## Rendu moderne, sophistication et accessibilité

Les captures montrent une identité cohérente marine/or, des pictogrammes de catégories distincts, une hiérarchie accueil/devis/univers et une navigation persistante. Material 3, le thème central, les SVG, les tokens et les états d'erreur constituent une bonne base. Pour affiner le rendu, les priorités sont la lisibilité, le comportement responsive et la hiérarchie des actions ; ajouter des effets visuels ne résout pas les attentes réseau.

| ID / priorité | Observation / preuve | Recommandation |
| --- | --- | --- |
| U01 / P2 | Dans le rendu accueil 390 px, l'orbe assistant recouvre une partie de la carte Éclairage solaire. Placement flottant dans [app_router.dart](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/core/router/app_router.dart:213). | Réserver une zone sans contrôle sous l'orbe ou un emplacement qui ne masque pas les cartes. Le déplacement manuel de l'orbe ne remplace pas un placement initial lisible. |
| U02 / P2 | À 320 px et texte à 150 %, labels de navigation tronqués et retours à la ligne difficiles sur le CTA dimensionnement. Hauteur navigation imposée à 64 : `app_router.dart:237`, titre CTA `home_screen.dart:1076`. Reproduit dans le rendu widget, à confirmer sur appareils. | Adapter hauteur et labels à l'agrandissement ; prévoir une composition compacte du CTA ; ne pas réduire globalement l'accessibilité par un plafond arbitraire du texte. |
| U03 / P2 | Chat : texte vert `#10B981` à 11,5 px, contraste calculé **2,54:1 sur blanc** (`ai_chat_bottom_sheet.dart:862`). Palette `leaf` avec blanc : **3,89:1** (`app_colors.dart:13`, `app_theme.dart:24`). Le fond exact du chat n'a pas été capturé. | Assombrir le vert informatif et vérifier les combinaisons réellement utilisées. Le [seuil WCAG AA du texte courant](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) est 4,5:1 ; 3:1 concerne le grand texte, avec exceptions pour contrôles inactifs. |
| U04 / P2 | Reset/fermer du chat avec cibles d'environ 32 px et absence de libellé explicite pour fermer : `ai_chat_bottom_sheet.dart:883,909,919`. | Cibles confortables cohérentes de 44–48 px comme objectif de conception ; labels sémantiques, focus et navigation clavier à vérifier. |
| U05 / P3 | Tokens centralisés, mais chat et CTA utilisent de nombreuses couleurs/rayons/tailles manuels (`ai_chat_bottom_sheet.dart:740,840`, `home_screen.dart:1000`). | Consolider quelques variantes de surface, de rayon et de typographie ; garder un CTA principal identifiable. Valider visuellement avant changements. |
| U06 / P3 | Choix de projet : trois offres disponibles et trois grandes cartes « Bientôt disponible » ; visible dans la capture. | Donner plus de place aux projets utilisables et une place secondaire aux projets futurs ; choix produit à valider, pas suppression automatique. |
| U07 / P3 | Interface presque entièrement française malgré sélection de langue et direction RTL ; respect partiel des animations réduites (splash, frappe, carrousel). | Localisation explicite des libellés ; désactivation des délais décoratifs et des animations continues selon les préférences utilisateur. |
| U08 / P3 à vérifier | Grilles produit : deux colonnes fixes sous 660 px et hauteur fixe (`product_grid.dart:248`). Elles n'ont pas été capturées avec de vraies fiches longues dans cet audit. | Tester 320/360 px, texte à 150–200 %, arabe RTL et titres longs. Aucun débordement catalogue démontré ici. |

Captures disponibles : [accueil mobile](C:/Users/hp/Desktop/heliantha_mobile_starter/docs/audit_2026-10-11/home_mobile.png), [accueil grand écran](C:/Users/hp/Desktop/heliantha_mobile_starter/docs/audit_2026-10-11/home_desktop.png), [petit écran / texte 150 %](C:/Users/hp/Desktop/heliantha_mobile_starter/docs/audit_2026-10-11/home_small_text150.png), [choix du projet](C:/Users/hp/Desktop/heliantha_mobile_starter/docs/audit_2026-10-11/quote_mobile.png). Limites de police et de données simulées décrites au début du rapport.

## Code mort, dépendances et documentation

Tous les **76 fichiers Dart de `lib` sont accessibles depuis `main.dart` par leurs imports**. Cela exclut l'idée d'un gros dossier entièrement orphelin, mais ne prouve pas l'utilisation de chaque membre public. Tous les assets Flutter déclarés ont des références dans les sources. Les dossiers de plateformes et registrants générés sont à conserver ; un manque de prise en charge d'une plateforme ne suffit pas à la classer comme code mort.

| Élément | Preuve et confiance | Action |
| --- | --- | --- |
| `cupertino_icons`, `mobile/pubspec.yaml:12` | Aucun import dans `lib`/`test`, confiance haute comme dépendance directe inutilisée | Candidat à retrait ciblé avec résolution et analyse ; gain de build/poids non mesuré, pas promis |
| `AppColors.slate`, `app_colors.dart:8` | Aucune référence dans `lib`/`test` | Nettoyage à faible impact |
| `AppSpacing.xxl`, `app_tokens.dart:13` | Aucune référence dans `lib`/`test` | Nettoyage à faible impact |
| `_upstream_error_detail`, `_upstream_status_code`, `backend/app/routers/devis.py:191,199` | Seules occurrences = définitions dans application et tests | Fonctions privées inutilisées, candidates au retrait |
| `ApiClient.apiBaseUrl`, `core/api/api_client.dart:7` | Aucun appel interne ; membre public | Nettoyage facultatif, vérifier consommateurs externes avant retrait |
| `PrestaShopClient.search`, `clients/prestashop.py:136` | Plus appelé dans les sources/tests actuels depuis passage à l'index complet | Ancienne méthode publique : déprécier/documenter avant retrait éventuel |
| `POST /v1/orders`, `api/routes/orders.py:55` → `services/orders.py:113` | Appelle un contrôleur `orders` absent du pont fourni et ne suit pas le drapeau checkout. Route publiée, donc pas simplement code inaccessible. | Déprécier/retirer avec vérification des clients, ou appliquer les protections du parcours actuel. Risque d'écriture conditionnel au pont réellement installé |

Points de maintenance confirmés :

- L'environnement `.venv` à la racine pointe vers `C:\Python314\python.exe`, absent. `backend/.venv` fonctionne avec Python 3.11.9 mais ne contient pas pytest. Les tests ont réutilisé les modules pytest purs Python déjà présents dans l'environnement racine, sans réparer les environnements ni modifier les dépendances. Un environnement de développement unique et reproductible éviterait ce détour.
- `mobile/android/app/build.gradle.kts:13` rend le fichier de signature optionnel, puis caste ses propriétés en `String` sans vérification à `:38`. Sur un checkout sans `key.properties`, la configuration Gradle peut échouer même pour debug. Créer la signature release seulement si les propriétés sont complètes et exiger la signature pour la tâche release. Le fichier existe actuellement ; ses valeurs n'ont pas été affichées.
- `AppConfig.resolvePdfUrl` résout les chemins relatifs sur le domaine de production même avec API locale (`app_config.dart:63`). Clarifier si les PDF de développement doivent suivre l'API configurée ; ne pas remplacer ce domaine sans vérifier le contrat Flask.
- README indique `ma.heliantha.app` (`:264`) et `api.heliantha.ma` (`:360,372`) ; le code utilise `ma.heliantha.mobile` et `app.heliantha.ma`. La commande « Analyser Flutter » se place aussi à la racine, tandis que le projet Flutter est dans `mobile`. Actualiser les instructions actives ; les anciens rapports datés restent historiques.
- Firebase s'initialise sur toute plateforme non web (`main.dart:17`), alors que le service push ne prend en charge qu'Android (`fcm_service.dart:43`). Vérifier avant d'annoncer la prise en charge iOS/desktop ; Android demeure le périmètre principal.
- Pas de verrou de dépendances Python ni configuration CI trouvés dans le starter inspecté. `mobile/pubspec.lock` est présent. Les bornes Python larges peuvent faire varier les environnements ; figer les résolutions après validation et automatiser les suites essentielles.

Versions observées dans l'environnement backend : FastAPI 0.128.2, Starlette 0.50.0, Uvicorn 0.54.0, HTTPX 0.28.1, Pydantic 2.13.4, pydantic-settings 2.15.0, PyJWT 2.15.1, python-multipart 0.0.32, firebase-admin 6.9.0, redis 5.3.1 et AnyIO 4.15.1. SDK Flutter local : 3.47.2 / Dart 3.13.2. La revue ciblée a confirmé l'applicabilité de l'avis Host Starlette ; elle n'établit pas l'absence d'autres CVE. Les anciens avis de formulaires/StaticFiles ne sont pas considérés exploitables simplement parce qu'une bibliothèque est présente lorsque les routes correspondantes ne sont pas utilisées.

Les fichiers sensibles ciblés (`.env`, clés Android, bases locales et secrets Firebase) ne sont pas suivis dans l'arbre courant contrôlé ; `backend/.env.example` est suivi. L'historique complet et les dépôts distants n'ont pas fait l'objet d'un scan de secrets.

## Protections à conserver

- Algorithme JWT fixé explicitement, expiration/type vérifiés, clés faibles refusées en environnement production.
- Comparaison constante des secrets de pont, webhook et purge cache ; refus lorsque non configurés.
- Contrôles de propriété des commandes et adresses ; aucune confirmation d'un IDOR commande/adresse avec le pont fourni.
- Paramètres SQL liés, WAL, transactions et index de déduplication de notifications de commande.
- CORS avec origines explicites, sans wildcard générique.
- Exemption maintenance vérifiée par Flask, sans confiance dans un simple rôle client ; fermeture lors d'une panne de contrôle.
- Pool HTTP PrestaShop, mutualisation des lectures, normalisation/pagination recherche, caches de pages bornés, placeholders et erreurs compréhensibles.
- Navigation conservant les onglets, protection contre les anciens résultats de recherche, garde de soumission checkout, contrat devise et persistance du panier.

## Ordre recommandé et critères de validation

1. **Sécuriser l'exposition :** S01, S02, S04, puis S03/S05 avec validation du pont installé. Reproduire les contrôles avec utilisateurs simulés ; exiger absence de fuite interclient, rejet du Host malformé, confirmation concurrente/reprise donnant une seule commande et un état de paiement approprié. Ces essais de pont se font sur une boutique de test.
2. **Réduire les attentes :** P01/P02/P03, puis retour panier/catégories. Mesurer les appels déclenchés par un clic, les latences p50/p95 à froid et à chaud, et le premier feedback. Garder l'exactitude financière côté serveur.
3. **Fiabiliser les états :** SingleFlight, reset chat, lecture notifications, changement de compte FCM/historique et politique de caches. Faire passer la suite backend complète, puis ajouter seulement les scénarios manquants correspondant aux défauts corrigés.
4. **Affiner le rendu :** dégager l'orbe, adapter texte agrandi, contrastes et cibles tactiles ; captures Chrome/Android avec vraies polices et jeux de données non sensibles. Tester clavier, lecteur d'écran, RTL et animations réduites.
5. **Nettoyer et rendre reproductible :** suppressions ciblées, API ancienne, documentation, environnement Python, signature debug/release, dépendances figées et CI. Vérifier ensuite analyse et suites adaptées.

Les résultats actuels ne justifient ni une suppression massive de fichiers, ni une refonte générale de l'application. Les défauts recensés peuvent être traités par changements ciblés avec validation de chaque parcours concerné.
