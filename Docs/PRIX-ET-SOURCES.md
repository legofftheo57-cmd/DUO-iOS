# Sources de prix : étude préalable

État au 29 octobre 2026. Aucun flux de prix connecté et aucune clé commerciale utilisée.

| Option | Disponibilité et fraîcheur | Couverture et coût | Conditions / décision |
|---|---|---|---|
| Open Prices / Open Food Facts | API REST et exports ; exports annoncés quotidiens, observations datées avec preuve et lieu | Contributions participatives : couverture des magasins et produits du foyer non mesurée ; accès public documenté, aucun abonnement engagé | Licence ODbL à respecter, attribution et contraintes de redistribution/combinaison. À évaluer avec des produits et magasins précis avant intégration |
| Saisie utilisateur à partir d’un ticket | Date, magasin, conditionnement et prix pourraient être explicitement saisis | Couverture limitée aux achats du foyer ; sans API payante | Modèle et calcul par paquet préparés, écran non développé. Option de reprise la plus simple |
| Catalogues enseignes | Aucune API nationale autorisée établie dans cette mission | Disponibilité, conditions et tarification non vérifiées enseigne par enseigne | Aucun scraping ni prix repris sans source autorisée |

Un export actualisé quotidiennement ne signifie pas que chaque prix a été observé ce jour-là. Un prix n’est utilisable que si le produit, le conditionnement, le lieu, la devise, la date et les conditions promotionnelles correspondent au contexte choisi. La limite de fraîcheur de sept jours dans le noyau est une politique de prototype, pas une garantie magasin. Le modèle courant n’a pas encore de géolocalisation ou de magasin : ne pas le brancher directement à un fournisseur avant cet ajout.

Le planificateur privilégie le stock et la variété. Même avec des prix complets, il applique une heuristique et ne prouve pas le minimum possible. Avec les données actuelles, l’interface doit conserver « budget non vérifiable » ; un budget de 35 € n’est jamais présenté comme respecté.

Sources primaires consultées :

- https://openfoodfacts.github.io/open-prices/guides/data/ — modalités d’accès et licence.
- https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorials/product-prices/ — collecte participative et preuves.
- https://openfoodfacts.github.io/open-prices/topics/core/ — données de prix, produits, preuves et lieux.
- https://openfoodfacts.github.io/open-prices/topics/data-quality/ — cohérence et validation des observations.

Les recettes sont rédigées pour ce projet ; aucun texte ou photo de recette provenant d’un site tiers n’est inclus. Les informations d’allergènes doivent être recoupées avec les emballages réellement utilisés.
