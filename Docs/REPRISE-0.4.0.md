# DUO 0.4.0 — invitation entre iPhone et assistant (29 octobre 2026)

## Périmètre vérifiable

Cette livraison reprend le projet natif iOS de DUO 0.3.0. Elle conserve SwiftUI, le design Graphite & Ice, les modèles métier, le stockage hors ligne, les RPC Supabase, les écrans existants et les migrations 001/002.

**Aucune compilation iOS, aucun compte Supabase réel, aucun envoi d'e-mail ou d'invitation, aucune facturation IA, aucune publication TestFlight n'ont été effectués.** Les modifications ci-dessous sont du code source, testable sur un Mac avec Xcode et sur une base de test validée.

## Parcours Lilou

1. L'application signée doit être installée sur les deux iPhone. Pour une première bêta privée, envisager TestFlight après inscription Apple Developer et autorisation explicite des coûts.
2. Une personne se connecte avec son compte et choisit « Créer notre foyer ».
3. Dans Réglages, choisir « Inviter Lilou / mon partenaire ». Le backend génère un code opaque, à usage unique, valable 24 heures, et invalidant les codes précédents du même foyer.
4. `ShareLink` présente Messages, WhatsApp, AirDrop, etc. avec un lien `duo://invite?token=...`. Le code reste affiché comme secours. L'installation de l'application ne se fait PAS automatiquement par ce lien.
5. Quand l'autre iPhone ouvre le lien (si le service de messagerie accepte les schémas personnalisés), DUO l'extrait et le conserve temporairement dans le Keychain local. L'utilisateur s'inscrit et confirme son e-mail si nécessaire, puis appuie sur « Accepter l'invitation ». Aucun compte n'est rejoint sans consentement et sans connexion.
6. La migration 001 contraint le foyer à deux personnes. Le code est haché SHA-256 dans la base, expire, et ne peut être consommé qu'une fois, sous verrou pour éviter les doubles utilisations simultanées.

**Limite UX** : un lien de schéma personnalisé `duo://` peut ne pas devenir cliquable dans certains services de messagerie. Le code de secours permet de rejoindre manuellement. Pour des liens HTTPS universels réellement fiables, il faudra un domaine contrôlé, un fichier Apple App Site Association et les entitlements `applinks:`. Rien de cela n'est prétendu déployé.

## Assistant DUO

Accès par l'icône « étincelles » dans la barre supérieure.

### Mode local inclus, sans cloud
- Suggestions de recettes à partir du catalogue DUO et du stock synchronisé/local, avec exclusion d'ingrédients/allergènes connus.
- Résumé des événements et tâches datés présents dans le cache iPhone.
- Aide à l'achat : critères pratiques sans invention de marques, stocks ou prix actuels.
- Commande limitée et déterministe : « Décale le sport à demain ». Identification de la tâche/événement, proposition respectant l'heure locale, signalement de chevauchement, puis bouton de **confirmation**. Rien n'est modifié avant confirmation.
- Pas de modèle de langage « hors ligne » : le moteur local est une aide à règles. Ne pas le présenter comme un LLM ou une compréhension universelle.

### IA conversationnelle en ligne, non activée
- Un bouton spécifique demande le consentement pour **chaque question** ; le seul corps envoyé au serveur est `{"question": ...}`. Aucune base de données, historique, recette privée ou jeton fournisseur ne part dans le corps. Le JWT utilisateur est transmis dans les en-têtes habituels de la connexion Supabase.
- Edge Function `duo-assistant`, authentifiée (JWT). Une migration optionnelle `003_ai_quota.sql` limite à 5 questions par utilisateur et par jour UTC. La suppression de compte efface les compteurs associés. Ceci ne constitue **pas** un plafond monétaire, à imposer côté fournisseur et à approuver avant toute activation.
- La clé `OPENAI_API_KEY` et le modèle `DUO_AI_MODEL` sont des secrets **uniquement sur Supabase**. Rien dans l'application ou dans le dépôt GitHub. `store:false` est demandé à l'API fournisseur, sans garantie générale sur toutes les règles de conservation du prestataire : la notice de confidentialité devra être mise à jour.
- Pas de facturation activée ; déploiement de la migration 003 et de la fonction seulement sur décision expresse. Le serveur limite la sortie à 350 tokens ; l'utilisateur n'a pas accès à des prix live dans cette fonction.
- **L'IA en ligne n'a aucun accès en écriture au planning.** Les suggestions de modifications sont exécutées uniquement par le mode local, après confirmation.

## Contrôles réellement exécutés

| Contrôle | Résultat | Portée |
|---|---|---|
| `swift test` | 60 XCTest réussis, 0 échec | Noyau Swift local et 8 nouveaux tests assistant / invitation |
| `swiftc -frontend -parse App/*.swift UITests/*.swift` | Syntaxe OK | N'est pas une compilation SwiftUI / iOS |
| `python Scripts/check_essentials.py` | 27/27 réussis | Références de sources, URL scheme, manifests, clés et fichiers |
| PostgreSQL migrations 001/002/003 | Pas exécutées durant cette reprise | Nécessite base de test et tests de sécurité |
| Edge Functions | Sources écrites, pas déployées | Nécessitent Supabase, variables serveur et tests authentifiés |
| Xcode / simulateur / deux iPhone | Pas exécutés | Mac hébergé/GitHub Actions et distribution Apple nécessaires |

Le script de vérification avancé `Scripts/validate.py` a des dépendances Python facultatives absentes de cette session. Le script autonome sans dépendance `Scripts/check_essentials.py` a été créé en complément ; il n'affirme ni une analyse PostgreSQL réelle ni une compilation Xcode.

## Étapes restantes, classées

**Bloquantes** : connexion GitHub autorisée par le propriétaire ; dépôt privé avec le contenu de `DUO/` à la racine ; workflow Actions manuel (le temps de calcul macOS peut être facturé selon le forfait) ; correction de toutes les erreurs de compilation et des UI tests ; projet Supabase de test approuvé avec migrations 001 puis 002 ; tests d'inscription/OTP, deux comptes, synchronisation offline, isolation RLS, conflits, résurrection après suppression, expiration et rejeu des invitations ; privacy/accessibilité sur appareils ; signature et distribution Apple.

**IA conversationnelle optionnelle** : décision de financer un fournisseur, plafond strict fixé dans son tableau de bord, migration 003 après 001/002, secrets côté serveur, déploiement du point d'entrée, revue des notices et des coûts, tests d'abus et d'authentification. La première version peut sortir avec l'assistant local uniquement.

**Pratiques** : App Store Connect / TestFlight selon les règles Apple ; onboarding Lilou, code manuel en secours ; tests de partage réel dans Messages/WhatsApp ; éventuellement domaine et Universal Links si on souhaite supprimer cette friction.

## GitHub : chemin immédiat

Une fois GitHub **effectivement connecté** à ChatGPT, créer un dépôt **privé** `duo-ios` pour le contenu du dossier `DUO/` (pas le ZIP comme unique fichier). Vérifier les frais/minutes Actions avant de cliquer sur `Actions > DUO iOS build and tests (no distribution) > Run workflow`. Aucun workflow ne se lance à chaque push : `workflow_dispatch` uniquement. L'intégration GitHub et la création du dépôt ne sont pas effectives dans cette livraison.
