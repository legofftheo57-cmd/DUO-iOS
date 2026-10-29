# Couverture de la mission

« Écrit » ci-dessous signifie présent dans le code source ; l’interface n’a pas encore été compilée/exécutée avec le SDK iOS.

| Domaine | Présent | Limites restantes |
|---|---|---|
| Accueil | Priorités matin/après-midi/soir, choix manuel, événements, tâches, suggestion, aliments à vérifier | À valider sur téléphone et avec beaucoup de contenu |
| Navigation | 5 onglets, NavigationStack, feuilles de saisie, menus, réglages | XCUITest préparés mais non exécutés |
| Apparence | Palette exacte, modes système/clair/sombre/horaire, réglages persistants, recalcul périodique | Aucun rendu iPhone vérifié ; pas de Liquid Glass personnalisé. Contrôles natifs adoptent le style de l’OS |
| Frigo | CRUD, unités, catégories, emplacements, date facultative, recherche, filtre, validation doublons | Pas de scan ; pas de synonymes automatiques ni dictionnaire produit |
| Recettes | 12 recettes originales, étapes, portions, allergènes, exclusions, suggestions, confirmation de stock | Allergènes selon produits de base : vérifier les étiquettes ; pas de validation nutritionnelle professionnelle |
| Courses | Liste manuelle/générée, catégories, édition, cases, mutualisation, allocation chronologique du stock | Prix non connectés ; pas de garantie de budget ; cocher n’ajoute pas l’achat au frigo |
| Repas | Génération de 1–12 repas depuis l’UI, diversité, remplacement, suppression, historique de cuisson | Stock possédé renseigné manuellement ; pas de substitutions alimentaires automatiques |
| Tâches | CRUD, attribution, échéance, validation/historique, récurrence tous les N jours, rappel local sur demande | Pas de règles « lundi et jeudi » ; pas de répartition automatique des efforts |
| Planning | Sélection jour/semaine, événements, repas, tâches, conflits, dates/fuseaux | Vue semaine en liste, pas de grille. Pas d’intégration Apple Calendar |
| Sport/habitudes | Séances privées par défaut, événements passés déclaratifs, habitudes, objectif de jours/semaine, progression | Pas d’objectif sportif en minutes, validation sportive dédiée ou HealthKit ; rappels des habitudes non implémentés |
| Comptes | Connexion e-mail/mot de passe, inscription avec confirmation e-mail, jetons Keychain et refresh | Aucun compte réel testé ; récupération de mot de passe et suppression autonome à implémenter |
| Synchronisation | Foyer deux comptes, code d’invitation, RPC, file persistante, conflits, tombstones | Backend non déployé ; cycles réseau/deux appareils non exécutés ; premier plan uniquement |
| Confidentialité | Données privées côté serveur, séparation des caches, aucun tracker ni IA | Manifeste fourni à revoir selon le backend réel ; export/suppression utilisateur à compléter |
| Distribution | Projet Xcode, schéma partagé, icône, configuration de signature, scripts | Pas de build iOS, signature, archive .ipa, App Store Connect ni TestFlight |

## Reprise prioritaire

1. Compiler l’application avec Xcode, corriger toute erreur de typage SwiftUI et exécuter les XCUITest ; conserver les xcresult.
2. Valider manuellement les petites tailles d’iPhone, Dynamic Type maximal, VoiceOver, Reduce Motion/Transparency, thème système et horaire à minuit.
3. Configurer un projet Supabase de test autorisé ; activer confirmation d’e-mail et une politique de mot de passe serveur ; tester Auth, Keychain, renouvellement et reconnexion.
4. Tester le parcours complet sur deux identités, interruptions réseau pendant l’écriture, arrêt forcé, modifications concurrentes, conflits de suppression, notifications devenues inutiles.
5. Compléter récupération/suppression de compte, export/suppression locale et notice de confidentialité avant une distribution à des utilisateurs réels.
6. Après ces validations : signer, archiver et préparer une bêta TestFlight privée avec accord explicite.
