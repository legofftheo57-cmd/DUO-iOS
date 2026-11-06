# DUO Solo — fiche de mise en route Windows et iPhone (6 novembre 2026)

## État vérifié sur GitHub

- Run : https://github.com/legofftheo57-cmd/DUO-iOS/actions/runs/42097144430
- Statut : `completed / success` ; SHA source `0ed8a88156dd578d42dc0df4f5f4ac2619c7f214`.
- Tests noyau Swift, compilation simulateur, compilation iPhone non signée, parcours utilisateur et écran « Nous deux » sur iPhone SE : tous réussis.
- Artefact **DUO-solo-validated-0ed8a88156dd578d42dc0df4f5f4ac2619c7f214** (GitHub artifact id 13450945369), non expiré au 6 novembre. Il contient l'IPA non signé et les fichiers de contrôle.
- Aucun nouveau build n'est nécessaire pour la première installation. Ne pas prendre l'ancien `DUO-solo-unsigned-ipa` d'un run antérieur.
- Le guide détaillé se trouve dans `Docs/DUO-SOLO-INSTALL-WINDOWS.md`.

## Sur le PC Windows — première installation

1. Ouvrir le lien du run ci-dessus dans le navigateur connecté à GitHub. Dans **Artifacts**, télécharger **DUO-solo-validated-0ed8a881...** ; décompresser l'archive sur le PC et retrouver `DUO-solo-unsigned.ipa`.
2. Contrôler que `SOURCE-COMMIT.txt` contient exactement `0ed8a88156dd578d42dc0df4f5f4ac2619c7f214`. Facultatif mais recommandé : dans PowerShell, `Get-FileHash -Algorithm SHA256 .\DUO-solo-unsigned.ipa`, puis comparer avec `SHA256SUMS.txt`.
3. Installer **Sideloadly Windows** depuis https://sideloadly.io/ et les composants Apple requis (suivre la FAQ officielle). Ne pas installer macOS sur Windows : l'IPA est déjà compilé sur un runner macOS.
4. Brancher l'iPhone avec un câble USB de données, déverrouiller, accepter « Faire confiance à cet ordinateur ». Dans Sideloadly, choisir cet appareil et glisser `DUO-solo-unsigned.ipa`.
5. Signer avec le compte Apple personnel. Entrer identifiant, mot de passe et éventuel code 2FA **directement dans le logiciel**, jamais dans ChatGPT. Ne pas modifier le bundle ID lors des renouvellements.
6. Installer puis, si iOS le demande, activer le mode développeur et faire confiance au profil développeur correspondant dans Réglages. Ouvrir DUO depuis l'écran d'accueil.
7. Effectuer les tests de réception dans `Docs/DUO-SOLO-TEST-IPHONE.md` : navigation, tâche et historique, courses, planning, « Nous deux », fermeture/réouverture, export JSON, restauration avec copie préalable. L'installation réelle et ces tests ne sont **pas encore validés**.

## Renouvellement automatique de signature — à activer sur Windows

1. Avec l'iPhone branché, dans iTunes pour Windows activer **Synchroniser avec cet iPhone en Wi-Fi**, puis synchroniser.
2. Vérifier que l'iPhone reste détectable par Sideloadly sur le même Wi-Fi après retrait du câble.
3. Activer et vérifier **Automatic App Refreshing** / Sideloadly Daemon et sa présence au démarrage de Windows. Conserver le même compte Apple et le même identifiant d'application.
4. Confirmer que DUO figure parmi les applications suivies par le daemon. Si la détection Wi-Fi ne fonctionne pas, revenir à l'USB.
5. Le PC doit être allumé, le daemon actif et l'iPhone joignable pour que le renouvellement puisse s'effectuer. Les profils gratuits expirent après environ sept jours ; aucune recompilation macOS n'est nécessaire pour les renouveler.
6. Si une authentification Apple supplémentaire est demandée, une intervention peut rester nécessaire. Ne jamais supprimer DUO pour renouveler : signer **par-dessus** pour conserver normalement les données.
7. Exporter régulièrement les données DUO au format JSON vers Fichiers et conserver une copie extérieure à l'app.

## État de livraison

**Terminé et vérifié :** sources GitHub enregistrées, tests CI réussis, artefact disponible, documentation prête.

**En attente de l'utilisateur :** téléchargement sur Windows, signature personnelle, installation physique, tests sur son iPhone et activation du daemon sur le PC.

**Hors périmètre Solo :** synchronisation entre deux iPhone, distribution App Store/TestFlight, garantie de renouvellement sans aucune intervention.

Aucune dépense, publication, compilation supplémentaire ni déploiement n'a été effectué pour préparer cette fiche.
