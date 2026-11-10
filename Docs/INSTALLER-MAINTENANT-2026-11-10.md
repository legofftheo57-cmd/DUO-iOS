# Installer DUO Solo sur iPhone depuis Windows

Cette archive contient la version Solo compilée le 5 novembre. Les nouveaux écrans Budget du 10 novembre n'y figurent pas.

1. Connectez-vous à GitHub sur le PC et ouvrez https://github.com/legofftheo57-cmd/DUO-iOS/actions/runs/42097144430 . Dans Artifacts, téléchargez **DUO-solo-validated-0ed8a881…**.
   Copie conservée sans expiration Actions : `Artifacts/DUO-solo-validated-0ed8a881.zip` sur `work/integration-daily-20261110` (ouvrir le fichier GitHub puis Download raw file).
2. Décompressez le ZIP. Il contient `DUO-solo-unsigned.ipa`, `SOURCE-COMMIT.txt` et `SHA256SUMS.txt`. Le SHA source doit être `0ed8a88156dd578d42dc0df4f5f4ac2619c7f214`.
3. Dans PowerShell, depuis ce dossier : `Get-FileHash -Algorithm SHA256 .\DUO-solo-unsigned.ipa`. Résultat attendu : `d89a1b02f7c8ef9cc0ee91f8201d58ec685fe44c45971fb8654e687d81384622`.
4. Installez Sideloadly depuis https://sideloadly.io/ et suivez ses prérequis Apple Windows officiels (versions web iTunes/iCloud demandées par le site). Vous n'avez pas besoin d'installer macOS.
5. Branchez l'iPhone déverrouillé par USB et acceptez « Faire confiance ». Dans Sideloadly, sélectionnez l'iPhone, glissez l'IPA puis utilisez votre propre compte Apple pour signer. Mot de passe et code éventuel se saisissent dans le logiciel, jamais dans ChatGPT.
6. Suivez les demandes iOS de confiance au développeur et de mode développeur. Ouvrez DUO depuis l'écran d'accueil. Cette étape physique n'a pas été exécutée par l'agent.
7. Testez une tâche, sa validation/réouverture, un article de courses, un événement, puis fermez et rouvrez DUO. Dans Réglages, exportez vos données et gardez une copie privée extérieure à l'app.

## Renouvellement

Avec un compte Apple gratuit, la signature dure environ sept jours. Activez Automatic App Refreshing / Sideloadly Daemon et la synchronisation Wi-Fi selon la documentation officielle. Le PC doit être allumé, le daemon lancé et l'iPhone joignable (même réseau ou USB) ; une nouvelle authentification Apple peut être demandée. Ce n'est pas garanti sans intervention.

Conservez le même compte Apple et le même bundle ID (`fr.theolegoff.duo.dev` à l'origine). Mettez à jour par-dessus l'app existante, sans la désinstaller, après export. Gardez cette archive comme secours ; ne revenez pas à un ancien binaire après saisie de nouvelles données sans export préalable.

## Limites

Ce build est local : deux iPhone ne partageront pas encore tâches ou courses. Aucun compte bancaire n'est connecté. L'IPA non signé ne s'installe pas par simple ouverture dans Safari ; aucune voie gratuite fiable entièrement depuis l'iPhone n'a été validée pour ce paquet. Le chemin retenu est Windows + signature personnelle.

Source installation/renouvellement vérifiée le 10 novembre : https://sideloadly.io/ .
