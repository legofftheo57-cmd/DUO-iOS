# DUO — Livraison du 10 novembre 2026

## Deux versions clairement distinctes

**À installer maintenant pour les premiers essais : Solo `0ed8a88156dd578d42dc0df4f5f4ac2619c7f214`.**
Le job GitHub `127490042656`, run `42097144430`, confirme la réussite des tests noyau, builds simulateur/iPhone, tests UI sélectionnés et petit écran. Ce résultat date du 5 novembre, pas d'une nouvelle exécution aujourd'hui. L'essai sur iPhone physique reste à faire.

**Nouveaux développements : `work/integration-daily-20261110`.** Créée depuis Budget `4eb4524ff6490d52f0119f79094a05b95e70f04c`. Les nouveaux écrans ne sont pas dans l'IPA Solo. Pas de nouveau build iOS produit. Ne pas distribuer la branche d'intégration comme une version iOS validée.

## Sauvegarde du build existant

- Run : https://github.com/legofftheo57-cmd/DUO-iOS/actions/runs/42097144430
- Artefact : `13450945369`, `DUO-solo-validated-0ed8a88156dd578d42dc0df4f5f4ac2619c7f214`, non expiré ; expiration annoncée le 5 décembre 2026.
- Copie durable sur cette branche : `Artifacts/DUO-solo-validated-0ed8a881.zip` (octets téléchargés depuis GitHub, sans recompilation).
- SHA256 archive : `f924535655d33fed0dad4524c4de587f28d61eba456e7fe83c4b110381522c7d`.
- SHA256 IPA : `d89a1b02f7c8ef9cc0ee91f8201d58ec685fe44c45971fb8654e687d81384622`.
- Vérifiés : archive lisible, empreinte d'archive identique au digest GitHub, empreinte IPA identique au fichier SHA256SUMS, SOURCE-COMMIT exact, Info.plist : bundle `fr.theolegoff.duo.dev`, iOS minimum 17.0, version 0.5.0 build 3.
- Ce contrôle n'est ni une signature Apple ni un test d'installation physique.

## Modifications concrètes

- Reprise ciblée de Joe : ne plus tronquer la fin des noms comme « Yoga » ; deux tests repris de la branche divergente.
- Reprise de `SyncContract` et de tests de sécurité : contrôle des réponses serveur, identité/visibilité/révision/payload, confirmations complètes avant retrait des modifications en attente ; refus des révisions anciennes et des titres >200 caractères. Aucun backend déployé.
- Tâches : attribution locale Théo/Lilou/Ensemble disponible en Solo, comptes de tâches terminées dans la semaine, indication des retards. Pas de score d'effort inventé.
- Moteur des tâches récurrentes extrait et testé : réouverture protégée, prochaine occurrence modifiée conservée, double clic/stale action refusé, sauvegarde/restauration du cycle.
- Éditeurs/actions : refus de modifier un ancien état après suppression ou modification ; une confirmation de cuisson obsolète ne peut pas consommer le stock deux fois.
- Courses : ajout fusionné par ingrédient et dimension avec conversion g/kg ou ml/L ; historique acheté conservé ; validation des quantités. Les ajouts explicites deviennent manuels pour survivre aux recalculs.
- Repas : écran pour changer date/portions ; ajout, remplacement et suppression associés au recalcul des courses dans une même transaction locale.
- Recettes : filtre par durée, préférence aux ingrédients bientôt périmés, calcul des scores une fois par recette ; aucune invention de prix.
- Accueil : fin de journée calculée par calendrier civil, y compris changements d'heure.
- Budget : montants strictement validés, modification d'une opération, intitulé « Reste du budget saisi » pour ne pas le confondre avec un solde bancaire. Saisie des opérations déjà effectuées.
- Sauvegarde : budget et soldes manuels intégrés à Snapshot, donc aux exports/restaurations. Migration du fichier budget-v1.json conservant l'original ; fichier illisible signalé sans bloquer le reste de DUO. Ancien export sans finances conserve les finances actuelles ; copie de sécurité avant restauration.
- Comptes manuels : saisie/modification/suppression de soldes datés ; comptes courants, épargne, investissements et CET séparés ; découvert possible pour compte courant. `FinanceLedger` est appelé par cet écran avec inclusion explicite des soldes manuels. Aucun faux solde bancaire connecté.
- Restauration : annule les anciens rappels locaux pour éviter des notifications devenues incohérentes ; reprogrammer les rappels souhaités.

## Validation exacte

Commande exécutée avec Swift 6.2.1 Linux : `swift test --jobs 2`, package DUOCore entier, y compris FinanceLedger.

**113 tests XCTest, 0 échec.** Voir `Docs/CORE-TESTS-2026-11-10.log`. Avant corrections : 79/79 sur le package Budget repris. Les tests de sécurité récupérés ont révélé trois validations de titres manquantes, corrigées avant le résultat final.

`swiftc -frontend -parse` : sources App, Core, AppTests, UITests sans erreur de syntaxe. Cela ne vérifie pas les types SwiftUI, ne compile pas iOS et ne remplace pas Xcode.

Tests AppStore ajoutés pour budget/export/restauration, ancienne sauvegarde, cuisson répétée, modification de repas. Test UI budget ajouté. **Codés mais non exécutés**, car aucun Xcode/simulateur sur cet hôte Linux.

| Fonction | État de cette livraison | Preuve / limite |
|---|---|---|
| Archive Solo et intégrité | TERMINÉ ET TESTÉ | Téléchargement et empreintes comparées ; CI historique réussie |
| Installation/signature iPhone réel | BLOQUÉ | Nécessite Windows, iPhone et authentification Apple personnelle |
| Moteurs tâches, courses, recettes, budget/finance, règles de synchro | TERMINÉ ET TESTÉ | 113 tests de package ; aucune preuve de backend réel |
| Nouveaux écrans tâches/repas/budget/comptes | CODÉ MAIS NON TESTÉ | Analyse syntaxique seulement ; Xcode et UI requis |
| Cuisine, courses, tâches, planning de base de l'IPA Solo | PARTIELLEMENT FONCTIONNEL | Des parcours CI historiques réussis ; pas tous les parcours demandés ni d'essai physique |
| Sport et habitudes | PARTIELLEMENT FONCTIONNEL | Création/édition/suppression existantes ; pas de validation iPhone exhaustive |
| Événements récurrents et rappels étendus | PARTIELLEMENT FONCTIONNEL | Événements ponctuels ; récurrence des tâches seulement ; pas de séries d'événements ni rappel automatique récurrent complet |
| Nous deux | PARTIELLEMENT FONCTIONNEL | Rotation et sauvegarde existantes, CI historique ; ni agenda d'activité ni historique quotidien complet |
| Joe local | PARTIELLEMENT FONCTIONNEL | Recettes/planning/courses et déplacements limités ; moteur testé, pas d'IA distante |
| Finances complètes du couple | PARTIELLEMENT FONCTIONNEL | Budget manuel et comptes codés ; objectifs, remboursement proportionnel, imports CSV et connecteur restant à réaliser |
| Authentification à deux, RLS, synchro réelle | BLOQUÉ | Backend et comptes de test non configurés/validés dans cette mission ; Solo demeure activé |
| Connexion bancaire | BLOQUÉ | Pas d'application prestataire/sandbox authentifiée ni coût confirmé pour deux titulaires |
| Fluidité, batterie, mémoire, clair/sombre et accessibilité exhaustifs | BLOQUÉ | Aucun profilage ou parcours visuel iOS exécuté sur la nouvelle version |

## Audit des branches (têtes relues le 10 novembre)

| Branche | SHA | Relation avec Solo / décision |
|---|---|---|
| main | db0ac4e670c0ed9c38fec5f01c636fd16b588683 | 73 commits en arrière ; inchangée |
| work/solo-iphone-install-20261105 | 4904ee2d81a5b1c9605c1b7cce20cffbdf63b7e8 | Référence préservée ; code compilé 0ed8a881, deux commits documentaires après |
| work/budget-couple-local-20261110 | 4eb4524ff6490d52f0119f79094a05b95e70f04c | +7 commits, base d'intégration ; inchangée |
| fix/joe-reschedule-and-core-checks-20261029 | 3a327fccf1bf138456d11186db02362319f25113 | Divergente (22 propres, 73 côté Solo) ; ports ciblés seulement |
| work/invitation-revocation-20261030 | 18dc2a15242027a8f5f6170aabe9196d0523496a | Ancêtre, 67 commits vers Solo |
| work/sync-session-safety-20261103 | c6cd5eaa621327928e0e9bb375b80f4acc0bf6c4 | Ancêtre, 63 commits vers Solo |
| work/backend-origin-guard-20261104 | 96030c8c5a9e00051c80ebb83787ca52bed46670 | Ancêtre, 62 commits vers Solo |
| work/fix-duopanel-compile-20261105 | 85abc3720c16e9b3412bd3c87ef365fc64e53b78 | Ancêtre, 61 commits vers Solo |

Pas de fusion générale de Joe : son comportement de rafraîchissement de session et ses anciens écrans ne sont pas repris automatiquement. Les garde-fous d'origine réseau et verrous de session de Solo restent présents.

## Blocage de nouvelle compilation

Les outils GitHub disponibles ne donnent pas accès à la facturation/quota. Tentative de lecture de la page Billing dans le navigateur : redirection vers connexion GitHub. Aucun lancement Actions, aucune dépense, aucune modification du budget de facturation.

Une fois la gratuité de la prochaine exécution confirmée, lancer sur **work/integration-daily-20261110** le workflow `ios-verify.yml`, avec `include_ui_tests=true`. Il compile le package, le simulateur et l'iPhone, puis exécute les tests AppStore/UI (audit automatisé d'accessibilité exclu par le workflow historique, donc à exécuter séparément). Corriger tout échec avant de remplacer l'IPA de secours. Ne pas recopier VALIDATION.txt du build précédent pour une nouvelle compilation.

## Banques : recherche, pas connexion

Les documents bancaires du 10 novembre restent applicables. Pages officielles relues pendant cette mission :
- https://enablebanking.com/docs/faq/ : production commerciale au volume avec minimum mensuel, devis ; sandbox et comptes propres restreints, pas une garantie de gratuité pour deux titulaires.
- https://enablebanking.com/docs/markets/fr/ : spécificités CIC/Caisse d'Épargne ; ce n'est pas une validation des comptes précis.
- https://powens.statuspal.eu/ : disponibilité des connecteurs, pas garantie des produits détenus.
- https://www.powens.com/fr/produits/agregation-donnees-financieres/ : Transactions et Wealth & Loans distincts. Aucun coût chiffré acceptable établi pour DUO.

Aucun appel de sandbox authentifié exécuté ; les fixtures locales de FinanceLedger ne sont pas un test de fournisseur. Pas de mots de passe ni de comptes bancaires réels. Les comptes de Lilou ne seront pas connectés sans son consentement.

## Actions réellement requises de Théo

1. Sur Windows, télécharger l'archive Solo, installer Sideloadly et les composants Apple officiels, brancher l'iPhone et effectuer la signature personnelle.
2. Ouvrir DUO, créer une tâche et un article, fermer/rouvrir, exporter. Ne pas supposer que deux installations se synchronisent.
3. Pour compiler la nouvelle version sans frais : rendre le quota Actions vérifiable ou confirmer sa disponibilité et l'absence de dépassement payant. Ne pas activer d'achat de minutes.
4. Plus tard seulement : autorisations séparées et coût accepté pour banques/backend. Aucun secret à envoyer dans la conversation.

La mission complète n'est pas achevée : les limites ci-dessus restent du travail technique, pas des fonctionnalités livrées.
