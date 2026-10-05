Audit de la recherche catalogue — 5 octobre 2026

Les constats suivants décrivent l'état avant correction. Les corrections
appliquées et leur validation figurent en fin de document.

La recherche fonctionne pour plusieurs modèles et références exactes, mais elle
ne retrouve pas tous les produits pertinents. Les deux défauts prioritaires sont
la limitation des résultats à dix produits et le filtrage trop strict des
variantes de saisie. Les constats ci-dessous portent sur le code actuel et sur
l'API locale `http://127.0.0.1:8011`, connectée au catalogue réel.

Des requêtes GET ont été utilisées pour les vérifications réelles. Les tests
Flutter supplémentaires ont été exécutés dans `mobile/.dart_tool/search_audit/`
avec des réponses simulées. Aucun correctif applicatif n'a été appliqué pendant
cet audit.

1. **Priorité élevée : résultats tronqués et pagination incomplète.**

   Le client backend utilise la ressource PrestaShop `search`, avec uniquement
   `query` et `language`.
   [Client PrestaShop](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/clients/prestashop.py:136).
   Le [code officiel de cette ressource](https://github.com/PrestaShop/PrestaShop/blob/develop/classes/webservice/WebserviceSpecificManagementSearch.php)
   appelle le moteur en mode AJAX ; le [moteur officiel](https://github.com/PrestaShop/PrestaShop/blob/develop/classes/Search.php)
   limite ce mode à dix produits. Le comportement observé sur l'API locale est
   cohérent avec cette limite.

   `panneau`, `batterie` et `onduleur` renvoient chacun dix produits, même avec
   `page_size=100`. Pour `panneau`, une taille de page de cinq donne cinq produits
   en page 2, puis aucun en page 3. Le backend découpe uniquement les identifiants
   déjà obtenus : il ne récupère pas les correspondances suivantes.
   [Pagination backend](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/services/catalog.py:398).

   Preuve d'omission : `batterie` ne renvoie ni le produit 330 DEYE SE-F5 ni le
   produit 328 DEYE SE-F12, alors que `batterie deye` les retrouve. De même,
   `onduleur` manque le MUST 340 que `PV18-3624 ECO` retrouve.

   Flutter attend trente produits par page et arrête de paginer dès qu'il en
   reçoit moins. Les dix résultats deviennent donc la liste complète affichée.
   [Fin de pagination Flutter](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/catalog/presentation/catalog_screen.dart:218).
   Le filtre catégorie est également appliqué après cette sélection limitée :
   il peut exclure les premiers résultats sans récupérer ceux de la catégorie
   situés plus loin dans les correspondances.

   **Correction recommandée :** exposer une véritable recherche paginée avec
   `total` et `has_more`, puis faire utiliser ces informations par Flutter.
   Augmenter seulement `page_size` sur l'API mobile ne supprime pas la limite
   du moteur appelé.

2. **Priorité élevée : accents, unités et fautes de frappe produisent des omissions.**

   Le filtre local abaisse la casse et exige la présence littérale de chaque
   terme dans le nom, la référence ou la description courte. Il ne normalise
   pas les accents, les décimales ou les exposants.
   [Filtre de correspondance](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/services/catalog.py:528).

   | Saisie testée | Résultat observé |
   | --- | --- |
   | `câble` | Retrouve les câbles KBE 313 et 315. |
   | `cable` | Un autre résultat ; les KBE 313 et 315 sont absents. |
   | `électrogène` | Dix résultats. |
   | `electrogene` | Aucun résultat. |
   | `3.6kW` | Retrouve notamment le MUST 340. |
   | `3,6 kW` | Aucun résultat. |
   | `10mm²` | Retrouve le câble KBE 315. |
   | `10mm2` | Aucun résultat. |
   | `baterie` | Aucun résultat. |
   | `JA` | Aucun résultat ; `JA Solar 715W` retrouve le panneau 339. |

   Le cas `JA` ne permet pas, à lui seul, d'établir quel réglage de
   l'index PrestaShop bloque le terme court. Il confirme néanmoins que cette
   saisie courante ne fonctionne pas actuellement.

   **Correction recommandée :** normaliser les textes et les requêtes de manière
   cohérente, gérer les variantes d'unités et proposer des suggestions en cas de
   faute. Vérifier que le filtre local conserve les correspondances légitimes
   du moteur, y compris ses éventuels alias ou corrections orthographiques.

3. **Priorité moyenne : mélange de deux recherches pendant le debounce.**

   La saisie déclenche une attente de 350 ms sans invalider immédiatement la
   pagination de la liste affichée. Pendant cette attente, `_loadMore()` lit le
   nouveau texte du champ et ajoute ses résultats aux anciens produits.
   [Changement de saisie](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/catalog/presentation/catalog_screen.dart:104),
   [Chargement de la page suivante](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/catalog/presentation/catalog_screen.dart:243).

   Reproduction Flutter confirmée : trente produits d'une liste précédente,
   saisie d'une nouvelle recherche, défilement immédiat ; la requête part avec
   la nouvelle recherche en page 2 et son produit est ajouté aux trente anciens.
   La première page de la nouvelle recherche corrige ensuite cette liste.

   **Correction recommandée :** figer requête, catégorie, langue et devise
   pour chaque génération de résultats ; invalider les requêtes précédentes
   dès le changement de saisie et suspendre la pagination pendant le debounce.

4. **Priorité moyenne : erreurs de préchargement non interceptées.**

   `prefetchProducts()` lance une Future sans gestion d'erreur. Le scénario
   simulant une réponse 503 confirme qu'une DioException arrive au gestionnaire
   des erreurs asynchrones non interceptées.
   [Préchargement](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/catalog/data/catalog_repository.dart:112).

   **Correction recommandée :** intercepter les échecs du préchargement et
   mutualiser les requêtes identiques en cours. Annuler les requêtes devenues
   inutiles réduirait aussi le travail réseau lors de recherches successives.

5. **Priorité moyenne : cache des catégories indépendant de la langue.**

   Une seule valeur est mémorisée pendant cinq minutes. Dans le scénario testé,
   la lecture en langue 1 puis en langue 2 retourne deux fois le libellé de
   langue 1, avec un seul appel réseau.
   [Cache des catégories](C:/Users/hp/Desktop/heliantha_mobile_starter/mobile/lib/features/catalog/data/catalog_repository.dart:20).

   **Correction recommandée :** inclure l'identifiant de langue dans la clé
   du cache ou invalider ce cache au changement de langue.

6. **Points complémentaires à améliorer.**

   - La route backend limite la recherche à 120 caractères ; le champ Flutter
     n'impose pas cette limite. Une saisie de 121 caractères renvoie HTTP 422.
     [Validation API](C:/Users/hp/Desktop/heliantha_mobile_starter/backend/app/api/routes/catalog.py:100).
   - Les requêtes observées sans cache ont pris environ 1,3 à 4,9 secondes.
     Ces mesures locales, réalisées avec jusqu'à trois lectures simultanées,
     constituent un échantillon et non un benchmark de charge.
   - Les caches de listes Flutter et backend ne disposent pas d'une capacité
     maximale ni d'un nettoyage global régulier des anciennes clés. Le backend
     retire une clé expirée lorsqu'elle est relue.
   - Les titres du catalogue contiennent des éléments comme `copy of` et
     `ariateur Solaire`. Un nettoyage des titres et des références, suivi d'une
     vérification de l'index, améliorerait les résultats et leur lisibilité.

Des mécanismes utiles sont déjà présents : debounce de 350 ms, transmission
encodée des recherches depuis l'accueil, filtrage des produits actifs, cache
des produits tenant compte de la page, de la langue et de la devise, et protection
contre une ancienne réponse lorsque la nouvelle recherche a déjà démarré.
Cette dernière protection a été vérifiée par un scénario Flutter dédié.

Validation réalisée : sept tests backend du catalogue réussis et quatre
scénarios Flutter d'audit réussis. Ces scénarios documentent le comportement
actuel, y compris les défauts reproduits ; ils ne prouvent pas leur correction.
Les tests backend existants couvrent l'appel à la recherche native et
l'exclusion de résultats non pertinents, mais pas une recherche exhaustive
au-delà de dix correspondances ni les variantes de saisie ci-dessus.

Ordre recommandé : pagination exhaustive, normalisation des correspondances,
gestion des requêtes concurrentes, puis préchargement, caches et suggestions UX.

Corrections appliquées — 5 octobre 2026

Les cinq anomalies principales sont corrigées côté FastAPI et Flutter.
Le dossier `prestashop_bridge_example` n'a pas été modifié.

- La recherche FastAPI lit tous les produits actifs via la ressource standard
  `products`, par lots de 100. Elle ne dépend plus de l'autocomplétion `search`
  limitée à dix correspondances. Un index temporaire par boutique et langue,
  conservé 60 secondes, mutualise les lectures concurrentes. Une lecture en
  erreur ne publie pas d'index incomplet. Les prix et stocks des seuls produits
  de la page sont ensuite récupérés par le circuit catalogue existant.
- La même normalisation s'applique aux requêtes et aux noms, références et
  descriptions courtes : accents, exposants, décimales, espaces entre valeur et
  unité et séparation des termes. Tous les termes doivent correspondre. Le
  filtre catégorie, descendants compris, s'applique aux correspondances
  complètes avant pagination.
- La taille de page par défaut est de 30. `/v1/products` fournit `items`,
  `page` et `has_more`, et conserve `data` et `meta` pour les consommateurs
  existants. La recherche et les catégories fournissent aussi `meta.total`.
  La liste sans filtre utilise une ligne supplémentaire pour déterminer
  précisément s'il reste une page, y compris lorsque la dernière est pleine.
- Flutter invalide immédiatement les requêtes précédentes au changement de
  saisie. La pagination est suspendue pendant les 350 ms de debounce ; requête,
  catégorie, langue et devise sont figées pour chaque liste. Les réponses
  obsolètes sont ignorées, y compris après effacement du champ. La pagination
  utilise `has_more`, sans déduire sa fin du nombre de lignes reçues.
- Les erreurs du préchargement sont interceptées silencieusement et une
  requête au premier plan peut réessayer. Les lectures identiques en cours
  sont mutualisées. Le cache des catégories utilise une clé
  `categories_<languageId>`. Les caches de pages sont bornés à 128 entrées
  côté Flutter et 256 côté FastAPI ; l'index est borné à huit entrées.

Vérification sur le catalogue réel, par requêtes GET uniquement :

| Vérification | Résultat après correction |
| --- | --- |
| `câble` et `cable` | Mêmes produits : 315, 313, 140. |
| `3,6 kW` et `3.6kW` | Mêmes produits : 340, 165. |
| `10mm²` et `10mm2` | Même produit : 315. |
| `batterie` | 22 produits, dont DEYE SE-F5 330 et SE-F12 328. |
| `panneau` | 13 produits, sans troncature à dix. |
| `onduleur` | 106 produits : pages de 30, 30, 30 et 16 ; aucun doublon. |

Validation complète : `pytest tests/` **116 tests réussis**, `flutter test`
**84 tests réussis**, `flutter analyze` **aucun problème**. Les commandes
Flutter ont utilisé `--no-pub`, avec les dépendances déjà installées.
Pytest conserve un avertissement de dépréciation préexistant dans
Starlette/AnyIO, sans échec de test.

Les nouveaux tests couvrent notamment un catalogue de 125 correspondances,
les dernières pages pleines et vides, les catégories descendantes au-delà des
dix premiers résultats, la langue et l'expiration de l'index, ainsi que les
réponses concurrentes et les échecs de préchargement Flutter.

La première recherche après expiration peut nécessiter une lecture complète
du catalogue. Le cache évite de refaire cette lecture pour chaque saisie.
Les suggestions pour fautes de frappe et le nettoyage des titres du catalogue
restent des améliorations distinctes ; ces corrections n'introduisent pas de
recherche approximative.
