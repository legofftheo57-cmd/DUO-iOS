# DUO 0.5.0 — Joe (29 octobre 2026)

La base est l’archive DUO 0.4.0 ; les fonctionnalités et protections précédentes sont conservées.

- Assistant nommé **Joe** dans son écran.
- Mode local gratuit et sans modèle IA : questions recettes, stock, planning, conseils de comparaison sans prix en temps réel.
- Proposition de déplacer une tâche/événement à demain, jamais sans confirmation.
- **Nouveau** : Joe reconnaît « Ajoute 2 kg de riz aux courses » et « Mets du lait sur la liste de courses » ; il prépare une ligne de courses, sans la créer avant validation.
- Les actions restent réévaluées au moment de la confirmation par l’écran ; aucune action d’écriture n’est accordée au mode IA en ligne.
- La valeur « 1 pièce » est un repli générique pour un produit non quantifié : l’utilisateur doit vérifier l’unité avant confirmation.

## Validation et limites

`swift test` teste uniquement DUOCore dans cet environnement Linux ; `swiftc -frontend -parse` vérifie la syntaxe des vues, sans typechecking SwiftUI iOS. Il reste indispensable d’exécuter Xcode/GitHub Actions macOS avant distribution. Le mode distant, Supabase, l’invitation Lilou et TestFlight n’ont pas été activés ni vérifiés sur téléphone.
