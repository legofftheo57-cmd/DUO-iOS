# DUO — terminer sur le PC (24 novembre 2026)

Branche : `work/integration-ipa-20261124` (version 0.5.0 + budget du couple).
Durée totale : environ 45 min. iPhone de Théo et iPhone de Lilou + câbles USB.

## État de départ (vérifié le 24/11 à 6 h 20)

- TERMINÉ ET VÉRIFIÉ : compilation iPhone de cette branche (run 45332148305, `BUILD SUCCEEDED`, IPA de 884 Ko).
- TERMINÉ ET VÉRIFIÉ (5/11) : version Solo testée sur simulateur (run 42097144430), sauvegardée dans `Artifacts/`.
- PRÉPARÉ MAIS NON TESTÉ : parcours de la version budget sur simulateur ; connexion à deux (code présent, jamais essayée en vrai).

## Étape 1 — Créer le serveur gratuit du foyer (Supabase, ~10 min)

C'est lui qui permet aux deux téléphones de partager les mêmes courses, tâches et repas.
Offre gratuite, sans carte bancaire.

1. Aller sur supabase.com → *Start your project* → se connecter (GitHub ou e-mail).
2. *New project* : nom `duo`, région **Europe (Paris)**, mot de passe de base : bouton *Generate*, puis le garder dans ton gestionnaire de mots de passe (pas besoin de me le donner).
3. Une fois le projet prêt : menu **SQL Editor** → *New query* → coller tout le contenu de `Backend/INSTALL-SUPABASE-TOUT-EN-UN.sql` → **Run**. Attendu : « Success. No rows returned ».
4. Menu **Authentication → Sign In / Providers** : vérifier que *Email* est activé (c'est le cas par défaut).
5. Menu **Project Settings → API Keys** (ou *Data API*) : repérer
   - la **Project URL** (`https://xxxx.supabase.co`)
   - la clé **publishable** (ou *anon public*).
   **Ne jamais copier la clé `service_role` / `secret`.**

## Étape 2 — Donner ces deux valeurs à GitHub (~3 min)

Sur github.com/legofftheo57-cmd/DUO-iOS → **Settings → Secrets and variables → Actions → New repository secret** :

| Nom | Valeur |
|---|---|
| `SUPABASE_URL` | la Project URL |
| `SUPABASE_PUBLISHABLE_KEY` | la clé publishable |

## Étape 3 — Fabriquer l'app « foyer » (~5 min)

**Actions → DUO - build .ipa non signe (manuel) → Run workflow** → branche `work/integration-ipa-20261124` → *Run*.
(Ou écrire à Claude : « lance le build DUO ».)
Dans le journal, l'étape *Fabriquer* doit afficher « URL du foyer dans l'app : https://xxxx.supabase.co ».
Télécharger l'artefact **DUO-unsigned-ipa** et le décompresser.

## Étape 4 — Installer sur l'iPhone de Théo (~10 min)

1. Installer Sideloadly (sideloadly.io) et, s'il le demande, iTunes / iCloud version site Apple (pas Microsoft Store).
2. Brancher l'iPhone, déverrouiller, « Faire confiance à cet ordinateur ».
3. Glisser `DUO-unsigned.ipa` dans Sideloadly, saisir l'identifiant Apple **dans Sideloadly**, *Start*.
4. iPhone : Réglages → Confidentialité et sécurité → **Mode développeur** → activer (redémarrage). Puis Réglages → Général → VPN et gestion de l'appareil → faire confiance au profil.

## Étape 5 — Installer sur l'iPhone de Lilou (~10 min)

Même procédure en branchant son iPhone au même PC.
Si Sideloadly refuse avec l'identifiant Apple de Théo (limite des comptes gratuits), utiliser l'identifiant Apple de Lilou, qu'elle saisit elle-même.

## Étape 6 — Se connecter à deux (~5 min)

1. **Théo** : DUO → Réglages → *Notre espace commun* → **Créer mon compte** (e-mail + mot de passe de 12 caractères minimum) → cliquer le lien de confirmation reçu par e-mail (la page qui s'ouvre peut afficher une erreur : ce n'est pas grave, le compte est confirmé) → **Se connecter** → **Créer notre foyer**.
2. **Théo** : **Inviter Lilou / mon partenaire** → envoyer le lien par Messages. Valable 24 h, une seule fois. Un code de secours s'affiche aussi.
3. **Lilou** : ouvrir le lien (il ouvre DUO), **Créer mon compte** avec son propre e-mail, confirmer, **Se connecter**, puis **Accepter l'invitation et rejoindre le foyer**.
4. Test : Théo ajoute « Lait » aux courses → **Synchroniser maintenant** → Lilou fait **Synchroniser maintenant** : « Lait » doit apparaître. La synchro se fait aussi toute seule toutes les 30 s quand l'app est ouverte.

Envoyer à Claude une capture de chaque erreur rencontrée.

## Ce qui reste limité

- Les apps signées avec un identifiant Apple gratuit expirent au bout de 7 jours : re-signer **par-dessus** avec Sideloadly (ne pas supprimer l'app, sinon les données locales sont perdues).
- La suppression de compte en ligne et l'assistant IA en ligne demandent des fonctions serveur pas encore déployées : non nécessaires pour l'usage à deux.
- Sauvegarde conseillée : Réglages → Confidentialité → *Préparer une copie de mes données*.
