# DUO — Finances réelles du couple : architecture et critères d'acceptation
_Date : 10 novembre 2026. **Spécification, pas une fonctionnalité livrée.** Aucune banque connectée, aucune donnée collectée, aucun prestataire contracté._

## Résultat attendu

Dans DUO, Théo et Lilou voient **les vrais soldes** de leurs comptes autorisés, les dépenses réellement comptabilisées par les banques, l'épargne, les dépenses communes et leur disponibilité pour leurs projets. Ils peuvent choisir quels comptes/champs sont visibles par l'autre. Les chiffres doivent rester justes quand une connexion échoue ou qu'un virement traverse deux comptes.

## Source de vérité et statuts

- **Solde réel** : valeur envoyée par la banque à un instant `synced_at`, avec type explicite (`booked`, `available` lorsque fourni), monnaie et état de connexion (`fresh`, `stale`, `auth_required`, `error`). La banque a autorité ; jamais de calcul à partir de transactions partielles pour *remplacer* un solde bancaire.
- **Opération réelle** : origine connecteur/compte/external_id ; états `pending` vs `booked`; déduplication stable ; réconciliation quand une opération en attente devient comptabilisée ; montants en centimes entiers (`Int64`, EUR).
- **Virement entre comptes du couple** : traité comme transfert interne, ni revenu ni dépense ; les deux moitiés sont rapprochées, sans double-compte.
- **Carte à débit différé** : ne pas compter deux fois les achats et le prélèvement mensuel de règlement de la carte ; traiter le type de carte et les opérations de compensation.
- **Dépense commune** : classification contrôlable et explicable, avec catégorie, payeur, bénéficiaire et règle de partage (50/50, proportionnelle ou personnalisée) choisie par le couple. Le remboursement interne ne devient pas un nouveau revenu.
- **Revenus** : uniquement transactions bancaires pointées comme revenus (salaires effectivement versés, remboursements selon catégorie). La fiche de paie est une prévision tant que la somme n'est pas arrivée sur le compte.
- **Épargne bancaire** : comptes d'épargne connectés lorsque le fournisseur prend ces produits en charge ; somme réelle déjà possédée, **pas** un nouveau revenu. Transfert compte courant → épargne = mouvement interne.
- **CET d'intérim** : source **manuelle/séparée**, montant brut différé, non assimilé à de la liquidité ou à de l'épargne immédiatement disponible. Pas d'API bancaire présumée. Conserver source, date et hypothèses de prélèvements.
- **Investissements** : valeur de portefeuille horodatée et origine déclarée ; si l'établissement n'est pas pris en charge, import relevé/manual. Bien distinguer dépôts, valeur de marché et gains/pertes latents.
- **Objectifs/projets** : affectations virtuelles d'une partie des fonds *déjà existants*, jamais création de valeur. Une somme ne peut pas être allouée simultanément à plusieurs projets ; total affectations <= total éligible disponible et contrôlé par l'utilisateur.

## Modèles fonctionnels à prévoir

```text
Household(id)
Member(id, household_id, role)
FinancialConnection(id, owner_user_id, provider, status, consent_expiry, last_sync)
FinancialAccount(id, connection_id, owner_user_id, type, currency, visibility)
BankBalance(account_id, kind, cents, observed_at, last_success_at, sync_status)
BankTransaction(id, provider_transaction_id, account_id, amount_cents, date, pending, category, transfer_group)
ManualAsset(id, owner_user_id, type, cents, gross_or_net, as_of_date, notes)
Goal(id, household_id, name, target_cents, due_date, visibility)
GoalAllocation(id, goal_id, account_id, amount_cents)
ExpenseSharing(transaction_id, rule_id, paid_by, participants, shares)
```

**Règle d'isolation :** un compte personnel reste privé par défaut, même pour deux utilisateurs du même foyer. Chaque utilisateur autorise explicitement le partage de l'intitulé, du solde ou des transactions de ses comptes. Des tables séparées, contrôles côté serveur, RLS et tests à deux identités sont nécessaires ; ne pas seulement masquer des champs en SwiftUI.

## Architecture de connexion financière

```text
iPhone Théo / iPhone Lilou
          │  auth DUO, requêtes TLS, rôle membre
          ▼
Backend DUO / Supabase (politiques RLS, API métier)
          │
          ├── Base: comptes autorisés, soldes horodatés, opérations, affectations, audit minimal
          └── Service de synchronisation serveur (secrets chiffrés, webhooks, file de tâches,
              limites, déduplication, purge, révocation des connexions)
                  │
                  ▼
          Prestataire Open Banking agréé (AIS *lecture seule*)
                  │ redirection et consentement de chacun
                  ▼
          Banque de Théo / banque de Lilou
```

- **Aucun identifiant bancaire dans le code Swift, GitHub, les journaux ou les discussions.**
- Les jetons prestataire secrets sont conservés uniquement dans un coffre côté serveur et ne sont jamais renvoyés à l'iPhone. Aucun `service_role` Supabase côté client.
- Ne pas activer de produits d'initiation de paiement (PIS) ni permettre des virements.
- Respecter le consentement, l'expiration, la déconnexion/révocation, la minimisation des données, la suppression/export.
- Prévoir idempotence de traitement des événements, chiffrement en transit/repos, contrôles d'accès **côté serveur**, authentification sûre, rate-limit et sauvegardes.
- Si la banque est indisponible, conserver les derniers montants **étiquetés anciens**, et désactiver toute suggestion fondée sur de l'argent prétendument actuel.

## Fournisseurs étudiés (à revalider lors de l'activation)

| Prestataire | Usage considéré | Réserve |
|---|---|---|
| **Enable Banking** | API soldes/transactions ; mode limité à ses propres comptes décrit dans la FAQ ; sandbox | Contrôler la couverture de chaque banque, l'éligibilité/contrat et la politique tarifaire. En production générale, minimum de facturation mensuel possible. |
| **GoCardless Bank Account Data** | API AIS PSD2 avec soldes/transactions ; accès EEE | Vérifier conditions d'usage actuelles, gratuité réelle et couverture, limites bancaires, maintenabilité. Ne pas supposer un accès inconditionnel illimité. |
| **Powens** | Couverture de banques, certains comptes d'épargne/investissements ; sandbox | Coûts de production et contractualisation non vérifiés ; fonctionnement généralement actualisé plusieurs fois par jour et non en continu. |
| **Bridge** | Agrégation comptes/transactions et suivi des statuts de rafraîchissement ; sandbox | Production à contractualiser et tarification à confirmer ; robustesse des cartes à débit différé à vérifier. |

Sources techniques : 
- https://enablebanking.com/docs/faq/
- https://enablebanking.com/knowledge-base
- https://docs.gocardless.com/docs/bank-account-data
- https://www.powens.com/fr/produits/transactions/
- https://docs.bridgeapi.io/docs/financial-data-aggregation
- https://eur-lex.europa.eu/eli/reg_del/2018/389/2023-07-25/eng

**Décision provisoire :** aucune intégration bancaire commerciale sans vérification des banques exactes, des produits épargne couverts et d'un coût documenté. Priorité à un essai sandbox ou mode comptes personnels éligible ; alternative manuelle/CSV clairement signalée comme telle.

## Phases avec critères de sortie non négociables

### A. DUO Solo installé
- IPA validé signé et lancé sur iPhone réel ; premier démarrage et redémarrage sans perte de données.
- Les opérations principales fonctionnent, le backup/export et l'import sont testés.
- Le module « Budget » manuel sur branche de travail est **un prototype**, pas un module bancaire : compiler, tester, puis décider de son rôle (fallback/avant connexion) avant intégration.

### B. Moteur financier indépendant et vérifié
- Tests pour montants négatifs, arrondis, overflow, multi-comptes, comptes à découvert, devise inattendue.
- Tests pour double-compte entre deux personnes, comptes épargne, transferts, paiements différés, remboursements, pending→booked et opérations dupliquées.
- Tests pour allocations de projets (réservations d'argent réellement détenu) et comptes non disponibles.
- Les écrans montrent sans ambiguïté « réel connecté », « manuel », « estimé » et « dernière mise à jour ».
- Le CET différé n'entre jamais dans « disponible aujourd'hui ».

### C. Vérification banque avec données de test
- Brancher un prestataire en sandbox sans divulguer de secrets et tester comptes, transactions, statut de connexion et invalidation des consentements.
- Ne pas prétendre que les comptes d'épargne, CET ou placements sont couverts sans test de la banque précise.
- Refuser les changements silencieux de solde en cas de pannes/erreurs de pagination.

### D. DUO à deux opérationnel
- Backend Supabase de test approuvé, deux utilisateurs réels ou tests, invitations à usage unique, règles RLS prouvées, confidentialité de chaque compte validée.
- Synchronisation en conditions réelles (deux appareils, hors-ligne, concurrence, changement de compte, session expirée).
- Connexion bancaire en lecture seule autorisée indépendamment par chaque partenaire, sous conditions du prestataire.
- Droit de révoquer, supprimer/exporter, séparations privé/commun validées.
- Tests iOS et tests utilisateurs signés : **seulement alors** appeler la fonction « disponible et fiable ».

## État du prototype Budget du 10/11 (ne pas enjoliver)

Le premier ajout `App/DUOApp.swift` crée une vue locale de saisie de revenus/dépenses/épargne et stockage JSON protégé. **Ne sait pas accéder à une banque, ne connaît pas les vrais soldes, n'est pas synchronisé entre iPhones, n'est pas compilé ni validé par la CI** ; le calcul « revenu − dépenses − épargne » représente un budget manuel, **pas** une valeur patrimoniale. Ce prototype ne doit ni entrer en production ni être présenté comme « Finances réelles » sans la refonte et les tests ci-dessus.

## Informations bloquantes à demander au moment de la connexion réelle

- Nom des banques **sans identifiants ni numéros de compte** pour chacun ; nature des comptes (courant, livret, PEA, CET).
- Niveau souhaité de confidentialité entre Théo/Lilou, règle de partage des dépenses communes.
- Accord séparé de chaque titulaire avant connexion bancaire et choix d'une formule tarifaire éventuellement payante.

## Coûts / actions non autorisées

Pas de dépenses, souscriptions, connexions à de vraies banques, déploiement de secrets, collecte de données personnelles ou publication sans validation explicite. **L'absence de banque compatible, de coût acceptable ou de consentement ne sera jamais masquée par des chiffres fictifs.**
