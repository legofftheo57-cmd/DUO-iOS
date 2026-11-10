# DUO — Vérification bancaire CIC, Revolut, Caisse d'Épargne
**Date de recherche : 10 novembre 2026.** Décision : **ne pas engager d'abonnement ni connecter les vrais comptes** sans validation des coûts, consentements et couverture des comptes précis.

## Banques réellement demandées
- Théo : **CIC** et **Revolut**.
- Lilou : **Caisse d'Épargne** (région exacte à sélectionner au moment de l'autorisation).
- Objectif : soldes bancaires effectivement lus, dépenses, épargne, projets, partage sélectif à deux utilisateurs DUO.

## Vérification de compatibilité (preuves publiques, pas des tests de connexion réelle)

| Banque | Powens (statut officiel) | Enable Banking | Points à tester |
|---|---|---|---|
| CIC | `Transactions / Tier A: Operational`, `Wealth & Loans / Tier A: Operational` | Documentation de marché FR couvrant le parcours CIC (semblable à Crédit Mutuel). | Compte courant, solde disponible et historique ; selon le produit, certains comptes anciens ne sont pas accessibles par PSD2. |
| Revolut | `Transactions / Tier A: Operational`; `Wealth & Loans / Tier B: Operational` | Documentation récente de Revolut EU et intégrations FR : oui en principe ; confirmer établissement/IBAN du compte. | Compte personnel, opérations cartes, multi-devises, poches d'épargne/trading ; ne jamais présumer de la couverture des produits hors PSD2. |
| Caisse d'Épargne | `Transactions / Tier A: Operational`; `Wealth & Loans / Tier A: Operational` | Documentations FR et liste des Caisses régionales ; connexion via Banque / Banxo avec authentification forte. | Caisse régionale, comptes courants, livrets, assurance vie, débit différé ; les données patrimoniales peuvent demander une seconde autorisation non PSD2. |

**Références**
1. Powens, statut opérationnel des connecteurs : https://powens.statuspal.eu/
2. Enable Banking, spécificités CIC et Caisse d'Épargne : https://enablebanking.com/docs/markets/fr/
3. Enable Banking, Revolut pris en charge en France (historique de mises à jour) : https://enablebanking.com/blog/2025/08/22/changelog-august-2025
4. iBanFirst, confirmation indépendante des trois banques pour la synchronisation (23 avril 2026) : https://support.ibanfirst.com/fr/articles/23203-banques-disponibles-pour-la-synchronisation-de-comptes-bancaires
5. Finary, Caisse d'Épargne + Powens et seconde autorisation de comptes d'épargne : https://help.finary.com/fr/articles/17640011-caisse-d-epargne-banque-populaire-credit-cooperatif-connecter-mon-compte

## Tarification et décision économique

| Prestataire | Ce que l'on sait | Ce qui n'est pas établi |
|---|---|---|
| **Enable Banking** | Sandbox ; mode production **restreint à des comptes explicitement pré-liés**, pour évaluation et usage individuel non commercial, sans contrat commercial initial. Production commerciale au volume + minimum de facturation mensuelle, **sur devis**. | Coût réel du mode restreint, conditions exactes permettant de lier aussi les comptes de Lilou et d'en faire profiter deux utilisateurs ; confirmer directement les ToS et éventuellement le support. Ne pas affirmer « gratuit pour vous deux ». |
| **Powens** | Très bonne couverture des 3 banques, connecteurs en état opérationnel ; produits Transactions et Wealth & Loans ; sandbox annoncée. | Prix public exploitable pour 3 connexions/2 personnes non trouvé ; offre plutôt B2B sur devis, pas de garantie de coût acceptable. |
| **Bridge** | Sandbox disponible ; documentation évoque période d'essai 30 jours puis passage production via Customer Success ; tarifs proposés sur devis. | Coûts et couverture opérationnelle des 3 comptes à confirmer avant sélection. |
| **GoCardless Bank Account Data** | Documentation API encore en ligne ; accès au portail et éligibilité à demander. Plusieurs sources de développeurs 2026 signalent nouveaux comptes fermés. | Ne pas miser sur un plan Nordigen historiquement gratuit ni promettre d'accès aujourd'hui. |

**Références :**
- https://enablebanking.com/docs/faq/
- https://enablebanking.com/docs/api/linked-accounts
- https://enablebanking.com/knowledge-base
- https://www.powens.com/fr/produits/agregation-donnees-financieres/
- https://www.powens.com/fr/produits/wealth-loans/
- https://support.bridgeapi.io/hc/fr-fr/articles/9798710145298-Cr%C3%A9ation-de-votre-application-de-Sandbox-Agr%C3%A9gation-Bancaire
- https://www.bridgeapi.io/bridge-et-vous/logiciels-de-paie-et-rh
- https://docs.gocardless.com/docs/bank-account-data

## Décision technique proposée (pas une intégration réalisée)

1. **Premier essai : Enable Banking**, en sandbox, pour standardiser la récupération des soldes, transactions et statuts de renouvellement. Examiner ensuite les ToS du mode restreint pour **deux titulaires**, avec une autorisation indépendante pour chacun. Si l'usage de Lilou ne peut pas être légalement ou techniquement couvert, **ne pas contourner** ces restrictions.
2. **Second choix : Powens** uniquement après avoir obtenu le prix chiffré pour 3 connexions + éventuels comptes épargne/placements. La présence d'un connecteur opérationnel ne garantit pas sa gratuité ni la disponibilité de tous les produits d'épargne.
3. **Plan de secours** : DUO doit rester fonctionnel en saisie manuelle et import CSV/OFX si banque inaccessible/consentement expiré. L'étiquette de provenance doit être visible à tout moment.
4. **Actualisation** : expliquer que la banque détermine la fraîcheur. Enable Banking documente jusqu'à quatre lectures par jour en arrière-plan pour de nombreuses banques ; davantage possible en présence utilisateur, sous limites de l'établissement. Afficher `dernier succès` et `à reconnecter`, sans prétendre au temps réel.
5. **Sécurité non négociable** : API d'information (AIS) lecture seule, authentification déléguée à la banque, aucun mot de passe bancaire dans DUO/GitHub/ChatGPT ; stockage des secrets du prestataire côté serveur, scopes minimaux et droits privés par défaut.

## Ce que DUO devrait afficher

- **Comptes courants connectés** : `CIC / Revolut / Caisse d'Épargne` ; solde observé, nature du solde et actualisation, erreurs de connexion visibles.
- **Épargne** : livrets & comptes d'épargne si le connecteur bancaire les fournit. Sinon montant manuel daté et étiqueté. Ne pas utiliser directement le CET Start People en montant net disponible : CET = brut différé, hors liquidités.
- **Projets** : objectifs (voyage, achat, dépenses logement), réserves virtuelles déduites du « non alloué », sans ajouter ni soustraire des fonds réellement détenus une seconde fois.
- **Couple** : dépenses communes, classification des virements internes, visibilité privée/partagée au niveau serveur, deux consentements séparés.

## Critères de passage de « compatible en principe » à « testé et opérationnel »

- [ ] L'utilisateur accepte explicitement un fournisseur et ses coûts (s'il y en a).
- [ ] Chacun effectue **lui-même** le consentement bancaire dans le parcours sécurisé de sa banque.
- [ ] Les 3 comptes courants retournent un solde, des transactions et une date de synchronisation cohérents.
- [ ] L'import gère pending→booked, doublons, pagination, transferts CIC↔Revolut et virements vers Caisse d'Épargne, débits différés.
- [ ] Les 2 utilisateurs voient uniquement les données autorisées ; tests d'accès interdit depuis l'autre profil.
- [ ] Les livrets/placements sont marqués « non disponibles » s'ils ne remontent pas, sans inventer de montant.
- [ ] Compte déconnecté ou consentement expiré : dernier solde affiché comme **périmé**, aucune fausse assertion « à jour ».
- [ ] Tests avec deux appareils puis installation/signature et essai réel.

**État effectif au 10/11/2026 : recherche documentaire seulement. Aucun token bancaire, aucun abonnement, aucune connexion réelle, aucune dépense.**
