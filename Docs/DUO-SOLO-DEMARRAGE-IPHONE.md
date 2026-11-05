# DUO Solo — démarrage sur iPhone

Version initiale : **un seul iPhone**, sans compte ni connexion au cloud. Interface **Graphite & Ice**, sombre par défaut. L'application est native iOS (pas un site).

## Les 5 gestes les plus utiles

1. **Accueil → Tâche** : ajoutez une corvée ou une priorité. Trois tâches maximum apparaissent directement sur l'accueil ; toutes les autres restent dans l'onglet **Tâches**.
2. **Tâches → Ajouter une tâche habituelle** : choisissez la vaisselle, la lessive, l'aspirateur, les poubelles ou les draps. Pour une tâche répétée, utilisez l'échéance et la récurrence lors de la modification.
3. **Accueil → Course** ou **Courses → Ajouter un indispensable** : ajoutez un article, puis touchez le cercle lorsqu'il est acheté. Une course cochée ne modifie jamais automatiquement le stock du frigo.
4. **Accueil → Cuisine** : renseignez les aliments et quantités réellement disponibles, regardez les recettes puis planifiez des dîners. Les ingrédients manquants sont ajoutés à la liste après recalcul. Les prix magasin ne sont pas connectés : le budget affiché n'est pas garanti.
5. **Planning** : créez les rendez-vous et consultez vos événements, repas et tâches à échéance.

## Une erreur de coche ?

Dans **Tâches**, activez **Voir l'historique**, puis touchez la flèche de retour sur la tâche terminée pour la rouvrir. Pour une tâche récurrente, DUO refuse de supprimer automatiquement une future occurrence qui a déjà été modifiée, afin de ne pas perdre votre travail.

## À protéger avant toute réinstallation

Dans **Réglages → Confidentialité**, touchez **Préparer une copie de mes données**, puis **Enregistrer ou partager l'export** et placez le fichier JSON dans **Fichiers** ou un emplacement personnel de votre choix.

Pour restaurer : **Réglages → Confidentialité → Restaurer une sauvegarde DUO**. L'application valide le fichier et demande une confirmation avant de remplacer le contenu du téléphone.

La copie interne de DUO est locale et exclue de la sauvegarde iCloud de l'application. Une désinstallation peut effacer cette copie. **Ne jamais désinstaller l'application pour renouveler une signature : réinstaller par-dessus avec le même identifiant de bundle.**

## Installation initiale

La compilation GitHub produit un paquet **DUO-solo-unsigned-ipa** non signé. Depuis Windows, Sideloadly peut signer et installer ce paquet à l'aide d'un compte Apple gratuit ; il faudra connecter l'iPhone et renouveler la signature environ tous les sept jours.

**Aucune installation sur le téléphone, aucun test sur un appareil physique et aucune publication App Store ne sont encore attestés.** La présence d'un IPA ne prouve pas que tous les parcours UI passent. Suivre les résultats du run GitHub avant de le considérer prêt.
