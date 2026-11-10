# DUO — Cartographie des branches et stratégie de livraison
_Date : 10 novembre 2026. État vérifié via GitHub (branches, commits, comparaisons) ; aucune fusion ni déploiement._

## Principes de travail

1. **Une branche n'est pas un produit livré.** Il faut démontrer compilation, tests pertinents et essai sur téléphone avant de marquer une fonction « fonctionnelle ».
2. Ne jamais écraser les commits des branches existantes ni effacer une branche avant d'avoir contrôlé ses différences.
3. Conserver la version Solo déjà validée comme référence de première installation ; développer les nouvelles fonctions à part.
4. Préparer la livraison à deux appareils en intégrant et testant la synchronisation, jamais en changeant seulement un drapeau.
5. Les frais, mises en production, comptes réels et autorisations bancaires demandent un accord explicite.

## Branches inventoriées

| Branche | Utilité avérée d'après l'historique | Relation avec Solo | État réel / action |
|---|---|---|---|
| `main` | Base native historique DUO 0.5.0, code et migrations initiaux | 73 commits derrière la branche Solo au 10/11 | **N'est pas la version à installer**. Ne pas fusionner Solo sans audit final. |
| `fix/joe-reschedule-and-core-checks-20261029` | Correction du déplacement de tâches de Joe, révisions de la synchronisation, tests de contrat/session, revue sécurité | **Divergente** de Solo : 22 commits propres à cette branche ; elle ne lui est pas ancêtre | **Audit indispensable** : identifier les corrections non reprises avant tout objectif « synchronisé à deux ». PR #1 encore en brouillon. Aucun merge aveugle. |
| `work/invitation-revocation-20261030` | Révocation des invitations par l'utilisateur et tests SQL des accès | **Ancêtre** de Solo (67 commits supplémentaires vers Solo) | Conserver comme jalon ; ses modifications sont dans l'historique de Solo. Fonction serveur non validée sur un backend hébergé. |
| `work/sync-session-safety-20261103` | Protection contre changement de session durant la synchro, conservation des changements non transmis | **Ancêtre** de Solo (63 commits supplémentaires) | Conserver comme jalon ; essais réels hors-ligne/reconnexion et deux comptes encore nécessaires. |
| `work/backend-origin-guard-20261104` | Empêcher les requêtes authentifiées vers une autre origine que le projet Supabase configuré | **Ancêtre** de Solo (62 commits supplémentaires) | Garde-fou inclus dans l'historique Solo ; vérifier sur backend réel. |
| `work/fix-duopanel-compile-20261105` | Correction de conflit de type SwiftUI `ViewModifier.Content` / `DUOCore.Content` | **Ancêtre** de Solo (61 commits supplémentaires) | Correctif inclus dans Solo et suivi de compilations CI. |
| `work/solo-iphone-install-20261105` | Interface accueil/tâches/courses/planning/« Nous deux », mode local iPhone, tests, génération IPA et procédure Windows + Sideloadly | **Branche de référence actuelle pour l'installation Solo** ; tête `4904ee2d` | **CI réussie le 05/11 sur `0ed8a881`** : tests Swift, compilation simulateur/iPhone, tests UI ciblés, IPA non signé. Les 2 commits suivants sont documentaires. **Installation physique non validée ; deux iPhone non synchronisés.** |
| `work/budget-couple-local-20261110` | Démonstrateur écran Budget local avec saisies manuelles, protection fichier, revenus/dépenses/épargne | Créée depuis Solo ; +1 commit applicatif `a8936438` initialement | **Non compilée ni testée** à date ; aucune donnée bancaire réelle, aucune synchro de finances. À conserver comme branche de travail isolée et faire évoluer après validation des règles métier. |

## Résultats CI réellement vérifiés

- `https://github.com/legofftheo57-cmd/DUO-iOS/actions/runs/42097144430` : `completed/success`, branche Solo, SHA `0ed8a88156dd578d42dc0df4f5f4ac2619c7f214`, 5 novembre 2026.
- Le document `Docs/DUO-WINDOWS-PREMIERE-INSTALLATION-06-11-2026.md` référence l'artefact **DUO-solo-validated-0ed8a881...** contenant un IPA **non signé**, à signer sous Windows.
- Aucune preuve d'essai de DUO sur le téléphone réel ; aucun backend Supabase hébergé ni synchronisation Théo/Lilou validés.
- La branche Budget n'a **aucun** run CI validant ses nouveaux changements. Ne pas utiliser son IPA tant que la CI n'a pas réussi.

## Ordre de consolidation / « definition of done »

1. **Installer et tester Solo** : signer l'IPA déjà validé, ouvrir sur iPhone ; tester ajout/modification/suppression, retour en arrière, redémarrage, export JSON ; reproduire tout défaut.
2. **Auditer la branche divergente Joe** : comparer ses fonctions/tests contre Solo ; porter seulement les protections utiles manquantes avec tests, sans fusionner 22 commits à l'aveugle.
3. **Finaliser les règles financières dans un module indépendant** : modèles testables (comptes, soldes horodatés, opérations, virements, objectifs, visibilité des données). Refuser toute erreur de total, doublon, confusion entre argent réel et prévisions.
4. **Vérifier la connexion bancaire en sandbox** avec les banques réellement utilisées, un prestataire autorisé, sans frais ni secrets embarqués ; puis autorisation utilisateur explicite pour la production.
5. **Activer/tester Supabase pour les deux appareils** (authentification, RLS, révocation, conflits, hors-ligne, déconnexion, effacement), protection de la visibilité privée/partagée par compte.
6. **Compiler et tester l'application complète** sur simulateur et deux iPhone, vérifier que les fonctions principales se comportent correctement avec et sans réseau.
7. Seulement après : version « DUO à deux » acceptée ; ne pas confondre « build réussi » avec « testé de bout en bout ».

## Politique de fusion

- Préférer une **PR explicite vers la prochaine branche d'intégration** avec les tests et une liste des fonctions touchées.
- Aucune suppression de branche avant comparaison et conservation de l'historique.
- Aucune publication, dépense, collecte de données bancaires, création de compte externe ou déclenchement de CI payante sans consentement.
