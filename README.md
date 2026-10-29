> **DUO 0.5.0 — Joe** : assistant local gratuit, propositions de déplacement du planning et d’ajout aux courses, confirmation obligatoire. Pas de connexion IA payante activée.

# DUO 0.4.0 — SwiftUI et assistant

Dernier état : `Docs/REPRISE-0.4.0.md`. Le moteur Swift a 60 tests réussis. La compilation Xcode, le backend Supabase et l’installation sur iPhone restent à valider.

# DUO — application native iOS, version de développement 0.3.0 (source candidate)

Livraison du 29 octobre 2026. SwiftUI, iOS 17 minimum. Identité Graphite & Ice.

**Ce dossier contient du code natif, un projet Xcode, un moteur Swift testé et un backend SQL initial testé historiquement en PostgreSQL embarqué (migration 002 non exécutée). Il ne contient pas d’application iPhone compilée ou signée. DUO n’est pas encore prêt pour TestFlight.**

**Mise à jour :** consultez `Docs/REPRISE-0.3.0.md` pour les nouvelles fonctions de compte, la migration SQL 002, les nouveaux tests et une procédure de compilation distante sans Mac personnel. Le statut demeure **non compilé sur iOS / non installable à ce stade**.

## Commencer

Ouvrir `DUO.xcodeproj` dans Xcode 16 ou ultérieur, sélectionner le schéma DUO et un simulateur iPhone, puis Run. Le mode local fonctionne sans configuration backend. La compilation de l’interface reste à confirmer sur macOS.

Pour lancer les vérifications sur un Mac équipé de Xcode et d’un simulateur iPhone :

```bash
./Scripts/check-macos.sh
```

Ce script compile le moteur, exécute ses tests, compile l’application et lance les XCUITest. Il ne publie rien et ne signe aucune distribution.

## Contenu

- `App/` : interface SwiftUI, stockage atomique protégé, Keychain, client Auth/REST Supabase et orchestration de synchronisation.
- `Core/` : modèles Codable, catalogue original de 12 recettes, calculs de portions/courses, planification, quantités, récurrences, conflits.
- `Tests/` : tests XCTest du moteur, exécutables avec `swift test` sans SDK iOS.
- `UITests/` : quatre parcours XCUITest préparés, non exécutés ici.
- `Backend/001_schema.sql` : migration PostgreSQL/Supabase, RLS, RPC, invitations et transactions versionnées.
- `Backend/tests/` : tests de sécurité SQL reproductibles avec PGlite.
- `Resources/` : couleurs dynamiques exactes, icône DUO et manifeste de confidentialité à revoir avant distribution.
- `Docs/` : architecture, couverture fonctionnelle, résultats, limites, distribution et sources.

## Premier parcours implémenté

1. Cuisine → Ajouter un aliment : nom correspondant au catalogue, quantité, unité, emplacement, date facultative.
2. Ouvrir une recette : ingrédients disponibles/manquants, portions, étapes et allergènes.
3. Ajouter le repas au planning, ou composer plusieurs dîners.
4. Courses : quantités mutualisées, déduction du stock, conservation des articles manuels.
5. Planning : confirmer un repas cuisiné pour déduire le stock, en une transaction locale ; remplacer une recette si besoin.
6. Après configuration et validation du backend : se connecter, créer le foyer et transmettre manuellement un code à son partenaire. La synchronisation se fait au premier plan ou à la demande.

Le frigo démarre vide. Aucun prix fictif, aliment personnel, nom du partenaire ou compte prérempli n’est importé. Le prototype web existant n’a pas été modifié et ses données ne sont pas migrées automatiquement.

## Résultat actuel

Consulter `Docs/RAPPORT-QUALITE.md` pour les nombres exacts, limites et journaux. Une réussite des tests métier/SQL ne certifie pas le fonctionnement de SwiftUI, du Keychain, de la signature ou du réseau sur iPhone.

## Les seuls accès indispensables pour la suite

1. Un environnement macOS avec Xcode (local ou distant) pour compiler et corriger l’interface si nécessaire, puis exécuter les tests iOS.
2. Un projet Supabase approuvé, son URL et sa **clé publique** pour valider Auth et la synchronisation réelle. Ne pas transmettre de mot de passe administrateur ni de clé service-role à l’application.
3. Deux identités de test et deux simulateurs/iPhone pour les scénarios de synchronisation.
4. Seulement pour TestFlight : un compte Apple Developer et l’autorisation de distribution. Aucun abonnement ni frais n’a été engagé.

La création du backend, l’envoi d’invitations et la publication n’ont pas été réalisés.
