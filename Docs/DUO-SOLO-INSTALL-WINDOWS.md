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

## Renouvellement tous les sept jours

Les profils gratuits Apple expirent après sept jours et le nombre d’apps signées gratuitement est limité à trois par appareil. Renouveler DUO avant expiration, avec le même compte Apple et le même identifiant d’application, **en installant par-dessus sans supprimer DUO**.

Le renouvellement automatique de Sideloadly nécessite son service actif sur le PC et l’iPhone accessible par USB ou par Wi-Fi préalablement configuré. Pour le Wi-Fi : connecter d’abord en USB, activer la synchronisation Wi-Fi dans iTunes puis garder PC et iPhone sur le même réseau. Un PC éteint ne peut pas renouveler l’app.

Avant chaque mise à jour ou renouvellement : **Réglages de DUO → Confidentialité → Préparer une copie de mes données → Enregistrer ou partager l’export → Enregistrer dans Fichiers**. Garder aussi une copie hors de l’app. Si la signature expire, renouveler sans désinstaller.

## Données et restauration

L’export contient tâches, courses, stocks, repas, événements, habitudes et validations quotidiennes de « Nous deux ». Les préférences d’apparence et exclusions alimentaires sont à noter séparément : elles ne sont pas incluses dans cet export.

Pour restaurer : **Réglages → Confidentialité → Restaurer une sauvegarde DUO**, sélectionner le JSON, puis confirmer le remplacement. DUO valide le fichier et écrit une copie de l’état courant avant de le remplacer. **Enregistrer la copie avant restauration** permet de récupérer cet état. Cette copie est locale et remplacée à la restauration suivante : l’enregistrer hors de DUO avant une autre restauration.

DUO Solo ne synchronise pas les deux iPhone. Joe est local ; les prix des magasins ne sont pas connectés. Les données locales ne remplacent pas un export régulier. L’application n’est ni publiée sur l’App Store ni distribuée par TestFlight.

## Sources vérifiées le 5 novembre 2026

- [Apple : compte et Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Sideloadly : téléchargement](https://sideloadly.io/)
- [Sideloadly : installation, confiance, renouvellement et limites](https://sideloadly.io/faq.html)
