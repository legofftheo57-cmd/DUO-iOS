# DUO Solo — installation sur un seul iPhone (Windows)

État : **code préparé ; compilation iPhone et installation réelle non encore vérifiées**.

Objectif : une application native iOS hors ligne sur le seul iPhone du propriétaire. La synchronisation avec Lilou, les comptes et l'IA distante sont reportés.

## Ce qui existe dans le code

- SwiftUI natif : cinq onglets Accueil, Cuisine, Courses, Planning et Tâches.
- Identité **Graphite & Ice** conservée (palette dynamique et mode sombre).
- Accueil avec tâches ouvertes, courses, raccourcis et suggestions de repas.
- Création/modification locale de tâches, d'événements, de courses et d'aliments.
- Recettes, planification de repas, stocks et suivi d'habitudes.
- Sauvegarde JSON locale et import avec validation et confirmation avant remplacement.
- Pas de connexion automatique ni d'envoi au serveur en version solo.
- Joe : réponses locales uniquement, sans abonnement IA requis.

## Étape 1 — Produire un IPA non signé

La branche de livraison est **work/solo-iphone-install-20261105**.

Dans GitHub, ouvrir **Actions → DUO - verification iOS (manuel) → Run workflow**.
Sélectionner la branche ci-dessus et laisser include_ui_tests désactivé pour la première compilation. Le workflow détecte cette branche et produit automatiquement le paquet IPA si les validations réussissent.

Le workflow :
1. exécute les tests du noyau Swift ;
2. compile l'interface SwiftUI pour le simulateur ;
3. compile l'application pour un vrai iPhone (iphoneos) sans signature ;
4. si les étapes ont réussi, produit un artefact **DUO-solo-unsigned-ipa**.

**Ce workflow utilise des minutes de runner macOS GitHub (susceptibles d'être facturées selon le forfait/quota). Ne pas le lancer sans validation explicite du propriétaire.**
Il comporte un plafond de 25 minutes. En cas d'échec de compilation, consulter l'artefact duo-xcode-diagnostics et corriger le code avant de réessayer. Un simple fichier IPA non signé n'est pas directement installable.

## Étape 2 — Installer depuis Windows

Le logiciel tiers [Sideloadly](https://sideloadly.io/) permet de signer l'IPA avec un compte Apple gratuit, puis de le charger sur l'iPhone. Ce logiciel ne fait pas partie de DUO ; utiliser uniquement sa source officielle, lire les conditions et ne communiquer les identifiants Apple qu'au logiciel si vous acceptez ses modalités.

1. Sur ton PC Windows, installer la version officielle de Sideloadly et les composants Apple Windows qu'il demande.
2. Brancher l'iPhone, le déverrouiller et autoriser la confiance envers le PC.
3. Télécharger l'artefact du workflow, extraire le fichier DUO-solo-unsigned.ipa du ZIP.
4. Dans Sideloadly, sélectionner l'iPhone et l'IPA puis utiliser ton propre identifiant Apple pour signer et installer.
5. Si iOS le demande, activer **Mode développeur** dans Réglages > Confidentialité et sécurité. Autoriser le profil d'app développeur dans les Réglages si nécessaire.
6. Ouvrir DUO, créer une tâche, fermer et rouvrir l'application : la tâche doit être toujours là.
7. Vérifier les courses, les repas et un export/import sur des données de test avant toute utilisation importante.

Avec un compte Apple gratuit, la signature doit être renouvelée environ tous les **7 jours**. Sideloadly dispose d'un système de rafraîchissement automatique avec un PC accessible par USB ou Wi-Fi configuré. Lors du renouvellement, conserver **le même identifiant Apple et le même identifiant d'application**, réinstaller par-dessus l'app et ne pas supprimer l'app existante. **Faire d'abord un export JSON**, stocké dans Fichiers ou un emplacement choisi.

Références à jour :
- [FAQ officielle Sideloadly](https://sideloadly.io/faq.html)
- [Règles Apple des Personal Teams](https://developer.apple.com/help/account/basics/about-your-developer-account)

## Vérifications bloquantes avant usage normal

- [ ] Tests DUOCore réussis sur le commit actuel.
- [ ] Compilation SwiftUI simulateur réussie ; aucune erreur.
- [ ] Compilation iPhone et génération de l'IPA réussies.
- [ ] Signature/installation sur le véritable iPhone réussies.
- [ ] Ouverture, création de tâche, sauvegarde après redémarrage.
- [ ] Parcours courses + repas + planning testé.
- [ ] Export JSON, import sur copie de test et confirmation de restauration.
- [ ] Lisibilité avec mode sombre, taille de texte accrue et VoiceOver rapide.
- [ ] Rafraîchissement de la signature testé sans suppression des données.

## Limites volontaires

- Les données solo ne sont pas synchronisées avec le téléphone de Lilou.
- Les sauvegardes JSON sont à exporter manuellement ; la copie locale est exclue de la sauvegarde iCloud.
- Aucun prix réel de magasin, aucune garantie de budget courses et aucune IA payante.
- Ce build n'est pas publié sur l'App Store ni accessible dans TestFlight.
- La source et l'IPA ne doivent pas être publiés ou partagés sans approbation.
