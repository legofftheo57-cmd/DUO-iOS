# DUO Solo — état de validation

Objectif : livraison individuelle sur iPhone, interface native Graphite & Ice aérée. Aucun compte et aucune synchronisation requis.

## Confirmé par les exécutions GitHub

- [x] 5 novembre 2026, exécution 42078217196 : **66 tests DUOCore réussis**, compilation pour simulateur réussie, compilation iPhone réussie, paquet IPA non signé produit.
- [x] Lors de cette exécution, deux tests UI ont réussi : **ajout d'un aliment / conservation au redémarrage** et **navigation entre les onglets et les réglages**.
- [ ] Audit d'accessibilité : le test automatique n'a pas conclu ; erreur « Audit failed to complete in time », dans un simulateur dont les événements de repos étaient très lents.
- [ ] Ensemble des tests UI : interrompu après le délai maximal ; pas une preuve d'échec de l'application, mais validation incomplète.
- [ ] Installation et manipulation sur l'iPhone réel : non effectuées, car le téléphone n'est pas accessible.

## Corrections apportées après ces résultats

- En mode `-duo-ui-test` uniquement, les deux `TimelineView` à mise à jour périodique sont remplacés par des écrans statiques, pour permettre à XCTest d'observer correctement la fin des interactions.
- L'application réelle conserve les mises à jour programmées de son thème et de son accueil.
- État vide de l'accueil rendu plus explicite pour la première utilisation.
- Les tests fonctionnels de l'interface sont exécutés indépendamment de l'audit d'accessibilité, qui demeure nécessaire avant une diffusion plus large.

## Conditions d'une version prête à essayer

- [ ] Nouveau build SwiftUI et IPA sur le dernier commit de la branche.
- [ ] Parcours fonctionnels UI réussis (tâches, courses, navigation, aliments et sauvegarde).
- [ ] Relire les avertissements et anomalies du dernier journal.
- [ ] Signer l'IPA personnellement depuis Windows et installer sur l'iPhone.
- [ ] Tester l'ouverture, l'ajout et le retrait d'une tâche, les courses, la cuisine, le planning, le redémarrage et l'export JSON.
- [ ] Vérifier le renouvellement de signature sans désinstallation ni perte des données.

**Important :** le test sur iPhone physique ne peut pas être réalisé dans GitHub Actions : il nécessite l'appareil du propriétaire.
