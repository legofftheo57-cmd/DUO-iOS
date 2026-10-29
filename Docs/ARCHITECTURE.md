# Architecture et invariants

## Séparation

SwiftUI → AppStore (`@MainActor`, Observable) → DUOCore. Le noyau ne dépend pas de SwiftUI, Security ni du réseau. `DiskStore` gère les instantanés ; `Backend` utilise URLSession ; `Keychain` conserve les jetons. Aucune dépendance iOS tierce n’est nécessaire.

Le format de persistance v1 est un document JSON Codable protégé par iOS et écrit atomiquement. Choix retenu plutôt que SwiftData pour garder les opérations stock/repas/courses et leur file de synchronisation dans une seule écriture locale, avec un moteur portable testable sous Linux. Ce choix vise deux personnes et un volume modéré, pas une grande base de données. Le plafond serveur est 20 000 enregistrements, tombstones compris ; archivage/purge futurs nécessaires avant cette limite.

## Données

| Modèle | Informations |
|---|---|
| Food | Nom, quantité, unité explicite, catégorie, emplacement, date limite facultative, ajout |
| Recipe | ID stable, titre, portions, temps, ingrédients, étapes, allergènes, famille |
| Meal | Recette, date, portions, confirmation de cuisson |
| Shopping | Ingrédient/quantité/unité, catégorie, acheté, origine générée/manuelle |
| HouseTask | Titre, attribution stable, échéance, intervalle de récurrence en jours, date de validation |
| Event | Titre, début/fin absolus, fuseau d’origine, séance de sport ou événement |
| Habit | Titre, objectif hebdomadaire en jours, dates de validation |
| Record | UUID, foyer, propriétaire privé facultatif, révision serveur, tombstone, contenu typé |
| Snapshot | Version de schéma, identité, foyer, records, IDs en attente, conflits |

Les dates Codable sont numériques (référence Foundation 2001), y compris dans JSONB. Aucun serveur ne les confond avec des timestamps Unix : le serveur compare les nombres sans conversion ; les expirations d’invitation sont de vrais timestamptz PostgreSQL. Le planning et les récurrences utilisent Calendar et le fuseau local. Les événements stockent des instants absolus et leur fuseau initial.

## Quantités et repas

Pas de conversion arbitraire entre masse, volume et pièces. g/kg et ml/l sont convertibles. Noms normalisés sans casse/accents, sans équivalence implicite entre produits différents. Une pièce reste entière, arrondie vers le haut pour les portions. Les lots sont consommés par date limite croissante, et une date dépassée n’est pas utilisable dans le calcul. Il reste à interpréter séparément DLC/DDM dans une version future ; le libellé courant est volontairement « à vérifier ».

Le planificateur utilise une heuristique : peu d’achats, familles variées, limitation des répétitions. Il ne garantit ni minimum global de coût, ni équilibre nutritionnel médical. Le stock est alloué une fois par repas chronologique et selon sa validité à la date de ce repas. Les besoins sont mutualisés ; les articles manuels déjà prévus couvrent une partie de la liste générée. Les articles cochés ne deviennent pas silencieusement du stock.

`PurchasePrice` et le calcul d’achat par paquet sont présents dans le noyau et testés avec des données synthétiques. Aucune source réelle ni écran de saisie de prix n’est connecté : l’interface affiche donc systématiquement « budget non vérifiable » et ne garantit pas 35 €.

## Transactions et synchronisation

Les changements locaux et les IDs à envoyer sont persistés ensemble. L’application ne remplace pas une modification locale pendant une requête : l’édition est suspendue durant la synchronisation. Le serveur traite le lot entier dans une transaction sous verrou du foyer ; chaque révision attendue doit correspondre. Un conflit fait échouer tout le lot, sans écriture partielle.

Le client commence par lire l’état distant. En cas de divergence avec une modification locale en attente, les deux versions sont conservées et un choix explicite est proposé. Les suppressions restent des tombstones et sont reçues par l’autre appareil. Une restauration explicitement choisie après suppression crée un nouvel ID. Deux validations simultanées d’une tâche récurrente ciblent un ID de successeur déterministe, ce qui évite de créer deux occurrences indépendantes.

Le transport est différé, par lecture du foyer et envoi des mutations, au premier plan toutes les 30 secondes et manuellement. Pas de WebSocket, push silencieux ni synchronisation garantie en arrière-plan. Les jetons sont renouvelés ; les erreurs réseau laissent les modifications sur disque. Si une réponse d’écriture est perdue, une prochaine lecture reconnaît les valeurs déjà appliquées et acquitte la mutation sans la rejouer.

Un cache distinct est utilisé pour chaque couple compte/foyer. Se connecter n’importe ni n’envoie les données du mode local. La déconnexion revient à ce mode et conserve les caches sur l’appareil, sans les mélanger. Prévoir une fonction de suppression explicite des caches et d’export utilisateur avant ouverture plus large.

## Sécurité

RLS activée sur toutes les tables. Les rôles clients ne peuvent écrire directement dans aucune table. `members` expose seulement l’appartenance du demandeur. Les RPC `SECURITY DEFINER` utilisent un `search_path` vide, des noms qualifiés, vérifient `auth.uid()` et les appartenances. Chaque foyer accueille au plus deux comptes, y compris lorsque les invitations sont concurrentes grâce au verrou du foyer.

Une invitation est un secret aléatoire issu de deux UUID, haché SHA-256 en base, valable 24 heures et utilisable une fois. Créer un nouveau code révoque le précédent. Les tables d’invitations ne sont pas lisibles par les clients. Le code est transmis manuellement par l’utilisateur ; l’application n’envoie pas de message à son partenaire.

Les données privées ont `owner_id = auth.uid()` ; la visibilité est fixée à la création et ne peut pas être modifiée par une écriture. Le client ne contient que la clé publique Supabase. Les jetons sont dans le Keychain, accessibles appareil déverrouillé et non transférables vers un autre appareil. Les fichiers locaux sont exclus des sauvegardes cloud.

Les RPC limitent taille et volume de lots, et valident les règles quantitatives principales côté serveur. Elles ne constituent pas une validation exhaustive de chaque sous-champ JSONB ; renforcer les formats/dates et les limites de tableaux avant exposition publique.

## Migrations

Le schéma local v1 est accepté et validé ; toute version inconnue ou donnée corrompue produit une erreur sans effacer le fichier. Aucun format natif antérieur n’existe : pas de migration fictive depuis le prototype web. Pour v2, ajouter une transformation explicite testée sur copie. La migration SQL initiale n’est pas idempotente : l’appliquer une seule fois sur un projet de test vide approuvé, avec suivi de version Supabase.
