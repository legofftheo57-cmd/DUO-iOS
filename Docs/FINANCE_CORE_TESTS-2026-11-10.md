# DUO — Preuve de validation du noyau financier
_Date : 10 novembre 2026 — branche `work/budget-couple-local-20261110`._

## Livrables concrets

- `Core/FinanceLedger.swift` : moteur Swift autonome, montants en centimes EUR `Int64`, soldes bancaire / épargne / investissement distincts, CET brut différé exclu de la liquidité, allocations de projets ne créant pas de faux argent, déduplication d'opérations, calcul des dépenses comptabilisées, marquage des données anciennes et erreurs explicites en cas de devises/overflow/données incohérentes.
- `Tests/FinanceLedgerTests.swift` : 11 tests de non-double-compte, virements internes, opérations en attente, doublons, virements/projets, CET, fraîcheur, devise, overflow.

## Vérification exécutée

- Environnement : Swift 6.2.1 sur Linux, Swift tools version 5.9.
- Test : copie exacte du fichier du moteur dans une **mini-package isolé** `DUOCore` et des 11 tests dans `DUOCoreTests`.
- Commande : `swift test --jobs 2`.
- Résultat : **11 tests exécutés, 0 échec**.
- Le même moteur avait été testé au préalable dans une mini-package `DUOFinance`, également 11/11.
- Les deux fichiers correspondant aux sources/tests ont ensuite été enregistrés sur GitHub, dans la branche Budget. Leur existence a été vérifiée par une lecture GitHub.

## Limites importantes

- Ce n'est **pas** un résultat `swift test` de tout le dépôt DUO ; les anciennes classes, écrans et tests n'ont pas été compilés ensemble ici.
- **Aucune compilation iOS/Xcode de la branche Budget**, aucun test UI, aucun test sur iPhone physique.
- Le moteur n'est pas encore branché à l'écran Budget : la vue actuelle conserve son calcul manuel distinct. Le vrai connecteur banque, le stockage chiffré serveur, la synchronisation entre deux iPhone et les contrôles RLS liés à la finance ne sont pas créés.
- La classification réelle des virements, prélèvements à débit différé et des opérations pending→booked est un travail d'import/normalisation à vérifier avec les données d'un fournisseur. Les tests du moteur supposent des opérations déjà classifiées correctement.
- Aucun frais, API payante, compte bancaire réel ou backend distant engagé.

## Prochaine vérification utile

Compiler la branche Budget entière avec Xcode/CI **après** avoir finalisé l'intégration, puis tester avec fixtures de comptes fictifs et cas d'opérations bancaires réalistes. Ne pas prétendre « synchronisation réelle » tant que la liaison bancaire et les essais à deux appareils ne sont pas validés.
