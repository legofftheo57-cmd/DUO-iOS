> **Archive historique 0.2.0 uniquement.** Les nouveaux travaux figurent dans `REPRISE-0.3.0.md` ; les chiffres ci-dessous ne valident pas la migration 002.

# Rapport de qualité — DUO 0.2.0

29 octobre 2026. Statut : **source native développée, noyau et règles SQL testés ; application iOS non compilée, distribution bloquée jusqu’aux validations Apple et réseau.**

## Environnement réellement utilisé

Ubuntu 24.04 x86_64. Swift 6.0.3 officiel pour Linux ajouté dans l’environnement temporaire, compilation avec un seul job. XCTest via Swift Package Manager. PostgreSQL 18.6 embarqué dans PGlite 0.5.13, Node.js. Analyseurs tree-sitter-swift, pglast et openstep-parser, Python 3. Aucun macOS, SDK iOS, Xcode, simulateur Apple, certificat, compte Developer ou projet Supabase hébergé disponible.

## Résultats exécutés

| Vérification | Résultat | Preuve |
|---|---|---|
| Compilation et tests Swift DUOCore | **49 tests réussis, 0 échec** | `swift-test-final.log` |
| Migration et sécurité SQL sur PostgreSQL embarqué | **31 scénarios réussis, 0 échec** | `backend-tests.json`, `backend-tests.log` |
| Syntaxe Swift/SQL, ressources, références Xcode et contrastes opaques | **69 contrôles réussis, 0 échec** | `static-checks.json` |
| Parsing des sources SwiftUI/XCUITest par le frontend Swift | Terminé sans erreur syntaxique | `swift-ui-parse.log` (vide en cas de succès) |
| Compilation avec SDK iOS et liaison de l’app | **Non exécutée** | Xcode/macOS absents |
| XCUITest : 4 méthodes préparées | **Non exécutés** | Simulateur iOS absent |
| Auth réelle, Keychain, deux comptes/appareils, réseau interrompu | **Non exécutés** | Backend hébergé et environnement Apple absents |
| Signature, archive .ipa, installation, TestFlight | **Non exécutés** | Préconditions absentes |

La ligne Swift Testing indiquant « 0 tests » à la fin du journal correspond à un autre runner vide. Les **49 tests exécutés sont les tests XCTest**, détaillés juste avant. Ne pas additionner les contrôles statiques aux tests fonctionnels pour prétendre que l’application a été intégralement testée.

## Couverture du noyau

Conversions g/kg et ml/l, incompatibilité masse/volume, quantités négatives/NaN/nulles, pièces entières, noms vides, normalisation, portions, arrondis, recette absente, stock déduit une seule fois, lots multiples, dates limites à la date du repas, repas cuisinés, exclusions, variété, absence/péremption des prix, arrondi par paquet, consommation FEFO, échec sans modification partielle, thème traversant minuit, horaires égaux, récurrence et changement d’heure Europe/Paris, identité stable de l’occurrence suivante, chevauchement, progression hebdomadaire, persistance de l’outbox, schéma inconnu/corruption, refus d’identité étrangère, confidentialité, conflits conservés et suppressions.

## Couverture SQL

Installation de la migration réelle, création du foyer, unicité d’appartenance, création/rédemption/rejeu du code, capacité de deux membres, création/édition d’enregistrements, confidentialité via RLS et RPC, interdiction de deviner un ID privé, révision obsolète ou absente, valeurs négatives/pièces fractionnaires, refus des écritures directes, rollback atomique d’un lot, isolation de deux foyers, refus d’usurpation de foyer/ID/appartenance, tombstones, absence de résurrection silencieuse, refus des rôles anonymes et absence d’identité.

La base utilise une fonction auth.uid() synthétique pour quatre identités fictives. Il s’agit d’exécution SQL réelle, mais pas d’un test Supabase Auth/JWT/HTTP. Les écritures obsolètes sont simulées séquentiellement ; la concurrence réseau réelle et les verrous avec plusieurs connexions doivent encore être testés sur PostgreSQL/Supabase hébergé.

## Défauts identifiés et corrigés

1. Ancien livrable web non natif : création d’un projet SwiftUI distinct, sans modifier le prototype.
2. Prix fictifs et unités ambiguës du prototype : aucun prix repris, quantités/unité/dimension explicites.
3. Risque de réutiliser le stock pour plusieurs repas : allocation mutualisée, puis chronologique tenant compte des expirations futures.
4. Risque d’effacer un changement simultané : révisions contrôlées côté serveur et conservation des deux versions.
5. Suppression non propagée / retour silencieux d’un élément : tombstones et protection serveur ; restauration explicite sous nouvel ID.
6. Révision absente pouvant contourner le contrôle SQL : refus explicite.
7. Deux validations simultanées d’une tâche récurrente : ID de successeur déterministe.
8. Prix périmés, futurs, partiels ou unités incompatibles : coût inconnu plutôt que montant inventé.
9. Contraste du texte secondaire sur Surface : référence conservée, variante lisible ajoutée et contrôlée.
10. Accolade manquante dans un écran : détectée par parsing, corrigée.
11. Première compilation Swift parallèle interrompue dans l’outil ; expression de planification simplifiée, exécution relancée avec un seul job et répertoire de build isolé. Les 49 tests de la version finale passent.
12. Risque de réinitialiser des données incompatibles : erreur explicite, fichier conservé.
13. Attribution des tâches affichée comme identifiant technique : conversion en libellés « Moi », « Mon partenaire », « Ensemble ».
14. Rappels obsolètes : annulation locale après édition/suppression/validation et pour les tâches reçues terminées ou supprimées.

## Limitations et défauts potentiels restant ouverts

- Le typage SwiftUI, la liaison, les API Apple, la navigation et le rendu restent **non vérifiés**. Une analyse syntaxique ne permet pas de les certifier.
- Le cycle Auth/PostgREST, les codes HTTP, le renouvellement des jetons et la sauvegarde Keychain ne sont pas testés sur appareil. Aucun backend n’est configuré par défaut.
- Les 4 XCUITest ne couvrent pas encore exhaustivement chaque bouton, les changements d’apparence, la suppression, la génération de menus et les conflits. Compléter après la première compilation.
- Pas de synchronisation en arrière-plan ; interrogation au premier plan toutes les 30 secondes. Les caches volumineux et les limites de 2 000 mutations par lot / 20 000 lignes doivent recevoir une pagination/compaction avant usage à long terme.
- Une notification existante sur l’autre iPhone n’est retirée qu’après sa prochaine synchronisation.
- Les exclusions reposent sur noms exacts normalisés et allergènes du catalogue. Pas d’analyse exhaustive des traces, des marques ni des synonymes.
- La confidentialité des comptes séparés est assurée par les chemins de cache et l’UI, pas par un verrou biométrique propre à DUO. Une personne ayant accès à l’iPhone déverrouillé peut accéder au mode local.
- Récupération de mot de passe, suppression autonome de compte, export/suppression des caches et validation de la notice de confidentialité restent à développer avant diffusion à des tiers.
- Les migrations futures sont préparées par version et refus sûr, mais aucune migration v1→v2 n’a encore de raison d’exister ni de test.
- Aucun prix magasin, aucune garantie du budget, aucune intégration calendrier/HealthKit/code-barres ; voir `FONCTIONNALITES.md`.

## Critère de livraison iPhone

Ne déclarer « application prête » qu’après compilation SDK iOS, exécution des parcours et audits d’accessibilité, authentification réelle, tests deux comptes hors ligne/reconnexion, correction des défauts observés et installation signée. Aucune publication ni dépense effectuée pendant cette mission.
