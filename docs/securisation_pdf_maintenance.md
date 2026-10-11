# Corrections PDF, maintenance et assistant — 11 octobre 2026

Les corrections suivent le périmètre demandé : S02, S04, P01 et P03.
Le pont PrestaShop, la logique et les secrets JWT, les fichiers `.env`, le routeur
Flutter et le composant de l’orbe flottant sont préservés.

## Accès aux devis

Flask génère `secrets.token_urlsafe(24)` pour chaque nouveau devis. La colonne
`quote_requests.access_token` est indexée de manière unique. La migration de
démarrage ajoute la colonne aux anciennes bases et attribue un jeton aux devis
historiques qui en sont dépourvus, sans changer leurs données client ou prix.
Les tests utilisent uniquement des bases temporaires ; la base réelle locale
n’a pas été migrée pendant ce chantier.

Toutes les routes PDF et les lectures JSON/HTML exposant un devis exigent son
jeton exact `?token=…` ou une session de portail signée, appartenant à un compte
actif autorisé. Un jeton ne permet de consulter que son propre devis. La
comparaison se fait avec `secrets.compare_digest`. Les réponses privées portent
`Cache-Control: private, no-store` et `Referrer-Policy: no-referrer`.

FastAPI transmet le jeton et, lorsqu’il existe, le cookie de session à Flask.
La présence d’un cookie ou d’un JWT client ne constitue pas une autorisation.
Une requête sans jeton ni cookie renvoie directement HTTP 403 avec le message
`Accès non autorisé à ce devis. Jeton de consultation requis.`. Flask vérifie
les autres cas. Les redirections de connexion et les réponses HTML ne sont pas
renvoyées comme des PDF. Les erreurs réseau ne reproduisent pas le jeton privé.

Les réponses de création, les liens WhatsApp et les cartes de l’assistant
contiennent les liens protégés. Flutter conserve le jeton dans son historique
et l’ajoute aux téléchargements et liens de secours reconstruits.

Après déploiement, les anciens liens sans jeton répondent HTTP 403 pour les
visiteurs. Un utilisateur du portail autorisé peut toujours ouvrir le devis
et récupérer un nouveau lien protégé. Ne pas retirer le paramètre `token`
des liens partagés ; toute personne possédant le lien peut consulter ce devis.

## Maintenance et réactivité

Le contrôle FastAPI utilise exclusivement `scope.path` et `scope.root_path`.
Un middleware extérieur refuse les Host malformés ou inconnus avant CORS et
maintenance. La liste peut être définie par `TRUSTED_HOSTS` dans l’environnement
du processus ; les détails figurent dans [le guide de déploiement](maintenance_deployment.md).

Les contrôles métier anonymes réutilisent un cache mémoire de 15 secondes.
À expiration, les requêtes concurrentes partagent une seule actualisation
asynchrone. Aucune attente réseau n’est enfermée dans un verrou global. Le canal
de suivi peut actualiser l’état toutes les secondes. Les sessions administrateur
restent vérifiées par Flask et leurs exemptions ne sont jamais mises en cache.
En cas de panne, seul le dernier état public vérifié est repris ; si aucun état
n’est connu, la requête reçoit HTTP 503. Le cache est indépendant par processus.

L’assistant injecte le texte entier, les cartes et les actions dès réception de
la réponse et réactive immédiatement l’envoi. Le défilement animé est conservé.
Le timer de frappe, son état et le curseur devenus inutiles sont supprimés.
Le délai réseau ou de génération de la réponse reste dépendant du service amont.

Un défaut préexistant de `SingleFlight`, qui laissait une exception non observée
dans un Future sans suiveur, est également corrigé pour remettre la suite backend
au vert. Les erreurs continuent de parvenir aux appelants et une nouvelle tentative
reste possible.

## Validation

Les tests vérifient notamment les refus sans jeton, les jetons invalides ou
appartenant à un autre devis, les sessions désactivées/non autorisées, la migration
idempotente, les Host malveillants, les deux conventions `root_path`, le partage
des actualisations, le secours après panne et l’affichage sans délai de frappe.
Les connexions externes des suites Python sont bloquées ; aucun service réel,
commande, notification ou devis client n’est sollicité.

| Vérification | Résultat |
| --- | --- |
| Suite FastAPI complète | 234 tests réussis ; 1 avertissement de dépendance |
| Suite Flutter complète | 139 tests réussis ; 1 test réservé au Web ignoré par le runner VM |
| Suite Flask complète puis reprise ciblée | 505 cas distincts validés ; détail ci-dessous |
| Analyse statique Dart | Aucun diagnostic |
| 10 contrôles maintenance simultanés, cache rempli | 0,405 ms ; aucun nouvel appel amont |
| Préservation des fichiers exclus | 14 empreintes SHA-256 identiques |

La mesure de maintenance est locale, avec un transport HTTP simulé qui attend
50 ms lors du remplissage initial. Elle mesure les lectures du cache du service,
pas le délai réseau d’un navigateur ou d’un contrôle à froid. Le test de réponse
assistant vérifie le texte complet sans avancer l’horloge après réception ; il
force seulement la construction de la longue bulle dans la liste différée. Les
animations du bouton et du défilement ont ensuite le temps de se terminer.

La suite Flask complète a produit 502 réussites et 3 échecs liés à l’en-tête
`Cache-Control` des réponses maintenance 503. Le garde PDF ajoutait son en-tête
privé en remplaçant le `no-store` existant. L’ajout utilise désormais `setdefault`
pour préserver cet en-tête. Après cette correction, les 38 tests maintenance,
PDF/JSON, sessions et migration ont tous réussi, y compris les 3 cas concernés.
Les 505 cas distincts sont ainsi validés entre le lancement complet et la reprise
ciblée ; il ne s’agit pas d’un unique lancement complet à 505 réussites.

## Mise en service

Déployer et redémarrer Flask puis FastAPI, avec un Host autorisé transmis par le
reverse proxy, et reconstruire/publier Flutter. La migration de jetons s’exécute
au démarrage de Flask ; les liens protégés sont nécessaires dès cette version.
Aucun déploiement distant n’est effectué par ces modifications locales.
