> Mise à jour : version de travail 0.3.0, procédure distante dans `REPRISE-0.3.0.md`. Les notes 0.2.0 ci-dessous décrivent le projet initial.

# Compilation, backend et distribution

## Préparation actuelle

Projet Xcode inclus, schéma DUO partagé, paquet local DUOCore, cible DUOUITests, icône et manifeste. Identifiant provisoire `fr.theolegoff.duo.dev`, version marketing 0.2.0, build 1, iOS 17+. Choisir un identifiant unique appartenant au compte de signature avant une distribution. L’équipe de signature est volontairement vide.

Le noyau a été compilé avec Swift 6.0.3 en mode Swift 5 sous Ubuntu. L’application nécessite le SDK Apple et **n’a pas été compilée dans cet environnement**. L’analyse syntaxique des fichiers SwiftUI ne remplace pas une compilation avec résolution des API Apple.

## Sur un Mac

1. Installer/ouvrir Xcode 16 ou plus récent, accepter ses composants et installer un simulateur iOS. Xcode 26 ou ultérieur permet de vérifier le style natif iOS 26.
2. Ouvrir `DUO.xcodeproj` → schéma DUO → simulateur iPhone. Run.
3. Lancer `Scripts/check-macos.sh`. Résultats dans `TestResults/` et bundle xcresult horodaté.
4. Tester les modes clair/sombre, la programmation traversant minuit, Dynamic Type, VoiceOver, Reduce Motion/Transparency, petit écran et fermeture/réouverture.
5. Pour un iPhone physique, sélectionner l’équipe de signature dans Xcode ou `Local.xcconfig`, puis le téléphone. Ne pas activer d’entitlement non nécessaire.

## Configurer Supabase — uniquement sur projet approuvé

Aucun projet n’a été créé, aucun backend n’a été déployé et aucune donnée personnelle n’a été transmise.

- Créer/choisir un projet de test vide dans une région adaptée, vérifier ses conditions et quotas au moment de l’activation.
- Appliquer `Backend/001_schema.sql` une fois. Ne pas exécuter aveuglément sur une base existante contenant d’autres tables homonymes.
- Activer la confirmation d’e-mail, imposer 12 caractères minimum côté Auth, vérifier les limites d’envoi d’e-mails et le fournisseur SMTP. Les restrictions du fournisseur intégré peuvent limiter les tests à deux personnes ; ne pas ajouter de service payant sans accord.
- Créer `Local.xcconfig` à côté de `Config.xcconfig` :

```text
DUO_BUNDLE_ID = votre.identifiant.unique
DUO_DEVELOPMENT_TEAM = VOTRE_TEAM_ID
SUPABASE_URL = https:/$()/votre-projet.supabase.co
SUPABASE_PUBLISHABLE_KEY = votre_cle_publique
```

`/$()/` évite que `//` soit traité comme un commentaire par le format xcconfig. Une URL https Supabase standard est requise par le client actuel. Ne jamais y placer de clé service-role.

Dans l’application : Réglages → créer le compte → confirmer l’e-mail → connexion → créer le foyer. Sur le second compte : connexion → rejoindre avec le code transmis manuellement. Le mode connecté dispose d’un cache distinct et n’importe pas le mode local.

Tester les pertes de réseau avant/après réponse, l’expiration de session, la reprise après arrêt forcé et les conflits. Le test PGlite utilise une fonction `auth.uid()` simulée pour les identités : il ne vérifie ni les JWT réels, ni l’envoi des e-mails, ni les réponses HTTP PostgREST.

Pour reproduire les tests SQL (Node/npm requis) :

```bash
cd Backend/tests
npm ci
node security.mjs
```

Pour les contrôles statiques facultatifs : `python3 -m pip install tree-sitter tree-sitter-swift pglast openstep-parser`, puis `python3 Scripts/validate.py`.

## TestFlight : pas encore prêt

Préconditions restantes : compilation/résolution des défauts iOS éventuels, tests réels de synchronisation, parcours de récupération/suppression de compte, notice de confidentialité adaptée, revue du manifeste, signature, archive et validation Xcode Organizer, fiche App Store Connect et informations de bêta.

Apple permet le développement et les essais sur appareil personnel avec un compte gratuit. TestFlight fait partie de l’Apple Developer Program ; le tarif officiel annoncé est de 99 USD/an ou l’équivalent local affiché à l’inscription. Aucun achat effectué. Les builds TestFlight expirent après 90 jours et la première bêta externe passe par une revue Apple. Une distribution TestFlight n’a pas été demandée ni effectuée dans cette livraison.

Sources Apple consultées le 29 octobre 2026 :

- https://developer.apple.com/help/account/membership/programs-overview/
- https://developer.apple.com/help/account/membership/program-enrollment
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- https://developer.apple.com/testflight/
- https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views

Documentation Supabase :

- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/auth/password-security
- https://supabase.com/docs/guides/auth/rate-limits

Ces vérifications ne remplacent pas celles que Xcode/App Store Connect imposeront au moment de l’envoi.
