# Vérifier DUO sur GitHub Actions sans Mac personnel

## Situation au 29 octobre 2026
La compilation macOS/iOS n'a pas encore été exécutée ni confirmée. Les tests du noyau Swift sur Linux ne prouvent pas que la version iPhone fonctionne.

## Protéger le budget
Le dépôt est privé. Vérifier d'abord sur GitHub **Settings > Billing & licensing** que le crédit de calcul inclus n'est pas épuisé et qu'aucune option de dépassement payant n'est autorisée. En 2026, la documentation GitHub Free annonce 12 USD de crédit mensuel, et la machine standard macOS environ 0,062 USD par minute. Un lancement est limité à 25 minutes (soit ~1,55 USD de crédit au maximum), mais ce plafond temporel ne garantit PAS zéro facture si le crédit inclus est épuisé et qu'un paiement est autorisé.

## Premier lancement : compilation et tests du noyau
1. Ouvrir https://github.com/legofftheo57-cmd/DUO-iOS/actions
2. Sélectionner « DUO - verification iOS (manuel) » dans le menu de gauche.
3. Cliquer « Run workflow », choisir la branche `main`, **laisser include_ui_tests décoché**, puis confirmer.
4. Ouvrir l'exécution ; une coche verte indique que les tests Swift et la **compilation iOS pour simulateur** ont réussi. Une croix rouge signifie qu'il faut analyser les journaux.
5. Si erreur, transmettre le lien de l'exécution GitHub ou le journal « duo-xcode-diagnostics ».

## Deuxième lancement : tests d'interface
Seulement après une première compilation réussie et vérification du crédit disponible, relancer avec **include_ui_tests coché**. Cette deuxième opération effectue notamment les tests de navigation, saisie, persistance et accessibilité sur simulateur iPhone. Elle est plus longue.

## Ce qui n'est pas réalisé
Le workflow ne signe pas d'application, ne produit pas une version installable par TestFlight, ne configure pas Supabase et ne teste pas la vraie synchronisation avec Lilou. Aucun compte Apple payant, clé de signature ou carte bancaire n'est requis pour la compilation sur simulateur.

GitHub conserve uniquement les fichiers .log pendant deux jours. Le workflow est **manuel uniquement** afin d'éviter les consommations automatiques à chaque commit. Il n'est pas nécessaire de rendre le dépôt public.

Sources : https://docs.github.com/en/billing/concepts/product-billing/github-actions et https://docs.github.com/en/actions/reference/runners/github-hosted-runners
