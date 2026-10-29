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
