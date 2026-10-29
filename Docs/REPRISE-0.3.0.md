# DUO 0.3.0 — reprise du développement (29 octobre 2026)

## Provenance exacte

Reprise à partir de `DUO-iOS-native-v0.2.0.zip`, original conservé séparément. L'archive d'origine passait 49 tests du noyau Swift et contenait un journal historique de 31 tests SQL en PostgreSQL embarqué. Les captures du travail ultérieur mentionnent 57 tests Swift et 45 scénarios SQL, mais **le code correspondant n'était pas disponible dans l'archive 0.2.0** ; ces chiffres ne sont pas revendiqués pour cette version.

## Travaux réellement incorporés

- Récupération de mot de passe : demande d'e-mail, saisie du code de récupération Supabase, nouveau mot de passe d'au moins 12 caractères. Les jetons de cette opération ne sont pas sauvegardés dans le Keychain.
- Export des données visibles du cache de l'iPhone : fichier JSON Codable avec `Snapshot`, sans mot de passe ni jeton ; bouton de partage iOS. Un export n'est pas une sauvegarde garantie de toutes les données du serveur : synchroniser d'abord.
- Suppression de compte : confirmation écrite `SUPPRIMER`, double confirmation, appel à une fonction Edge authentifiée, effacement local du cache du compte **après confirmation serveur**, retour au stockage local indépendant.
- Migration SQL 002 : identification de l'auteur à la création des enregistrements, données privées effacées, enregistrements partagés du créateur remplacés par des tombstones anonymes, données du partenaire conservées ; blocage des anciennes sessions dans les opérations de foyer, même si le JWT est encore valide.
- Fonction Supabase Edge `delete-account` : utilise l'identité du JWT vérifié (jamais un ID choisi par le client) et la clé privilégiée uniquement côté serveur ; nettoyage transactionnel puis suppression de l'identité Auth. Retentative possible si la suppression Auth échoue après nettoyage.
- Workflow GitHub Actions macOS à **déclenchement manuel uniquement** pour compiler l'application et exécuter les tests XCUITest sur simulateur, sans tentative de publication et sans secrets de signature.
- Trois tests Swift supplémentaires : auteur persisté, compatibilité des anciens JSON sans auteur, tombstone expurgée.

## Exécution effectuée dans cette session

| Contrôle | Résultat | Limite |
|---|---|---|
| `swift test --jobs 1` | **52 tests XCTest réussis, 0 échec** | Moteur de règles, pas l'interface iOS |
| `swiftc -frontend -parse App/*.swift UITests/*.swift` | **Aucune erreur de syntaxe** | Pas de vérification des types SwiftUI ni des API Apple |
| Migration 002 et Edge Function | **Code écrit, pas de serveur déployé** | Aucun test sur base PostgreSQL ou API Supabase |
| Vérification Xcode et simulateur | **Non exécutée** | Environnement Linux, SDK iOS indisponible |
| Export, récupération, suppression sur deux iPhone | **Non exécutées** | Nécessitent Xcode, e-mails de test, backend approuvé |

Le test SQL historique (31) n'a **pas** été réexécuté : PGlite était absent et son installation hors ligne a échoué. Ne pas interpréter ces 31 tests comme une validation de la migration 002.

## Marche à suivre pour terminer, sans Mac personnel

### 1. Compiler sur un Mac hébergé

Créer un dépôt GitHub privé avec le **contenu du dossier `DUO/` à la racine** (pas le ZIP lui-même), puis lancer manuellement `Actions > DUO iOS build and tests (no distribution) > Run workflow`. Le job macOS exécute `Scripts/check-macos.sh`, tente de construire l'application et de lancer les tests iOS, puis archive les logs. Les coûts de minutes GitHub dépendent du compte/du dépôt : vérifier le quota et les paramètres de facturation avant d'exécuter. Aucun workflow ne démarre automatiquement.

Si le premier build échoue, corriger les erreurs *réelles* de `TestResults/build.log`, puis relancer. Ne pas affirmer que l'application compile avant un rapport de build vert.

### 2. Préparer un serveur de développement (seulement après validation de sa création)

Créer un projet Supabase distinct de production. Appliquer **dans cet ordre** `Backend/001_schema.sql`, puis `Backend/002_account_privacy.sql`. Déployer la fonction `Backend/functions/delete-account/index.ts` avec JWT vérifié. Configurer le modèle d'e-mail de récupération avec un code OTP `{{ .Token }}`. Ne jamais placer de `service_role`/secret dans l'application iPhone, le dépôt ou un fichier `.xcconfig`.

Renseigner uniquement URL et clé **publique** dans `Local.xcconfig`, non suivi par Git :

```xcconfig
SUPABASE_URL = https://VOTRE-PROJET.supabase.co
SUPABASE_PUBLISHABLE_KEY = VOTRE_CLE_PUBLIQUE
```

### 3. Tests iPhone indispensables

Avec **deux comptes fictifs** et deux iPhone/simulateurs : création, confirmation e-mail, récupération par code, invitation à usage unique, courses, aliments, tâches, synchronisation bidirectionnelle, conflits, mode hors-ligne, déconnexion, export sans secrets, suppression d'un compte et conservation des données du partenaire. Tester aussi la tentative de renvoi d'anciennes mutations depuis un appareil resté hors-ligne. Ces scénarios nécessitent un serveur de test ; aucune donnée réelle ne doit être détruite lors des vérifications.

### 4. Prêt à installer

Débloquer les défauts identifiés par Xcode, vérifier VoiceOver et Dynamic Type, revoir les documents confidentialité et manifestes, puis utiliser la signature Apple et TestFlight **après autorisation**. L'inscription Apple Developer peut occasionner un coût ; ne pas la souscrire automatiquement.

## Limites explicites de la suppression

La migration 002 attribue l'auteur **aux nouvelles données**. Les enregistrements partagés créés historiquement avant cette migration peuvent avoir un auteur inconnu et ne sont pas automatiquement attribués au hasard. Ce projet n'avait pas de backend hébergé, donc pas de données partagées historiques dans le service annoncé.

Un iPhone hors ligne conserve temporairement ses données locales : aucun système ne peut garantir un effacement instantané d'un appareil déconnecté. La migration évite cependant que son ancien compte réadhère au foyer ou republie les données supprimées. La suppression des fichiers locaux intervient lorsque cet iPhone reconnecté exécute lui-même le parcours de suppression, ou après une intervention manuelle sur l'appareil ; tester ce comportement avant une publication.
