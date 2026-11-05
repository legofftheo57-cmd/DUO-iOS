# Graphite & Ice

Les valeurs de référence sont des assets dynamiques sRGB. Elles ne sont pas remplacées par des approximations.

| Token | Clair | Sombre |
|---|---|---|
| Background | #F5F6F8 | #0B0D12 |
| Surface | #E5EAF1 | #222936 |
| Ice | #C4D0E0 | #5A6D89 |
| Accent | #9AAEC8 | #B6C9E5 |
| Text | #202632 | #F1F5FC |
| Secondary | #60728C | #B6C9E5 |
| SecondaryAccent | #697F9E | #B6C9E5 (variante) |
| SecondaryReadable | #53657D | #B6C9E5 |
| Control | #465D7B | #B6C9E5 |
| Error | #A12C36 | #FFADB5 |

La référence Secondary claire donne environ 4,06:1 sur Surface, sous 4,5:1 pour du texte courant. La variante SecondaryReadable atteint 4,93:1 et sert aux textes secondaires. Accent reste une référence décorative et ne sert pas seul à un petit texte interactif. Les 14 paires texte/surface utilisées ont été calculées ; ce n’est pas un audit visuel de tous les écrans ni des matériaux translucides.

Typographie système, styles sémantiques Dynamic Type, SF Symbols, zones tactiles de 44 points pour les contrôles dédiés, libellés d’accessibilité pour boutons iconiques, indication textuelle des erreurs/conflits. Listes et formulaires natifs ; cartes réservées au regroupement de l’accueil. Aucune image culinaire sans licence et aucune image artificielle utilisée pour remplir les écrans.

Icône originale dessinée par code : deux formes reliées en graphite/glacier, PNG opaque 1024×1024. Pas de photographie ni de ressource tierce à licencier.

Les matériaux SwiftUI standard sont utilisés ; Reduce Transparency reçoit un fond opaque sur les panneaux. Les contrôles standards bénéficient du style natif Liquid Glass sur les versions compatibles, sans appeler une API iOS 26 sur iOS 17. Pas d’animation personnalisée imposée ni de vibration automatique ajoutée : les transitions et interactions restent natives. Vérification Reduce Motion indispensable sur simulateur/appareil.

Le mode système renvoie `nil` à `preferredColorScheme`. Le mode horaire travaille en minutes locales, gère les intervalles traversant minuit et est recalculé toutes les 30 secondes lorsque l’application est affichée. Horaires identiques : mode clair. Le thème système et les réglages locaux persistent via AppStorage.

## Direction validée — 5 novembre 2026

Le propriétaire a retenu **le concept A / nº 1, Graphite & Ice**, mais considère la première maquette un peu trop dense. La version à livrer doit donc **conserver strictement la palette, l'ambiance sombre premium et les panneaux translucides** tout en retrouvant de l'air.

Décisions d'interface :
- **Quatre onglets fixes** : Accueil, Tâches, Courses, Planning ; la cuisine reste à un geste depuis l'accueil et la suggestion de repas.
- **Accueil organisé dans l'ordre d'utilité** : salutation, trois priorités maximum, actions rapides, indicateurs discrets, programme et idée de repas.
- **Moins de blocs à l'écran** : métriques limitées, maximum trois tâches visibles sur l'accueil ; le détail est disponible dans les écrans dédiés.
- **Plus d'espace et de contraste lisible** : espacement vertical plus généreux, icônes bleutées mesurées, libellés courts, cartes seulement pour les groupes cohérents.
- **Pas de fonction fictive** : pas d'avatars artificiels de partenaires, pas de répartition réelle entre deux iPhone, pas d'indicateur de budget courses sans données de prix.
- **Version solo d'abord** : toutes les données sur l'iPhone, sauvegarde JSON, aucune authentification ou synchronisation automatique.

L'image conceptuelle est une **direction visuelle**, pas une capture d'écran d'une version compilée. L'itération de l'interface doit être validée par une nouvelle compilation après les changements, puis testée sur iPhone.
