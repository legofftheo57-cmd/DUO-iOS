# Installer DUO Solo sur iPhone depuis Windows

Version avec « Nous deux » — 5 novembre 2026. Application native, locale, iOS 17 minimum.

## Télécharger le bon paquet

Dans le dépôt privé, ouvrir [GitHub Actions](https://github.com/legofftheo57-cmd/DUO-iOS/actions), puis le dernier contrôle **réussi** de la branche `work/solo-iphone-install-20261105`.
Dans **Artifacts**, télécharger `DUO-solo-validated-…`, puis extraire le ZIP sous Windows.
Le paquet contient `DUO-solo-unsigned.ipa`, le commit exact dans `SOURCE-COMMIT.txt`, l’empreinte dans `SHA256SUMS.txt`, les résultats et ce guide.
Ne pas utiliser l’ancien IPA du 5 novembre qui précède « Nous deux ». Les artefacts sont conservés 30 jours : garder le paquet sur le PC.

L’IPA est **non signé**. Il ne peut pas s’installer en le touchant depuis Fichiers sur l’iPhone.

## Installation personnelle gratuite

1. Sur le PC, télécharger [Sideloadly pour Windows depuis son site officiel](https://sideloadly.io/). Installer les composants Apple demandés par l’éditeur. Si l’iPhone n’est pas détecté, consulter sa FAQ pour les versions web d’iTunes/iCloud et leurs pilotes.
2. Brancher l’iPhone par un câble USB de données, le déverrouiller et accepter **Faire confiance à cet ordinateur**.
3. Dans Sideloadly, sélectionner cet iPhone et glisser **DUO-solo-unsigned.ipa**. Utiliser la signature avec ton **compte Apple personnel**. Saisir toi-même ton mot de passe et le code à deux facteurs dans le logiciel ; ne pas les communiquer à ChatGPT. Aucun abonnement Apple Developer payant n’est nécessaire pour cette méthode personnelle.
4. Lancer la signature et l’installation. Ne pas modifier la version iOS minimale ni injecter d’extensions. Conserver le compte et l’identifiant d’application attribué par Sideloadly pour les renouvellements.
5. Si demandé, sur l’iPhone : **Réglages → Confidentialité et sécurité → Mode développeur**, activer puis suivre le redémarrage et la confirmation. Si « développeur non approuvé » apparaît : **Réglages → Général → VPN et gestion de l’appareil**, ouvrir le profil correspondant à ton compte et lui faire confiance.
6. Ouvrir **DUO** depuis l’écran d’accueil et suivre `TEST-IPHONE.md`.

Sideloadly est un logiciel tiers, distinct d’Apple. Le processus utilise la signature personnelle de développement sans jailbreak ; sa réussite sur ton PC et ton iPhone reste à vérifier physiquement.

## Renouvellement automatique (à configurer lors de la première installation)

Il ne faut **pas recompiler DUO sur macOS tous les sept jours** : c’est le profil gratuit de signature Apple qui expire après sept jours. Apple limite également le compte gratuit à trois apps sideloadées par appareil. Le même IPA peut être re-signé automatiquement, sans utiliser GitHub Actions.

**À faire une fois sur Windows lors de l'installation initiale :**

1. Installer Sideloadly depuis https://sideloadly.io/ et les composants Apple nécessaires (versions web d’iTunes/iCloud recommandées par l’éditeur). Connecter l’iPhone en USB, le déverrouiller et lui faire faire confiance au PC.
2. Dans **iTunes → iPhone → Résumé → Options**, activer **Synchroniser avec cet iPhone en Wi-Fi**, puis synchroniser. Vérifier que l’iPhone réapparaît dans Sideloadly sur le même réseau local, après avoir retiré le câble. Si besoin, ouvrir iTunes et réveiller l’écran de l’iPhone.
3. Ajouter **DUO-solo-unsigned.ipa** à Sideloadly, conserver le même compte Apple et l’identifiant d’application attribué. Activer **Automatic App Refreshing / Automatically refresh** lors du sideload (vérifier l’option même si elle est généralement activée par défaut).
4. Installer DUO, vérifier qu’il s’ouvre, puis vérifier que **Sideloadly Daemon** est actif sur Windows et que DUO est bien inscrit au rafraîchissement automatique. Au prochain démarrage de Windows, vérifier que le daemon s’exécute et reconnaît encore l’iPhone via Wi-Fi.
5. **Ne pas désinstaller DUO** lors des renouvellements : signer par-dessus avec le **même compte Apple et le même identifiant d’application** préserve normalement les données. Faire malgré tout des exports JSON réguliers vers Fichiers.

**Conditions de fonctionnement :** le PC doit être allumé avec le service Sideloadly actif ; l’iPhone doit pouvoir être détecté par USB ou sur le même Wi-Fi local. Le daemon tente alors de renouveler les applications proches de l’expiration. La réussite n’est pas garantie si le PC est éteint, si la connexion échoue ou si Apple redemande une authentification ; l’interface du logiciel peut dans ces cas exiger une intervention. Cette automatisation dépend de Sideloadly, pas d’une tâche planifiée ChatGPT, et ne peut être activée depuis GitHub seulement.

**En cas d’échec :** connecter l’iPhone en USB, ouvrir Sideloadly, vérifier l’état du daemon puis relancer la signature du même IPA avec le même compte Apple et le même identifiant d’application. Ne pas supprimer l’application ; si un nouveau code Apple est demandé, le saisir toi-même sur ton ordinateur, jamais dans un chat.

**Mises à jour du code :** contrairement au simple rafraîchissement de signature, installer une nouvelle version nécessite de construire un nouvel IPA et de le charger manuellement dans Sideloadly (ou d’organiser un flux de mise à jour spécifique). Cette opération ne se fait pas automatiquement par le seul daemon.

Avant une restauration ou une opération sensible : **Réglages de DUO → Confidentialité → Préparer une copie de mes données → Enregistrer ou partager l’export → Enregistrer dans Fichiers**. Conserver la sauvegarde hors de DUO.

## Données et restauration

L’export contient tâches, courses, stocks, repas, événements, habitudes et validations quotidiennes de « Nous deux ». Les préférences d’apparence et exclusions alimentaires sont à noter séparément : elles ne sont pas incluses dans cet export.

Pour restaurer : **Réglages → Confidentialité → Restaurer une sauvegarde DUO**, sélectionner le JSON, puis confirmer le remplacement. DUO valide le fichier et écrit une copie de l’état courant avant de le remplacer. **Enregistrer la copie avant restauration** permet de récupérer cet état. Cette copie est locale et remplacée à la restauration suivante : l’enregistrer hors de DUO avant une autre restauration.

DUO Solo ne synchronise pas les deux iPhone. Joe est local ; les prix des magasins ne sont pas connectés. Les données locales ne remplacent pas un export régulier. L’application n’est ni publiée sur l’App Store ni distribuée par TestFlight.

## Sources vérifiées le 5 novembre 2026

- [Apple : compte et Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Sideloadly : téléchargement](https://sideloadly.io/)
- [Sideloadly : installation, confiance, renouvellement et limites](https://sideloadly.io/faq.html)
